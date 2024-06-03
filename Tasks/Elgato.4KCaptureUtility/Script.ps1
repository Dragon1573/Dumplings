$Object1 = Invoke-RestMethod -Uri 'https://gc-updates.elgato.com/windows/spotlight-update/1.0.0/final/update.php'

# Version
$this.CurrentState.Version = $Object1.Update.ReleaseManualUpdate.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Update.ReleaseManualUpdate.DownloadUrl64
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.Update.ReleaseManualUpdate.Date, 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = $Object1.Update.ReleaseManualUpdate.ReleaseNotes.LocalizedText.Where({ $_.Language -eq 'English' }, 'First')[0].Text.'#cdata-section' | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('/html/body') | Get-TextContent | Format-Text
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
