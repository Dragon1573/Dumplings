$Object1 = Invoke-RestMethod -Uri 'https://updater.techsmith.com/TSCUpdate_deploy/Updates.asmx' -Method Post -Body @"
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <CheckForUpdates xmlns="http://localhost/TSCUpdater">
      <product>Snagit</product>
      <currentVersion>22.0.0</currentVersion>
      <language>ENU</language>
      <os>10.0.22000.0</os>
      <dotNet>4.8.9037</dotNet>
      <bitness>64</bitness>
    </CheckForUpdates>
  </soap:Body>
</soap:Envelope>
"@ -ContentType 'text/xml; charset=utf-8'

if ($Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult -is [string]) {
  $this.Log("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.NextVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.techsmith.com/snagit/releases/$($this.CurrentState.Version.Split('.')[0..2] -join '')/snagit.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromBurn
        UpgradeCode = $InstallerFile | Read-UpgradeCodeFromBurn
      }
    )

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = Get-RedirectedUrl -Uri $Object1.Envelope.Body.CheckForUpdatesResponse.CheckForUpdatesResult.InfoLink | Split-Uri -LeftPart Path
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/html/body/h2[contains(@id, '20$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
