$Prefix = 'https://cloud.r-project.org/bin/windows/Rtools/'

$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

$MainVersion = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/table/tr[contains(./td[2]/text(), "R-release")]/td[1]/a').InnerText,
  'RTools ([\d\.]+)'
).Groups[1].Value
$MainVersionShort = $MainVersion.Replace('.', '')

$Object2 = Invoke-WebRequest -Uri "${Prefix}rtools${MainVersionShort}/files/"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = "${Prefix}rtools${MainVersionShort}/files/$($Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('aarch64') } catch {} }, 'First')[0].href)"
  ProductCode  = "Rtools${MainVersionShort}_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrlARM64 = "${Prefix}rtools${MainVersionShort}/files/$($Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('aarch64') } catch {} }, 'First')[0].href)"
  ProductCode  = "Rtools${MainVersionShort}-aarch64_is1"
}

$BuildX64 = [regex]::Match($InstallerUrlX64, "rtools${MainVersionShort}-(\d+)").Groups[1].Value
$BuildARM64 = [regex]::Match($InstallerUrlARM64, "rtools${MainVersionShort}-aarch64-(\d+)").Groups[1].Value
$FullVersionX64 = "${MainVersion}.${BuildX64}"
$FullVersionARM64 = "${MainVersion}.${BuildARM64}"

if ($FullVersionX64 -ne $FullVersionARM64) {
  $this.Log("x64 version: ${FullVersionX64}")
  $this.Log("arm64 version: ${FullVersionARM64}")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $FullVersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "${Prefix}rtools${MainVersionShort}/news.html"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("/html/body/h3[contains(text(), '${BuildX64}')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
    if ($this.LastState.Contains('Version') -and ($this.LastState.Version.Split('.')[0..1] -join '.') -eq $MainVersion) {
      $this.Config.RemoveLastVersion = $true
    }
    $this.Submit()
  }
}
