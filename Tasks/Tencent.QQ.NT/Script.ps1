$Object1 = Invoke-RestMethod -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.ntVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.ntDownloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.ntDownloadX64Url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.ntPublishTime | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-FileVersionFromExe

    try {
      # Only parse version for major updates
      if (-not $this.LastState.Contains('Version') -or ($this.CurrentState.Version.Split('.')[0..2] -join '.') -ne ($this.LastState.Version.Split('.')[0..2] -join '.')) {
        $Object2 = Invoke-RestMethod -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsQQVersionList.js' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

        $ReleaseNotesObject = $Object2.ntLogs.Where({ $_.version.EndsWith($Object1.ntVersion) }, 'First')
        if ($ReleaseNotesObject) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject[0].features.text | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
    $this.Submit()
  }
}
