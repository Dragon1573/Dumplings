# Global
$Object1 = Invoke-WebRequest -Uri 'https://www.hihonor.com/global/tech/honor-suite/' | ConvertFrom-Html
$Version1 = [regex]::Match(
  $Object1.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# China
$Object2 = Invoke-WebRequest -Uri 'https://www.hihonor.com/cn/tech/honor-suite/' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $this.Log('Distinct versions detected', 'Warning')
  $this.Log("Global version: ${Version1}")
  $this.Log("China version: ${Version2}")
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Version = $Version2

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/div[1]/a[1]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/div[1]/a[1]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object2.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('HonorSuite') -and $Global:DumplingsStorage.HonorSuite.Contains($Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HonorSuite.$Version.ReleaseNotesEN
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HonorSuite.$Version.ReleaseNotesCN
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
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
