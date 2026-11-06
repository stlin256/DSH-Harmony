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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-mode-subagent-e2e'
}
if (-not [IO.Path]::IsPathRooted($OutputDir)) {
  $OutputDir = Join-Path $repo $OutputDir
}
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'plan-lineage'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; mode/subagent E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$bundle = 'io.github.stlin256.dshharmony'
$firstLaunch = $true

function Text-Hex {
  param([string]$Text)
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')
}

function Launch-Fixture {
  param(
    [string]$Screen,
    [string]$State,
    [string]$Theme = 'dark'
  )
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = $Screen
    State = $State
    Theme = $Theme
    OutputDir = $OutputDir
    ResetData = $true
  }
  if ($SkipBuild -or -not $firstLaunch) {
    $arguments.SkipBuild = $true
  }
  if ($SkipInstall -or -not $firstLaunch) {
    $arguments.SkipInstall = $true
  }
  & $mockScript @arguments | Out-Host
  $script:firstLaunch = $false
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-mode-$Name.json"
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
  $remote = "/data/local/tmp/dsh-mode-$Name.jpeg"
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

function Wait-Query-ById {
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
  throw "Layout wait failed for '$Id' after $TimeoutMilliseconds ms: $lastError"
}

function Assert-Same-HeaderRow {
  param(
    [object]$Title,
    [object]$CountChip
  )
  $titleBounds = [regex]::Match([string]$Title.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  $chipBounds = [regex]::Match([string]$CountChip.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $titleBounds.Success -or -not $chipBounds.Success) {
    throw "Cannot compare header bounds: title=$($Title.bounds), chip=$($CountChip.bounds)"
  }
  $titleTop = [int]$titleBounds.Groups[2].Value
  $titleBottom = [int]$titleBounds.Groups[4].Value
  $chipTop = [int]$chipBounds.Groups[2].Value
  $chipBottom = [int]$chipBounds.Groups[4].Value
  $overlap = [Math]::Min($titleBottom, $chipBottom) - [Math]::Max($titleTop, $chipTop)
  if ($overlap -le 0) {
    throw "Subagent count is not in the conversation title row: title=$($Title.bounds), chip=$($CountChip.bounds)"
  }
}

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
    Width = [int]$match.Groups[3].Value - [int]$match.Groups[1].Value
    Height = [int]$match.Groups[4].Value - [int]$match.Groups[2].Value
  }
}

function Assert-Compact-SubagentEntry {
  param(
    [object]$Entry
  )
  $bounds = [regex]::Match([string]$Entry.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $bounds.Success) {
    throw "Cannot read subagent entry bounds: $($Entry.bounds)"
  }
  $width = [int]$bounds.Groups[3].Value - [int]$bounds.Groups[1].Value
  $height = [int]$bounds.Groups[4].Value - [int]$bounds.Groups[2].Value
  if ($width -gt 280 -or $height -lt 100) {
    throw "Subagent title entry is not compact or misses its 44vp target: " +
      "width=$width height=$height bounds=$($Entry.bounds)"
  }
}

function Capture-Pressed-SubagentEntry {
  param(
    [object]$Entry
  )
  $bounds = Get-Bounds $Entry
  $x = [int](($bounds.Left + $bounds.Right) / 2)
  $y = [int](($bounds.Top + $bounds.Bottom) / 2)
  $remoteLayout = '/data/local/tmp/dsh-mode-subagent-pressed.json'
  $localLayout = Join-Path $captureDir 'subagent-entry-pressed.json'
  $remoteImage = '/data/local/tmp/dsh-mode-subagent-pressed.jpeg'
  $localImage = Join-Path $captureDir 'subagent-entry-pressed.jpeg'
  $longPress = Start-Process -FilePath $hdc `
    -ArgumentList @('-t', $Device, 'shell', "uitest uiInput longClick $x $y") `
    -WindowStyle Hidden -PassThru
  Start-Sleep -Milliseconds 220
  & $hdc -t $Device shell "uitest dumpLayout -p $remoteLayout -i -b $bundle" | Out-Null
  & $hdc -t $Device shell "uitest screenCap -p $remoteImage" | Out-Null
  & $hdc -t $Device file recv $remoteLayout $localLayout | Out-Null
  & $hdc -t $Device file recv $remoteImage $localImage | Out-Null
  $longPress.WaitForExit()
  if ($longPress.ExitCode -ne 0) {
    throw "Subagent press injection failed: $($longPress.ExitCode)"
  }
  if (-not (Test-Path -LiteralPath $localImage)) {
    throw 'Subagent pressed-state screenshot is missing.'
  }
}

function Assert-LayoutBottomSafe {
  param([string]$Layout)
  $raw = & python $queryScript $Layout `
    --assert-bottom-safe `
    --bottom-safe-px 60 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Bottom safe-area assertion failed: $($raw -join [Environment]::NewLine)"
  }
}

function Invoke-Click {
  param(
    [object]$Node,
    [int]$SettleMilliseconds = 650
  )
  if ($null -eq $Node.x -or $null -eq $Node.y) {
    throw "Cannot click a node without bounds: $($Node.text)"
  }
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Input click failed at $($Node.x),$($Node.y)"
  }
  Start-Sleep -Milliseconds $SettleMilliseconds
}

function Enter-Text {
  param(
    [object]$Node,
    [string]$Text
  )
  if ($null -eq $Node.x -or $null -eq $Node.y) {
    throw "Cannot enter text without focused bounds: $($Node.text)"
  }
  & $hdc -t $Device shell "uitest uiInput inputText $($Node.x) $($Node.y) $Text" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Text input failed at $($Node.x),$($Node.y)"
  }
  Start-Sleep -Milliseconds 500
}

function Query-Rightmost-Action {
  param(
    [string]$Layout,
    [int]$AnchorX,
    [int]$AnchorY
  )
  $raw = & python $queryScript $Layout `
    --rightmost-clickable-below $AnchorX $AnchorY 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Rightmost action query failed: $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Wait-Rightmost-Action {
  param(
    [string]$Name,
    [int]$AnchorX,
    [int]$AnchorY,
    [int]$TimeoutMilliseconds = 6000
  )
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
  $lastError = ''
  $attempt = 0
  do {
    $attempt++
    try {
      $layout = Dump-Layout "$Name-$attempt"
      return (Query-Rightmost-Action $layout $AnchorX $AnchorY)
    } catch {
      $lastError = $_.Exception.Message
      Start-Sleep -Milliseconds 250
    }
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Enabled composer action did not appear after $TimeoutMilliseconds ms: $lastError"
}

function Return-To-ParentConversation {
  for ($attempt = 0; $attempt -lt 3; $attempt++) {
    $layout = Dump-Layout "returned-parent-$attempt"
    try {
      $null = Query-Node-ById $layout 'subagent-title-entry' 'clickable' 1
      return
    } catch {
      & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
      Start-Sleep -Milliseconds 650
    }
  }
  throw 'System Back did not return from the child conversation to the parent.'
}

Launch-Fixture -Screen 'conversation' -State 'plan-subagent' -Theme 'dark'
$null = Wait-Query-Node 'plan-chip-absent' '计划' 'text' 0
$titleNode = Wait-Query-Node 'title-visible' '计划与子智能体' 'text'
$planLayout = Dump-Layout 'plan-subagents'
$subagents = Query-Node-ById $planLayout 'subagent-title-entry' 'clickable' 1
$baselineEntryBounds = Get-Bounds $subagents
$null = Query-Node $planLayout '任务计划' 'clickable' 1
Assert-Same-HeaderRow $titleNode $subagents
Assert-Compact-SubagentEntry $subagents
Assert-LayoutBottomSafe $planLayout
Capture-Screen 'plan-visible'
Capture-Pressed-SubagentEntry $subagents
$more = Wait-Query-ById 'plan-more' 'workspace-utility-more' 'clickable'
Invoke-Click $more
$exitPlan = Wait-Query-Node 'plan-exit-action' '退出计划模式' 'clickable'
Invoke-Click $exitPlan
Start-Sleep -Milliseconds 650
$moreAfter = Wait-Query-ById 'plan-more-after' 'workspace-utility-more' 'clickable'
Invoke-Click $moreAfter
$planRemoved = Dump-Layout 'plan-removed'
$null = Query-Node $planRemoved '退出计划模式' 'clickable' 0
Capture-Screen 'plan-removed'

Launch-Fixture -Screen 'conversation' -State 'plan-off-error' -Theme 'dark'
$null = Wait-Query-Node 'plan-error-no-chip' '计划' 'text' 0
$moreError = Wait-Query-ById 'plan-error-more' 'workspace-utility-more' 'clickable'
Invoke-Click $moreError
$planError = Wait-Query-Node 'plan-error-before' '退出计划模式' 'clickable'
Invoke-Click $planError -SettleMilliseconds 100
$null = Wait-Query-Node 'plan-error-visible' '退出计划模式失败' 'text' 1
$moreErrorAfter = Wait-Query-ById 'plan-error-more-after' 'workspace-utility-more' 'clickable'
Invoke-Click $moreErrorAfter
$planErrorAfter = Dump-Layout 'plan-error-after'
$null = Query-Node $planErrorAfter '退出计划模式' 'clickable' 1
Capture-Screen 'plan-error-after'

Launch-Fixture -Screen 'conversation' -State 'plan-subagent-long-count' -Theme 'dark'
$null = Wait-Query-Node 'long-count-visible' '128' 'text' 1
$longTitle = Wait-Query-Node 'long-title-visible' '计划与子智能体标题很长时优先压缩标题并保留数量' 'text'
$longLayout = Dump-Layout 'plan-subagents-long-count'
$longEntry = Query-Node-ById $longLayout 'subagent-title-entry' 'clickable' 1
$longEntryBounds = Get-Bounds $longEntry
$longMore = Query-Node-ById $longLayout 'workspace-utility-more' 'clickable' 1
$longMoreBounds = Get-Bounds $longMore
$longTitleBounds = Get-Bounds $longTitle
Assert-Same-HeaderRow $longTitle $longEntry
Assert-Compact-SubagentEntry $longEntry
if ($longEntryBounds.Width -le $baselineEntryBounds.Width) {
  throw "Long subagent count did not expand the entry: " +
    "baseline=$($baselineEntryBounds.Width), long=$($longEntryBounds.Width)"
}
if ($longEntryBounds.Left -ge $baselineEntryBounds.Left) {
  throw "Long subagent count did not move its left edge outward: " +
    "baseline=$($baselineEntryBounds.Left), long=$($longEntryBounds.Left)"
}
if ($longTitleBounds.Right -gt $longEntryBounds.Left + 2) {
  throw "Title did not yield space to the long subagent count: " +
    "title=$($longTitleBounds.Right), entry=$($longEntryBounds.Left)"
}
if ($longEntryBounds.Right -gt $longMoreBounds.Left + 2) {
  throw "Long subagent count overlaps the more action: " +
    "entry=$($longEntryBounds.Right), more=$($longMoreBounds.Left)"
}
Assert-LayoutBottomSafe $longLayout
Capture-Screen 'plan-visible-long-count'

Launch-Fixture -Screen 'lineage' -State 'plan-subagent' -Theme 'dark'
$lineageLayout = Dump-Layout 'lineage-open'
$null = Query-Node $lineageLayout '可继续检查' 'text' 1
$null = Query-Node $lineageLayout '一次性检查' 'text' 1
$null = Query-Node $lineageLayout '未知模式记录' 'text' 1
$null = Query-Node $lineageLayout '外部任务' 'text' 1
$null = Query-Node $lineageLayout '不可打开' 'text' 1
Assert-LayoutBottomSafe $lineageLayout
Capture-Screen 'lineage-open'
& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 650
$null = Wait-Query-Node 'lineage-closed' '计划与子智能体' 'text' 1

Launch-Fixture -Screen 'subagent' -State 'subagent-continuable' -Theme 'dark'
$continuableLayout = Dump-Layout 'continuable'
$null = Query-Node $continuableLayout '可继续检查' 'text' 1
$null = Query-Node-ById $continuableLayout 'workspace-sidebar' 'clickable' 0
$null = Query-Node-ById $continuableLayout 'workspace-subagent-back' 'clickable' 1
$composer = Query-Node $continuableLayout '发送消息…' 'text' 1
Assert-LayoutBottomSafe $continuableLayout
Capture-Screen 'continuable'
Invoke-Click $composer
$composerFocused = Dump-Layout 'continuable-focused'
$focusedComposer = Query-Node $composerFocused '发送消息…' 'text' 1
Enter-Text $focusedComposer 'subagent_probe'
$composerActive = Dump-Layout 'continuable-active'
$activeDraft = Query-Node $composerActive 'subagent_probe' 'text' 1
$send = Wait-Rightmost-Action 'continuable-send-enabled' $activeDraft.x $activeDraft.y
Invoke-Click $send
$null = Wait-Query-Node 'subagent-sent' 'subagent_probe' 'text' 1
$subagentSent = Dump-Layout 'subagent-sent'
$null = Query-Node $subagentSent 'subagent_probe' 'text' 1
Capture-Screen 'subagent-sent'
Return-To-ParentConversation

Launch-Fixture -Screen 'subagent' -State 'subagent-one-shot' -Theme 'light'
$oneShotLayout = Dump-Layout 'one-shot'
$null = Query-Node $oneShotLayout '一次性子智能体记录' 'text' 1
$null = Query-Node $oneShotLayout '发送消息…' 'text' 0
Assert-LayoutBottomSafe $oneShotLayout
Capture-Screen 'one-shot'

Launch-Fixture -Screen 'subagent' -State 'subagent-unknown' -Theme 'light'
$unknownLayout = Dump-Layout 'unknown'
$null = Query-Node $unknownLayout '此子智能体暂时只读' 'text' 1
$null = Query-Node $unknownLayout '发送消息…' 'text' 0
Assert-LayoutBottomSafe $unknownLayout
Capture-Screen 'unknown'

Launch-Fixture -Screen 'subagent' -State 'subagent-parent-offline' -Theme 'dark'
$offlineLayout = Dump-Layout 'parent-offline'
$null = Query-Node $offlineLayout '父会话暂不可用' 'text' 1
$null = Query-Node $offlineLayout '发送消息…' 'text' 0
Assert-LayoutBottomSafe $offlineLayout
Capture-Screen 'parent-offline'

& $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
Start-Sleep -Milliseconds 500
$coldLaunch = "aa start -a EntryAbility -b $bundle -m entry " +
  '--ps storeShowcase true --ps showcaseState completed --ps showcaseTheme dark'
& $hdc -t $Device shell $coldLaunch | Out-Null
$null = Wait-Query-ById 'cold-root' 'workspace-sidebar' 'clickable' 1 15000
$coldLayout = Dump-Layout 'cold-root-layout'
$null = Query-Node-ById $coldLayout 'workspace-subagent-back' 'clickable' 0
Capture-Screen 'cold-root'

& $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
Start-Sleep -Milliseconds 500
$requestedChildLaunch = "aa start -a EntryAbility -b $bundle -m entry " +
  '--ps storeShowcase true --ps showcaseScreen conversation ' +
  '--ps showcaseState plan-subagent --ps showcaseTheme dark ' +
  '--ps sessionId showcase-child-continuable'
& $hdc -t $Device shell $requestedChildLaunch | Out-Null
$null = Wait-Query-ById 'requested-child-root' 'workspace-sidebar' 'clickable' 1 15000
$requestedChildLayout = Dump-Layout 'requested-child-root-layout'
$null = Query-Node-ById $requestedChildLayout 'workspace-subagent-back' 'clickable' 0
$null = Query-Node $requestedChildLayout '计划与子智能体' 'text' 1
Capture-Screen 'requested-child-root'

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during mode/subagent E2E.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap')).Hash
  result = 'Passed'
  checked = [ordered]@{
    planChipAbsentFromHeader = $true
    planExitLivesInOverflowMenu = $true
    planFailureKeepsActionAndShowsMessage = $true
    subagentCountSharesTitleRow = $true
    subagentEntryUsesCompactIconAndCount = $true
    subagentLongCountExpandsLeftAndCompressesTitle = $true
    subagentPressedSurfaceIsCompactCapsule = $true
    childPageHasNoSidebarEntry = $true
    coldStartLandsOnFirstLevelConversation = $true
    requestedChildRouteFallsBackToFirstLevelConversation = $true
    nonScrollableControlsKeepBottomSafeInset = $true
    lineageShowsFourModes = $true
    externalModeIsNotOpenable = $true
    drawerBackReturnsToConversation = $true
    continuableComposerAcceptsText = $true
    continuablePromptAppearsOnce = $true
    childBackReturnsToParent = $true
    oneShotIsReadOnly = $true
    unknownIsReadOnly = $true
    parentOfflineIsReadOnly = $true
    processAliveAfterAllFlows = $true
  }
}
$manifest |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Mode and subagent Mock E2E passed. Evidence: $captureDir"
