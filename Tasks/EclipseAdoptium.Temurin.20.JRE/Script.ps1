$Object1 = Invoke-RestMethod -Uri 'https://api.adoptium.net/v3/assets/latest/20/hotspot?image_type=jre&os=windows'

$Object2 = $Object1 | Where-Object -FilterScript { $_.binary.architecture -eq 'x64' } | Select-Object -First 1

# Version
$this.CurrentState.Version = "$($Object2.version.major).$($Object2.version.minor).$($Object2.version.security).$($Object2.version.build)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.binary.installer.link
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.binary.updated_at.ToUniversalTime()

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object2.release_link | ConvertTo-UnescapedUri
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
