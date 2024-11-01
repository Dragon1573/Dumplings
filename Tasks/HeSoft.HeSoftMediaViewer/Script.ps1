# x86
$Prefix1 = 'https://cdn2.wodeabc.com/file/upload/600134/files/update-hesoft-media-viewer/ia32/'
$Object1 = Invoke-RestMethod -Uri "${Prefix1}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml
# x64
$Prefix2 = 'https://cdn2.wodeabc.com/file/upload/600134/files/update-hesoft-media-viewer/x64/'
$Object2 = Invoke-RestMethod -Uri "${Prefix2}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml

if ($Object1.version -ne $Object2.version) {
  $this.Log("x86 version: $($Object1.version)")
  $this.Log("x64 version: $($Object2.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix1 + $Object1.files[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix2 + $Object2.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.wodeabc.com/article/show/8002663' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[contains(@class, 'article-content')]/h1[contains(., 'v$($this.CurrentState.Version -replace '\.0$')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h1'; $Node = $Node.NextSibling) {
          # Remove download links
          $Node.SelectNodes('.//li[contains(., "[下载]")]').ForEach({ $_.Remove() })
          $Node
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
