$Object1 = Invoke-WebRequest -Uri 'https://u.y.qq.com/cgi-bin/musicu.fcg' -Method Post -Body (
  @{
    comm                                              = @{
      ct       = '19'
      cv       = '0'
      tmeAppID = 'qqmusic'
    }
    'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate' = @{
      method = 'QueryUpdate'
      module = 'platform.uniteUpdate.UniteUpdateSvr'
      param  = @{}
    }
  } | ConvertTo-Json -Compress
) | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgVersion.ToString().Insert(2, '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com') | ConvertTo-Https
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = '"' + $Object1.'platform.uniteUpdate.UniteUpdateSvr.QueryUpdate'.data.pkgDesc + '"' | ConvertFrom-Json | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://y.qq.com/download/download.html' | ConvertFrom-Html

      if ($Object2.SelectSingleNode('/html/body/div[2]/div[2]/ul/li[1]/h3/span').InnerText.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $Object2.SelectSingleNode('/html/body/div[2]/div[2]/ul/li[1]/ul/li[last()]').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
