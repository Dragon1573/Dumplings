$Prefix = 'https://download.xnview.com/old_versions/XnConvert/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;P=*win*x64*.exe;F=0"

$InstallerName = $Object1.Links[1].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '-([\d\.]+)[-\.]').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}${InstallerName}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

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
