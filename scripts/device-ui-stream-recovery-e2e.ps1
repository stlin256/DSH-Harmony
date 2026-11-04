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
if (-not $OutputDir) { $OutputDir = Join-Path $repo 'artifacts\device-e2e\stream-reconstruction' }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'recovery'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
$bundle = 'io.github.stlin256.dshharmony'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$hap = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$results = @()

function Dump-Layout([string]$Name) {
  $remote = "/data/local/tmp/dsh-recovery-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Layout capture failed.' }
  return $local
}
function Capture-Screen([string]$Name) {
  $remote = "/data/local/tmp/dsh-recovery-$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  & $hdc -t $Device file recv $remote (Join-Path $captureDir "$Name.jpeg") | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Screenshot capture failed.' }
}
function ConvertTo-Hex([string]$Text) {
  # Windows PowerShell 5.1 lacks Convert.ToHexString; BitConverter works on both.
  return ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant()
}
function Query-Node([string]$Layout, [string]$Text, [string]$Target = 'text') {
  $hex = ConvertTo-Hex $Text
  $raw = & python $queryScript $Layout --find-text-hex $hex --target $Target 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Expected control absent: $Text" }
  return (($raw -join '') | ConvertFrom-Json)
}
function Assert-TextAbsent([string]$Layout, [string]$Text) {
  $hex = ConvertTo-Hex $Text
  & python $queryScript $Layout --find-text-hex $hex --target text --expect-count 0 *> $null
  if ($LASTEXITCODE -ne 0) { throw "Unexpected text: $Text" }
}
function Invoke-Click($Node) {
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
}

# STR-R1/R2/R5: quiet >12 seconds, burst convergence, themes, reduced motion,
# composer and System Back, with stable process throughout each scenario.
$scenarios = @(
  @{ Screen = 'conversation'; State = 'stream-burst-quiet'; Theme = 'dark'; Reduce = $false },
  @{ Screen = 'conversation'; State = 'stream-burst-quiet'; Theme = 'light'; Reduce = $false },
  @{ Screen = 'conversation'; State = 'stream-burst-quiet'; Theme = 'dark'; Reduce = $true },
  @{ Screen = 'conversation'; State = 'stream-reconnect'; Theme = 'light'; Reduce = $false }
)
foreach ($scenario in $scenarios) {
  $name = "$($scenario.State)-$($scenario.Theme)-$($scenario.Reduce)"
  $args = @{ DevEcoHome = $DevEcoHome; Device = $Device; OutputDir = $OutputDir
    Screen = $scenario.Screen; State = $scenario.State; Theme = $scenario.Theme
    SkipBuild = [bool]$SkipBuild; SkipInstall = [bool]$SkipInstall; ReduceMotion = $scenario.Reduce }
  & $mockScript @args | Out-Host
  $SkipBuild = $true; $SkipInstall = $true
  $initialPid = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
  $marker = if ($scenario.State -eq 'stream-reconnect') { 'STREAM-RECOVERED-DONE' } else { 'STREAM-BURST-DONE' }
  $deadline = [DateTime]::UtcNow.AddSeconds(45)
  $found = $false
  $samples = 0
  while ([DateTime]::UtcNow -lt $deadline) {
    $layout = Dump-Layout $name
    if ($scenario.State -eq 'stream-burst-quiet') { Assert-TextAbsent $layout '连接中断' }
    Assert-TextAbsent $layout '连接暂时无法恢复'
    try { $null = Query-Node $layout $marker; $found = $true; break } catch {}
    $samples++
    Start-Sleep -Milliseconds 1000
  }
  if (-not $found) { throw "Stream did not converge: $name" }
  Capture-Screen $name
  $composer = Query-Node $layout '发送消息…' 'clickable'
  Invoke-Click $composer
  & $hdc -t $Device shell "uitest uiInput inputText $($composer.x) $($composer.y) recoveryAlive" | Out-Null
  Start-Sleep -Milliseconds 400
  $layout = Dump-Layout "$name-composer"
  $null = Query-Node $layout 'recoveryAlive'
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  $finalPid = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
  if ($initialPid -ne $finalPid) { throw 'Stream recovery restarted the app.' }
  $results += @{ scenario = $name; marker = $marker; samples = $samples; processStable = $true; composer = $true }
}

# STR-R3/R4: permanent child read failure, explicit retry, readable child and Back.
foreach ($theme in @('dark', 'light')) {
  & $mockScript -DevEcoHome $DevEcoHome -Device $Device -OutputDir $OutputDir `
    -Screen 'subagent' -State 'subagent-unavailable' -Theme $theme -SkipBuild -SkipInstall | Out-Host
  $layout = Dump-Layout "child-$theme-unavailable"
  $null = Query-Node $layout '子智能体记录暂时无法读取'
  Assert-TextAbsent $layout '连接中断'
  Capture-Screen "child-$theme-unavailable"
  $retry = Query-Node $layout '重新连接' 'clickable'
  Invoke-Click $retry
  Start-Sleep -Milliseconds 1000
  $layout = Dump-Layout "child-$theme-retried"
  Assert-TextAbsent $layout '子智能体记录暂时无法读取'
  $null = Query-Node $layout '可继续检查'
  Capture-Screen "child-$theme-retried"
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 700
  $layout = Dump-Layout "child-$theme-parent"
  Assert-TextAbsent $layout '重新连接'
  $results += @{ scenario = "child-$theme"; unavailable = $true; retry = $true; systemBack = $true }
}
$manifest = @{ generatedAt = [DateTime]::UtcNow.ToString('o'); result = 'Passed'; variant = 'mock'
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash
  apiVersion = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join '').Trim()
  scenarios = $results }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8
Write-Output "Stream recovery E2E passed: $captureDir"
