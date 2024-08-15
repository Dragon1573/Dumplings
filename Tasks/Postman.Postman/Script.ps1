$Object1 = Invoke-RestMethod -Uri 'https://dl.pstmn.io/update/status' -Body @{
  channel        = 'stable'
  currentVersion = $this.LastState.Contains('Version') ? $this.LastState.Version : '10.24.26'
  arch           = '64'
  platform       = 'win64'
} -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = (($Object1.notes | ConvertFrom-Json).'Release Notes' | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
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
