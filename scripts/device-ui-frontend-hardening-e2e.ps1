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
  $OutputDir = Join-Path $repo 'artifacts\device-e2e\frontend-hardening'
}
$captureDir = Join-Path $OutputDir 'secret-stream-settings'
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
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$firstFixture = $true
$syntheticToken = @('sk-', 'demo', '0123456789ABCDEFGHIJ') -join ''

function Text-Hex {
  param([string]$Text)
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
}

function Open-Fixture {
  param(
    [ValidateSet('secret-masked', 'stream-repaired', 'settings-search')]
    [string]$State,
    [string]$Theme = 'dark'
  )
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = if ($State -eq 'settings-search') { 'settings' } else { 'conversation' }
    State = $State
    Theme = $Theme
    OutputDir = $OutputDir
  }
  if ($SkipBuild -or -not $firstFixture) { $arguments.SkipBuild = $true }
  if ($SkipInstall -or -not $firstFixture) { $arguments.SkipInstall = $true }
  & $mockScript @arguments | Out-Host
  $script:firstFixture = $false
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-hardening-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b io.github.stlin256.dshharmony" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Layout dump failed: $Name" }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Layout receive failed: $Name"
  }
  return $local
}

function Capture-Screen {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-hardening-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Screen capture failed: $Name" }
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
    [string]$Target = 'clickable'
  )
  $raw = & python $queryScript $Layout --find-text-hex (Text-Hex $Text) --target $Target 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout query failed for '$Text': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Assert-TextAbsent {
  param([string]$Layout, [string]$Text)
  $raw = & python $queryScript $Layout --find-text-hex (Text-Hex $Text) --target text 2>&1
  if ($LASTEXITCODE -eq 0) {
    throw "Unexpected visible text: $Text"
  }
}

function Invoke-Click {
  param([object]$Node)
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Input click failed at $($Node.x),$($Node.y)" }
  Start-Sleep -Milliseconds 750
}

# Secret display: raw values stay in the model while the rendered message masks.
Open-Fixture -State 'secret-masked' -Theme 'dark'
$secretMasked = Dump-Layout 'secret-masked'
$null = Query-Node $secretMasked '凭据已遮蔽' 'text'
Assert-TextAbsent $secretMasked $syntheticToken
$reveal = Query-Node $secretMasked '显示凭据'
Capture-Screen 'secret-masked'
Invoke-Click $reveal
$secretRevealed = Dump-Layout 'secret-revealed'
$null = Query-Node $secretRevealed '隐藏凭据'
$null = Query-Node $secretRevealed $syntheticToken 'text'
Capture-Screen 'secret-revealed'
$hide = Query-Node $secretRevealed '隐藏凭据'
Invoke-Click $hide
$secretHiddenAgain = Dump-Layout 'secret-hidden-again'
$null = Query-Node $secretHiddenAgain '显示凭据'
Assert-TextAbsent $secretHiddenAgain $syntheticToken

$messageSource = Get-Content -Raw -LiteralPath (
  Join-Path $repo 'harmony\entry\src\main\ets\components\NativeMessageView.ets')
$copyUsesRawSource =
  $messageSource -match 'private copyMessage\(\)[\s\S]{0,180}rawMessageText\(\)'

# Streaming Markdown: the repaired marker is visible while an unfinished table
# and link target are not.
Open-Fixture -State 'stream-repaired' -Theme 'dark'
$streamRepaired = Dump-Layout 'stream-repaired'
$null = Query-Node $streamRepaired '流式 Markdown' 'text'
Assert-TextAbsent $streamRepaired '| --- | --'
Assert-TextAbsent $streamRepaired 'https://example.invalid/doc'
Capture-Screen 'stream-repaired'

# Settings search: seeded results, clear, bilingual query, navigation and Back.
Open-Fixture -State 'settings-search' -Theme 'dark'
$settingsSearch = Dump-Layout 'settings-search'
$null = Query-Node $settingsSearch '搜索设置'
$null = Query-Node $settingsSearch '通知'
Capture-Screen 'settings-search'
$clearSearch = Query-Node $settingsSearch '清除设置搜索'
Invoke-Click $clearSearch
$settingsCleared = Dump-Layout 'settings-search-cleared'
$searchField = Query-Node $settingsCleared '搜索设置'
Invoke-Click $searchField
& $hdc -t $Device shell 'uitest uiInput inputText dark' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Settings search text input failed' }
Start-Sleep -Milliseconds 750
$settingsDark = Dump-Layout 'settings-search-dark'
$themeResult = Query-Node $settingsDark '主题'
Capture-Screen 'settings-search-dark'
Invoke-Click $themeResult
$appearance = Dump-Layout 'settings-result-opened'
$null = Query-Node $appearance '外观与动效' 'text'
Capture-Screen 'settings-result-opened'
& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 750
$settingsBack = Dump-Layout 'settings-back-returned'
$null = Query-Node $settingsBack '搜索设置'

$hap = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash
  result = 'Passed'
  secret = [ordered]@{
    firstPaintMasked = $true
    revealed = $true
    hiddenAgain = $true
    copySourceRaw = if ($copyUsesRawSource) { 'source-contract-passed' } else { 'failed' }
  }
  stream = [ordered]@{
    noUnfinishedSuffix = $true
  }
  settings = [ordered]@{
    queryEntered = $true
    resultOpened = $true
    backReturned = $true
  }
}
if (-not $copyUsesRawSource) { throw 'Message copy no longer uses the raw source value.' }
$manifest |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Frontend hardening E2E passed. Evidence: $captureDir"
