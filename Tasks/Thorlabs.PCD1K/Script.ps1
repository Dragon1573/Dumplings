$Object1 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/software_pages/check_updates.cfm?ItemID=PCD1K'

# Version
$this.CurrentState.Version = $Object1.ItemID.SoftwarePkg.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink.Replace('\', '/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Media\Components\PockelsCellDriver\PockelsCellDriver_Setup.exe' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'PockelsCellDriver_Setup.exe'
      $InstallerFile2Extracted = $InstallerFile2 | Expand-InstallShield
      $InstallerFile3 = Join-Path $InstallerFile2Extracted 'PockelsCellDriver.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
