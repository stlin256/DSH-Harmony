param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$HapPath = '',
  [ValidateSet('launch', 'conversation', 'process', 'disclosure', 'sidebar', 'browser', 'preview', 'settings',
    'lineage', 'subagent', 'plugins', 'automation', 'more')]
  [string]$Screen = 'conversation',
  [ValidateSet(
    'iteration-notice',
    'completed',
    'live-change',
    'attachments',
    'streaming',
    'stream-long',
    'secret-masked',
    'stream-repaired',
    'document-preview',
    'text-config-preview',
    'delimited-preview',
    'tsv-preview',
    'delimited-error-preview',
    'binary-preview',
    'empty',
    'long-history',
    'dock-send-idle',
    'dock-queue-pending',
    'dock-queue-authoritative',
    'dock-queue-many',
    'dock-send-error',
    'dock-material-quiet',
    'dock-material-elevated',
    'interaction-approval',
    'interaction-question',
    'plan-subagent',
    'plan-subagent-long-count',
    'plan-dock-overlay',
    'plan-off-error',
    'subagent-continuable',
    'subagent-one-shot',
    'subagent-unknown',
    'subagent-parent-offline',
    'plugins-list',
    'plugins-empty',
    'plugins-error',
    'plugins-detail',
    'plugins-restart',
    'plugins-install-failed',
    'automation-list',
    'automation-empty',
    'automation-detail',
    'automation-editor',
    'automation-history',
    'automation-conflict',
    'more-actions',
    'disclosure-task-plan',
    'disclosure-process-reasoning',
    'disclosure-process-read',
    'disclosure-process-search',
    'disclosure-process-terminal',
    'disclosure-process-diff',
    'disclosure-process-nested',
    'disclosure-process-malformed',
    'disclosure-process-empty',
    'disclosure-process-oversized',
    'disclosure-process-web',
    'disclosure-process-goal',
    'disclosure-process-job',
    'disclosure-process-web-fetch',
    'disclosure-process-job-lifecycle',
    'disclosure-process-read-image',
    'disclosure-process-command',
    'disclosure-process-subagent',
    'disclosure-process-present',
    'disclosure-process-image',
    'disclosure-process-question',
    'disclosure-process-plugin',
    'disclosure-process-plan',
    'disclosure-process-order',
    'disclosure-reasoning',
    'disclosure-legacy-tool',
    'disclosure-diff',
    'disclosure-background-notice',
    'disclosure-queue',
    'disclosure-sidebar-more',
    'disclosure-sidebar-group'
  )]
  [string]$State = 'live-change',
  [ValidateSet('light', 'dark', 'system')]
  [string]$Theme = 'dark',
  [string]$OutputDir = '',
  [ValidateRange(5, 120)]
  [int]$StartupTimeoutSeconds = 30,
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [switch]$ResetData,
  [switch]$ReduceMotion,
  [switch]$ReduceTransparency
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'resolve-deveco-home.ps1')
$DevEcoHome = Resolve-DevEcoHome -ExplicitHome $DevEcoHome
$hdc = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path -LiteralPath $hdc)) {
  throw "HDC not found: $hdc"
}
if (-not $HapPath) {
  $HapPath = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-mock'
}

function Get-ReadyDevice {
  $lines = & $hdc list targets -v
  $ready = @($lines | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No unlocked USB HarmonyOS device is ready.'
  }
  return ($ready[0] -split "`t")[0]
}

function Test-AppForeground {
  param(
    [string]$BundleName
  )

  $abilityDump = (& $hdc -t $Device shell 'aa dump -a' 2>&1 | Out-String)
  $bundlePattern = [regex]::Escape($BundleName)
  $mission = [regex]::Match(
    $abilityDump,
    "(?s)Mission ID[^\r\n]*$bundlePattern`:entry`:EntryAbility.*?(?=\r?\n\s*Mission ID #|\r?\n\s*ExtensionRecords:)"
  )
  return $mission.Success -and
    $mission.Value -match 'state #FOREGROUND' -and
    $mission.Value -match 'app state #FOREGROUND'
}

function Test-UiLayoutReady {
  param(
    [string]$BundleName,
    [string]$RemotePath,
    [string]$LocalPath
  )

  Remove-Item -LiteralPath $LocalPath -Force -ErrorAction SilentlyContinue
  & $hdc -t $Device shell "rm -f $RemotePath" | Out-Null
  & $hdc -t $Device shell "uitest dumpLayout -p $RemotePath -i -b $BundleName" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    $script:lastLayoutFailure = "dump-exit-$LASTEXITCODE"
    return $false
  }
  # The command can return just before the remote JSON file is fully flushed.
  Start-Sleep -Milliseconds 200
  & $hdc -t $Device file recv $RemotePath $LocalPath | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $LocalPath)) {
    $script:lastLayoutFailure = "recv-exit-$LASTEXITCODE"
    return $false
  }

  try {
    $parsed = Get-Content -Raw -Encoding UTF8 -LiteralPath $LocalPath | ConvertFrom-Json
    $root = @($parsed)[0]
    $ready = $root.attributes.pagePath -eq 'pages/Index' -and
      @($root.children).Count -gt 0 -and
      $root.attributes.bundleName -eq $BundleName
    if (-not $ready) {
      $script:lastLayoutFailure = "shape-page-$($root.attributes.pagePath)-bundle-$($root.attributes.bundleName)-children-$(@($root.children).Count)"
    } else {
      $script:lastLayoutFailure = ''
    }
    return $ready
  } catch {
    $message = ($_.Exception.Message -split "`r?`n")[0]
    $script:lastLayoutFailure = "parse-$message"
    return $false
  }
}

function Wait-FixtureReady {
  param(
    [string]$BundleName,
    [string]$RemoteProbeLayout,
    [string]$ProbeLayout,
    [int]$TimeoutSeconds
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $lastProcessId = ''
  $lastForeground = $false
  $lastLayoutReady = $false
  $readyProcessId = ''
  $readyEvidenceCount = 0
  $attemptCount = 0
  while ((Get-Date) -lt $deadline) {
    $attemptCount++
    $lastProcessId = ((& $hdc -t $Device shell "pidof $BundleName" 2>&1) -join ' ').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $lastProcessId) {
      $readyEvidenceCount = 0
      Start-Sleep -Milliseconds 500
      continue
    }
    $lastForeground = Test-AppForeground -BundleName $BundleName
    if ($lastForeground) {
      $lastLayoutReady = Test-UiLayoutReady `
        -BundleName $BundleName `
        -RemotePath $RemoteProbeLayout `
        -LocalPath $ProbeLayout
      if ($lastLayoutReady) {
        # Active fixture states may contain timers or progress indicators, so a
        # whole-tree hash is not a valid readiness signal. Require two valid
        # renders from one process, but tolerate transient dump failures between
        # evidence samples; they do not make an otherwise rendered page stale.
        if ($readyProcessId -ne $lastProcessId) {
          $readyProcessId = $lastProcessId
          $readyEvidenceCount = 0
        }
        $readyEvidenceCount++
        if ($readyEvidenceCount -ge 2) {
          return $lastProcessId
        }
      } else {
        Start-Sleep -Milliseconds 250
      }
    } else {
      $readyEvidenceCount = 0
    }
    Start-Sleep -Milliseconds 500
  }

  $diagnostic = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString('o')
    bundleName = $BundleName
    processId = $lastProcessId
    foreground = $lastForeground
    layoutReady = $lastLayoutReady
    layoutFailure = $script:lastLayoutFailure
    attempts = $attemptCount
    validEvidence = $readyEvidenceCount
    timeoutSeconds = $TimeoutSeconds
  }
  $diagnostic |
    ConvertTo-Json |
    Set-Content -LiteralPath (Join-Path $captureDir 'startup-timeout.json') -Encoding utf8
  throw "Fixture did not become foreground and render a non-empty UI tree within $TimeoutSeconds seconds."
}

if (-not $Device) {
  $Device = Get-ReadyDevice
}
if (-not $SkipBuild) {
  & (Join-Path $PSScriptRoot 'build-harmony.ps1') -DevEcoHome $DevEcoHome -Product mock -BuildMode release
  if ($LASTEXITCODE -ne 0) {
    throw "Mock Release build failed: $LASTEXITCODE"
  }
}
$hap = (Resolve-Path -LiteralPath $HapPath).Path
if (-not $SkipInstall) {
  & $hdc -t $Device install -r $hap
  if ($LASTEXITCODE -ne 0) {
    throw "HAP installation failed: $LASTEXITCODE"
  }
}

$bundle = 'io.github.stlin256.dshharmony'
& $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
if ($ResetData) {
  & $hdc -t $Device shell "bm clean -n $bundle -d"
  if ($LASTEXITCODE -ne 0) {
    throw "Fixture data reset failed: $LASTEXITCODE"
  }
}
$variantSuffix = ''
if ($ReduceMotion) { $variantSuffix += '-reduced-motion' }
if ($ReduceTransparency) { $variantSuffix += '-reduced-transparency' }
$captureName = "$State-$Theme-$Screen$variantSuffix"
$captureDir = Join-Path $OutputDir $captureName
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

$launch = "aa start -a EntryAbility -b $bundle -m entry " +
  "--ps storeShowcase true --ps showcaseScreen $Screen " +
  "--ps showcaseState $State --ps showcaseTheme $Theme"
if ($ReduceMotion) { $launch += ' --ps showcaseReduceMotion true' }
if ($ReduceTransparency) { $launch += ' --ps showcaseReduceTransparency true' }
& $hdc -t $Device shell $launch
if ($LASTEXITCODE -ne 0) {
  throw "Fixture launch failed: $State/$Theme/$Screen"
}

$remoteImage = "/data/local/tmp/dsh-ui-$Screen-$State-$Theme.jpeg"
$remoteLayout = "/data/local/tmp/dsh-ui-$Screen-$State-$Theme.json"
$localImage = Join-Path $captureDir 'screen.jpeg'
$localLayout = Join-Path $captureDir 'layout.json'
$probeLayout = Join-Path $captureDir 'layout-probe.json'
$null = Wait-FixtureReady `
  -BundleName $bundle `
  -RemoteProbeLayout "/data/local/tmp/dsh-ui-ready-$Screen-$State-$Theme.json" `
  -ProbeLayout $probeLayout `
  -TimeoutSeconds $StartupTimeoutSeconds

& $hdc -t $Device shell "uitest screenCap -p $remoteImage"
if ($LASTEXITCODE -ne 0) {
  throw 'Screen capture failed.'
}
& $hdc -t $Device file recv $remoteImage $localImage | Out-Null
& $hdc -t $Device shell "uitest dumpLayout -p $remoteLayout -i -b $bundle"
if ($LASTEXITCODE -ne 0) {
  throw 'UI layout dump failed.'
}
& $hdc -t $Device file recv $remoteLayout $localLayout | Out-Null

$layoutAssertion = 'not-requested'
if ($Screen -eq 'conversation') {
  $assertScript = Join-Path $PSScriptRoot 'device-ui-layout-assert.py'
  $assertionArguments = @(
    $localLayout,
    '--match',
    'DeepSeek-V4-Pro',
    '--require-composer-visible'
  )
  $assertionOutput = & python $assertScript @assertionArguments 2>&1
  $assertionExit = $LASTEXITCODE
  $assertionOutput | Set-Content -LiteralPath (Join-Path $captureDir 'layout-assert.txt') -Encoding utf8
  if ($assertionExit -ne 0) {
    throw "Bottom-dock layout assertion failed: $captureDir"
  }
  $layoutAssertion = 'passed'
}

$bundleDump = (& $hdc -t $Device shell "bm dump -n $bundle" | Out-String)
$versionMatch = [regex]::Match($bundleDump, '"versionName"\s*:\s*"([^"]+)"')
$model = ((& $hdc -t $Device shell 'param get const.product.model') -join ' ').Trim()
$api = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join ' ').Trim()
$appProcessId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  deviceModel = $model
  apiVersion = $api
  bundleName = $bundle
  variant = 'mock'
  bundleVersion = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { '' }
  processId = $appProcessId
  layoutAssertion = $layoutAssertion
  fixture = [ordered]@{
    storeShowcase = $true
    screen = $Screen
    state = $State
    theme = $Theme
    reduceMotion = [bool]$ReduceMotion
    reduceTransparency = [bool]$ReduceTransparency
  }
  files = [ordered]@{
    screenshot = 'screen.jpeg'
    layout = 'layout.json'
    assertion = if ($Screen -eq 'conversation') { 'layout-assert.txt' } else { '' }
  }
}
$manifest |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Get-ChildItem -LiteralPath $captureDir | Select-Object FullName, Length, LastWriteTime
