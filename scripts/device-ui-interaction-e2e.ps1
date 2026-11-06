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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-interaction-e2e'
}
$captureDir = Join-Path $OutputDir 'approval-question'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; interaction E2E remains pending.'
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
    [string]$State,
    [string]$Theme
  )
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = 'conversation'
    State = $State
    Theme = $Theme
    OutputDir = $OutputDir
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
  $remote = "/data/local/tmp/dsh-interaction-$Name.json"
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
  $remote = "/data/local/tmp/dsh-interaction-$Name.jpeg"
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
    [ValidateSet('text', 'clickable')]
    [string]$Target = 'clickable',
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
    [ValidateSet('text', 'clickable')]
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

function Assert-CompactQuestionAction {
  param([object]$Node, [string]$Name)
  $bounds = Get-Bounds $Node.bounds
  $height = $bounds.bottom - $bounds.top
  # HBN-AL80 reports 32vp as 108px; this still rejects the previous 36vp control.
  if ($height -gt 112) {
    throw "$Name is not compact: height=$height bounds=$($Node.bounds)"
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

Launch-Fixture -State 'interaction-approval' -Theme 'dark'
$approval = Dump-Layout 'approval-before'
$null = Query-Node $approval '等待审批' 'text'
$allow = Query-Node $approval '允许一次' 'clickable'
Capture-Screen 'approval-before'
Invoke-Click $allow
$approvalAfter = Dump-Layout 'approval-after'
$null = Query-Node $approvalAfter '等待审批' 'text' 0

Launch-Fixture -State 'interaction-question' -Theme 'light'
$question = Dump-Layout 'question-before'
$questionHeader = Query-Node $question '界面偏好' 'text'
$questionTitle = Query-Node $question '哪一种底部 Dock 的反馈更清晰？' 'text'
$questionCard = Query-Node-ById $question 'question-card' 'text'
$questionHeaderRow = Query-Node-ById $question 'question-header-row' 'text'
$null = Query-Node $question '1 / 1' 'text' 1
$null = Query-Node $question '排队' 'clickable' 0
$null = Query-Node $question '接管' 'clickable' 0
$answer = Query-Node-ById $question 'question-custom-answer' 'text'
$answerPlaceholder = Query-Node $question '自定义回答' 'text'
$answerBounds = Get-Bounds $answer.bounds
$placeholderBounds = Get-Bounds $answerPlaceholder.bounds
$cardBounds = Get-Bounds $questionCard.bounds
$headerRowBounds = Get-Bounds $questionHeaderRow.bounds
$headerBounds = Get-Bounds $questionHeader.bounds
$titleBounds = Get-Bounds $questionTitle.bounds
if ($headerBounds.top - $cardBounds.top -lt 6) {
  throw "Question header lacks its top inset: card=$($questionCard.bounds), header=$($questionHeader.bounds)"
}
if ($titleBounds.top - $headerRowBounds.bottom -gt 30) {
  throw "Question title is too far from its header: header=$($questionHeaderRow.bounds), title=$($questionTitle.bounds)"
}
$answerCenter = ($answerBounds.top + $answerBounds.bottom) / 2
$placeholderCenter = ($placeholderBounds.top + $placeholderBounds.bottom) / 2
if ([Math]::Abs($answerCenter - $placeholderCenter) -gt 9) {
  throw "Custom-answer placeholder is not vertically centered: input=$($answer.bounds), placeholder=$($answerPlaceholder.bounds)"
}
$skip = Query-Node-ById $question 'question-skip'
$submitBefore = Query-Node-ById $question 'question-submit'
Assert-CompactQuestionAction $skip 'Skip'
Assert-CompactQuestionAction $submitBefore 'Submit'
$choice = Query-Node $question '渐变毛玻璃' 'clickable'
Capture-Screen 'question-before'
Invoke-Click $choice
$selected = Dump-Layout 'question-selected'
$submit = Query-Node-ById $selected 'question-submit'
Assert-CompactQuestionAction $submit 'Submit'
Capture-Screen 'question-selected'
Invoke-Click $submit
$questionAfter = Dump-Layout 'question-after'
$null = Query-Node $questionAfter '界面偏好' 'text' 0

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during interaction E2E.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  result = 'Passed'
  checked = [ordered]@{
    approvalCardRendered = $true
    approvalSubmittedWithoutNetwork = $true
    approvalCardDismissed = $true
    questionCardRendered = $true
    questionHeaderHasTopInset = $true
    questionSequenceRenderedOnce = $true
    questionComposerModeSelectorAbsent = $true
    customAnswerPlaceholderCentered = $true
    questionActionsCompact = $true
    questionOptionSelected = $true
    questionSubmittedWithoutNetwork = $true
    questionCardDismissed = $true
    processAliveAfterAllFlows = $true
  }
}
$manifest |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Interaction Mock E2E passed. Evidence: $captureDir"
