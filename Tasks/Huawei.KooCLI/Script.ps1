$Object1 = Invoke-RestMethod -Uri 'https://cn-north-4-hdn-koocli.obs.cn-north-4.myhuaweicloud.com/cli/latest/version.txt'

# Version
$this.CurrentState.Version = $Object1.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = "https://cn-north-4-hdn-koocli.obs.cn-north-4.myhuaweicloud.com/cli/$($this.CurrentState.Version)/huaweicloud-cli-windows-amd64.zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = 'hcloud.exe'
      PortableCommandAlias = 'hcloud'
    }
  )
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
