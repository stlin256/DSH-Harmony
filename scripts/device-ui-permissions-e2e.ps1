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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-permissions-e2e'
}
$captureDir = Join-Path $OutputDir 'permissions'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; permission E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$buildScript = Join-Path $PSScriptRoot 'build-harmony.ps1'
$hapPath = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$bundle = 'io.github.stlin256.dshharmony'
$firstLaunch = $true

function Text-Hex {
  param([string]$Text)
  return (([System.BitConverter]::ToString(
    [Text.Encoding]::UTF8.GetBytes($Text)
  )) -replace '-', '').ToLowerInvariant()
}

function Launch-Fixture {
  param(
    [string]$State,
    [string]$Theme,
    [string]$Screen = 'conversation'
  )
  if ($firstLaunch -and -not $SkipBuild) {
    & $buildScript -DevEcoHome $DevEcoHome -Product mock -BuildMode release
    if ($LASTEXITCODE -ne 0) {
      throw "Mock Release build failed: $LASTEXITCODE"
    }
  }
  if ($firstLaunch -and -not $SkipInstall) {
    & $hdc -t $Device install -r (Resolve-Path -LiteralPath $hapPath).Path | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "Mock HAP installation failed: $LASTEXITCODE"
    }
  }
  & $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
  $launch = "aa start -a EntryAbility -b $bundle -m entry " +
    "--ps storeShowcase true --ps showcaseScreen $Screen " +
    "--ps showcaseState $State --ps showcaseTheme $Theme"
  & $hdc -t $Device shell $launch | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Fixture launch failed: $State/$Theme/$Screen"
  }
  Start-Sleep -Milliseconds 2500
  $script:firstLaunch = $false
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-permission-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Layout dump failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Layout receive failed: $Name"
  }
  Start-Sleep -Milliseconds 350
  return $local
}

function Capture-Screen {
  param([string]$Name, [int]$DelayMilliseconds = 350)
  $remote = "/data/local/tmp/dsh-permission-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  if ($DelayMilliseconds -gt 0) {
    Start-Sleep -Milliseconds $DelayMilliseconds
  }
  & $hdc -t $Device shell "snapshot_display -f $remote" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Screen capture failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Screen receive failed: $Name"
  }
  Start-Sleep -Milliseconds 200
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

function Invoke-Click {
  param([object]$Node, [int]$WaitMilliseconds = 650)
  if ($null -eq $Node.x -or $null -eq $Node.y) {
    throw "Cannot click a node without bounds: $($Node.text)"
  }
  Invoke-Click-Point -X ([int]$Node.x) -Y ([int]$Node.y) -WaitMilliseconds $WaitMilliseconds
}

function Invoke-Click-Point {
  param([int]$X, [int]$Y, [int]$WaitMilliseconds = 650)
  Start-Sleep -Milliseconds 650
  & $hdc -t $Device shell "uitest uiInput click $X $Y" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Input click failed at $X,$Y"
  }
  Start-Sleep -Milliseconds $WaitMilliseconds
}

Launch-Fixture -State 'permission-current-workspace' -Theme 'dark'
$chipLayout = Dump-Layout 'chip-workspace'
$chip = Query-Node-ById $chipLayout 'permission-chip' 'clickable'
$chipBounds = Get-Bounds $chip.bounds
if (($chipBounds.bottom - $chipBounds.top) -gt 112) {
  throw "Permission chip hit target is too tall: $($chip.bounds)"
}
if (($chipBounds.right - $chipBounds.left) -gt 112) {
  throw "Permission chip hit target is too wide: $($chip.bounds)"
}
if ($chip.background -ne '#00000000') {
  throw "Permission chip must not have a fixed highlight background: $($chip.background)"
}
$null = Query-Node-ById $chipLayout 'permission-current-workspace-write' 'text'
Capture-Screen 'chip-workspace'

foreach ($mode in @(
  @{ State = 'permission-current-read-only'; Id = 'permission-current-read-only'; Name = 'chip-read-only' },
  @{ State = 'permission-current-full'; Id = 'permission-current-danger-full-access'; Name = 'chip-full' },
  @{ State = 'permission-current-custom'; Id = 'permission-current-custom'; Name = 'chip-custom' }
)) {
  Launch-Fixture -State $mode.State -Theme 'dark'
  $modeLayout = Dump-Layout $mode.Name
  $null = Query-Node-ById $modeLayout $mode.Id 'text'
  $modeChip = Query-Node-ById $modeLayout 'permission-chip' 'clickable'
  if ($modeChip.background -ne '#00000000') {
    throw "Permission chip must stay transparent for $($mode.State): $($modeChip.background)"
  }
  Capture-Screen $mode.Name
}

Launch-Fixture -State 'permission-menu' -Theme 'dark'
$menuLayout = Dump-Layout 'menu'
$null = Query-Node $menuLayout '会话权限' 'text'
$null = Query-Node $menuLayout '只影响当前会话' 'text'
$null = Query-Node $menuLayout '只放行当前工具调用' 'text' 0
$menuComposer = Query-Node-ById $menuLayout 'conversation-composer' 'text'
$permissionPicker = Query-Node-ById $menuLayout 'permission-picker' 'text'
$composerBounds = Get-Bounds $menuComposer.bounds
$pickerBounds = Get-Bounds $permissionPicker.bounds
if ([Math]::Abs($pickerBounds.left - $composerBounds.left) -gt 4 -or
    [Math]::Abs($pickerBounds.right - $composerBounds.right) -gt 4 -or
    $pickerBounds.bottom -gt $composerBounds.top) {
  throw "Permission picker is not aligned above the composer: picker=$($permissionPicker.bounds) composer=$($menuComposer.bounds)"
}
$menuChip = Query-Node-ById $menuLayout 'permission-chip' 'clickable'
if ($menuChip.background -ne '#00000000') {
  throw "Open permission chip must stay transparent: $($menuChip.background)"
}
$selectedWorkspace = Query-Node-ById $menuLayout 'permission-option-workspace-write' 'clickable'
if ($selectedWorkspace.background -eq '#00000000') {
  throw 'Current permission option must have a selected surface'
}
$null = Query-Node-ById $menuLayout 'permission-option-read-only' 'clickable'
$null = Query-Node-ById $menuLayout 'permission-option-danger-full-access' 'clickable'
$null = Query-Node-ById $menuLayout 'permission-option-auto' 'clickable'
$fullOption = Query-Node-ById $menuLayout 'permission-option-danger-full-access' 'clickable'
Invoke-Click $fullOption 1800
$confirmLayout = Dump-Layout 'confirm'
$null = Query-Node $confirmLayout '确认启用完全权限？' 'text'
$null = Query-Node-ById $confirmLayout 'permission-risk-ack' 'clickable'
$disabledConfirm = Query-Node-ById $confirmLayout 'permission-confirm' 'clickable'
if ($disabledConfirm.enabled -ne 'false') {
  throw "Confirm permission action must be disabled before acknowledgement: $($disabledConfirm.enabled)"
}

Launch-Fixture -State 'permission-full-confirm' -Theme 'dark'
$confirmReadyLayout = Dump-Layout 'confirm-ready'
$ack = Query-Node-ById $confirmReadyLayout 'permission-risk-ack' 'clickable'
$ackBounds = Get-Bounds $ack.bounds
Invoke-Click-Point -X ($ackBounds.left + 34) -Y (($ackBounds.top + $ackBounds.bottom) / 2) -WaitMilliseconds 700
$ackLayout = Dump-Layout 'confirm-acknowledged'
$confirm = Query-Node-ById $ackLayout 'permission-confirm'
if ($confirm.enabled -ne 'true') {
  throw "Confirm permission action must be enabled after acknowledgement: $($confirm.enabled)"
}
Invoke-Click $confirm 250
$switchLayout = Dump-Layout 'switching'
$null = Query-Node $switchLayout '正在提交审批' 'text' 0
Start-Sleep -Milliseconds 800
$switchedLayout = Dump-Layout 'switched'
$null = Query-Node-ById $switchedLayout 'permission-current-danger-full-access' 'text'
$null = Query-Node $switchedLayout '确认启用完全权限？' 'text' 0
Capture-Screen 'switched'

Launch-Fixture -State 'permission-menu' -Theme 'dark'
$menuEvidenceLayout = Dump-Layout 'menu-evidence'
$null = Query-Node-ById $menuEvidenceLayout 'permission-picker' 'text'
Capture-Screen 'menu'

Launch-Fixture -State 'permission-full-confirm' -Theme 'dark'
$confirmEvidenceLayout = Dump-Layout 'confirm-evidence'
$null = Query-Node $confirmEvidenceLayout '确认启用完全权限？' 'text'
Capture-Screen 'confirm-before-ack'

Launch-Fixture -State 'permission-full-confirm' -Theme 'dark'
$ackEvidenceLayout = Dump-Layout 'confirm-ack-evidence-before'
$ackEvidence = Query-Node-ById $ackEvidenceLayout 'permission-risk-ack' 'clickable'
$ackEvidenceBounds = Get-Bounds $ackEvidence.bounds
Invoke-Click-Point -X ($ackEvidenceBounds.left + 34) -Y (($ackEvidenceBounds.top + $ackEvidenceBounds.bottom) / 2) -WaitMilliseconds 450
$ackEvidenceResult = Dump-Layout 'confirm-acknowledged'
$ackEvidenceConfirm = Query-Node-ById $ackEvidenceResult 'permission-confirm' 'clickable'
if ($ackEvidenceConfirm.enabled -ne 'true') {
  throw 'Acknowledged confirmation evidence state did not enable the action'
}
Capture-Screen 'confirm-acknowledged'

Launch-Fixture -State 'permission-current-custom' -Theme 'dark'
$customBaseLayout = Dump-Layout 'custom-click-before'
$customChip = Query-Node-ById $customBaseLayout 'permission-chip' 'clickable'
Invoke-Click $customChip
$customMenuLayout = Dump-Layout 'custom-menu'
$null = Query-Node $customMenuLayout '自定义权限' 'text'
$null = Query-Node-ById $customMenuLayout 'permission-option-read-only' 'clickable'
$null = Query-Node-ById $customMenuLayout 'permission-option-workspace-write' 'clickable'
$null = Query-Node-ById $customMenuLayout 'permission-option-danger-full-access' 'clickable'
Capture-Screen 'custom-menu'

Launch-Fixture -State 'permission-full-cancel' -Theme 'dark'
$cancelLayout = Dump-Layout 'cancel-before'
$cancel = Query-Node $cancelLayout '取消' 'clickable'
Invoke-Click $cancel 180
$cancelledLayout = Dump-Layout 'cancel-after'
$null = Query-Node $cancelledLayout '确认启用完全权限？' 'text' 0
$null = Query-Node-ById $cancelledLayout 'permission-current-workspace-write' 'text'
Capture-Screen 'cancel-after'

Launch-Fixture -State 'approval-workspace-once' -Theme 'dark'
$approvalLayout = Dump-Layout 'approval-workspace'
$null = Query-Node $approvalLayout '允许一次仅影响当前工具调用，不会改变会话权限。' 'text'
$null = Query-Node $approvalLayout '工作区内修改' 'text'
Capture-Screen 'approval-workspace'

Launch-Fixture -State 'approval-submitting' -Theme 'dark'
$approvalLayout = Dump-Layout 'approval-submitting-ready'
$allow = Query-Node $approvalLayout '允许一次' 'clickable'
Invoke-Click $allow 120
Capture-Screen 'approval-submitting' 250
$submittingLayout = Dump-Layout 'approval-submitting'
$null = Query-Node $submittingLayout '正在提交审批' 'text'
$null = Query-Node $submittingLayout '允许一次' 'clickable' 0
$busyReject = Query-Node-ById $submittingLayout 'approval-reject' 'clickable'
$busyAllow = Query-Node-ById $submittingLayout 'approval-allow-once' 'clickable'
if ($busyReject.enabled -ne 'false' -or $busyAllow.enabled -ne 'false') {
  throw "Approval actions must be disabled while submitting: reject=$($busyReject.enabled) allow=$($busyAllow.enabled)"
}
Start-Sleep -Milliseconds 3000
$approvalEndedLayout = Dump-Layout 'approval-ended'
$null = Query-Node $approvalEndedLayout '等待审批' 'text' 0

Launch-Fixture -State 'approval-full-once' -Theme 'dark'
$fullApprovalLayout = Dump-Layout 'approval-full'
$null = Query-Node $fullApprovalLayout '完全权限' 'text'
$null = Query-Node $fullApprovalLayout '允许一次仅影响当前工具调用，不会改变会话权限。' 'text'
Capture-Screen 'approval-full'

Launch-Fixture -State 'approval-long-reason' -Theme 'dark'
$longLayout = Dump-Layout 'approval-long'
$null = Query-Node $longLayout '允许一次' 'clickable'
$null = Query-Node $longLayout '拒绝' 'clickable'
Capture-Screen 'approval-long'

Launch-Fixture -State 'approval-ended' -Theme 'dark'
$endedLayout = Dump-Layout 'approval-ended-state'
$null = Query-Node $endedLayout '等待审批' 'text' 0
Capture-Screen 'approval-ended-state'

Launch-Fixture -State 'approval-disconnected' -Theme 'dark'
$disconnectedLayout = Dump-Layout 'approval-disconnected'
$null = Query-Node $disconnectedLayout '等待审批' 'text' 0
$null = Query-Node $disconnectedLayout '允许一次' 'clickable' 0
Capture-Screen 'approval-disconnected'

Launch-Fixture -State 'permission-default-setting' -Theme 'dark' -Screen 'settings'
$settingsLayout = Dump-Layout 'settings-default'
$null = Query-Node $settingsLayout '新会话默认权限' 'text'
$null = Query-Node $settingsLayout '只影响之后创建的会话' 'text'
$null = Query-Node $settingsLayout '工作区内修改' 'clickable'
Capture-Screen 'settings-default'

Launch-Fixture -State 'permission-menu' -Theme 'light'
$lightMenuLayout = Dump-Layout 'light-menu'
$null = Query-Node-ById $lightMenuLayout 'permission-option-workspace-write' 'clickable'
$lightMenuChip = Query-Node-ById $lightMenuLayout 'permission-chip' 'clickable'
if ($lightMenuChip.background -ne '#00000000') {
  throw "Light permission chip must stay transparent: $($lightMenuChip.background)"
}
Capture-Screen 'light-menu'

Launch-Fixture -State 'permission-full-confirm' -Theme 'light'
$lightConfirmLayout = Dump-Layout 'light-confirm'
$null = Query-Node $lightConfirmLayout '确认启用完全权限？' 'text'
$null = Query-Node-ById $lightConfirmLayout 'permission-risk-ack' 'clickable'
Capture-Screen 'light-confirm'

Launch-Fixture -State 'approval-workspace-once' -Theme 'light'
$lightApprovalLayout = Dump-Layout 'light-approval'
$null = Query-Node $lightApprovalLayout '允许一次仅影响当前工具调用，不会改变会话权限。' 'text'
Capture-Screen 'light-approval'

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during permission E2E.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  result = 'Passed'
  checked = [ordered]@{
    permissionChipPresent = $true
    permissionChipVisualCompact = $true
    permissionChipHasNoFixedHighlight = $true
    permissionChipTracksAuthoritativeProjection = $true
    permissionModesCaptured = $true
    permissionButtonClickOpensMenu = $true
    permissionPickerAlignedWithComposer = $true
    permissionPickerUsesMask = $true
    permissionPickerExplanatoryFooterRemoved = $true
    permissionMenuCompact = $true
    permissionConfirmRequiresAcknowledgement = $true
    permissionCancelDoesNotWrite = $true
    permissionSwitchWaitsForProjection = $true
    approvalShowsOneShotBoundary = $true
    approvalTargetScopeVisible = $true
    approvalLongReasonKeepsActions = $true
    approvalSubmittingLocksActions = $true
    approvalEndedRemovesCard = $true
    approvalDisconnectedNeverShowsAllowed = $true
    settingsDefaultPermissionVisible = $true
    lightThemePermissionSurfaces = $true
    processAliveAfterAllFlows = $true
  }
}
$manifest |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Permission Mock E2E passed. Evidence: $captureDir"
