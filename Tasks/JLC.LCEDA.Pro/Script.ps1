$Object1 = Invoke-WebRequest -Uri 'https://lceda.cn/page/download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[2]/div/span/a').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl.Replace('-x64-', '-ia32-')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '-(\d+\.\d+\.\d+(?:\.\d+)*)[-.]').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://pro.lceda.cn/page/update-record' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@class, 'doc-body-left')]/p[contains(./strong/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        # ReleaseTime
        $this.CurrentState.ReleaseTime = ($ReleaseNotesTimeNode.InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTimeNode.NextSibling; -not $Node.SelectSingleNode('./strong'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
