$Prefix = 'https://ftpmirror.gnu.org/octave/windows/'

$Object1 = Invoke-WebRequest -Uri 'https://ftp.gnu.org/gnu/octave/windows/?C=N;O=D;V=1;F=0;P=*-w64-installer.exe' | ConvertFrom-Html

$InstallerName = $Object1.SelectSingleNode('/html/body/ul/li[2]/a').Attributes['href'].Value

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Prefix + $InstallerName
  ProductCode  = "Octave-${InstallerName} (Local)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = $Prefix + $InstallerName
  ProductCode  = "Octave-${InstallerName}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://octave.org/feed.xml').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://octave.org/news.html'
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://octave.org/news.html'
      }
    }

    try {
      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
