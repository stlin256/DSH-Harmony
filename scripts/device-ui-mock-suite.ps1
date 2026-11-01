param(
  [string]$DevEcoHome = 'C:\Users\yjzlx\AppData\Local\Programs\Huawei\DevEcoStudio-26.0.0',
  [string]$Device = '',
  [string]$OutputDir = '',
  [ValidateRange(5, 120)]
  [int]$StartupTimeoutSeconds = 30,
  [switch]$SkipBuild,
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-mock'
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$scenarios = @(
  [pscustomobject]@{ Screen = 'conversation'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'live-change'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'live-change'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'attachments'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'attachments'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'streaming'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'streaming'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'empty'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'empty'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'long-history'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'long-history'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-send-idle'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-send-idle'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-authoritative'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-authoritative'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-many'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-many'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-send-error'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-quiet'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-quiet'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'light'; ReduceTransparency = $true },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'dark'; ReduceTransparency = $true },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-approval'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-approval'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-question'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-question'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-subagent'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-subagent'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-off-error'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'lineage'; State = 'plan-subagent'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'lineage'; State = 'plan-subagent'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-continuable'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-continuable'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-one-shot'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-one-shot'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-unknown'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-unknown'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-parent-offline'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-parent-offline'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'process'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'process'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'sidebar'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'sidebar'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'browser'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'browser'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'settings'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'settings'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-list'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-list'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-empty'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-error'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-detail'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-detail'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-restart'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-install-failed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-list'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-list'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-empty'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-detail'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-detail'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-editor'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-history'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-conflict'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'more'; State = 'more-actions'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'more'; State = 'more-actions'; Theme = 'dark' }
)

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$results = [System.Collections.Generic.List[object]]::new()
$firstRun = $true
$failedCount = 0

foreach ($scenario in $scenarios) {
  $startedAt = Get-Date
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Screen = $scenario.Screen
    State = $scenario.State
    Theme = $scenario.Theme
    OutputDir = $OutputDir
    StartupTimeoutSeconds = $StartupTimeoutSeconds
  }
  if ($Device) {
    $arguments.Device = $Device
  }
  if ($scenario.PSObject.Properties.Name -contains 'ReduceTransparency' -and
      $scenario.ReduceTransparency) {
    $arguments.ReduceTransparency = $true
  }

  # Build and install once. Reinstalling between graphical scenarios only
  # introduces unrelated process-termination noise.
  if ($SkipBuild -or -not $firstRun) {
    $arguments.SkipBuild = $true
  }
  if ($SkipInstall -or -not $firstRun) {
    $arguments.SkipInstall = $true
  }

  $message = ''
  try {
    & $mockScript @arguments | Out-Host
    $result = 'Passed'
  } catch {
    $result = 'Failed'
    $message = $_.Exception.Message
    $failedCount++
  }

  $results.Add([pscustomobject]@{
    screen = $scenario.Screen
    state = $scenario.State
    theme = $scenario.Theme
    result = $result
    durationSeconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
    message = $message
  })
  $firstRun = $false
}

$summary = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  bundleName = 'io.github.stlin256.dshharmony'
  scenarios = $results
}
$summaryPath = Join-Path $OutputDir 'suite-summary.json'
$summary |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath $summaryPath -Encoding utf8

$contactSheet = Join-Path $OutputDir 'dock-material-contact-sheet.png'
& python (Join-Path $PSScriptRoot 'compose-dock-contact-sheet.py') `
  --root $OutputDir `
  --out $contactSheet
if ($LASTEXITCODE -ne 0) {
  throw "Dock material contact sheet failed: $LASTEXITCODE"
}

$materialAssert = Join-Path $PSScriptRoot 'device-ui-material-assert.py'
foreach ($theme in @('light', 'dark')) {
  $captureDir = Join-Path $OutputDir "dock-material-elevated-$theme-conversation"
  & python $materialAssert `
    (Join-Path $captureDir 'layout.json') `
    (Join-Path $captureDir 'screen.jpeg') `
    --theme $theme `
    --json-out (Join-Path $OutputDir "dock-material-$theme-assert.json")
  if ($LASTEXITCODE -ne 0) {
    throw "Dock material pixel assertion failed for $theme."
  }
}

$results | Format-Table -AutoSize | Out-Host
if ($failedCount -gt 0) {
  throw "$failedCount fixture scenarios failed. See $summaryPath"
}
Write-Output "All $($results.Count) fixture scenarios passed. Evidence: $summaryPath"
