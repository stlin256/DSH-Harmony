param(
  [string]$DevEcoHome = 'C:\Users\yjzlx\AppData\Local\Programs\Huawei\DevEcoStudio-26.0.0',
  [string]$Device = '',
  [string]$OutputDir = '',
  [switch]$SkipBuild,
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$hdc = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path -LiteralPath $hdc)) {
  throw "HDC not found: $hdc"
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-mode-subagent-e2e'
}
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
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
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

Launch-Fixture -Screen 'conversation' -State 'plan-subagent' -Theme 'dark'
$planLayout = Dump-Layout 'plan-visible'
$plan = Query-Node $planLayout '计划' 'clickable'
$null = Query-Node $planLayout '4 个子智能体' 'clickable'
Capture-Screen 'plan-visible'
Invoke-Click $plan
$planRemoved = Dump-Layout 'plan-removed'
$null = Query-Node $planRemoved '计划' 'text' 0

Launch-Fixture -Screen 'conversation' -State 'plan-off-error' -Theme 'dark'
$planErrorLayout = Dump-Layout 'plan-error-before'
$planError = Query-Node $planErrorLayout '计划' 'clickable'
Invoke-Click $planError
$planErrorAfter = Dump-Layout 'plan-error-after'
$null = Query-Node $planErrorAfter '计划' 'text' 1
$null = Query-Node $planErrorAfter '退出计划模式失败' 'text' 1
Capture-Screen 'plan-error-after'

Launch-Fixture -Screen 'lineage' -State 'plan-subagent' -Theme 'dark'
$lineageLayout = Dump-Layout 'lineage-open'
$null = Query-Node $lineageLayout '可继续检查' 'text' 1
$null = Query-Node $lineageLayout '一次性检查' 'text' 1
$null = Query-Node $lineageLayout '未知模式记录' 'text' 1
$null = Query-Node $lineageLayout '外部任务' 'text' 1
$null = Query-Node $lineageLayout '不可打开' 'text' 1
Capture-Screen 'lineage-open'
& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 650
$lineageClosed = Dump-Layout 'lineage-closed'
$null = Query-Node $lineageClosed '计划' 'text' 1

Launch-Fixture -Screen 'subagent' -State 'subagent-continuable' -Theme 'dark'
$continuableLayout = Dump-Layout 'continuable'
$null = Query-Node $continuableLayout '可继续检查' 'text' 1
$null = Query-Node $continuableLayout '发送消息…' 'text' 1
$null = Query-Node $continuableLayout '排队' 'clickable' 1
Capture-Screen 'continuable'
& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 650
$parentLayout = Dump-Layout 'returned-parent'
$null = Query-Node $parentLayout '发布准备与商店检查' 'text' 1

Launch-Fixture -Screen 'subagent' -State 'subagent-one-shot' -Theme 'light'
$oneShotLayout = Dump-Layout 'one-shot'
$null = Query-Node $oneShotLayout '一次性子智能体记录' 'text' 1
$null = Query-Node $oneShotLayout '发送消息…' 'text' 0
Capture-Screen 'one-shot'

Launch-Fixture -Screen 'subagent' -State 'subagent-unknown' -Theme 'light'
$unknownLayout = Dump-Layout 'unknown'
$null = Query-Node $unknownLayout '此子智能体暂时只读' 'text' 1
$null = Query-Node $unknownLayout '发送消息…' 'text' 0
Capture-Screen 'unknown'

Launch-Fixture -Screen 'subagent' -State 'subagent-parent-offline' -Theme 'dark'
$offlineLayout = Dump-Layout 'parent-offline'
$null = Query-Node $offlineLayout '父会话暂不可用' 'text' 1
$null = Query-Node $offlineLayout '发送消息…' 'text' 0
Capture-Screen 'parent-offline'

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during mode/subagent E2E.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  result = 'Passed'
  checked = [ordered]@{
    planChipRemovedOnlyAfterProjection = $true
    planFailureKeepsChipAndShowsMessage = $true
    lineageShowsFourModes = $true
    externalModeIsNotOpenable = $true
    drawerBackReturnsToConversation = $true
    continuableHasQueueAndComposer = $true
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
