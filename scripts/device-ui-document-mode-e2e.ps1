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
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')
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

function Query-Node-ById {
  param(
    [string]$Layout,
    [string]$Id,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'clickable',
    [int]$ExpectCount = 1
  )
  $raw = & python $queryScript `
    $Layout `
    --find-id $Id `
    --target $Target `
    --expect-count $ExpectCount 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout id query failed for '$Id': $($raw -join [Environment]::NewLine)"
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

function Wait-Query-Node-ById {
  param(
    [string]$Name,
    [string]$Id,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'clickable',
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
      return (Query-Node-ById $layout $Id $Target $ExpectCount)
    } catch {
      $lastError = $_.Exception.Message
      Start-Sleep -Milliseconds 250
    }
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Layout id wait failed for '$Id' after $TimeoutMilliseconds ms: $lastError"
}

function Wait-Revealed-Table-Cell {
  param(
    [string]$Name,
    [string]$AnchorText,
    [string]$TargetText
  )
  $anchor = Wait-Query-Node "$Name-anchor" $AnchorText 'text'
  $bounds = [regex]::Match([string]$anchor.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $bounds.Success) {
    throw "Cannot read table anchor bounds: $($anchor.bounds)"
  }
  $swipeY = ([int]$bounds.Groups[2].Value + [int]$bounds.Groups[4].Value) / 2
  for ($attempt = 0; $attempt -lt 5; $attempt++) {
    $layout = Dump-Layout "$Name-$attempt"
    try {
      return (Query-Node $layout $TargetText 'text' 1)
    } catch {
      $lastError = $_.Exception.Message
    }
    & $hdc -t $Device shell "uitest uiInput swipe 1100 $swipeY 180 $swipeY 600" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw 'Horizontal table swipe failed.'
    }
    Start-Sleep -Milliseconds 500
  }
  throw "Could not reveal '$TargetText' by horizontal table scrolling: $lastError"
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

function Assert-ActionOrder {
  param(
    [object]$Mode,
    [object]$Download,
    [object]$Close
  )
  $modeBounds = [regex]::Match([string]$Mode.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  $downloadBounds = [regex]::Match([string]$Download.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  $closeBounds = [regex]::Match([string]$Close.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $modeBounds.Success -or -not $downloadBounds.Success -or -not $closeBounds.Success) {
    throw "Cannot compare preview action order: mode=$($Mode.bounds), download=$($Download.bounds), close=$($Close.bounds)"
  }
  $modeX = ([int]$modeBounds.Groups[1].Value + [int]$modeBounds.Groups[3].Value) / 2
  $downloadX = ([int]$downloadBounds.Groups[1].Value + [int]$downloadBounds.Groups[3].Value) / 2
  $closeX = ([int]$closeBounds.Groups[1].Value + [int]$closeBounds.Groups[3].Value) / 2
  if (-not ($modeX -lt $downloadX -and $downloadX -lt $closeX)) {
    throw "Preview actions are not ordered mode -> download -> close: $($Mode.bounds), $($Download.bounds), $($Close.bounds)"
  }
}

function Get-Bounds {
  param([string]$Value)
  if ($Value -notmatch '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$') {
    throw "Invalid bounds: $Value"
  }
  return @{
    left = [int]$Matches[1]
    top = [int]$Matches[2]
    right = [int]$Matches[3]
    bottom = [int]$Matches[4]
  }
}

function Assert-TableTopLeft {
  param(
    [object]$Container,
    [object]$FirstCell
  )
  $containerBounds = Get-Bounds $Container.bounds
  $cellBounds = Get-Bounds $FirstCell.bounds
  if ([Math]::Abs($cellBounds.left - $containerBounds.left) -gt 2) {
    throw "Table is not left aligned: container=$($Container.bounds) firstCell=$($FirstCell.bounds)"
  }
  if ([Math]::Abs($cellBounds.top - $containerBounds.top) -gt 2) {
    throw "Table is not top aligned: container=$($Container.bounds) firstCell=$($FirstCell.bounds)"
  }
}

function Assert-TableColumnWidths {
  param(
    [object]$ShortHeader,
    [object]$WideHeader,
    [object]$ShortCell,
    [object]$WideCell
  )
  $shortHeaderBounds = Get-Bounds $ShortHeader.bounds
  $wideHeaderBounds = Get-Bounds $WideHeader.bounds
  $shortCellBounds = Get-Bounds $ShortCell.bounds
  $wideCellBounds = Get-Bounds $WideCell.bounds
  $shortHeaderWidth = $shortHeaderBounds.right - $shortHeaderBounds.left
  $wideHeaderWidth = $wideHeaderBounds.right - $wideHeaderBounds.left
  $shortCellWidth = $shortCellBounds.right - $shortCellBounds.left
  $wideCellWidth = $wideCellBounds.right - $wideCellBounds.left
  if ($wideHeaderWidth -le $shortHeaderWidth + 8) {
    throw "Content-heavy table column did not grow: short=$($ShortHeader.bounds) wide=$($WideHeader.bounds)"
  }
  if ([Math]::Abs($shortHeaderWidth - $shortCellWidth) -gt 1) {
    throw "Short header/data widths differ: header=$($ShortHeader.bounds) cell=$($ShortCell.bounds)"
  }
  if ([Math]::Abs($wideHeaderWidth - $wideCellWidth) -gt 1) {
    throw "Wide header/data widths differ: header=$($WideHeader.bounds) cell=$($WideCell.bounds)"
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
$title = Wait-Query-Node-ById 'preview-default' 'document-preview-title' 'text'
$sourceAction = Wait-Query-Node-ById 'preview-source-action' 'document-mode-toggle'
$previewLayout = Dump-Layout 'preview-default-layout'
$null = Query-Node $previewLayout '预览' 'text' 0
$null = Query-Node $previewLayout '代码' 'text' 0
$null = Query-Node $previewLayout '复制文件路径' 'clickable' 0
$previewDownload = Query-Node-ById $previewLayout 'document-download'
$previewClose = Query-Node-ById $previewLayout 'document-close'
Assert-Same-HeaderRow $title $sourceAction
Assert-ActionOrder $sourceAction $previewDownload $previewClose
Capture-Screen 'preview-default'

Invoke-Click $sourceAction
$sourceMarker = Wait-Query-Node 'source-mode' '<!-- DSH_SOURCE_MARKER -->' 'text'
$previewAction = Wait-Query-Node-ById 'source-preview-action' 'document-mode-toggle'
Assert-Same-HeaderRow $title $previewAction
Capture-Screen 'source-mode'

Invoke-Click $previewAction
$restoredAction = Wait-Query-Node-ById 'preview-restored' 'document-mode-toggle'
$restoredLayout = Dump-Layout 'preview-restored-layout'
$null = Query-Node $restoredLayout '<!-- DSH_SOURCE_MARKER -->' 'text' 0
Assert-Same-HeaderRow $title $restoredAction
Capture-Screen 'preview-restored'

Launch-Fixture -State 'text-config-preview'
$configTitle = Wait-Query-Node-ById 'config-title' 'document-preview-title' 'text'
$configViewer = Wait-Query-Node-ById 'config-viewer' 'document-code-viewer' 'text'
$configLayout = Dump-Layout 'config-layout'
$null = Query-Node-ById $configLayout 'document-mode-toggle' 'clickable' 0
$null = Query-Node $configLayout '复制文件路径' 'clickable' 0
Capture-Screen 'config-preview'

Launch-Fixture -State 'delimited-preview'
$delimitedTitle = Wait-Query-Node-ById 'delimited-title' 'document-preview-title' 'text'
$null = Wait-Query-Node-ById 'delimited-table-ready' 'delimited-table' 'text'
$delimitedTableLayout = Dump-Layout 'delimited-table-layout'
$delimitedTable = Query-Node-ById $delimitedTableLayout 'delimited-table' 'text'
$delimitedFirstCell = Query-Node-ById $delimitedTableLayout 'delimited-table-h-0' 'text'
$delimitedShortHeader = Query-Node-ById $delimitedTableLayout 'delimited-table-h-1' 'text'
$delimitedWideHeader = Query-Node-ById $delimitedTableLayout 'delimited-table-h-3' 'text'
$delimitedShortCell = Query-Node-ById $delimitedTableLayout 'delimited-table-r-0-1' 'text'
$delimitedWideCell = Query-Node-ById $delimitedTableLayout 'delimited-table-r-0-3' 'text'
Assert-TableTopLeft $delimitedTable $delimitedFirstCell
Assert-TableColumnWidths $delimitedShortHeader $delimitedWideHeader `
  $delimitedShortCell $delimitedWideCell
$tableMarker = Wait-Revealed-Table-Cell 'delimited-table-marker' 'Alpha' 'DSH_TABLE_MARKER'
$literalTable = Wait-Query-Node 'delimited-literal-table' '**literal value**' 'text'
$delimitedSourceAction = Wait-Query-Node-ById 'delimited-source-action' 'document-mode-toggle'
Assert-Same-HeaderRow $delimitedTitle $delimitedSourceAction
Capture-Screen 'delimited-table-wide'

Invoke-Click $delimitedSourceAction
$delimitedPreviewAction = Wait-Query-Node-ById 'delimited-preview-action' 'document-mode-toggle'
$delimitedSourceLayout = Dump-Layout 'delimited-source-layout'
$null = Query-Node-ById $delimitedSourceLayout 'document-code-viewer' 'text' 1
$null = Query-Node $delimitedSourceLayout '行' 'text' 0
Capture-Screen 'delimited-source'

Invoke-Click $delimitedPreviewAction
$restoredTable = Wait-Query-Node 'delimited-restored-table' 'Alpha' 'text'
Capture-Screen 'delimited-restored'

Launch-Fixture -State 'tsv-preview'
$tsvTitle = Wait-Query-Node-ById 'tsv-title' 'document-preview-title' 'text'
$null = Wait-Query-Node-ById 'tsv-table-ready' 'delimited-table' 'text'
$tsvTableLayout = Dump-Layout 'tsv-table-layout'
$tsvTable = Query-Node-ById $tsvTableLayout 'delimited-table' 'text'
$tsvFirstCell = Query-Node-ById $tsvTableLayout 'delimited-table-h-0' 'text'
Assert-TableTopLeft $tsvTable $tsvFirstCell
$tsvMarker = Wait-Revealed-Table-Cell 'tsv-marker' 'Alpha' 'DSH_TSV_MARKER'
$tsvSourceAction = Wait-Query-Node-ById 'tsv-source-action' 'document-mode-toggle'
Assert-Same-HeaderRow $tsvTitle $tsvSourceAction
Capture-Screen 'tsv-table-wide'

Launch-Fixture -State 'delimited-error-preview'
$delimitedErrorTitle = Wait-Query-Node-ById 'delimited-error-title' 'document-preview-title' 'text'
$delimitedError = Wait-Query-Node 'delimited-error-message' '表格包含未闭合的引号' 'text'
$delimitedErrorAction = Wait-Query-Node-ById 'delimited-error-source-action' 'document-mode-toggle'
Assert-Same-HeaderRow $delimitedErrorTitle $delimitedErrorAction
Capture-Screen 'delimited-error'

Launch-Fixture -State 'binary-preview'
$binaryTitle = Wait-Query-Node-ById 'binary-title' 'document-preview-title' 'text'
$binaryMessage = Wait-Query-Node 'binary-message' '此文件类型暂不支持预览，仍可下载' 'text'
$binaryLayout = Dump-Layout 'binary-layout'
$null = Query-Node $binaryLayout '复制文件路径' 'clickable' 0
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
    modeActionOccupiesFormerCopySlot = $true
    previewCopyActionAbsent = $true
    legacyModeLabelsAbsent = $true
    sourceModeShowsSource = $true
    previewModeRestoresRendering = $true
    sourceMarkerAbsentAfterRestore = $true
    configCodeViewerRendered = $true
    plainConfigHasNoModeToggle = $true
    csvTableRenderedByDefault = $true
    csvLiteralCellNotMarkdown = $true
    csvTableStartsAtTopLeft = $true
    csvColumnsAdaptToContent = $true
    csvHeaderAndDataColumnsShareWidths = $true
    csvSourceModeActionSharesTitleRow = $true
    csvSourceHidesTableProjection = $true
    csvTableRestored = $true
    tsvTableRendered = $true
    tsvTableStartsAtTopLeft = $true
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
