# x64
$InstallerUrl1 = Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x64.exe'
$Version1 = [regex]::Match($InstallerUrl1, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

# x86
$InstallerUrl2 = Get-RedirectedUrl -Uri 'https://www.swi-prolog.org/download/stable/bin/swipl-latest.x86.exe'
$Version2 = [regex]::Match($InstallerUrl2, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl2
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl1
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = "https://www.swi-prolog.org/ChangeLog?branch=stable&from=$($this.LastState.Version)&to=$($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
