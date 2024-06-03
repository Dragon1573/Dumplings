$Object1 = Invoke-WebRequest -Uri 'https://www.enterprisedb.com/downloads/postgres-postgresql-downloads' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//table/tbody/tr[starts-with(./td[1]/text(), "12")][1]/td[5]/a').Attributes['href'].Value
}

# Version
$VersionMatches = [regex]::Match($InstallerUrl, '((12(\.\d+)+)-\d+)')
$this.CurrentState.Version = $VersionMatches.Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.postgresql.org/docs/release/$($VersionMatches.Groups[2].Value)/"
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
