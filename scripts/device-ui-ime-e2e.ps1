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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-ime-e2e'
}
$captureDir = Join-Path $OutputDir 'composer-layout'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; composer IME E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'

function Text-Hex {
  param([string]$Text)
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')
}

function Launch-Fixture {
  param(
    [string]$State,
    [string]$Theme,
    [bool]$First = $false
  )

  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = 'conversation'
    State = $State
    Theme = $Theme
    OutputDir = $OutputDir
  }
  if ($SkipBuild -or -not $First) {
    $arguments.SkipBuild = $true
  }
  if ($SkipInstall -or -not $First) {
    $arguments.SkipInstall = $true
  }
  & $mockScript @arguments | Out-Host
}

function Dump-Layout {
  param([string]$Name)
  [OutputType([string])]
  $remote = "/data/local/tmp/dsh-ime-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -m true" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Layout dump failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Layout receive failed: $Name"
  }
  return [string]$local
}

function Capture-Screen {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-ime-$Name.jpeg"
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
  $raw = & python $queryScript $Layout `
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
    [string]$Target = 'text',
    [int]$ExpectCount = 1
  )
  $raw = & python $queryScript $Layout `
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
    [string]$layoutPath = @(Dump-Layout "$Name-$attempt")[-1]
    try {
      return (Query-Node $layoutPath $Text $Target $ExpectCount)
    } catch {
      $lastError = $_.Exception.Message
    }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Layout wait failed for '$Text' after $TimeoutMilliseconds ms: $lastError"
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

function Assert-HeaderStable {
  param([object]$Before, [object]$After)
  $beforeBounds = Get-Bounds $Before.bounds
  $afterBounds = Get-Bounds $After.bounds
  if ([Math]::Abs($afterBounds.top - $beforeBounds.top) -gt 1) {
    throw "Header moved while IME opened: $($before.bounds) -> $($After.bounds)"
  }
}

function Assert-TranscriptAnchored {
  param(
    [object]$BeforeRow,
    [object]$OpenRow,
    [object]$OpenComposer
  )
  $beforeBounds = Get-Bounds $BeforeRow.bounds
  $openBounds = Get-Bounds $OpenRow.bounds
  $composerBounds = Get-Bounds $OpenComposer.bounds
  if ($openBounds.bottom -ge ($beforeBounds.bottom - 40)) {
    throw "Transcript tail did not move upward with the IME: $($BeforeRow.bounds) -> $($OpenRow.bounds)"
  }
  if ($openBounds.bottom -gt $composerBounds.top) {
    throw "Transcript tail overlaps the composer: tail=$($OpenRow.bounds) composer=$($OpenComposer.bounds)"
  }
}

function Open-Ime {
  param(
    [string]$Name,
    [object]$InitialComposer
  )
  $deadline = [DateTime]::UtcNow.AddMilliseconds(6000)
  $lastError = ''
  do {
    try {
      $layout = Dump-Layout "$Name-open"
      $composer = Query-Node $layout '发送消息…' 'text'
      $composerBounds = Get-Bounds $composer.bounds
      $initialBounds = Get-Bounds $InitialComposer.bounds
      if ($composerBounds.top -lt ($initialBounds.top - 80)) {
        return @{
          layout = $layout
          composer = $composer
        }
      }
      $lastError = "Composer did not move above the IME: $($InitialComposer.bounds) -> $($composer.bounds)"
    } catch {
      $lastError = $_.Exception.Message
    }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "IME did not open or resize the composer: $lastError"
}

function Close-Ime {
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw 'IME dismissal failed.'
  }
  Start-Sleep -Milliseconds 450
}

function Invoke-Click {
  param([object]$Node)
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Input click failed at $($Node.x),$($Node.y)"
  }
  Start-Sleep -Milliseconds 300
}

function Get-RootBounds {
  param([string]$Layout)
  $content = Get-Content -LiteralPath $Layout -Raw -Encoding UTF8
  $parsed = $content | ConvertFrom-Json

  function Find-AppRoot {
    param([object]$Node)
    if ($null -eq $Node) {
      return $null
    }
    $attributes = $Node.attributes
    if ($attributes.type -eq 'root' -and $attributes.bundleName -eq $bundle -and
      $attributes.abilityName -eq 'EntryAbility') {
      return $Node
    }
    foreach ($child in @($Node.children)) {
      $found = Find-AppRoot $child
      if ($null -ne $found) {
        return $found
      }
    }
    return $null
  }

  $root = Find-AppRoot $parsed
  if ($null -eq $root) {
    throw "App window root not found in merged layout: $Layout"
  }
  return Get-Bounds $root.attributes.bounds
}

function Assert-ImeSendGap {
  param(
    [string]$Layout,
    [object]$Send,
    [int]$MaximumPixels
  )
  $rootBounds = Get-RootBounds $Layout
  $sendBounds = Get-Bounds $Send.bounds
  $gap = $rootBounds.bottom - $sendBounds.bottom
  if ($gap -lt 0 -or $gap -gt $MaximumPixels) {
    throw "Composer send control has an invalid IME gap: gap=$gap send=$($Send.bounds) root=$($rootBounds.left),$($rootBounds.top),$($rootBounds.right),$($rootBounds.bottom)"
  }
  return $gap
}

$bundle = 'io.github.stlin256.dshharmony'

$firstTheme = $true
foreach ($theme in @('dark', 'light')) {
  Launch-Fixture -State 'completed' -Theme $theme -First $firstTheme
  $firstTheme = $false
  $initialLayout = Dump-Layout "$theme-initial"
  $initialTitle = Query-Node $initialLayout '发布准备与商店检查' 'text'
  $initialComposer = Query-Node $initialLayout '发送消息…' 'text'
  $initialSend = Query-Node-ById $initialLayout 'composer-send' 'text'
  $initialTail = Query-Node-ById $initialLayout 'transcript-tail-row' 'text'
  $initialGap = Assert-ImeSendGap $initialLayout $initialSend 96

  Invoke-Click $initialComposer
  $opened = Open-Ime "$theme-ime" $initialComposer
  $openedTitle = Query-Node $opened.layout '发布准备与商店检查' 'text'
  Assert-HeaderStable $initialTitle $openedTitle
  $openedSend = Query-Node-ById $opened.layout 'composer-send' 'text'
  $openedTail = Query-Node-ById $opened.layout 'transcript-tail-row' 'text'
  $openedGap = Assert-ImeSendGap $opened.layout $openedSend 66
  if ($openedGap -ge $initialGap) {
    throw "IME did not tighten the composer gap: closed=$initialGap open=$openedGap"
  }
  Assert-TranscriptAnchored $initialTail $openedTail $opened.composer

  $rootBounds = Get-RootBounds $opened.layout
  $openComposerBounds = Get-Bounds $opened.composer.bounds
  if ($openComposerBounds.bottom -gt $rootBounds.bottom) {
    throw "Composer extends below the resized page: $($opened.composer.bounds) > $rootBounds"
  }
  Capture-Screen "$theme-ime-open"

  if ($theme -eq 'dark') {
    & $hdc -t $Device shell "uitest uiInput inputText $($opened.composer.x) $($opened.composer.y) ime_layout_probe" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw 'Draft input failed.'
    }
    $null = Wait-Query-Node 'dark-ime-draft' 'ime_layout_probe' 'text' 1
    Capture-Screen 'dark-ime-draft'
  }

  Close-Ime
  $closedLayout = Dump-Layout "$theme-closed"
  $closedTitle = Query-Node $closedLayout '发布准备与商店检查' 'text'
  $closedComposer = if ($theme -eq 'dark') {
    Query-Node $closedLayout 'ime_layout_probe' 'text'
  } else {
    Query-Node $closedLayout '发送消息…' 'text'
  }
  $closedSend = Query-Node-ById $closedLayout 'composer-send' 'text'
  $closedTail = Query-Node-ById $closedLayout 'transcript-tail-row' 'text'
  $closedGap = Assert-ImeSendGap $closedLayout $closedSend 96
  if ($closedGap -le $openedGap) {
    throw "Composer gap did not restore after IME close: open=$openedGap closed=$closedGap"
  }
  Assert-HeaderStable $initialTitle $closedTitle
  $closedComposerBounds = Get-Bounds $closedComposer.bounds
  $initialComposerBounds = Get-Bounds $initialComposer.bounds
  if ([Math]::Abs($closedComposerBounds.top - $initialComposerBounds.top) -gt 2) {
    throw "Composer geometry did not restore after IME close: $($initialComposer.bounds) -> $($closedComposer.bounds)"
  }
  $closedTailBounds = Get-Bounds $closedTail.bounds
  $initialTailBounds = Get-Bounds $initialTail.bounds
  if ([Math]::Abs($closedTailBounds.bottom - $initialTailBounds.bottom) -gt 4) {
    throw "Transcript tail geometry did not restore after IME close: $($initialTail.bounds) -> $($closedTail.bounds)"
  }
  if ($theme -eq 'dark') {
    $null = Query-Node $closedLayout 'ime_layout_probe' 'text' 1
  }
  Capture-Screen "$theme-ime-closed"
}

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during composer IME E2E.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap')).Hash
  result = 'Passed'
  checked = [ordered]@{
    initialNativeModeUsesResize = $true
    headerTopStableWhileImeOpen = $true
    composerRemainsInsideResizedPage = $true
    imeSendGapTightened = $true
    transcriptTailMovesUpWithIme = $true
    transcriptTailRemainsAboveComposer = $true
    idleSafeGapRestored = $true
    headerComposerAndTranscriptGeometryRestore = $true
    draftSurvivesImeClose = $true
    lightAndDarkHeaderStable = $true
    processAliveAfterAllFlows = $true
  }
  evidence = [ordered]@{
    darkInitialLayout = 'dark-initial.json'
    darkOpenScreenshot = 'dark-ime-open.jpeg'
    darkOpenLayout = 'dark-ime-open.json'
    darkDraftScreenshot = 'dark-ime-draft.jpeg'
    darkClosedScreenshot = 'dark-ime-closed.jpeg'
    darkClosedLayout = 'dark-ime-closed.json'
    lightOpenScreenshot = 'light-ime-open.jpeg'
    lightOpenLayout = 'light-ime-open.json'
    lightClosedScreenshot = 'light-ime-closed.jpeg'
    lightClosedLayout = 'light-ime-closed.json'
  }
}
$manifest |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Composer IME E2E passed. Evidence: $captureDir"
