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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-workspace-scope-e2e'
}
$captureDir = Join-Path $OutputDir 'sidebar-workspace-scope'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; workspace sidebar E2E remains pending.'
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
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = 'sidebar'
    State = 'completed'
    Theme = 'dark'
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
  $remote = "/data/local/tmp/dsh-workspace-$Name.json"
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
  $remote = "/data/local/tmp/dsh-workspace-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Screen capture failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Screen receive failed: $Name"
  }
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

function Query-Text {
  param(
    [string]$Layout,
    [string]$Text,
    [int]$ExpectCount = 1
  )
  $raw = & python $queryScript `
    $Layout `
    --find-text-hex (Text-Hex $Text) `
    --target text `
    --exact-text `
    --expect-count $ExpectCount 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout text query failed for '$Text': $($raw -join [Environment]::NewLine)"
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
  Start-Sleep -Milliseconds 700
}

function Wait-Query-ById {
  param(
    [string]$Name,
    [string]$Id,
    [string]$Target = 'clickable',
    [int]$ExpectCount = 1,
    [int]$TimeoutMs = 15000
  )
  $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
  $lastError = ''
  while ((Get-Date) -lt $deadline) {
    try {
      $layout = Dump-Layout $Name
      return Query-Node-ById $layout $Id $Target $ExpectCount
    } catch {
      $lastError = $_.Exception.Message
      Start-Sleep -Milliseconds 350
    }
  }
  throw "Timed out waiting for layout id '$Id': $lastError"
}

Launch-Fixture
$initial = Dump-Layout 'initial'
$null = Query-Node-ById $initial 'sidebar-all-workspaces' 'text' 1
$null = Query-Node-ById $initial 'sidebar-workspace-workspace-mobile' 'text' 1
$null = Query-Node-ById $initial 'sidebar-workspace-workspace-gateway' 'text' 1
$newSession = Query-Node-ById $initial 'sidebar-new-session'
Capture-Screen 'sidebar-all-workspaces'
Invoke-Click $newSession

$picker = Dump-Layout 'create-picker'
$null = Query-Node-ById $picker 'workspace-picker-title' 'text' 1
$null = Query-Text $picker '选择工作区' 1
$null = Query-Text $picker '全部会话' 0
$gateway = Query-Node-ById $picker 'workspace-picker-workspace-gateway'
Capture-Screen 'create-picker'
Invoke-Click $gateway

$sidebar = Wait-Query-ById 'after-create-sidebar' 'workspace-sidebar'
Invoke-Click $sidebar
$afterCreate = Dump-Layout 'after-create'
$null = Query-Node-ById $afterCreate 'sidebar-all-workspaces' 'text' 1
$null = Query-Node-ById $afterCreate 'sidebar-workspace-workspace-mobile' 'text' 1
$null = Query-Node-ById $afterCreate 'sidebar-workspace-workspace-gateway' 'text' 1

$manager = Query-Node-ById $afterCreate 'sidebar-workspace-manager'
Invoke-Click $manager
$managePicker = Dump-Layout 'manage-picker'
$mobile = Query-Node-ById $managePicker 'workspace-picker-workspace-mobile'
Invoke-Click $mobile
$afterSwitch = Dump-Layout 'after-workspace-switch'
$null = Query-Node-ById $afterSwitch 'sidebar-all-workspaces' 'text' 1
$null = Query-Node-ById $afterSwitch 'sidebar-workspace-workspace-mobile' 'text' 1
$null = Query-Node-ById $afterSwitch 'sidebar-workspace-workspace-gateway' 'text' 1
Capture-Screen 'after-workspace-switch'

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during workspace sidebar E2E.'
}

$hapPath = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hapPath).Hash
  result = 'Passed'
  checked = [ordered]@{
    allWorkspacesVisibleInitially = $true
    createPickerRequired = $true
    createPickerHasNoAllSessionsTarget = $true
    selectedWorkspaceCreatesImmediately = $true
    allWorkspacesVisibleAfterCreation = $true
    selectingAnotherWorkspaceDoesNotFilter = $true
    processAliveAfterAllFlows = $true
  }
}
$manifest |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Workspace sidebar Mock E2E passed. Evidence: $captureDir"
