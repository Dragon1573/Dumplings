$Object1 = Invoke-WebRequest -Uri 'https://release.axocdn.com/windows/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://release.axocdn.com/windows/GitKrakenSetup-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://help.gitkraken.com/gitkraken-client/current/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@data-widget_type='theme-post-content.default']/div/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        try {
          $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::h3[1]')

          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
            [regex]::Match($ReleaseTimeNode.InnerText, '([a-zA-Z]+\s+\d{1,2}(st|nd|rd|th),\s+\d{4})').Groups[1].Value,
            # "[string[]]" is needed here to convert "array" object to string array
            [string[]]@(
              "MMMM d'st', yyyy",
              "MMMM d'nd', yyyy",
              "MMMM d'rd', yyyy",
              "MMMM d'th', yyyy"
            ),
            (Get-Culture -Name 'en-US'),
            [System.Globalization.DateTimeStyles]::None
          ).ToString('yyyy-MM-dd')

          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = for ($Node = $ReleaseTimeNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        } catch {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        }
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
