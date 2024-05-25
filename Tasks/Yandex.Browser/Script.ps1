$Object1 = Invoke-RestMethod -Uri 'https://api.browser.yandex.com/update-info/browser/int/win-int.rss' -Body @{
  version = $this.LastState.Contains('Version') ? $this.LastState.Version : '24.4.4.1168'
  custo   = 'yes'
  manual  = 'yes'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.cdn.yandex.net/browser/int/$([regex]::Match($Object1.guid64, '/(\d+_\d+_\d+_\d+_\d+)').Groups[1].Value)/en/Yandex.exe"
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.pubDate, 'ddd, dd MMM yyyy HH:mm:ss "UTC"', (Get-Culture -Name 'en-US')) | ConvertTo-UtcDateTime -Id 'UTC'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
