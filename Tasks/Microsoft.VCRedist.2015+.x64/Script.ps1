$ManifestFile = $Global:DumplingsStorage.VisualStudioManifestFile

$StreamReader = [System.IO.StreamReader]::new($ManifestFile)
$JsonTextReader = [Newtonsoft.Json.JsonTextReader]::new($StreamReader)

$PackageId = 'Microsoft.VisualCpp.Redist.14'
$PackageChip = 'x64'

$Mode = 0

while ($JsonTextReader.Read()) {
  if ($Mode -eq 0) {
    if ($JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::PropertyName -and $JsonTextReader.Value -eq 'id') {
      if ($JsonTextReader.Read() -and $JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::String -and $JsonTextReader.Value -eq $PackageId) {
        $Mode = 1
      }
    }
  } elseif ($Mode -eq 1) {
    if ($JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::PropertyName) {
      switch ($JsonTextReader.Value) {
        'version' {
          if ($JsonTextReader.Read() -and $JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::String) {
            # Version
            $this.CurrentState.Version = $JsonTextReader.Value
          }
        }
        'chip' {
          if ($JsonTextReader.Read() -and $JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::String -and $JsonTextReader.Value -eq $PackageChip) {
            $Mode = 2
          }
        }
      }
    }
  } elseif ($Mode -eq 2) {
    if ($JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::PropertyName -and $JsonTextReader.Value -eq 'fileName') {
      if ($JsonTextReader.Read() -and $JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::String -and $JsonTextReader.Value -eq 'VC_redist.x64.exe') {
        $Mode = 3
      }
    }
  } elseif ($Mode -eq 3) {
    if ($JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::PropertyName -and $JsonTextReader.Value -eq 'url') {
      if ($JsonTextReader.Read() -and $JsonTextReader.TokenType -eq [Newtonsoft.Json.JsonToken]::String) {
        # Installer
        $this.CurrentState.Installer += [ordered]@{
          Architecture = 'x64'
          InstallerUrl = $JsonTextReader.Value
        }
        break
      }
    }
  }
}

$JsonTextReader.Close()
$StreamReader.Close()

if ($Mode -ne 3) {
  throw "The package ${PackageId} with architecture ${PackageArch} was not found"
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
