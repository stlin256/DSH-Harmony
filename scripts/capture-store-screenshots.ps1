param(
  [string]$DevEcoHome = '',
  [string]$HapPath = '',
  [string]$Device = '',
  [string]$OutputDir = '',
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [Alias('RestorePersonal')][switch]$RestoreCommunity
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'resolve-deveco-home.ps1')
$DevEcoHome = Resolve-DevEcoHome -ExplicitHome $DevEcoHome
if (-not $HapPath) {
  $HapPath = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\store-screenshots'
}
$rawDir = Join-Path $OutputDir 'raw'
$finalDir = Join-Path $OutputDir 'final'
New-Item -ItemType Directory -Force -Path $rawDir, $finalDir | Out-Null
Get-ChildItem -LiteralPath $rawDir -Filter '*.png' -File |
  Remove-Item -Force

$hdc = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path -LiteralPath $hdc)) {
  throw "HDC not found: $hdc"
}

function Get-ReadyDevice {
  $lines = & $hdc list targets -v
  $ready = @($lines | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No unlocked USB device is ready. Connect the HarmonyOS device and enable USB debugging.'
  }
  return ($ready[0] -split "`t")[0]
}

if (-not $Device) {
  $Device = Get-ReadyDevice
}

$env:DEVECO_CLI_STUDIO_PATH = $DevEcoHome
if (-not $SkipBuild) {
  & (Join-Path $PSScriptRoot 'build-harmony.ps1') -DevEcoHome $DevEcoHome -Product mock -BuildMode release -AssembleApp
  if ($LASTEXITCODE -ne 0) {
    throw "Mock Release build failed: $LASTEXITCODE"
  }
}
$hap = (Resolve-Path -LiteralPath $HapPath).Path

if (-not $SkipInstall) {
  & $hdc -t $Device install -r $hap
  if ($LASTEXITCODE -ne 0) {
    throw "HAP installation failed: $LASTEXITCODE"
  }
}

$bundle = 'io.github.stlin256.dshharmony'

function Capture([string]$fileName, [string]$screen, [string]$state, [string]$theme) {
  $path = Join-Path $rawDir $fileName
  Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  & $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
  & $hdc -t $Device shell "aa start -a EntryAbility -b $bundle -m entry --ps storeShowcase true --ps showcaseScreen $screen --ps showcaseState $state --ps showcaseTheme $theme"
  if ($LASTEXITCODE -ne 0) {
    throw "Launch failed for $screen/$state/$theme"
  }
  Start-Sleep -Seconds 4
  devecocli ui screenshot --device $Device --path $path
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $path)) {
    throw "Screenshot failed: $fileName"
  }
}

$captures = @(
  [ordered]@{ file = '01-conversation-light.png'; screen = 'conversation'; state = 'plan-dock-overlay'; theme = 'light' },
  [ordered]@{ file = '02-process-light.png'; screen = 'process'; state = 'completed'; theme = 'light' },
  [ordered]@{ file = '03-lineage-light.png'; screen = 'lineage'; state = 'plan-subagent'; theme = 'light' },
  [ordered]@{ file = '04-preview-light.png'; screen = 'preview'; state = 'text-config-preview'; theme = 'light' },
  [ordered]@{ file = '05-settings-light.png'; screen = 'settings'; state = 'completed'; theme = 'light' },
  [ordered]@{ file = '06-conversation-dark.png'; screen = 'conversation'; state = 'plan-subagent'; theme = 'dark' },
  [ordered]@{ file = '07-process-dark.png'; screen = 'process'; state = 'completed'; theme = 'dark' },
  [ordered]@{ file = '08-subagent-dark.png'; screen = 'subagent'; state = 'subagent-continuable'; theme = 'dark' },
  [ordered]@{ file = '09-automation-dark.png'; screen = 'automation'; state = 'automation-list'; theme = 'dark' },
  [ordered]@{ file = '10-plugins-dark.png'; screen = 'plugins'; state = 'plugins-list'; theme = 'dark' }
)

foreach ($capture in $captures) {
  Capture $capture.file $capture.screen $capture.state $capture.theme
}

python (Join-Path $PSScriptRoot 'compose-store-screenshots.py') --raw $rawDir --out $finalDir
if ($LASTEXITCODE -ne 0) {
  throw "Screenshot composition failed: $LASTEXITCODE"
}

$deviceModel = (& $hdc -t $Device shell "param get const.product.model").Trim()
$deviceApi = (& $hdc -t $Device shell "param get const.ohos.apiversion").Trim()
$hapHash = (Get-FileHash -LiteralPath $hap -Algorithm SHA256).Hash
$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  deviceModel = $deviceModel
  deviceApi = $deviceApi
  bundleName = $bundle
  product = 'mock'
  hap = 'harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap'
  hapSha256 = $hapHash
  rawDirectory = 'artifacts/store-screenshots/raw'
  finalDirectory = 'artifacts/store-screenshots/final'
  mockModel = 'DeepSeek-V4-Pro'
  reasoningEffort = 'max'
  scenes = $captures
  artifactCount = @(Get-ChildItem -LiteralPath $finalDir -Filter '*.png').Count
  appGalleryLandscapeCount = @(Get-ChildItem -LiteralPath (Join-Path $finalDir 'appgallery-landscape') -Filter '*.png').Count
  appGalleryPortraitCount = @(Get-ChildItem -LiteralPath (Join-Path $finalDir 'appgallery-portrait') -Filter '*.png').Count
}
$manifest |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $OutputDir 'manifest.json') -Encoding utf8

Get-ChildItem -LiteralPath $finalDir -Filter '*.png' |
  Select-Object FullName, Length, LastWriteTime

if ($RestoreCommunity) {
  & (Join-Path $PSScriptRoot 'build-harmony.ps1') -DevEcoHome $DevEcoHome -Product community -BuildMode release -AssembleApp
  if ($LASTEXITCODE -ne 0) {
    throw "Community Release build failed: $LASTEXITCODE"
  }
  $communityHap = (Resolve-Path -LiteralPath (
    Join-Path $repo 'harmony\entry\build\default\outputs\default\entry-default-signed.hap'
  )).Path
  & $hdc -t $Device install -r $communityHap
  if ($LASTEXITCODE -ne 0) {
    throw "Community HAP installation failed: $LASTEXITCODE"
  }
  & $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
  & $hdc -t $Device shell "aa start -a EntryAbility -b $bundle -m entry" | Out-Null
}
