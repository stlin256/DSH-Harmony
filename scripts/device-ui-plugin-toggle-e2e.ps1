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
if (-not $Device) { $Device = @(& $hdc list targets | Where-Object { $_ -and $_ -notmatch 'Empty' })[0] }
if (-not $Device) { throw 'No connected device.' }
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'artifacts\device-e2e\plugin-toggle' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'plugin-toggle'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
$bundle = 'io.github.stlin256.dshharmony'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$toggleScript = Join-Path $PSScriptRoot 'device-ui-layout-toggle.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$hap = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$results = @()

function ConvertTo-Hex([string]$Text) {
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant()
}
function Dump-Layout([string]$Name) {
  $remote = "/data/local/tmp/dsh-plugin-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Layout capture failed.' }
  return $local
}
function Capture-Screen([string]$Name) {
  $remote = "/data/local/tmp/dsh-plugin-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Screenshot capture failed.' }
}
function Toggle-State([string]$Layout, [string]$Id) {
  $raw = & python $toggleScript $Layout $Id 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Toggle lookup failed: $Id" }
  $value = (($raw -join '') | ConvertFrom-Json)
  if (-not $value.found) { throw "Toggle not found: $Id" }
  return $value
}
function Find-Text([string]$Layout, [string]$Text) {
  $raw = & python $queryScript $Layout --find-text-hex (ConvertTo-Hex $Text) --target text 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Missing text: $Text" }
  return (($raw -join '') | ConvertFrom-Json)
}
function Find-Id([string]$Layout, [string]$Id) {
  $raw = & python $queryScript $Layout --find-id $Id --target clickable 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Missing id: $Id" }
  return (($raw -join '') | ConvertFrom-Json)
}
function Click-Node($Node) {
  if ($Node.x) { & $hdc -t $Device shell ("uitest uiInput click " + [int]$Node.x + " " + [int]$Node.y) | Out-Null }
}
function Assert-Toggle([string]$Layout, [string]$Id, [string]$Checked) {
  $state = Toggle-State $Layout $Id
  if ($state.checked -ne $Checked) { throw "Toggle $Id expected checked=$Checked, got $($state.checked)" }
  return $state
}
function Assert-Banner([string]$Layout, [string]$Text) {
  $null = Find-Text $Layout $Text
  $banner = Toggle-State $Layout 'plugin-result-banner'
  if ($banner.height -gt 140) { throw "Plugin banner height $($banner.height)px is not one-line compact." }
  return $banner
}

function Invoke-PluginCase([string]$Theme) {
  & $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'plugins' -State 'plugins-list' -Theme $Theme -SkipBuild:$SkipBuild -SkipInstall:$SkipInstall | Out-Host
  Start-Sleep -Milliseconds 1200
  $layout = Dump-Layout "$Theme-initial"
  $before = Assert-Toggle $layout 'plugin-bundle-toggle-@dsh/api-inspector' 'true'
  & $hdc -t $Device shell ("uitest uiInput click " + [int]$before.x + " " + [int]$before.y) | Out-Null
  Start-Sleep -Milliseconds 700
  $offLayout = Dump-Layout "$Theme-off"
  $off = Assert-Toggle $offLayout 'plugin-bundle-toggle-@dsh/api-inspector' 'false'
  $offBanner = Assert-Banner $offLayout '已关闭'
  Capture-Screen "$Theme-off"
  & $hdc -t $Device shell ("uitest uiInput click " + [int]$off.x + " " + [int]$off.y) | Out-Null
  Start-Sleep -Milliseconds 700
  $onLayout = Dump-Layout "$Theme-on"
  $on = Assert-Toggle $onLayout 'plugin-bundle-toggle-@dsh/api-inspector' 'true'
  $onBanner = Assert-Banner $onLayout '已启用'
  Capture-Screen "$Theme-on"
  return [pscustomobject]@{ scenario = "$Theme-bundle"; theme = $Theme; bannerHeight = $offBanner.height; refreshInPlace = $true }
}

$results += Invoke-PluginCase 'dark'
$results += Invoke-PluginCase 'light'

# Detail row switch must refresh in place as well.
& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'plugins' -State 'plugins-detail' -Theme 'dark' -SkipBuild -SkipInstall | Out-Host
Start-Sleep -Milliseconds 1200
$detail = Dump-Layout 'detail-initial'
$rowBefore = Assert-Toggle $detail 'plugin-row-toggle-native-bridge' 'true'
& $hdc -t $Device shell ("uitest uiInput click " + [int]$rowBefore.x + " " + [int]$rowBefore.y) | Out-Null
Start-Sleep -Milliseconds 700
$detailOff = Dump-Layout 'detail-off'
$rowAfter = Assert-Toggle $detailOff 'plugin-row-toggle-native-bridge' 'false'
$rowBanner = Assert-Banner $detailOff '已关闭'
Capture-Screen 'detail-off'
$results += [pscustomobject]@{ scenario = 'detail-row'; theme = 'dark'; bannerHeight = $rowBanner.height; refreshInPlace = $true }

$manifest = @{ generatedAt = [DateTime]::UtcNow.ToString('o'); result = 'Passed'; variant = 'mock'; hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash; apiVersion = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join '').Trim(); scenarios = $results }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8
Write-Output "Plugin toggle E2E passed: $captureDir"
