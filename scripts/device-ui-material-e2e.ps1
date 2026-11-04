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
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'artifacts\device-e2e\material' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'material'
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
  $remote = "/data/local/tmp/dsh-material-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Layout capture failed.' }
  return $local
}
function Capture-Screen([string]$Name) {
  $remote = "/data/local/tmp/dsh-material-$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  & $hdc -t $Device file recv $remote (Join-Path $captureDir "$Name.jpeg") | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Screenshot capture failed.' }
}
function Assert-LayoutId([string]$Layout, [string]$Id) {
  $raw = & python $queryScript $Layout --find-id $Id --target text 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Missing layout id: $Id" }
  return (($raw -join '') | ConvertFrom-Json)
}
function Invoke-TaskDockCase([string]$Name, [string]$Theme) {
  & $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'plan-dock-overlay' -Theme $Theme -ImmersiveMaterial -SkipBuild -SkipInstall | Out-Host
  Start-Sleep -Milliseconds 1600
  $layout = Dump-Layout $Name
  $deadline = [DateTime]::UtcNow.AddSeconds(6)
  while ($true) {
    & python $queryScript $layout --find-id 'task-dock' --target text *> $null
    if ($LASTEXITCODE -eq 0) { break }
    if ([DateTime]::UtcNow -ge $deadline) { throw "Task dock missing: $Name" }
    Start-Sleep -Milliseconds 600
    $layout = Dump-Layout $Name
  }
  Capture-Screen $Name
  return [pscustomobject]@{ scenario = $Name; theme = $Theme; immersiveMaterial = $true; taskDock = $true }
}

function Invoke-MaterialCase([string]$Name, [string]$Theme, [bool]$Material) {
  $launch = @{ DevEcoHome = $DevEcoHome; Device = $Device; OutputDir = $OutputDir
    Screen = 'conversation'; State = 'dock-material-elevated'; Theme = $Theme
    SkipBuild = $true; SkipInstall = $true }
  if ($Material) { $launch.ImmersiveMaterial = $true }
  & $mockScript @launch | Out-Host
  Start-Sleep -Milliseconds 700
  $layout = Dump-Layout $Name
  $composer = Assert-LayoutId $layout 'composer-input'
  Capture-Screen $Name
  return [pscustomobject]@{ scenario = $Name; theme = $Theme; immersiveMaterial = $Material;
    composer = $true; composerBounds = [string]$composer.bounds }
}

& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'dock-material-elevated' -Theme 'dark' -ImmersiveMaterial -SkipBuild:$SkipBuild -SkipInstall:$SkipInstall | Out-Host
Start-Sleep -Milliseconds 700
$darkLayout = Dump-Layout 'material-dark'
$null = Assert-LayoutId $darkLayout 'composer-input'
Capture-Screen 'material-dark'
# The composer is an interactive control even when the material is visual only.
$composer = Assert-LayoutId $darkLayout 'composer-input'
& $hdc -t $Device shell ("uitest uiInput click " + [int]$composer.x + " " + [int]$composer.y) | Out-Null
Start-Sleep -Milliseconds 600
& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
$results += [pscustomobject]@{ scenario = 'material-dark'; theme = 'dark'; immersiveMaterial = $true; composerBounds = [string]$composer.bounds }

$results += Invoke-MaterialCase 'material-light' 'light' $true
$results += Invoke-MaterialCase 'material-off-dark' 'dark' $false
$results += Invoke-TaskDockCase 'task-dock-material-dark' 'dark'
$results += Invoke-TaskDockCase 'task-dock-material-light' 'light'

$manifest = @{ generatedAt = [DateTime]::UtcNow.ToString('o'); result = 'Passed'; variant = 'mock'; hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash; apiVersion = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join '').Trim(); scenarios = $results }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8
Write-Output "Immersive material E2E passed: $captureDir"
