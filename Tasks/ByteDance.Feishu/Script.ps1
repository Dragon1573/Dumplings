$Object1 = Invoke-RestMethod -Uri 'https://www.feishu.cn/api/downloads' -Headers @{ cookie = '__tea__ug__uid=1' }

# Version
$this.CurrentState.Version = [regex]::Match($Object1.versions.Windows.version_number, 'V([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.versions.Windows.download_link
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.versions.Windows.release_time | ConvertFrom-UnixTimeSeconds

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Uri2 = 'https://www.feishu.cn/hc/en-US/articles/360043073734'
      $Object2 = ((Invoke-WebRequest -Uri $Uri2).Content | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable).GetEnumerator().Where({ $_.Value -is [array] -and $_.Value.Where({ $_ -is [hashtable] -and $_.Contains('tabName') }) }, 'First')

      $ReleaseNotesNode = $Object2[0].Value.Where({ $_.html.html.Contains("V$($this.CurrentState.Version.Split('.')[0..1] -join '.')") }, 'First')
      if ($ReleaseNotesNode) {
        $ReleaseNotesTitleNode = ($ReleaseNotesNode[0].html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.SelectSingleNode('.//text()[contains(., "Updated")]|.//hr'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Uri2
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Uri2
      }
    }

    try {
      $Uri3 = 'https://www.feishu.cn/hc/zh-CN/articles/360043073734'
      $Object3 = ((Invoke-WebRequest -Uri $Uri3).Content | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable).GetEnumerator().Where({ $_.Value -is [array] -and $_.Value.Where({ $_ -is [hashtable] -and $_.Contains('tabName') }) }, 'First')

      $ReleaseNotesCNNode = $Object3[0].Value.Where({ $_.html.html.Contains("V$($this.CurrentState.Version.Split('.')[0..1] -join '.')") }, 'First')
      if ($ReleaseNotesCNNode) {
        $ReleaseNotesCNTitleNode = ($ReleaseNotesCNNode[0].html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and -not $Node.SelectSingleNode('.//text()[contains(., "发布于")]|.//hr'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesCNTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) and ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $Uri3
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Uri3
      }
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
