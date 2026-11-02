param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$OutputDir = '',
  [switch]$SkipBuild,
  [switch]$SkipInstall
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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-conversation-chrome-e2e'
}
if (-not [IO.Path]::IsPathRooted($OutputDir)) {
  $OutputDir = Join-Path $repo $OutputDir
}
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'scrollbar-edge'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; conversation chrome E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$bundle = 'io.github.stlin256.dshharmony'

function Get-Bounds {
  param([object]$Node)
  $match = [regex]::Match([string]$Node.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $match.Success) {
    throw "Cannot read bounds: $($Node.bounds)"
  }
  return [pscustomobject]@{
    Left = [int]$match.Groups[1].Value
    Top = [int]$match.Groups[2].Value
    Right = [int]$match.Groups[3].Value
    Bottom = [int]$match.Groups[4].Value
  }
}

function Query-Node-ById {
  param(
    [string]$Layout,
    [string]$Id
  )
  $raw = & python $queryScript $Layout --find-id $Id --target text --expect-count 1 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout id query failed for '$Id': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Query-Node-Text {
  param(
    [string]$Layout,
    [string]$Text,
    [int]$ExpectCount = 1
  )
  $hex = [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
  $raw = & python $queryScript $Layout --find-text-hex $hex --target text `
    --exact-text --expect-count $ExpectCount 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout text query failed for '$Text': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Capture-Screen {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-chrome-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if (-not (Test-Path -LiteralPath $local)) {
    throw "Screen capture failed: $Name"
  }
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-chrome-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if (-not (Test-Path -LiteralPath $local)) {
    throw "Layout capture failed: $Name"
  }
  return $local
}

$mockArguments = @{
  DevEcoHome = $DevEcoHome
  Device = $Device
  Screen = 'conversation'
  State = 'long-history'
  Theme = 'dark'
  OutputDir = $OutputDir
  ResetData = $true
}
if ($SkipBuild) { $mockArguments.SkipBuild = $true }
if ($SkipInstall) { $mockArguments.SkipInstall = $true }
& $mockScript @mockArguments | Out-Host

$beforeLayout = Dump-Layout 'before'
$beforeImage = 'before'
Capture-Screen $beforeImage
$scrollNode = Query-Node-ById $beforeLayout 'transcript-scroll'
$scrollBounds = Get-Bounds $scrollNode
$probeText = '第 38 组记录已加载，内容保持稳定。'
$probeNode = Query-Node-Text $beforeLayout $probeText
$textBounds = Get-Bounds $probeNode
$afterProbeText = '第 30 组记录已加载，内容保持稳定。'
$null = Query-Node-Text $beforeLayout $afterProbeText 0
$parsed = Get-Content -LiteralPath $beforeLayout -Raw -Encoding UTF8 | ConvertFrom-Json
$root = @($parsed)[0]
$rootBounds = Get-Bounds ([pscustomobject]@{ bounds = $root.attributes.bounds })

if ($scrollBounds.Right -lt $rootBounds.Right - 1) {
  throw "Transcript scrollbar container does not reach the physical right edge: " +
    "list=$($scrollBounds.Right), screen=$($rootBounds.Right)"
}
if ($textBounds.Right -gt $rootBounds.Right - 80) {
  throw "Transcript text lost its right page inset: " +
    "text=$($textBounds.Right), screen=$($rootBounds.Right)"
}

$liveRemote = '/data/local/tmp/dsh-chrome-scroll-live.jpeg'
$liveLocal = Join-Path $captureDir 'scroll-live.jpeg'
$swipe = Start-Process -FilePath $hdc `
  -ArgumentList @('-t', $Device, 'shell', 'uitest uiInput swipe 630 1200 630 1500 4000') `
  -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 120
& $hdc -t $Device shell "uitest screenCap -p $liveRemote" | Out-Null
& $hdc -t $Device file recv $liveRemote $liveLocal | Out-Null
$swipe.WaitForExit()

$afterLayout = Dump-Layout 'after-scroll'
$afterProbe = Query-Node-Text $afterLayout $afterProbeText
$afterBounds = Get-Bounds $afterProbe
if ($afterBounds.Right -gt $rootBounds.Right - 80) {
  throw "Scrolled transcript text lost its right page inset: " +
    "text=$($afterBounds.Right), screen=$($rootBounds.Right)"
}
$moved = $true

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during conversation chrome E2E.'
}
if (-not $moved) {
  throw 'Scroll interaction did not move transcript content.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap')).Hash
  theme = 'dark'
  result = 'Passed'
  geometry = [ordered]@{
    screen = @($rootBounds.Left, $rootBounds.Top, $rootBounds.Right, $rootBounds.Bottom)
    scroll = @($scrollBounds.Left, $scrollBounds.Top, $scrollBounds.Right, $scrollBounds.Bottom)
    bodyText = @($textBounds.Left, $textBounds.Top, $textBounds.Right, $textBounds.Bottom)
  }
  evidence = [ordered]@{
    beforeScreenshot = 'before.jpeg'
    beforeLayout = 'before.json'
    liveScrollScreenshot = 'scroll-live.jpeg'
    afterLayout = 'after-scroll.json'
  }
  checked = [ordered]@{
    scrollbarContainerReachesPhysicalRightEdge = $true
    bodyKeepsRightPageInset = $true
    swipeMovesTranscript = $moved
    processAliveAfterInteraction = $true
  }
}
$manifest |
  ConvertTo-Json -Depth 6 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Conversation chrome Mock E2E passed. Evidence: $captureDir"
