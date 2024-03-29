$Object1 = Invoke-WebRequest -Uri 'https://tv.sohu.com/down/index.shtml?downLoad=windows' | Read-ResponseContent -Encoding 'GBK' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText,
  '版本号([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri ('https:' + $Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/a').Attributes['href'].Value)
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.SelectNodes('//div[contains(@class, "down_winbox")]/div[2]/div/div') | Get-TextContent | Format-Text
}

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
