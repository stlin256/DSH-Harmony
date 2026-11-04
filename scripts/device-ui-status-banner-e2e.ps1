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
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'artifacts\device-e2e\connection-banner' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'connection-banner'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
$bundle = 'io.github.stlin256.dshharmony'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$hap = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$results = @()

function ConvertTo-Hex([string]$Text) {
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant()
}
function Dump-Layout([string]$Name) {
  $remote = "/data/local/tmp/dsh-banner-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Layout capture failed.' }
  return $local
}
function Capture-Screen([string]$Name) {
  $remote = "/data/local/tmp/dsh-banner-$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  & $hdc -t $Device file recv $remote (Join-Path $captureDir "$Name.jpeg") | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Screenshot capture failed.' }
}
function Find-Text([string]$Layout, [string]$Text) {
  $options = @('--find-text-hex', (ConvertTo-Hex $Text), '--target', 'text')
  $raw = & python $queryScript $Layout @options 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Connection banner missing: $Text" }
  $node = (($raw -join '') | ConvertFrom-Json)
  if ([int]$node.count -lt 1) { throw "Connection banner missing: $Text" }
  return $node
}
function Assert-Banner([string]$Theme, [bool]$ReduceMotion) {
  $name = "$Theme"
  if ($ReduceMotion) { $name += '-reduced-motion' }
  $layout = Dump-Layout $name
  $script:lastBannerLayout = $layout
  $banner = Find-Text $layout '连接中断，正在尝试重连'
  Capture-Screen $name
  return [pscustomobject]@{ scenario = $name; theme = $Theme; reduceMotion = $ReduceMotion;
    bannerCount = [int]$banner.count; bannerBounds = [string]$banner.bounds }
}

& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'connection-retrying' -Theme 'dark' -SkipBuild:$SkipBuild -SkipInstall:$SkipInstall | Out-Host
$results += Assert-Banner 'dark' $false

# The banner is a passive status surface: a tap elsewhere must not drop it.
$tap = Find-Text $script:lastBannerLayout '连接中断，正在尝试重连'
& $hdc -t $Device shell ("uitest uiInput click " + [int]$tap.x + " " + [int]$tap.y) | Out-Null
Start-Sleep -Milliseconds 400
$afterTap = Dump-Layout 'dark-after-tap'
$null = Find-Text $afterTap '连接中断，正在尝试重连'
$results += @{ scenario = 'BAN-01-tap'; bannerPersists = $true }

& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'connection-retrying' -Theme 'light' -SkipBuild -SkipInstall | Out-Host
$results += Assert-Banner 'light' $false

& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'connection-retrying' -Theme 'dark' -ReduceMotion -SkipBuild -SkipInstall | Out-Host
$results += Assert-Banner 'dark' $true

$manifest = @{ generatedAt = [DateTime]::UtcNow.ToString('o'); result = 'Passed'; variant = 'mock'; hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash; apiVersion = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join '').Trim(); scenarios = $results }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8
Write-Output "Connection banner E2E passed: $captureDir"
