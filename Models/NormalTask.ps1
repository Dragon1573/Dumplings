<#
.SYNOPSIS
  A model with the minimum logic necessary to run a script
.DESCRIPTION
  This model provides necessary interfaces for bootstrapping script and common method for task scripts.
  Generally it does the following:
  1. Implement a constructor and a method Invoke() to be called by the bootstrapping script:
     The constructor receives the properties and probes the script.
     The Invoke() method runs the script file ("Script.ps1") in the same folder as the task config file ("Config.yaml").
  2. Implement common method to be called by the task scripts including Log():
     - Log() prints the message to the console. If messaging is enabled, it will also be sent to Telegram.
.PARAMETER NoSkip
  Force run the script even if the task is set not to run
#>

enum LogLevel {
  Verbose
  Log
  Info
  Warning
  Error
}

class NormalTask {
  #region Properties
  [ValidateNotNullOrEmpty()][string]$Name

  [ValidateNotNullOrEmpty()][string]$Path
  [string]$ScriptPath

  [System.Collections.IDictionary]$Config = [ordered]@{}
  [System.Collections.IDictionary]$Preference = [ordered]@{}
  #endregion

  NormalTask([System.Collections.IDictionary]$Properties) {
    # Load name
    if (-not $Properties.Contains('Name')) {
      throw 'NormalTask: The property Name is undefined and should be specified'
    }
    $this.Name = $Properties.Name

    # Load path
    if (-not $Properties.Contains('Path')) {
      throw 'NormalTask: The property Path is undefined and should be specified'
    }
    if (-not (Test-Path -Path $Properties.Path)) {
      throw 'NormalTask: The property Path is not reachable'
    }
    $this.Path = $Properties.Path

    # Probe script
    $this.ScriptPath ??= Join-Path $this.Path 'Script.ps1' -Resolve

    # Load config
    if ($Properties.Contains('Config') -and $Properties.Config -is [System.Collections.IDictionary]) {
      $this.Config = $Properties.Config
    } else {
      $this.Config ??= Join-Path $this.Path 'Config.yaml' -Resolve | Get-Item | Get-Content -Raw | ConvertFrom-Yaml -Ordered
    }
  }

  # Log with template, specifying log level
  [void] Log([string]$Message, [LogLevel]$Level) {
    Write-Log -Object $Message -Identifier "NormalTask $($this.Name)" -Level $Level
  }

  # Log in default level
  [void] Log([string]$Message) {
    $this.Log($Message, 'Log')
  }

  # Invoke script
  [void] Invoke() {
    if (($Global:DumplingsPreference.Contains('NoSkip') -and $this.Preference.NoSkip) -or -not ($this.Config.Contains('Skip') -and $this.Config.Skip)) {
      Write-Log -Object 'Run!' -Identifier "NormalTask $($this.Name)"
      & $this.ScriptPath | Out-Null
    } else {
      $this.Log('Skipped', 'Info')
    }
  }
}
