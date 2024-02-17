$RepoOwner = 'libjpeg-turbo'
$RepoName = 'libjpeg-turbo'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x86'
  InstallerUrl           = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match '[^a-zA-Z0-9]gcc[^a-zA-Z0-9]' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  ProductCode            = "libjpeg-turbo-gcc $($this.CurrentState.Version)"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "libjpeg-turbo SDK v$($this.CurrentState.RealVersion) for GCC"
      ProductCode = "libjpeg-turbo-gcc $($this.CurrentState.Version)"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerUrl           = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('gcc64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  ProductCode            = "libjpeg-turbo-gcc64 $($this.CurrentState.Version)"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "libjpeg-turbo SDK v$($this.CurrentState.RealVersion) for GCC 64-bit"
      ProductCode = "libjpeg-turbo-gcc64 $($this.CurrentState.Version)"
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  $ReleaseNotesObject = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html
  $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode('./h2[text()="Release Notes"]')
  if ($ReleaseNotesTitleNode) {
    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
    }
  } else {
    $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
  }
} else {
  $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.html_url
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
