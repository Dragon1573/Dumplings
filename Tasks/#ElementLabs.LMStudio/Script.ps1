$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['LMStudio'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['LMStudio'] = $OldReleases = [ordered]@{}
}

$Object1 = Invoke-RestMethod -Uri "https://versions-prod.lmstudio.ai/win32/x86/$($this.Status.Contains('New') ? '0.3.2' : $this.LastState.Version)"

# Version
$this.CurrentState.Version = $Object1.version

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $ReleaseNotesObject = $Object1.releaseNotes | Convert-MarkdownToHtml
    $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[contains(text(), '$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
      }
    } else {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes = $ReleaseNotesObject | Get-TextContent | Format-Text
      }
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseNotes = $ReleaseNotes
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }
  }
  'New' {
    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated' {
    $this.Print()
    $this.Write()
    if (-not $OldReleases.Contains($this.CurrentState.Version)) {
      $this.Message()
    }
  }
  { $_ -match 'Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Print()
    $this.Message()
  }
}
