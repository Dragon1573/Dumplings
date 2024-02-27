$Object1 = $Global:LocalStorage.JetBrainsApps.TBA.release

# Version
$this.CurrentState.Version = $Object1.build

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.downloads.windows.link
}
# $this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
#   Architecture           = 'arm64'
#   InstallerUrl           = $Object1.downloads.windowsARM64.link
# }

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.date | Get-Date -Format 'yyyy-MM-dd'

if ($Object1.whatsnew) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Object1.whatsnew | ConvertFrom-Html | Get-TextContent | Format-Text
  }
} else {
  $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.notesLink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.downloads.windows.checksumLink).Split()[0].ToUpper()
    # $InstallerARM64['InstallerSha256'] = (Invoke-RestMethod -Uri $Object1.downloads.windowsARM64.checksumLink).Split()[0].ToUpper()

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
