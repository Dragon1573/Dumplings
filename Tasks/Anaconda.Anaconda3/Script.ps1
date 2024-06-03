$Prefix = 'https://repo.anaconda.com/archive/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object1.Links.href | Where-Object -FilterScript { $_.EndsWith('.exe') -and $_.Contains('x86_64') -and $_.Contains('Anaconda3-') } | Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '-([\d\.]+(-\d+)?)-').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}${InstallerName}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # ProductCode / AppsAndFeaturesEntries (DisplayName)
    $PythonVersion = [regex]::Match(
      (7z.exe e -y -so $InstallerFile 'conda-meta\history' | Select-String -Pattern '::python-' -Raw | Select-Object -First 1),
      '::python-([\d\.]+)'
    ).Groups[1].Value
    $this.CurrentState.Installer[0]['ProductCode'] = "Anaconda3 $($this.CurrentState.Version) (Python ${PythonVersion} 64-bit)"

    try {
      $ReleaseNotesUrl = 'https://docs.anaconda.com/free/anaconda/release-notes/'
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//section[@id='anaconda-release-notes']/section[contains(./h2/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.SelectSingleNode('./h2/text()').InnerText, '\(([a-zA-Z]+\W+\d{1,2}\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove link marks
        $ReleaseNotesNode.SelectNodes('.//a[@class="headerlink"]').ForEach({ $_.Remove() })
        # Remove "Packages"
        $ReleaseNotesNode.SelectNodes('.//details').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./h2/following-sibling::node()') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesNode.SelectSingleNode('./h2/text()').InnerText.ToLower() -creplace '[^a-zA-Z0-9]+', '-').Trim('-')
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
      }
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
