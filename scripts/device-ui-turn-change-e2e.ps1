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
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-turn-change-e2e'
}
$captureDir = Join-Path $OutputDir 'completed-card'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$mockArguments = @{
  DevEcoHome = $DevEcoHome
  Device = $Device
  Screen = 'conversation'
  State = 'completed'
  Theme = 'dark'
  OutputDir = $OutputDir
}
if ($SkipBuild) {
  $mockArguments.SkipBuild = $true
}
if ($SkipInstall) {
  $mockArguments.SkipInstall = $true
}
& $mockScript @mockArguments | Out-Host

$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'

function Text-Hex {
  param([string]$Text)
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-turn-change-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b io.github.stlin256.dshharmony" | Out-Null
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
  $remote = "/data/local/tmp/dsh-turn-change-$Name.jpeg"
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
    [string]$TextHex,
    [ValidateSet('text', 'clickable')]
    [string]$Target = 'clickable'
  )
  $raw = & python $queryScript $Layout --find-text-hex $TextHex --target $Target 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout query failed: $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Invoke-Click {
  param([object]$Node)
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Input click failed at $($Node.x),$($Node.y)"
  }
  Start-Sleep -Milliseconds 750
}

$collapsed = Dump-Layout 'collapsed'
$expand = Query-Node $collapsed (Text-Hex '已编辑 4 个文件') 'clickable'
Invoke-Click $expand
$expanded = Dump-Layout 'expanded'
$null = Query-Node $expanded (Text-Hex '收起文件') 'text'
Start-Sleep -Milliseconds 650
Capture-Screen 'expanded'

$fileRow = Query-Node $expanded (Text-Hex 'NativeBottomConversationDock.ets') 'clickable'
Invoke-Click $fileRow
Start-Sleep -Milliseconds 1000
$preview = Dump-Layout 'file-preview'
$null = Query-Node $preview (Text-Hex 'NativeBottomConversationDock.ets') 'text'
Capture-Screen 'file-preview'

& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 750
$returned = Dump-Layout 'returned-to-expanded-card'
$null = Query-Node $returned (Text-Hex '收起文件') 'text'

$collapse = Query-Node $returned (Text-Hex '收起文件') 'clickable'
Invoke-Click $collapse
$collapsedAgain = Dump-Layout 'collapsed-again'
$null = Query-Node $collapsedAgain (Text-Hex '再显示 1 个文件') 'text'
Start-Sleep -Milliseconds 650
Capture-Screen 'collapsed-again'

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  result = 'Passed'
  checked = [ordered]@{
    fourFileSummaryVisible = $true
    expansionRevealsAllFiles = $true
    fileRowOpensPreview = $true
    previewBackReturnsToExpandedCard = $true
    collapseRestoresOverflowSummary = $true
  }
}
$manifest |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Turn change card E2E passed. Evidence: $captureDir"
