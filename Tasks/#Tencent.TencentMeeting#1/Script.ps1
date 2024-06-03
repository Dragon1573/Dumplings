$OldReleaseNotesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleaseNotesPath) {
  $Global:DumplingsStorage['TencentMeeting1'] = $OldReleaseNotes = Get-Content -Path $OldReleaseNotesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['TencentMeeting1'] = $OldReleaseNotes = [ordered]@{}
}

# x86
$Object1 = Invoke-RestMethod -Uri 'https://meeting.tencent.com/web-service/query-download-info?q=[{"package-type":"app","channel":"0300000000","platform":"windows"}]&nonce=AAAAAAAAAAAAAAAA'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://meeting.tencent.com/web-service/query-download-info?q=[{"package-type":"app","channel":"0300000000","platform":"windows","arch":"x86_64"}]&nonce=AAAAAAAAAAAAAAAA'

if ($Object1.'info-list'[0].version -ne $Object2.'info-list'[0].version) {
  $this.Log("x86 version: $($Object1.'info-list'[0].version)")
  $this.Log("x64 version: $($Object2.'info-list'[0].version)")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object2.'info-list'[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = $Object1.'info-list'[0].url.Replace('.officialwebsite', '')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object2.'info-list'[0].url.Replace('.officialwebsite', '')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.'info-list'[0].'sub-date' | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleaseNotes[$this.CurrentState.Version] = [ordered]@{
      InstallerUrl    = $InstallerUrl
      InstallerUrlX64 = $InstallerUrlX64
      ReleaseTime     = $this.CurrentState.ReleaseTime
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleaseNotes | ConvertTo-Yaml -OutFile $OldReleaseNotesPath -Force
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
}
