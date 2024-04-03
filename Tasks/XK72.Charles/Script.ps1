$Object1 = Invoke-WebRequest -Uri 'https://www.charlesproxy.com/download/latest-release/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//form[@class="download-form"]//input[@name="version"]').Attributes['Value'].Value

$Object2 = Invoke-WebRequest -Uri "https://www.charlesproxy.com/latest-release/download.do?os=windows64&beta=false&version=$($this.CurrentState.Version)" | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [uri]::new("https://www.charlesproxy.com$([regex]::Match($Object2.SelectSingleNode('//meta[@http-equiv="refresh"]').Attributes['content'].Value, 'url=(.+)').Groups[1].Value)").GetLeftPart([System.UriPartial]::Path)
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.charlesproxy.com/documentation/version-history/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@class='content']/h4[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTimeNode.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTimeNode.NextSibling; $Node -and $Node.Name -ne 'h4'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
