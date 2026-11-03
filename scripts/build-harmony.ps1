param(
  [string]$DevEcoHome = $env:DEVECO_STUDIO_HOME,
  [ValidateSet('community','default','store','mock')][string]$Product = 'community',
  [ValidateSet('debug','release')][string]$BuildMode = 'debug',
  [switch]$AssembleApp
)
$ErrorActionPreference = 'Stop'
if (-not $DevEcoHome) { throw 'Set DEVECO_STUDIO_HOME or pass -DevEcoHome.' }
$ide = (Resolve-Path -LiteralPath $DevEcoHome).Path
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = (Resolve-Path (Join-Path $repo 'harmony')).Path
$profile = Join-Path $project 'build-profile.json5'
$manifest = Join-Path $project 'entry/src/main/module.json5'
$storeManifest = Join-Path $project 'variants/store/module.json5'
$appStrings = Join-Path $project 'AppScope/resources/base/element/string.json'
$buildProduct = if ($Product -eq 'community' -or $Product -eq 'default') { 'default' } else { $Product }
$capabilityRoot = if ($buildProduct -eq 'default') { 'community' } else { $Product }
$capabilitySource = Join-Path $project ("entry/src/{0}/ProductCapabilities.ets" -f $capabilityRoot)
$verifyNode = Join-Path $ide 'tools/node/node.exe'
$verifyCoverage = Join-Path $repo 'scripts/verify-mock-coverage.mjs'
$productDisplayName = [regex]::Match(
  [IO.File]::ReadAllText($capabilitySource),
  "appDisplayName\s*:\s*string\s*=\s*'([^']+)'"
).Groups[1].Value
if (-not $productDisplayName) {
  throw "Product display name not found in $capabilitySource"
}
if (-not (Test-Path -LiteralPath $verifyNode)) {
  throw "Node.js not found in DevEco Studio: $verifyNode"
}
& $verifyNode $verifyCoverage
if ($LASTEXITCODE -ne 0) {
  throw 'Mock frontend coverage verification failed.'
}
if (-not (Test-Path -LiteralPath $profile)) {
  Copy-Item -LiteralPath (Join-Path $project 'build-profile.example.json5') -Destination $profile
}
$restoreManifest = $null
$restoreAppStrings = $null
$savedNode = $env:NODE_HOME
$savedJava = $env:JAVA_HOME
$savedSdk = $env:DEVECO_SDK_HOME
$savedCli = $env:DEVECO_CLI_STUDIO_PATH
$savedPath = $env:Path
Push-Location -LiteralPath $project
try {
  if ($buildProduct -eq 'store') {
    $restoreManifest = [IO.File]::ReadAllBytes($manifest)
    Copy-Item -LiteralPath $storeManifest -Destination $manifest -Force
  }
  $restoreAppStrings = [IO.File]::ReadAllBytes($appStrings)
  $resourceText = [Text.Encoding]::UTF8.GetString($restoreAppStrings)
  $resource = $resourceText | ConvertFrom-Json
  $appNameEntry = @($resource.string) | Where-Object { $_.name -eq 'app_name' } | Select-Object -First 1
  if ($null -eq $appNameEntry) {
    throw "app_name entry not found in $appStrings"
  }
  $appNameEntry.value = $productDisplayName
  $resourceJson = $resource | ConvertTo-Json -Depth 8 -Compress
  [IO.File]::WriteAllText($appStrings, $resourceJson + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
  $env:NODE_HOME = Join-Path $ide 'tools/node'
  $env:JAVA_HOME = Join-Path $ide 'jbr'
  $env:DEVECO_SDK_HOME = Join-Path $ide 'sdk'
  $env:Path = "$env:NODE_HOME;$env:JAVA_HOME/bin;$savedPath"
  & (Join-Path $ide 'tools/ohpm/bin/ohpm.bat') install
  if ($LASTEXITCODE -ne 0) { throw 'ohpm install failed' }
  if ($AssembleApp) {
    $env:DEVECO_CLI_STUDIO_PATH = $ide
    & devecocli build --product $buildProduct --build-mode $BuildMode
  } else {
    & (Join-Path $env:NODE_HOME 'node.exe') (Join-Path $ide 'tools/hvigor/bin/hvigorw.js') --mode module -p "product=$buildProduct" -p "module=entry@$buildProduct" -p "buildMode=$BuildMode" assembleHap --no-daemon
  }
  if ($LASTEXITCODE -ne 0) { throw "HarmonyOS build failed: $LASTEXITCODE" }
} finally {
  Pop-Location
  if ($null -ne $restoreManifest) {
    [IO.File]::WriteAllBytes($manifest, $restoreManifest)
  }
  if ($null -ne $restoreAppStrings) {
    [IO.File]::WriteAllBytes($appStrings, $restoreAppStrings)
  }
  $env:NODE_HOME = $savedNode
  $env:JAVA_HOME = $savedJava
  $env:DEVECO_SDK_HOME = $savedSdk
  $env:DEVECO_CLI_STUDIO_PATH = $savedCli
  $env:Path = $savedPath
}
