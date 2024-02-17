# Download
$Object1 = Invoke-RestMethod -Uri 'https://jsonschema.qpic.cn/2993ffb0f5d89de287319113301f3fca/179b0d35c9b088e5e72862a680864254/config'
# Upgrade x64
$Prefix2 = 'https://dldir1v6.qq.com/weiyun/electron-update/release/x64/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix2 -Locale 'zh-CN'
# Upgrade x86
$Prefix3 = 'https://dldir1v6.qq.com/weiyun/electron-update/release/win32/'
$Object3 = Invoke-RestMethod -Uri "${Prefix3}latest-win32.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix3 -Locale 'zh-CN'

if ((Compare-Version -ReferenceVersion $Object1.electron_win64.version -DifferenceVersion $Object2.Version) -gt 0) {
  $Identical = $true
  if ($Object2.Version -ne $Object3.Version) {
    $this.Log('Distinct versions detected', 'Warning')
    $Identical = $false
  }

  $this.CurrentState = $Object2
  $this.CurrentState.Installer = $Object3.Installer + $this.CurrentState.Installer
  $this.CurrentState.Installer.ForEach({ $_.InstallerUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com') })
} else {
  $Identical = $true
  if ($Object1.electron_win64.version -ne $Object1.electron_win32.version) {
    $this.Log('Distinct versions detected', 'Warning')
    $Identical = $false
  }

  # Version
  $this.CurrentState.Version = $Object1.electron_win64.version

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Object1.electron_win32.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Object1.electron_win64.download_url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
  }

  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Object1.electron_win64.date | Get-Date -Format 'yyyy-MM-dd'
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
