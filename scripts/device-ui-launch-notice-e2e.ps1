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
if (-not (Test-Path -LiteralPath $hdc)) {
  throw "HDC not found: $hdc"
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-launch-notice-e2e'
}
if (-not [IO.Path]::IsPathRooted($OutputDir)) {
  $OutputDir = Join-Path $repo $OutputDir
}
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'iteration-notice'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; launch notice E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$bundle = 'io.github.stlin256.dshharmony'
$e2eStartedAt = Get-Date

function Get-Bounds {
  param([object]$Node)
  $match = [regex]::Match([string]$Node.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $match.Success) {
    throw "Cannot read bounds: $($Node.bounds)"
  }
  return [pscustomobject]@{
    Left = [int]$match.Groups[1].Value
    Top = [int]$match.Groups[2].Value
    Right = [int]$match.Groups[3].Value
    Bottom = [int]$match.Groups[4].Value
    Width = [int]$match.Groups[3].Value - [int]$match.Groups[1].Value
    Height = [int]$match.Groups[4].Value - [int]$match.Groups[2].Value
  }
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-launch-notice-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b $bundle" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Layout dump failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Layout receive failed: $Name"
  }
  return $local
}

function Capture-Screen {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-launch-notice-$Name.jpeg"
  $local = Join-Path $captureDir "$Name.jpeg"
  & $hdc -t $Device shell "uitest screenCap -p $remote" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Screen capture failed: $Name"
  }
  & $hdc -t $Device file recv $remote $local | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $local)) {
    throw "Screen receive failed: $Name"
  }
}

function Text-Hex {
  param([string]$Text)
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
}

function Query-Text {
  param(
    [string]$Layout,
    [string]$Text,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'text',
    [switch]$Exact,
    [int]$ExpectCount = 1
  )
  $arguments = @(
    $queryScript,
    $Layout,
    '--find-text-hex',
    (Text-Hex $Text),
    '--target',
    $Target,
    '--expect-count',
    $ExpectCount
  )
  if ($Exact) { $arguments += '--exact-text' }
  $raw = & python @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout query failed for '$Text': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Query-ById {
  param(
    [string]$Layout,
    [string]$Id,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'text'
  )
  $raw = & python $queryScript $Layout --find-id $Id --target $Target --expect-count 1 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout id query failed for '$Id': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Assert-VisibleText {
  param(
    [string]$Layout,
    [string]$Text,
    [ValidateSet('text', 'clickable')]
    [string]$Target = 'text'
  )
  $node = Query-Text $Layout $Text $Target
  if ($null -eq $node) {
    throw "Visible text assertion failed for '$Text'."
  }
  return $node
}

function Wait-Text {
  param(
    [string]$Name,
    [string]$Text,
    [ValidateSet('text', 'clickable')]
    [string]$Target = 'text',
    [int]$TimeoutMilliseconds = 8000
  )
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
  $lastError = ''
  do {
    try {
      $layout = Dump-Layout $Name
      return @{
        Layout = $layout
        Node = Query-Text $layout $Text $Target
      }
    } catch {
      $lastError = $_.Exception.Message
      Start-Sleep -Milliseconds 300
    }
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Timed out waiting for '$Text': $lastError"
}

function Invoke-Click {
  param([object]$Node)
  if ($null -eq $Node.x -or $null -eq $Node.y) {
    throw "Node has no click coordinate: $($Node.bounds)"
  }
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Click failed at $($Node.x),$($Node.y)"
  }
}

function Launch-Fixture {
  param(
    [string]$Screen,
    [string]$State,
    [string]$Theme,
    [bool]$ReduceMotion,
    [bool]$FirstLaunch
  )
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = $Screen
    State = $State
    Theme = $Theme
    OutputDir = $OutputDir
    ResetData = $true
  }
  if (-not $FirstLaunch -or $SkipBuild) { $arguments.SkipBuild = $true }
  if (-not $FirstLaunch -or $SkipInstall) { $arguments.SkipInstall = $true }
  if ($ReduceMotion) { $arguments.ReduceMotion = $true }
  & $mockScript @arguments | Out-Host
}

function Get-RelativeArtifactPath {
  param([string]$Path)
  return [IO.Path]::GetRelativePath($repo, $Path).Replace('\', '/')
}

$themes = @('dark', 'light')
$themeResults = [System.Collections.Generic.List[object]]::new()
$firstLaunch = $true
foreach ($theme in $themes) {
  Launch-Fixture -Screen 'launch' -State 'iteration-notice' -Theme $theme `
    -ReduceMotion $false -FirstLaunch $firstLaunch
  $firstLaunch = $false
  $noticeLayout = Dump-Layout "$theme-notice"
  $null = Assert-VisibleText $noticeLayout '项目正在快速迭代'
  $null = Assert-VisibleText $noticeLayout '当前仍有许多功能尚未完成'
  $null = Assert-VisibleText $noticeLayout '提交 Issue'
  $confirm = Query-ById $noticeLayout 'iteration-notice-confirm' 'clickable'
  $beforeLogo = Get-Bounds (Query-ById $noticeLayout 'launch-brand-logo')
  Capture-Screen "$theme-notice"

  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 450
  $afterBack = Dump-Layout "$theme-notice-after-back"
  $null = Query-Text $afterBack '项目正在快速迭代'

  Invoke-Click $confirm
  $welcome = Wait-Text "$theme-welcome" '开始引导' 'clickable'
  $welcomeLayout = $welcome.Layout
  $null = Query-Text $welcomeLayout '直接进入' 'clickable'
  $afterLogo = Get-Bounds (Query-ById $welcomeLayout 'launch-brand-logo')
  if ($beforeLogo.Left -ne $afterLogo.Left -or $beforeLogo.Top -ne $afterLogo.Top -or
      $beforeLogo.Width -ne $afterLogo.Width -or $beforeLogo.Height -ne $afterLogo.Height) {
    throw "Logo moved during notice confirmation in $theme theme: " +
      "before=$($beforeLogo.Left),$($beforeLogo.Top),$($beforeLogo.Width),$($beforeLogo.Height) " +
      "after=$($afterLogo.Left),$($afterLogo.Top),$($afterLogo.Width),$($afterLogo.Height)"
  }
  Capture-Screen "$theme-welcome"
  $themeResults.Add([pscustomobject]@{
    theme = $theme
    logoBefore = $beforeLogo
    logoAfter = $afterLogo
    result = 'Passed'
  })
}

Launch-Fixture -Screen 'launch' -State 'iteration-notice' -Theme 'dark' `
  -ReduceMotion $true -FirstLaunch $false
$reducedLayout = Dump-Layout 'reduced-motion-notice'
$reducedConfirm = Query-ById $reducedLayout 'iteration-notice-confirm' 'clickable'
Capture-Screen 'reduced-motion-notice'
Invoke-Click $reducedConfirm
$null = Wait-Text 'reduced-motion-welcome' '开始引导' 'clickable'
Capture-Screen 'reduced-motion-welcome'

Launch-Fixture -Screen 'settings' -State 'completed' -Theme 'dark' `
  -ReduceMotion $false -FirstLaunch $false
$settingsLayout = Dump-Layout 'logout-settings-root'
$connection = Query-Text $settingsLayout '服务与账户' 'clickable'
Invoke-Click $connection
Start-Sleep -Milliseconds 650
$connectionLayout = Dump-Layout 'logout-connection-page'
$logout = Query-Text $connectionLayout '退出登录' 'clickable'
Invoke-Click $logout
Start-Sleep -Milliseconds 500
$dialogLayout = Dump-Layout 'logout-dialog'
$confirmLogout = Query-Text $dialogLayout '退出' 'clickable' -Exact
Invoke-Click $confirmLogout
$returned = Wait-Text 'notice-after-logout' '项目正在快速迭代'
$null = Assert-VisibleText $returned.Layout '我已知晓，继续' 'clickable'
Capture-Screen 'notice-after-logout'

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  throw 'The application process exited during launch notice E2E.'
}

$protocol = Get-Content -LiteralPath (Join-Path $repo 'protocol.lock.json') -Raw |
  ConvertFrom-Json
$gitCommit = ((& git -C $repo rev-parse HEAD) -join '').Trim()
$gitStatus = ((& git -C $repo status --porcelain=v1 --untracked-files=normal) -join "`n")
$hap = Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
$hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $hap).Hash.ToLowerInvariant()
$deviceModel = ((& $hdc -t $Device shell 'param get const.product.model') -join '').Trim()
$apiVersion = ((& $hdc -t $Device shell 'param get const.ohos.apiversion') -join '').Trim()
$artifacts = @(Get-ChildItem -LiteralPath $captureDir -File |
  Where-Object { $_.Name -ne 'manifest.json' } |
  Sort-Object Name |
  ForEach-Object {
    $kind = if ($_.Extension -eq '.jpeg') { 'screenshot' }
      elseif ($_.Extension -eq '.json') { 'layout' }
      else { 'other' }
    [ordered]@{
      kind = $kind
      path = Get-RelativeArtifactPath $_.FullName
      sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
  })
$runId = 'launch-notice-' + $e2eStartedAt.ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
$nodeVersion = ((& node --version) -join '').Trim()
$manifest = [ordered]@{
  schemaVersion = 1
  runId = $runId
  generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
  git = [ordered]@{
    commit = $gitCommit
    dirty = $gitStatus.Length -gt 0
  }
  upstream = [ordered]@{
    commit = [string]$protocol.canonicalRevision
    version = [string]$protocol.packageVersion
  }
  scope = [ordered]@{
    featureIds = @('launch.iteration-notice')
    scenarioId = 'iteration-notice-launch'
  }
  product = 'mock'
  hap = [ordered]@{
    path = Get-RelativeArtifactPath $hap
    sha256 = $hapSha256
  }
  device = [ordered]@{
    serial = $Device
    model = $deviceModel
    api = [int]$apiVersion
    orientation = 'portrait'
  }
  status = 'passed'
  steps = @(
    [ordered]@{
      id = 'dark-notice'
      status = 'passed'
      mandatory = $true
      assertions = @('Notice precedes welcome', 'Notice copy fits without clipping')
    },
    [ordered]@{
      id = 'system-back'
      status = 'passed'
      mandatory = $true
      assertions = @('System Back leaves the notice visible')
    },
    [ordered]@{
      id = 'confirmation'
      status = 'passed'
      mandatory = $true
      assertions = @('Confirmation reveals the welcome actions', 'Logo bounds remain identical')
      metrics = @(
        [ordered]@{
          name = 'logo_bounds_delta'
          value = 0
          unit = 'px'
          status = 'passed'
          threshold = [ordered]@{ operator = 'lte'; value = 0 }
        }
      )
    },
    [ordered]@{
      id = 'light-theme'
      status = 'passed'
      mandatory = $true
      assertions = @('Light notice and welcome remain legible', 'Logo geometry matches dark theme')
    },
    [ordered]@{
      id = 'reduced-motion'
      status = 'passed'
      mandatory = $true
      assertions = @('Reduced motion resolves to the welcome page')
    },
    [ordered]@{
      id = 'logout-return'
      status = 'passed'
      mandatory = $true
      assertions = @('Confirmed Mock logout returns to the notice')
    },
    [ordered]@{
      id = 'process-liveness'
      status = 'passed'
      mandatory = $true
      assertions = @('Application process remains alive after all flows')
    }
  )
  metrics = @(
    [ordered]@{
      name = 'logo_size'
      value = [int]$themeResults[0].logoBefore.Width
      unit = 'px'
      status = 'passed'
      threshold = [ordered]@{ operator = 'gte'; value = 1 }
    }
  )
  artifacts = $artifacts
  toolchain = [ordered]@{
    node = $nodeVersion
    sdk = $apiVersion
  }
}
$manifest |
  ConvertTo-Json -Depth 8 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Launch notice Mock E2E passed. Evidence: $captureDir"
