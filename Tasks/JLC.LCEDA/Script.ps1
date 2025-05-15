$Object1 = Invoke-WebRequest -Uri 'https://lceda.cn/page/download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[2]/a').Attributes['href'].Value
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[1]/a').Attributes['href'].Value
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://lceda.cn/page/update-record' | ConvertFrom-Html
      $Object3 = [System.IO.StringReader]::new(($Object2.SelectSingleNode('//*[contains(@class, "doc-body-left")]') | Get-TextContent))

      while ($Object3.Peek() -ne -1) {
        $String = $Object3.ReadLine()
        if ($String -match "^v?$([regex]::Escape($this.CurrentState.Version))") {
          break
        }
      }
      if ($Object3.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object3.Peek() -ne -1) {
          $String = $Object3.ReadLine()
          if ($String -match '^(20\d{2}\.\d{1,2}\.\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } elseif ($String -notmatch '^v?(\d+(?:\.\d+)+)') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object3.Close()
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
