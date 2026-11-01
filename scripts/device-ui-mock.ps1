param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$HapPath = '',
  [ValidateSet('conversation', 'process', 'sidebar', 'browser', 'settings', 'lineage', 'subagent',
    'plugins', 'automation', 'more')]
  [string]$Screen = 'conversation',
  [ValidateSet(
    'completed',
    'live-change',
    'attachments',
    'streaming',
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
    'more-actions'
  )]
  [string]$State = 'live-change',
  [ValidateSet('light', 'dark', 'system')]
  [string]$Theme = 'dark',
  [string]$OutputDir = '',
  [ValidateRange(5, 120)]
  [int]$StartupTimeoutSeconds = 30,
  [switch]$SkipBuild,
  [switch]$SkipInstall,
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
    return $false
  }
  & $hdc -t $Device file recv $RemotePath $LocalPath | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $LocalPath)) {
    return $false
  }

  try {
    $parsed = Get-Content -Raw -LiteralPath $LocalPath | ConvertFrom-Json
    $root = @($parsed)[0]
    return $root.attributes.pagePath -eq 'pages/Index' -and
      @($root.children).Count -gt 0 -and
      $root.attributes.bundleName -eq $BundleName
  } catch {
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
  $readyStreak = 0
  while ((Get-Date) -lt $deadline) {
    $lastProcessId = ((& $hdc -t $Device shell "pidof $BundleName" 2>&1) -join ' ').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $lastProcessId) {
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
        $readyStreak++
        # Active fixture states may contain timers or progress indicators, so a
        # whole-tree hash is not a valid readiness signal. Require repeated
        # foreground, non-empty renders instead of waiting for an idle frame.
        if ($readyStreak -ge 2) {
          Start-Sleep -Milliseconds 650
          if (Test-UiLayoutReady `
            -BundleName $BundleName `
            -RemotePath $RemoteProbeLayout `
            -LocalPath $ProbeLayout) {
            return $lastProcessId
          }
          $readyStreak = 0
        }
      } else {
        $readyStreak = 0
      }
    } else {
      $readyStreak = 0
    }
    Start-Sleep -Milliseconds 500
  }

  $diagnostic = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString('o')
    bundleName = $BundleName
    processId = $lastProcessId
    foreground = $lastForeground
    layoutReady = $lastLayoutReady
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
$variantSuffix = ''
if ($ReduceMotion) { $variantSuffix += '-reduced-motion' }
if ($ReduceTransparency) { $variantSuffix += '-reduced-transparency' }
$captureName = "$State-$Theme-$Screen$variantSuffix"
$captureDir = Join-Path $OutputDir $captureName
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

& $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
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
  if ($State -eq 'completed') {
    $topLabel = [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes(
      '任务计划, 已完成 2 · 进行中 1 · 待处理 1'))
    $bottomLabel = [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes(
      '帮我检查这个版本是否达到应用商店上架条件，并整理还需要完成的发布事项。'))
    $assertionArguments += @(
      '--forbid-overlap-hex',
      $topLabel,
      $bottomLabel
    )
  }
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
