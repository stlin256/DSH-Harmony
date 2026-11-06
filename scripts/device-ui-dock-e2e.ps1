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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-dock-e2e'
}
$captureDir = Join-Path $OutputDir 'send-and-queue'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; Dock send E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$bottomAssertScript = Join-Path $PSScriptRoot 'device-ui-bottom-dock-assert.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$bundle = 'io.github.stlin256.dshharmony'

function Text-Hex {
  param([string]$Text)
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')
}

function Launch-Fixture {
  param(
    [string]$State,
    [string]$Theme = 'dark',
    [bool]$First = $false,
    [bool]$ReduceTransparency = $false,
    [bool]$ImmersiveMaterial = $false
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
  if ($ReduceTransparency) {
    $arguments.ReduceTransparency = $true
  }
  if ($ImmersiveMaterial) {
    $arguments.ImmersiveMaterial = $true
  }
  & $mockScript @arguments | Out-Host
}

function Dump-Layout {
  param([string]$Name)
  [OutputType([string])]
  $remote = "/data/local/tmp/dsh-dock-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
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
  $remote = "/data/local/tmp/dsh-dock-$Name.jpeg"
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

function Wait-Query-Node {
  param(
    [string]$Name,
    [string]$Text,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'clickable',
    [int]$ExpectCount = 1,
    [int]$TimeoutMilliseconds = 6000,
    [int]$MinimumY = -1
  )
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
  $lastError = ''
  $attempt = 0
  do {
    $attempt++
    [string]$layoutPath = @(Dump-Layout "$Name-$attempt")[-1]
    try {
      $node = Query-Node $layoutPath $Text $Target $ExpectCount
      if ($MinimumY -lt 0 -or [int]$node.y -ge $MinimumY) {
        return $node
      }
      $lastError = "Layout match is still above y=$MinimumY (found y=$($node.y))."
    } catch {
      $lastError = $_.Exception.Message
    }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Layout wait failed for '$Text' after $TimeoutMilliseconds ms: $lastError"
}

function Wait-Send-Node {
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
    [string]$layoutPath = @(Dump-Layout "$Name-$attempt")[-1]
    $raw = & python $queryScript $layoutPath --rightmost-clickable-below $AnchorX $AnchorY `
      --expect-count 1 2>&1
    if ($LASTEXITCODE -eq 0) {
      return (($raw -join '') | ConvertFrom-Json)
    }
    $lastError = $raw -join [Environment]::NewLine
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Send node wait failed after $TimeoutMilliseconds ms: $lastError"
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
  Start-Sleep -Milliseconds 250
}

function Send-Token {
  param([string]$Token)
  [string]$before = @(Dump-Layout ('before-' + $Token))[-1]
  $composer = Query-Node $before '发送消息…' 'text'
  Invoke-Click $composer
  $focusedComposer = Wait-Query-Node ('focused-' + $Token) '发送消息…' 'text'
  & $hdc -t $Device shell "uitest uiInput inputText $($focusedComposer.x) $($focusedComposer.y) $Token" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Text input failed: $Token"
  }
  $null = Wait-Query-Node ('entered-' + $Token) $Token 'text' 1
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Keyboard dismissal failed: $Token"
  }
  $sendComposer = Wait-Query-Node ('send-ready-' + $Token) $Token 'text' 1 6000 `
    ([int]$focusedComposer.y + 300)
  $send = Wait-Send-Node ('send-' + $Token) $sendComposer.x $sendComposer.y
  Invoke-Click $send
}

# Idle Send: the Mock must insert the user event and then settle a reply.
Launch-Fixture -State 'dock-send-idle' -Theme 'dark' -First $true
$idleToken = 'dock_send_probe'
Send-Token $idleToken
$null = Wait-Query-Node 'idle-settled' $idleToken 'text' 2
$null = Wait-Query-Node 'idle-response' '已收到这条测试消息。Dock、发送与流式状态均已正常更新。' 'text' 1
$null = Wait-Query-Node 'idle-ready' '发送消息…' 'text' 1
Capture-Screen 'idle-settled'

# Running Queue Send: capture the local echo before authoritative reconciliation,
# then prove the row is replaced rather than duplicated.
Launch-Fixture -State 'dock-queue-pending' -Theme 'light' -First $false
$queueToken = 'dock_queue_probe'
Send-Token $queueToken
Start-Sleep -Milliseconds 280
$pendingLayout = Dump-Layout 'queue-pending'
$null = Query-Node $pendingLayout $queueToken 'text' 1
$null = Query-Node $pendingLayout '发送中…' 'text' 1
Capture-Screen 'queue-pending'

Start-Sleep -Milliseconds 4400
$authoritativeFixtureState = 'dock-queue-authoritative'
$authoritativeLayout = Dump-Layout 'queue-authoritative'
$null = Query-Node $authoritativeLayout $queueToken 'text' 1
$null = Query-Node $authoritativeLayout '发送中…' 'text' 0
$null = Query-Node $authoritativeLayout '发送消息…' 'text' 1
Capture-Screen 'queue-authoritative'

# Material ownership: quiet must have no elevated content, elevated must retain
# the composer and queue rows, and reduced transparency must preserve geometry.
Launch-Fixture -State 'dock-material-quiet' -Theme 'dark' -First $false
$quietLayout = Dump-Layout 'dock-material-quiet'
$null = Query-Node $quietLayout '发送消息…' 'text' 1
$null = Query-Node $quietLayout '2 条排队消息' 'text' 0
Capture-Screen 'dock-material-quiet'

Launch-Fixture -State 'dock-material-elevated' -Theme 'dark' -First $false -ImmersiveMaterial $true
$elevatedLayout = Dump-Layout 'dock-material-elevated'
$null = Query-Node $elevatedLayout '2 条排队消息' 'text' 1
$null = Query-Node $elevatedLayout '发送消息…' 'text' 1
Capture-Screen 'dock-material-elevated'

Launch-Fixture -State 'dock-material-elevated' -Theme 'dark' -First $false -ReduceTransparency $true
$reducedLayout = Dump-Layout 'dock-material-reduced-transparency'
$null = Query-Node $reducedLayout '2 条排队消息' 'text' 1
$null = Query-Node $reducedLayout '发送消息…' 'text' 1
Capture-Screen 'dock-material-reduced-transparency'

# Deliberate failure: the draft remains editable, no success bubble is added and
# the error is visible in place.
Launch-Fixture -State 'dock-send-error' -Theme 'dark' -First $false
$errorToken = 'dock_error_probe'
Send-Token $errorToken
Start-Sleep -Milliseconds 320
$errorLayout = Dump-Layout 'send-error'
$null = Query-Node $errorLayout 'Mock 发送失败，请重试' 'text' 1
$null = Query-Node $errorLayout $errorToken 'text' 1
$null = Query-Node $errorLayout '发送中…' 'text' 0
Capture-Screen 'send-error'

$bottomRaw = & python $bottomAssertScript `
  --quiet $quietLayout `
  --elevated $elevatedLayout `
  --queue $authoritativeLayout `
  --error $errorLayout 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Bottom Dock spacer assertion failed: $($bottomRaw -join [Environment]::NewLine)"
}
$bottomGeometry = ($bottomRaw -join '') | ConvertFrom-Json

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during Dock send E2E.'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap')).Hash
  result = 'Passed'
  settledFixtureState = $authoritativeFixtureState
  checked = [ordered]@{
    idleSendInsertedUserMessage = $true
    idleSendSettledAssistantResponse = $true
    composerClearedAfterSend = $true
    pendingQueueEchoVisibleOnce = $true
    authoritativeQueueReconciledWithoutDuplicate = $true
    quietDockHasNoElevatedQueue = $true
    elevatedDockRetainsQueueAndComposer = $true
    reducedTransparencyRetainsLayout = $true
    failedSendKeepsDraftAndShowsError = $true
    failedSendDoesNotCreateFalseSuccess = $true
    extraBottomDockOwnsMatchingTranscriptSpacer = $true
    processAliveAfterAllFlows = $true
  }
  bottomSpacerGeometry = $bottomGeometry
  evidence = [ordered]@{
    idleScreenshot = 'idle-settled.jpeg'
    idleLayout = 'idle-settled.json'
    queuePendingScreenshot = 'queue-pending.jpeg'
    queuePendingLayout = 'queue-pending.json'
    queueAuthoritativeScreenshot = 'queue-authoritative.jpeg'
    queueAuthoritativeLayout = 'queue-authoritative.json'
    quietDockScreenshot = 'dock-material-quiet.jpeg'
    quietDockLayout = 'dock-material-quiet.json'
    elevatedDockScreenshot = 'dock-material-elevated.jpeg'
    elevatedDockLayout = 'dock-material-elevated.json'
    reducedTransparencyScreenshot = 'dock-material-reduced-transparency.jpeg'
    reducedTransparencyLayout = 'dock-material-reduced-transparency.json'
    sendErrorScreenshot = 'send-error.jpeg'
    sendErrorLayout = 'send-error.json'
  }
}
$manifest |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Dock send and queue E2E passed. Evidence: $captureDir"
