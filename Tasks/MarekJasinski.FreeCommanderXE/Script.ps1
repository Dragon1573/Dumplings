$Object1 = Invoke-WebRequest -Uri 'https://freecommander.com/files/WebVersion32.txt' | Read-ResponseContent | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Public.Build

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://freecommander.com/downloads/FreeCommanderXE-32-public_setup$($this.CurrentState.Version).zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'FreeCommanderXE-32-public_setup.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'FreeCommanderXE-32-public_setup.exe'

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://freecommander.com/files/WebVersionHistory.txt' | Read-ResponseContent | ConvertFrom-Ini

      if ($Object2.Contains("Changes_$($this.CurrentState.Version)")) {
        $Object3 = $Object2."Changes_$($this.CurrentState.Version)"

        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object3.Date, 'dd.MM.yyyy', $null).Tostring('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $ReleaseNotesList = [System.Collections.Generic.List[string]]::new()
        for ($i = 1; $Object3.Contains($i.ToString()); $i++) {
          $ReleaseNotesList.Add($Object3[$i.ToString()])
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesList | Format-Text
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
