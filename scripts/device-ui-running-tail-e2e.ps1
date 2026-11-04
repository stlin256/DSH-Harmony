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
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'artifacts\device-e2e\running-tail' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'running-tail'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
$bundle = 'io.github.stlin256.dshharmony'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$diffScript = Join-Path $PSScriptRoot 'image-region-diff.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$hap = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$results = @()

function ConvertTo-Hex([string]$Text) {
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant()
}
function Dump-Layout([string]$Name) {
  $remote = "/data/local/tmp/dsh-tail-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Layout capture failed.' }
  return $local
}
function Capture-Screen([string]$Name) {
  $remote = "/data/local/tmp/dsh-tail-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Screenshot capture failed.' }
  return $local
}
function Find-Text([string]$Layout, [string]$Text) {
  $raw = & python $queryScript $Layout --find-text-hex (ConvertTo-Hex $Text) --target text 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Missing text: $Text" }
  return (($raw -join '') | ConvertFrom-Json)
}
function Assert-TailText([string]$Layout) {
  $null = Find-Text $Layout '深度求索中'
}
function Layout-Texts([string]$Layout) {
  $textsScript = Join-Path $PSScriptRoot 'device-ui-layout-texts.py'
  $raw = & python $textsScript $Layout 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Layout text extraction failed.' }
  return ($raw -join "`n")
}
function Tail-Region([string]$Layout) {
  $text = Find-Text $Layout '深度求索中'
  $match = [regex]::Match([string]$text.bounds, '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$')
  if (-not $match.Success) { throw 'Running tail bounds unavailable.' }
  $x1 = [Math]::Max(0, [int]$match.Groups[1].Value - 42)
  $y1 = [Math]::Max(0, [int]$match.Groups[2].Value - 8)
  $x2 = [Math]::Min(1260, [int]$match.Groups[3].Value + 80)
  $y2 = [Math]::Min(2844, [int]$match.Groups[4].Value + 8)
  return @($x1, $y1, $x2, $y2)
}
function Region-Diff([string]$A, [string]$B, [int[]]$Region) {
  $raw = & python $diffScript $A $B $Region[0] $Region[1] $Region[2] $Region[3] 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Region diff failed.' }
  return (($raw -join '') | ConvertFrom-Json)
}
function Elapsed-Seconds([string]$Layout) {
  $secondsScript = Join-Path $PSScriptRoot 'device-ui-running-seconds.py'
  $raw = & python $secondsScript $Layout 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Elapsed extraction failed.' }
  return [int](($raw -join '').Trim())
}

# Animated dark case: line present, live clock advances, region changes between frames.
& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'stream-tail' -Theme 'dark' -SkipBuild:$SkipBuild -SkipInstall:$SkipInstall | Out-Host
Start-Sleep -Milliseconds 1800
$layout = Dump-Layout 'dark-live'
Assert-TailText $layout
$region = Tail-Region $layout
$beforeSeconds = Elapsed-Seconds $layout
$first = Capture-Screen 'dark-a'
Start-Sleep -Milliseconds 260
$second = Capture-Screen 'dark-b'
$diff = Region-Diff $first $second $region
Start-Sleep -Milliseconds 2300
$later = Dump-Layout 'dark-later'
$null = Find-Text $later '深度求索中'
$afterSeconds = Elapsed-Seconds $later
if (-not ($afterSeconds -gt $beforeSeconds)) { throw "Elapsed clock did not advance: $beforeSeconds -> $afterSeconds" }
if (-not $diff.changed) { throw 'Running-tail region did not animate.' }
# Scrolling the transcript must not detach the tail line.
& $hdc -t $Device shell 'uitest uiInput swipe 630 1500 630 1200 260' | Out-Null
Start-Sleep -Milliseconds 350
$scrolled = Dump-Layout 'dark-scrolled'
$null = Find-Text $scrolled '深度求索中'
Capture-Screen 'dark-scrolled' | Out-Null
$results += [pscustomobject]@{ scenario = 'dark-live'; theme = 'dark'; reducedMotion = $false;
  elapsedBefore = $beforeSeconds; elapsedAfter = $afterSeconds; regionChanged = [bool]$diff.changed;
  regionDelta = $diff.mean_delta }

# Light theme keeps the same copy and legibility.
& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'stream-tail' -Theme 'light' -SkipBuild -SkipInstall | Out-Host
Start-Sleep -Milliseconds 1800
$lightLayout = Dump-Layout 'light-live'
Assert-TailText $lightLayout
Capture-Screen 'light-live' | Out-Null
$results += [pscustomobject]@{ scenario = 'light-live'; theme = 'light'; reducedMotion = $false;
  elapsed = (Elapsed-Seconds $lightLayout) }

# Reduced motion resolves to the static whale and static text.
& $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir -Screen 'conversation' -State 'stream-tail' -Theme 'dark' -ReduceMotion -SkipBuild -SkipInstall | Out-Host
Start-Sleep -Milliseconds 1800
$quietLayout = Dump-Layout 'reduced-live'
Assert-TailText $quietLayout
$quietRegion = Tail-Region $quietLayout
$static = $false
for ($attempt = 0; $attempt -lt 4 -and -not $static; $attempt++) {
  $quietA = Capture-Screen ("reduced-a-$attempt")
  $quietLabelA = Elapsed-Seconds $quietLayout
  Start-Sleep -Milliseconds 200
  $quietB = Capture-Screen ("reduced-b-$attempt")
  $quietLabelB = Elapsed-Seconds $quietLayout
  if ($quietLabelA -ne $quietLabelB) { continue }
  $quietDiff = Region-Diff $quietA $quietB $quietRegion
  $static = -not $quietDiff.changed
}
if (-not $static) { throw 'Reduced-motion running tail still animates.' }
Capture-Screen 'reduced-live' | Out-Null
$results += [pscustomobject]@{ scenario = 'reduced-live'; theme = 'dark'; reducedMotion = $true; staticRegion = $static }

$manifest = @{ generatedAt = [DateTime]::UtcNow.ToString('o'); result = 'Passed'; variant = 'mock'; hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash; apiVersion = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join '').Trim(); scenarios = $results }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8
Write-Output "Running tail E2E passed: $captureDir"
