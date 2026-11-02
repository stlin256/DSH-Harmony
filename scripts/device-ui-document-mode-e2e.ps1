param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$HapPath = '',
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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-document-mode-e2e'
}
$captureDir = Join-Path $OutputDir 'document-mode'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; document mode E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}
if (-not $HapPath) {
  $HapPath = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
}

$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$bundle = 'io.github.stlin256.dshharmony'

function Text-Hex {
  param([string]$Text)
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
}

function Launch-Fixture {
  param(
    [string]$Screen = 'preview',
    [string]$State = 'document-preview',
    [string]$Theme = 'dark'
  )
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    HapPath = $HapPath
    Screen = $Screen
    State = $State
    Theme = $Theme
    OutputDir = $OutputDir
  }
  if ($SkipBuild) { $arguments.SkipBuild = $true }
  if ($SkipInstall) { $arguments.SkipInstall = $true }
  & $mockScript @arguments | Out-Host
  $script:SkipBuild = $true
  $script:SkipInstall = $true
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-document-mode-$Name.json"
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
  $remote = "/data/local/tmp/dsh-document-mode-$Name.jpeg"
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

function Wait-Query-Node {
  param(
    [string]$Name,
    [string]$Text,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'text',
    [int]$ExpectCount = 1,
    [int]$TimeoutMilliseconds = 6000
  )
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
  $lastError = ''
  $attempt = 0
  do {
    $attempt++
    try {
      $layout = Dump-Layout "$Name-$attempt"
      return (Query-Node $layout $Text $Target $ExpectCount)
    } catch {
      $lastError = $_.Exception.Message
      Start-Sleep -Milliseconds 250
    }
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Layout wait failed for '$Text' after $TimeoutMilliseconds ms: $lastError"
}

function Assert-Same-HeaderRow {
  param(
    [object]$Title,
    [object]$Action
  )
  $titleBounds = [regex]::Match([string]$Title.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  $actionBounds = [regex]::Match([string]$Action.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $titleBounds.Success -or -not $actionBounds.Success) {
    throw "Cannot compare header bounds: title=$($Title.bounds), action=$($Action.bounds)"
  }
  $titleTop = [int]$titleBounds.Groups[2].Value
  $titleBottom = [int]$titleBounds.Groups[4].Value
  $actionTop = [int]$actionBounds.Groups[2].Value
  $actionBottom = [int]$actionBounds.Groups[4].Value
  $overlap = [Math]::Min($titleBottom, $actionBottom) - [Math]::Max($titleTop, $actionTop)
  if ($overlap -le 0) {
    throw "Mode action is outside the title row: title=$($Title.bounds), action=$($Action.bounds)"
  }
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

Launch-Fixture -State 'document-preview'
$HapPath = (Resolve-Path -LiteralPath $HapPath).Path
$hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $HapPath).Hash
$title = Wait-Query-Node 'preview-default' 'diagram.svg' 'text'
$sourceAction = Wait-Query-Node 'preview-source-action' '切换到源码' 'clickable'
$previewLayout = Dump-Layout 'preview-default-layout'
$null = Query-Node $previewLayout '预览' 'text' 0
$null = Query-Node $previewLayout '代码' 'text' 0
Assert-Same-HeaderRow $title $sourceAction
Capture-Screen 'preview-default'

Invoke-Click $sourceAction
$sourceMarker = Wait-Query-Node 'source-mode' '<!-- DSH_SOURCE_MARKER -->' 'text'
$previewAction = Wait-Query-Node 'source-preview-action' '切换到渲染预览' 'clickable'
Assert-Same-HeaderRow $title $previewAction
Capture-Screen 'source-mode'

Invoke-Click $previewAction
$restoredAction = Wait-Query-Node 'preview-restored' '切换到源码' 'clickable'
$restoredLayout = Dump-Layout 'preview-restored-layout'
$null = Query-Node $restoredLayout '<!-- DSH_SOURCE_MARKER -->' 'text' 0
Assert-Same-HeaderRow $title $restoredAction
Capture-Screen 'preview-restored'

Launch-Fixture -State 'text-config-preview'
$configTitle = Wait-Query-Node 'config-title' 'app.conf' 'text'
$configMarker = Wait-Query-Node 'config-marker' 'DSH_CONFIG_MARKER' 'text'
$configSourceAction = Wait-Query-Node 'config-source-action' '切换到源码' 'clickable'
Assert-Same-HeaderRow $configTitle $configSourceAction
Capture-Screen 'config-preview'

Launch-Fixture -State 'delimited-preview'
$delimitedTitle = Wait-Query-Node 'delimited-title' 'users.csv' 'text'
$tableMarker = Wait-Query-Node 'delimited-table-marker' 'DSH_TABLE_MARKER' 'text'
$literalTable = Wait-Query-Node 'delimited-literal-table' '**literal value**' 'text'
$delimitedSourceAction = Wait-Query-Node 'delimited-source-action' '切换到源码' 'clickable'
Assert-Same-HeaderRow $delimitedTitle $delimitedSourceAction
Capture-Screen 'delimited-table'

Invoke-Click $delimitedSourceAction
$delimitedPreviewAction = Wait-Query-Node 'delimited-preview-action' '切换到渲染预览' 'clickable'
$delimitedSourceLayout = Dump-Layout 'delimited-source-layout'
$null = Query-Node $delimitedSourceLayout '**literal value**' 'text' 0
Capture-Screen 'delimited-source'

Invoke-Click $delimitedPreviewAction
$restoredTableMarker = Wait-Query-Node 'delimited-restored-marker' 'DSH_TABLE_MARKER' 'text'
Capture-Screen 'delimited-restored'

Launch-Fixture -State 'tsv-preview'
$tsvTitle = Wait-Query-Node 'tsv-title' 'report.tsv' 'text'
$tsvMarker = Wait-Query-Node 'tsv-marker' 'DSH_TSV_MARKER' 'text'
$tsvSourceAction = Wait-Query-Node 'tsv-source-action' '切换到源码' 'clickable'
Assert-Same-HeaderRow $tsvTitle $tsvSourceAction
Capture-Screen 'tsv-table'

Launch-Fixture -State 'delimited-error-preview'
$delimitedErrorTitle = Wait-Query-Node 'delimited-error-title' 'malformed.csv' 'text'
$delimitedError = Wait-Query-Node 'delimited-error-message' '表格包含未闭合的引号' 'text'
$delimitedErrorAction = Wait-Query-Node 'delimited-error-source-action' '切换到源码' 'clickable'
Assert-Same-HeaderRow $delimitedErrorTitle $delimitedErrorAction
Capture-Screen 'delimited-error'

Launch-Fixture -State 'binary-preview'
$binaryTitle = Wait-Query-Node 'binary-title' 'archive.zip' 'text'
$binaryMessage = Wait-Query-Node 'binary-message' '此文件类型暂不支持预览，仍可下载' 'text'
Capture-Screen 'binary-preview'

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during document mode E2E.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  hapPath = $HapPath
  hapSha256 = $hapSha256
  result = 'Passed'
  checked = [ordered]@{
    modeActionSharesTitleRow = $true
    legacyModeLabelsAbsent = $true
    sourceModeShowsSource = $true
    previewModeRestoresRendering = $true
    sourceMarkerAbsentAfterRestore = $true
    configMarkerRendered = $true
    configModeActionSharesTitleRow = $true
    csvTableRenderedByDefault = $true
    csvLiteralCellNotMarkdown = $true
    csvSourceModeActionSharesTitleRow = $true
    csvSourceHidesTableProjection = $true
    csvTableRestored = $true
    tsvTableRendered = $true
    malformedCsvShowsTableError = $true
    malformedCsvSourceRemainsAvailable = $true
    binaryDownloadOnlyMessageRendered = $true
    processAliveAfterToggle = $true
  }
}
$manifest |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Document mode E2E passed. Evidence: $captureDir"
