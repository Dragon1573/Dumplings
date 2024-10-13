function Get-Version {
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.DashboardInstallerSA.exe' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted '2.DashboardInstallerSA.exe'
  $this.CurrentState.Version = [regex]::Match(
    (powershell.exe -NoProfile -Command "[System.IO.StreamReader]::new([System.Reflection.Assembly]::LoadFile('$InstallerFile2').GetManifestResourceStream('Installer.Resources.dashboard_version.h')).ReadToEnd()"),
    'DASHBOARD_VERSION\s+"([\d\.]+)"'
  ).Groups[1].Value
}

function Get-ReleaseTime {
  try {
    if ($Global:DumplingsStorage.Contains('Dashboard') -and $Global:DumplingsStorage.Dashboard.Contains($this.CurrentState.Version)) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.Dashboard[$this.CurrentState.Version].ReleaseTime
    } else {
      $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://wddashboarddownloads.wdc.com/wdDashboard/DashboardSetupSA.exe'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  Get-Version
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseTime

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  Get-Version
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseTime

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag was not updated
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
# Version
Get-Version
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseTime

# Case 4: The ETag was updated, but the hash wasn't
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag was changed, but the hash is the same', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, hash, and version were updated
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: Both the ETag and the hash were updated, but the version wasn't
  Default {
    $this.Log('The ETag and the hash were changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
