$Object1 = Invoke-RestMethod -Uri 'https://ifile.space/download' -Method Post -Body '{}' -ContentType 'application/json; charset=utf-8'

# Version
$this.CurrentState.Version = $Object1.data.serverbanben.title

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://dl.ifile.space/apps/ifile_windows_amd64_$($this.CurrentState.Version).zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://ifile.space/update' -Method Post -Body (
        @{
          action = 'serve'
        } | ConvertTo-Json -Compress
      ) -ContentType 'application/json; charset=utf-8'
      $Object3 = $Object2.data.list.Where({ $_.title -eq $this.CurrentState.Version }, 'First')

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object3[0].addtime.ToString(), 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].contentfmt | ForEach-Object -Process {
            $TypeName = switch ($_.Type) {
              'youhua' { '优化' }
              'xiufu' { '修复' }
              'xinzeng' { '新增' }
              Default { $_ }
            }
            "【${TypeName}】$($_.content)"
          } | Format-Text
        }
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
