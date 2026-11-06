param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$OutputDir = '',
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [switch]$ReduceMotion
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'resolve-deveco-home.ps1')
$DevEcoHome = Resolve-DevEcoHome -ExplicitHome $DevEcoHome
$hdc = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path -LiteralPath $hdc)) {
  throw "HDC not found: $hdc"
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-task-dock'
}
$captureDir = Join-Path $OutputDir 'floating-overlay'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; floating task Dock E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$assertScript = Join-Path $PSScriptRoot 'device-ui-task-dock-assert.py'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$bundle = 'io.github.stlin256.dshharmony'
$firstLaunch = $true

function Text-Hex {
  param([string]$Text)
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')
}

function Launch-Fixture {
  param([string]$Theme)
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = 'conversation'
    State = 'plan-dock-overlay'
    Theme = $Theme
    OutputDir = $OutputDir
  }
  if ($SkipBuild -or -not $firstLaunch) {
    $arguments.SkipBuild = $true
  }
  if ($SkipInstall -or -not $firstLaunch) {
    $arguments.SkipInstall = $true
  }
  if ($ReduceMotion) {
    $arguments.ReduceMotion = $true
  }
  & $mockScript @arguments | Out-Host
  $script:firstLaunch = $false
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-task-dock-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Layout dump failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Layout receive failed: $Name"
  }
  return $local
}

function Capture-Screen {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-task-dock-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Screen capture failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Screen receive failed: $Name"
  }
}

function Query-Node {
  param(
    [string]$Layout,
    [string]$Text,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'text',
    [int]$ExpectCount = 1
  )
  $raw = & python $queryScript `
    $Layout `
    --find-text-hex (Text-Hex $Text) `
    --target $Target `
    --exact-text `
    --expect-count $ExpectCount 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout query failed for '$Text': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Invoke-Click {
  param([object]$Node)
  if ($null -eq $Node.x -or $null -eq $Node.y) {
    throw "Cannot click a node without bounds: $($Node.text)"
  }
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Input click failed at $($Node.x),$($Node.y)"
  }
  Start-Sleep -Milliseconds 650
}

function Scroll-Transcript-ToTop {
  param([int]$X = 630)
  1..4 | ForEach-Object {
    & $hdc -t $Device shell "uitest uiInput swipe $X 1700 $X 2400 450" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw 'Could not scroll the transcript to the top.'
    }
    Start-Sleep -Milliseconds 350
  }
}

function Assert-Overlay {
  param(
    [string]$Collapsed,
    [string]$Expanded,
    [string]$Scrolled = ''
  )
  $arguments = @('--collapsed', $Collapsed, '--expanded', $Expanded)
  if ($Scrolled) {
    $arguments += @('--scrolled', $Scrolled)
  }
  $raw = & python $assertScript @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Task Dock overlay assertion failed: $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

$geometries = [ordered]@{}
foreach ($theme in @('dark', 'light')) {
  Launch-Fixture -Theme $theme
  Scroll-Transcript-ToTop
  $collapsedLayout = Dump-Layout "$theme-collapsed"
  $null = Query-Node $collapsedLayout '悬浮任务计划' 'text' 1
  $taskDock = Query-Node $collapsedLayout '任务计划' 'clickable' 1
  Capture-Screen "$theme-collapsed"

  Invoke-Click $taskDock
  $expandedLayout = Dump-Layout "$theme-expanded"
  $null = Query-Node $expandedLayout '检查隐私与账户入口' 'text' 1
  Capture-Screen "$theme-expanded"
  $geometry = Assert-Overlay -Collapsed $collapsedLayout -Expanded $expandedLayout

  & $hdc -t $Device shell "uitest uiInput swipe $($geometry.scroll.x) $($geometry.scroll.startY) $($geometry.scroll.x) $($geometry.scroll.endY) 600" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Outside-Dock swipe failed in $theme theme"
  }
  Start-Sleep -Milliseconds 900
  $scrolledLayout = Dump-Layout "$theme-scrolled"
  Capture-Screen "$theme-scrolled"
  try {
    $geometry = Assert-Overlay -Collapsed $collapsedLayout -Expanded $expandedLayout -Scrolled $scrolledLayout
  } catch {
    # A follow-flick may briefly report the pre-scroll snapshot. Resample once
    # before treating the transcript as immovable.
    Start-Sleep -Milliseconds 500
    $scrolledLayout = Dump-Layout "$theme-scrolled-retry"
    Capture-Screen "$theme-scrolled-retry"
    $geometry = Assert-Overlay -Collapsed $collapsedLayout -Expanded $expandedLayout -Scrolled $scrolledLayout
  }

  $taskDockAfterScroll = Query-Node $scrolledLayout '任务计划' 'clickable' 1
  Invoke-Click $taskDockAfterScroll
  $collapsedAgainLayout = Dump-Layout "$theme-collapsed-again"
  $null = Query-Node $collapsedAgainLayout '检查隐私与账户入口' 'text' 0
  Capture-Screen "$theme-collapsed-again"
  $geometries[$theme] = $geometry
}

$darkGeometry = $geometries['dark']
$lightGeometry = $geometries['light']

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during floating task Dock E2E.'
}
$hapPath = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$hapSha256 = (Get-FileHash -LiteralPath $hapPath -Algorithm SHA256).Hash

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  hapSha256 = $hapSha256
  result = 'Passed'
  checked = [ordered]@{
    dockAnchoredAtTranscriptTop = $true
    expandedDockOverlapsTranscript = $true
    transcriptListTopAndHeightStable = $true
    topSpacerTracksCollapsedAndExpandedDock = $true
    outsideDockSwipeMovesTranscript = $true
    darkTheme = $true
    lightTheme = $true
    reducedMotion = [bool]$ReduceMotion
    processAliveAfterAllFlows = $true
  }
  geometry = [ordered]@{
    dark = $darkGeometry
    light = $lightGeometry
  }
}
$manifest |
  ConvertTo-Json -Depth 8 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Floating task Dock Mock E2E passed. Evidence: $captureDir"
