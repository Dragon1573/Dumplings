# Global
$Object1 = Invoke-RestMethod -Uri 'https://cubox-official-resource.s3.us-west-1.amazonaws.com/desktop/update.json'
# China
$Object2 = Invoke-RestMethod -Uri 'https://update.cubox.pro/update.json'

# Version
$this.CurrentState.Version = $Object1.version

$Identical = $true
if ($Object1.version -ne $Object2.version) {
  $this.Log('Distinct versions detected', 'Warning')
  $this.Log("Global version: $($Object1.version)")
  $this.Log("China version: $($Object2.version)")
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.platforms.'windows-x86_64'.url
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Cubox_$($this.CurrentState.Version)_x64_en-US.msi"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale      = 'zh-CN'
  InstallerUrl         = $Object2.platforms.'windows-x86_64'.url
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Cubox_$($this.CurrentState.Version)_x64_zh-CN.msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime() ?? $Object2.pub_date.ToUniversalTime()
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
