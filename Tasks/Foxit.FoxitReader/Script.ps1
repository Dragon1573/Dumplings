$Object1 = Invoke-RestMethod -Uri 'https://www.foxit.com/portal/download/getdownloadform.html?retJson=1&platform=Windows&product=Foxit-Enterprise-Reader&formId=pdf-reader-enterprise-register'

# Version
$this.CurrentState.Version = $Object1.package_info.version[0]

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down.Replace('.exe', '_Prom.exe')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.package_info.release, 'MM/dd/yy', $null).ToString('yyyy-MM-dd')

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.foxit.com/pdf-reader/version-history.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@id='version_$($this.CurrentState.Version)_detail']")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./*[position()>2]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
