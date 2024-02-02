$Prefix = 'https://paperlib.app/distribution/electron-win/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object1 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/GeoffreyChen777/paperlib/master/CHANGELOG_EN.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object1.SelectSingleNode("./h2[contains(@id, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]{3} \d{1,2} \d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/GeoffreyChen777/paperlib/master/CHANGELOG_CN.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("./h2[contains(@id, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{2} \d{4})').Groups[1].Value,
          'dd/MM yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
