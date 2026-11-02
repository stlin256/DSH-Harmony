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
  $OutputDir = Join-Path $repo 'artifacts\device-e2e\stream-long'
}
$captureDir = Join-Path $OutputDir 'stream-long-liveness'
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

$bundle = 'io.github.stlin256.dshharmony'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'

function Text-Hex {
  param([string]$Text)
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-stream-long-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Layout dump failed: $Name" }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Layout receive failed: $Name"
  }
  return $local
}

function Capture-Screen {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-stream-long-$Name.jpeg"
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

function Try-Query-Node {
  param([string]$Layout, [string]$Text, [string]$Target = 'text')
  $raw = & python $queryScript $Layout --find-text-hex (Text-Hex $Text) --target $Target 2>&1
  if ($LASTEXITCODE -ne 0) { return $null }
  return (($raw -join '') | ConvertFrom-Json)
}

function Assert-TextAbsent {
  param([string]$Layout, [string]$Text)
  $raw = & python $queryScript $Layout --find-text-hex (Text-Hex $Text) --target text 2>&1
  if ($LASTEXITCODE -eq 0) {
    throw "Unexpected visible text: $Text"
  }
}

function Text-Signature {
  param([string]$Layout)
  $parsed = Get-Content -Raw -LiteralPath $Layout | ConvertFrom-Json
  $root = if ($parsed -is [array]) { $parsed[0] } else { $parsed }
  $labels = New-Object 'System.Collections.Generic.List[string]'
  function Add-Labels {
    param([object]$Node)
    $attributes = $Node.attributes
    foreach ($value in @($attributes.text, $attributes.accessibilityText, $attributes.originalText)) {
      if ($value) { $labels.Add([string]$value) }
    }
    foreach ($child in @($Node.children)) {
      if ($null -ne $child) { Add-Labels -Node $child }
    }
  }
  Add-Labels -Node $root
  $text = $labels -join "`n"
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))
  } finally {
    $sha.Dispose()
  }
  return ([BitConverter]::ToString($hash)).Replace('-', '')
}

function Invoke-Click {
  param([object]$Node)
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Input click failed at $($Node.x),$($Node.y)" }
  Start-Sleep -Milliseconds 650
}

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$mockArguments = @{
  DevEcoHome = $DevEcoHome
  Device = $Device
  Screen = 'conversation'
  State = 'stream-long'
  Theme = 'dark'
  OutputDir = $OutputDir
}
if ($SkipBuild) { $mockArguments.SkipBuild = $true }
if ($SkipInstall) { $mockArguments.SkipInstall = $true }
& $mockScript @mockArguments | Out-Host

$fixtureDir = Join-Path $OutputDir 'stream-long-dark-conversation'
$fixtureManifestPath = Join-Path $fixtureDir 'manifest.json'
$fixtureLayout = Join-Path $fixtureDir 'layout.json'
$fixtureManifest = Get-Content -Raw -LiteralPath $fixtureManifestPath | ConvertFrom-Json
$initialPid = [string]$fixtureManifest.processId
Copy-Item -LiteralPath (Join-Path $fixtureDir 'screen.jpeg') -Destination (Join-Path $captureDir 'live-01.jpeg')
Copy-Item -LiteralPath $fixtureLayout -Destination (Join-Path $captureDir 'live-01.json')
$firstSignature = Text-Signature (Join-Path $captureDir 'live-01.json')

Start-Sleep -Milliseconds 1300
Capture-Screen 'live-02'
$secondLayout = Dump-Layout 'live-02'
$secondSignature = Text-Signature $secondLayout
if ($secondSignature -eq $firstSignature) {
  throw 'Long stream text did not advance between the first two captures.'
}

$finalLayout = ''
$deadline = (Get-Date).AddSeconds(24)
while ((Get-Date) -lt $deadline) {
  $probe = Dump-Layout 'stream-poll'
  if (Try-Query-Node $probe 'STREAM-LONG-DONE' 'text') {
    $finalLayout = $probe
    break
  }
  Start-Sleep -Milliseconds 700
}
if (-not $finalLayout) {
  throw 'STREAM-LONG-DONE did not become visible without relaunching the App.'
}

$null = Query-Node $finalLayout '长流持续输出' 'text'
$null = Query-Node $finalLayout '发送消息…' 'clickable'
Assert-TextAbsent $finalLayout '连接中断'
Capture-Screen 'live-final'
Copy-Item -LiteralPath $finalLayout -Destination (Join-Path $captureDir 'live-final.json')

$finalPid = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $initialPid -or $finalPid -ne $initialPid) {
  throw "App process changed during the long stream: '$initialPid' -> '$finalPid'"
}

$composer = Query-Node $finalLayout '发送消息…' 'clickable'
Invoke-Click $composer
& $hdc -t $Device shell 'uitest uiInput inputText streamAlive' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Composer input failed during the long-stream fixture.' }
Start-Sleep -Milliseconds 600
$interactiveLayout = Dump-Layout 'composer-responsive'
$null = Query-Node $interactiveLayout 'streamAlive' 'text'
Capture-Screen 'composer-responsive'
& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 600
$returnedLayout = Dump-Layout 'composer-returned'
$null = Query-Node $returnedLayout '长流持续输出' 'text'
$null = Query-Node $returnedLayout '发送消息…' 'clickable'

$hap = if ($SkipBuild) {
  (Resolve-Path -LiteralPath (Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap')).Path
} else {
  (Resolve-Path -LiteralPath (Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap')).Path
}
$api = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join ' ').Trim()
$model = ((& $hdc -t $Device shell 'param get const.product.model') -join ' ').Trim()
$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  deviceModel = $model
  apiVersion = $api
  variant = 'mock'
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash
  result = 'Passed'
  processId = $initialPid
  processStable = $true
  textAdvanced = $true
  finalMarker = 'STREAM-LONG-DONE'
  reconnectBannerAbsent = $true
  composerResponsive = $true
  captures = @(
    'live-01.jpeg',
    'live-02.jpeg',
    'live-final.jpeg',
    'composer-responsive.jpeg'
  )
}
$manifest |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Long-stream E2E passed. Evidence: $captureDir"
