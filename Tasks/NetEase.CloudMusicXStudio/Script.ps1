$Object1 = Invoke-RestMethod -Uri 'https://xstudio-singer.xiaoice.com/version/update' -Headers @{
  'architecture-abi'      = 'x86_64'
  'platform-with-version' = 'Windows'
}

# Version
$this.CurrentState.Version = $Object1.latest.name

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Object1.latest.release.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.latest.release.date | ConvertTo-UtcDateTime -Id 'UTC'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.latest.release.content | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
