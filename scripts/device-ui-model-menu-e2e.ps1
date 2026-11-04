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
if (-not $Device) {
  $Device = @(& $hdc list targets | Where-Object { $_ -and $_ -notmatch 'Empty' })[0]
}
if (-not $Device) { throw 'No connected device.' }
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'artifacts\device-e2e\model-picker' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'model-picker'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
$bundle = 'io.github.stlin256.dshharmony'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$hap = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$results = @()

function ConvertTo-Hex([string]$Text) {
  # Windows PowerShell 5.1 lacks Convert.ToHexString; BitConverter works on both.
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant()
}
function Dump-Layout([string]$Name) {
  $remote = "/data/local/tmp/dsh-menu-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Layout capture failed.' }
  return $local
}
function Capture-Screen([string]$Name) {
  $remote = "/data/local/tmp/dsh-menu-$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  & $hdc -t $Device file recv $remote (Join-Path $captureDir "$Name.jpeg") | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Screenshot capture failed.' }
}
function Query-Layout([string]$Layout, [string[]]$Options) {
  $raw = & python $queryScript $Layout @Options 2>&1
  if ($LASTEXITCODE -ne 0) { throw ('Layout query failed: ' + ($Options -join ' ')) }
  return (($raw -join '') | ConvertFrom-Json)
}
function Find-Id([string]$Layout, [string]$Id) {
  return Query-Layout $Layout @('--find-id', $Id, '--target', 'clickable')
}
function Find-Text([string]$Layout, [string]$Text, [string]$Target = 'text', [int]$MinY = -1) {
  $options = @('--find-text-hex', (ConvertTo-Hex $Text), '--target', $Target)
  if ($MinY -ge 0) { $options += @('--minimum-y', "$MinY") }
  return Query-Layout $Layout $options
}
function Assert-TextAbsent([string]$Layout, [string]$Text) {
  $options = @('--find-text-hex', (ConvertTo-Hex $Text), '--target', 'text', '--expect-count', '0')
  & python $queryScript $Layout @options *> $null
  if ($LASTEXITCODE -ne 0) { throw "Unexpected text: $Text" }
}
function Assert-IdAbsent([string]$Layout, [string]$Id) {
  & python $queryScript $Layout --find-id $Id --target clickable --expect-count 0 *> $null
  if ($LASTEXITCODE -ne 0) { throw "Unexpected control: $Id" }
}
function Bounds([object]$Node) {
  $match = [regex]::Match([string]$Node.bounds, '\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]')
  if (-not $match.Success) { throw 'Layout node has no bounds.' }
  return [pscustomobject]@{
    Left = [int]$match.Groups[1].Value
    Top = [int]$match.Groups[2].Value
    Right = [int]$match.Groups[3].Value
    Bottom = [int]$match.Groups[4].Value
  }
}
function Click([object]$Node) {
  & $hdc -t $Device shell ("uitest uiInput click " + [int]$Node.x + " " + [int]$Node.y) | Out-Null
}
function Assert-AboveComposer([string]$Layout, [string]$Label) {
  $inputBox = Bounds (Find-Id $Layout 'composer-input')
  $pickerBox = Bounds (Find-Id $Layout 'model-picker')
  if ($pickerBox.Bottom -gt $inputBox.Top) {
    throw ("Model sheet overlaps the composer input (" + $Label + "): pickerBottom=" + $pickerBox.Bottom + " inputTop=" + $inputBox.Top)
  }
  return [pscustomobject]@{ pickerTop = $pickerBox.Top; pickerBottom = $pickerBox.Bottom; inputTop = $inputBox.Top }
}

& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'model-menu' -Theme 'dark' -SkipBuild:$SkipBuild -SkipInstall:$SkipInstall | Out-Host
Start-Sleep -Milliseconds 1400
$layout = Dump-Layout 'closed-open'
$null = Find-Id $layout 'model-picker'
Assert-TextAbsent $layout '搜索模型'
$closed = Assert-AboveComposer $layout 'keyboard-closed'
Capture-Screen 'closed-open'
$results += @{ scenario = 'MP-01'; keyboard = 'closed'; pickerTop = $closed.pickerTop; pickerBottom = $closed.pickerBottom; inputTop = $closed.inputTop; searchBox = $false }

& $hdc -t $Device shell 'uitest uiInput click 60 300' | Out-Null
Start-Sleep -Milliseconds 800
$layout = Dump-Layout 'closed-dismissed'
Assert-IdAbsent $layout 'model-picker'
$results += @{ scenario = 'MP-03'; dismissedByOutsideTap = $true }

Click (Find-Id $layout 'composer-input')
Start-Sleep -Milliseconds 1500
$layout = Dump-Layout 'keyboard-before'
$inputBox = Bounds (Find-Id $layout 'composer-input')
Click (Find-Text $layout 'DeepSeek-V4-Pro' 'clickable' ($inputBox.Top - 250))
Start-Sleep -Milliseconds 900
$layout = Dump-Layout 'keyboard-open'
$null = Find-Id $layout 'model-picker'
Assert-TextAbsent $layout '搜索模型'
$opened = Assert-AboveComposer $layout 'keyboard-open'
Capture-Screen 'keyboard-open'
$results += @{ scenario = 'MP-02'; keyboard = 'open'; pickerTop = $opened.pickerTop; pickerBottom = $opened.pickerBottom; inputTop = $opened.inputTop; searchBox = $false }

& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 800
$layout = Dump-Layout 'sheet-closed'
Assert-IdAbsent $layout 'model-picker'
$caption = Find-Text $layout 'DeepSeek-V4-Pro' 'text'
$results += @{ scenario = 'MP-04'; closedByBack = $true; caption = [string]$caption.text }

if ((Bounds (Find-Id $layout 'composer-input')).Top -lt 2000) {
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 900
}
$layout = Dump-Layout 'keyboard-hidden'
Click (Find-Id $layout 'permission-chip')
Start-Sleep -Milliseconds 900
$layout = Dump-Layout 'permission-open'
$null = Find-Id $layout 'permission-picker'
$permissionBottom = (Bounds (Find-Id $layout 'permission-picker')).Bottom
$permissionInputTop = (Bounds (Find-Id $layout 'composer-input')).Top
if ($permissionBottom -gt $permissionInputTop) { throw 'Permission sheet no longer sits above the composer input.' }
Capture-Screen 'permission-open'
$results += @{ scenario = 'MP-05'; permissionAboveComposer = $true }
& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null

$manifest = @{ generatedAt = [DateTime]::UtcNow.ToString('o'); result = 'Passed'; variant = 'mock'; hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash; apiVersion = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join '').Trim(); scenarios = $results }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8
Write-Output "Model picker E2E passed: $captureDir"
