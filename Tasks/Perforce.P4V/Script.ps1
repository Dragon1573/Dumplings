$Object1 = (Invoke-RestMethod -Uri 'https://updates.perforce.com/static/P4V/P4V.json').versions | Where-Object -Property 'platform' -EQ -Value 'ntx64' | Sort-Object -Property { @([int]$_.major, [int]$_.minor) } -Bottom 1

# Version
$this.CurrentState.Version = "$($Object1.major -replace '^20').$($Object1.minor)"

# Installer
$this.CurrentState.Installer += $InstallerWix = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = "https://www.perforce.com/downloads/perforce/r$($this.CurrentState.Version)/bin.ntx64/p4vinst64.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = "https://www.perforce.com/downloads/perforce/r$($this.CurrentState.Version)/bin.ntx64/p4vinst64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFileWix = Get-TempFile -Uri $InstallerWix.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFileWix | Read-ProductVersionFromMsi
    # InstallerSha256
    $InstallerWix['InstallerSha256'] = (Get-FileHash -Path $InstallerFileWix -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $InstallerWix['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $InstallerWix['ProductCode'] = $InstallerFileWix | Read-ProductCodeFromMsi
        UpgradeCode = $InstallerFileWix | Read-UpgradeCodeFromMsi
      }
    )

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
