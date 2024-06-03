# Download
$Version1 = @($Global:DumplingsStorage['TencentMeeting1'].Keys)[-1] ?? '0'
# Upgrade
$Version2 = @($Global:DumplingsStorage['TencentMeeting2'].Keys)[-1] ?? '0'

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Version2) -le 0) {
  # Version
  $this.CurrentState.Version = $Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Global:DumplingsStorage['TencentMeeting1'].$Version1.InstallerUrl
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Global:DumplingsStorage['TencentMeeting1'].$Version1.InstallerUrlX64
  }
} else {
  # Version
  $this.CurrentState.Version = $Version = $Version2

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Global:DumplingsStorage['TencentMeeting2'].$Version2.InstallerUrl
  }
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Global:DumplingsStorage['TencentMeeting2'].$Version2.InstallerUrlX64
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage['TencentMeeting1'].Contains($Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['TencentMeeting1'].$Version.ReleaseTime
      }

      if ($Global:DumplingsStorage['TencentMeeting2'].Contains($Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['TencentMeeting2'].$Version.ReleaseNotesCN
        }
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
