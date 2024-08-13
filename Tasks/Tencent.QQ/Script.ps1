$Object1 = Invoke-WebRequest -Uri 'https://im.qq.com/pcqq/index.shtml'
$Object2 = Invoke-RestMethod -Uri ([regex]::Match($Object1.Content, 'rainbowConfigUrl\s*=\s*"(.+?)"').Groups[1].Value) | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $InstallerUrl = $Object2.downloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '((\d+\.\d+\.\d+).\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.publishTime | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-FileVersionFromExe

    try {
      # Only parse version for major updates
      if (-not $this.LastState.Contains('Version') -or ($this.CurrentState.Version.Split('.')[0..2] -join '.') -ne ($this.LastState.Version.Split('.')[0..2] -join '.')) {
        $Object3 = Invoke-RestMethod -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsQQVersionList.js' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

        $ReleaseNotesObject = $Object3.ntLogs.Where({ $_.version.EndsWith($Object2.version) }, 'First')
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
  }
  'Updated' {
    $this.Submit()
  }
}
