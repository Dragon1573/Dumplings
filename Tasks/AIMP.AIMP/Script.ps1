# x86
$Object1 = Invoke-RestMethod -Uri 'http://update.aimp.ru/' -Body @{
  id = '1'
  b  = $this.LastState.Contains('Build') ? $this.LastState.Build : '2563'
  p  = 'aimp'
  u  = '1'
}
# x64
$Object2 = Invoke-RestMethod -Uri 'http://update.aimp.ru/' -Body @{
  id = '1'
  b  = $this.LastState.Contains('Build') ? $this.LastState.Build : '2563'
  p  = 'aimp64'
  u  = '1'
}

if ($Object1.update.version.build -ne $Object2.update.version.build) {
  $this.Log("x86 version: $($Object1.update.version)")
  $this.Log("x64 version: $($Object2.update.version)")
  throw 'Inconsistent versions detected'
}

# Build
$this.CurrentState.Build = $Object2.update.version.build

# Version
$this.CurrentState.Version = ($Object2.update.version.title -replace '^v') + '.' + $Object2.update.version.build

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.update.version.setuplink
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.update.version.setuplink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object2.update.version.date, 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')

      # ReleaseNotes
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotes'
        Value = $Object2.update.message -replace '\[b\](.+?)\[/b\]', '$1' | Format-Text
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
