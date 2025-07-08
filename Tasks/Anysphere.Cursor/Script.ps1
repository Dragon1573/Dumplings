# The hash part of the URL is the SHA256 hash of the machine GUID from HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography\MachineGuid
# Use a random hash here
$Hash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes([guid]::NewGuid().Guid))).ToLower()
# x64 user
$Object1 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-x64-user/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeX64User'
if ($StatusCodeX64User -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# x64 machine
$Object2 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-x64/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeX64Machine'
if ($StatusCodeX64Machine -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# arm64 user
$Object3 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-arm64-user/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeARM64User'
if ($StatusCodeARM64User -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# arm64 machine
$Object4 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-arm64/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeARM64Machine'
if ($StatusCodeARM64Machine -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.productVersion } -Unique).Count -gt 1) {
  $this.Log("x64 user version: $($Object1.productVersion)")
  $this.Log("x64 machine version: $($Object2.productVersion)")
  $this.Log("arm64 user version: $($Object3.productVersion)")
  $this.Log("arm64 machine version: $($Object4.productVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = $Object3.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'machine'
  InstallerUrl = $Object4.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object5 = Invoke-WebRequest -Uri 'https://www.cursor.com/changelog' | ConvertFrom-Html

      $ReleaseNotesTitleObject = $Object5.SelectSingleNode("//main//article[contains(.//div[contains(@class, 'absolute') and contains(@class, 'left')]//div[contains(@class, 'rounded')], '$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
      if ($ReleaseNotesTitleObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleObject.SelectSingleNode('.//div[contains(@class, "absolute") and contains(@class, "left")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove video players
        $Object5.SelectNodes('.//*[contains(@aria-label, "Video player container")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleObject.SelectNodes('.//h2[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
