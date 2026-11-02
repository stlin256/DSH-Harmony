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
  $OutputDir = Join-Path $repo 'artifacts\device-ui-settings-e2e'
}
$captureDir = Join-Path $OutputDir 'appearance-persistence'
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

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$mockArguments = @{
  DevEcoHome = $DevEcoHome
  Device = $Device
  Screen = 'settings'
  State = 'completed'
  Theme = 'dark'
  OutputDir = $OutputDir
}
if ($SkipBuild) {
  $mockArguments.SkipBuild = $true
}
if ($SkipInstall) {
  $mockArguments.SkipInstall = $true
}
& $mockScript @mockArguments | Out-Host

$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$appearanceText = 'E5A496E8A782E4B88EE58AA8E69588'
$reduceMotionText = 'E5878FE5B091E58AA8E68081E69588E69E9C'
$reduceTransparencyText = 'E5878FE5B091E9808FE6988EE69588E69E9C'

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-settings-$Name.json"
  $local = Join-Path $captureDir "$Name.json"
  & $hdc -t $Device shell "uitest dumpLayout -p $remote -i -b io.github.stlin256.dshharmony" | Out-Null
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
  $remote = "/data/local/tmp/dsh-settings-$Name.jpeg"
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

function Query-Node {
  param(
    [string]$Layout,
    [string]$TextHex,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'clickable',
    [string]$ExpectChecked = '',
    [string]$ContainerTextHex = '',
    [string]$ExpectBackground = ''
  )
  $arguments = @(
    $queryScript,
    $Layout,
    '--find-text-hex',
    $TextHex,
    '--target',
    $Target
  )
  if ($ExpectChecked) {
    $arguments += @('--expect-checked', $ExpectChecked)
  }
  if ($ContainerTextHex) {
    $arguments += @('--container-text-hex', $ContainerTextHex)
  }
  if ($ExpectBackground) {
    $arguments += @('--expect-background', $ExpectBackground)
  }
  $raw = & python @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout query failed: $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Invoke-Click {
  param([object]$Node)
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Input click failed at $($Node.x),$($Node.y)"
  }
  Start-Sleep -Milliseconds 750
}

function Text-Hex {
  param([string]$Text)
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
}

function Parse-Bounds {
  param([string]$Value)
  if ($Value -notmatch '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$') {
    throw "Invalid layout bounds: $Value"
  }
  $left = [int]$Matches[1]
  $top = [int]$Matches[2]
  $right = [int]$Matches[3]
  $bottom = [int]$Matches[4]
  return [pscustomobject]@{
    left = $left
    top = $top
    right = $right
    bottom = $bottom
    width = $right - $left
    height = $bottom - $top
  }
}

$settingsRoot = Dump-Layout 'settings-root'
$appearance = Query-Node $settingsRoot $appearanceText
Invoke-Click $appearance
$appearanceBefore = Dump-Layout 'appearance-before'
Capture-Screen 'appearance-before'

# Switch to light and back to dark to verify the theme controls update state
# without leaving the page.
$lightChoice = Query-Node $appearanceBefore (Text-Hex '浅色') 'clickable'
Invoke-Click $lightChoice
$lightAppearance = Dump-Layout 'appearance-light'
$null = Query-Node `
  $lightAppearance `
  (Text-Hex '浅色') `
  'clickable' `
  '' `
  '' `
  '#FFEEF3FF'
Capture-Screen 'appearance-light'
$darkChoice = Query-Node $lightAppearance (Text-Hex '深色') 'clickable'
Invoke-Click $darkChoice
$appearanceBefore = Dump-Layout 'appearance-dark-restored'
$null = Query-Node `
  $appearanceBefore `
  (Text-Hex '深色') `
  'clickable' `
  '' `
  '' `
  '#FF30343B'

# Exercise the full row hit target.
$motionRow = Query-Node $appearanceBefore $reduceMotionText 'clickable' 'false'
Invoke-Click $motionRow
$motionAfter = Dump-Layout 'motion-on'
$null = Query-Node $motionAfter $reduceMotionText 'clickable' 'true'

# Exercise the switch control itself directly.
$transparencySwitch = Query-Node $motionAfter $reduceTransparencyText 'checkable' 'false'
Invoke-Click $transparencySwitch
$bothAfter = Dump-Layout 'both-on'
$null = Query-Node $bothAfter $reduceMotionText 'clickable' 'true'
$null = Query-Node $bothAfter $reduceTransparencyText 'checkable' 'true'
Capture-Screen 'both-on'

& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 750
$settingsReturned = Dump-Layout 'settings-returned'
$appearanceReturned = Query-Node $settingsReturned $appearanceText
Invoke-Click $appearanceReturned
$appearanceReopened = Dump-Layout 'appearance-reopened'
$null = Query-Node $appearanceReopened $reduceMotionText 'clickable' 'true'
$null = Query-Node $appearanceReopened $reduceTransparencyText 'checkable' 'true'
Capture-Screen 'appearance-reopened'

& $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
Start-Sleep -Milliseconds 750

$pageResults = [System.Collections.Generic.List[object]]::new()
$selectorSpacingResults = [System.Collections.Generic.List[object]]::new()
$notificationLevelBounds = [System.Collections.Generic.List[object]]::new()
$pages = @(
  [pscustomobject]@{ Name = 'dsh'; Label = 'DSH 设置'; Expected = '插件版本' },
  [pscustomobject]@{ Name = 'notifications'; Label = '通知'; Expected = '通知级别' },
  [pscustomobject]@{ Name = 'cards'; Label = '桌面卡片'; Expected = '显示任务名称' },
  [pscustomobject]@{ Name = 'storage'; Label = '存储管理'; Expected = '缓存池' },
  [pscustomobject]@{ Name = 'connection'; Label = '服务与账户'; Expected = '当前服务' },
  [pscustomobject]@{ Name = 'about'; Label = '关于'; Expected = '关于' }
)
foreach ($page in $pages) {
  $root = Dump-Layout "root-before-$($page.Name)"
  $row = Query-Node $root (Text-Hex $page.Label) 'clickable'
  Invoke-Click $row
  $detail = Dump-Layout "$($page.Name)-page"
  $null = Query-Node $detail (Text-Hex $page.Expected) 'text'
  if ($page.Name -eq 'dsh') {
    $null = Query-Node $detail (Text-Hex 'v0.3.7') 'text'
    $selectorValues = @('详细', '完成时', '全部回复', '排队')
    $selectorBounds = @()
    foreach ($value in $selectorValues) {
      $selector = Query-Node $detail (Text-Hex $value) 'clickable'
      $selectorBounds += [pscustomobject]@{
        value = $value
        bounds = $selector.bounds
        geometry = Parse-Bounds $selector.bounds
      }
    }
    $selectorBounds = @($selectorBounds | Sort-Object { $_.geometry.top })
    for ($index = 1; $index -lt $selectorBounds.Count; $index++) {
      $previous = $selectorBounds[$index - 1]
      $current = $selectorBounds[$index]
      $gap = $current.geometry.top - $previous.geometry.bottom
      $minimumGap = [Math]::Max(1, [int]($previous.geometry.height * 0.6))
      if ($gap -lt $minimumGap) {
        throw (
          "DSH selector rows are too close: {0} to {1} gap {2}px, expected at least {3}px" -f
          $previous.value, $current.value, $gap, $minimumGap
        )
      }
      $selectorSpacingResults.Add([pscustomobject]@{
        from = $previous.value
        to = $current.value
        fromBounds = $previous.bounds
        toBounds = $current.bounds
        gapPx = $gap
        minimumGapPx = $minimumGap
      })
    }
    Capture-Screen 'dsh-page'
  }
  $interaction = 'opened-and-returned'
  if ($page.Name -eq 'notifications') {
    foreach ($value in @('关闭', '静默', '标准', '醒目')) {
      $choice = Query-Node `
        $detail `
        (Text-Hex $value) `
        'clickable' `
        '' `
        (Text-Hex '任务完成')
      $notificationLevelBounds.Add([pscustomobject]@{
        value = $value
        bounds = $choice.bounds
        geometry = Parse-Bounds $choice.bounds
      })
    }
    $referenceChoice = $notificationLevelBounds[0].geometry
    foreach ($choice in $notificationLevelBounds) {
      if ([Math]::Abs($choice.geometry.height - $referenceChoice.height) -gt 1 -or
          [Math]::Abs($choice.geometry.width - $referenceChoice.width) -gt 1) {
        throw "Notification level controls do not share one compact geometry: $($choice.value)"
      }
    }
    $prominent = Query-Node `
      $detail `
      (Text-Hex '醒目') `
      'clickable' `
      '' `
      (Text-Hex '任务完成') `
      '#FF313236'
    Invoke-Click $prominent
    $detail = Dump-Layout 'notifications-level-changed'
    $null = Query-Node `
      $detail `
      (Text-Hex '醒目') `
      'clickable' `
      '' `
      (Text-Hex '任务完成') `
      '#FF679EFE'
    $monitorSwitch = Query-Node $detail (Text-Hex '后台任务监控') 'checkable' 'false'
    Invoke-Click $monitorSwitch
    $detail = Dump-Layout 'notifications-monitor-on'
    $null = Query-Node $detail (Text-Hex '后台任务监控') 'checkable' 'true'
    $interaction = 'level-and-monitor-updated'
  }
  if ($page.Name -eq 'cards') {
    $cardSwitch = Query-Node $detail (Text-Hex '显示任务名称') 'checkable' 'true'
    Invoke-Click $cardSwitch
    $detail = Dump-Layout 'cards-toggle-off'
    $null = Query-Node $detail (Text-Hex '显示任务名称') 'checkable' 'false'
    $interaction = 'task-name-toggle-updated'
  }
  Capture-Screen "$($page.Name)-page"
  $pageResults.Add([pscustomobject]@{
    page = $page.Name
    result = 'Passed'
    expected = $page.Expected
    interaction = $interaction
  })
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 750
  $returned = Dump-Layout "root-after-$($page.Name)"
  $null = Query-Node $returned (Text-Hex $page.Label) 'clickable'
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  result = 'Passed'
  checked = [ordered]@{
    rowTapToggledReduceMotion = $true
    switchTapToggledReduceTransparency = $true
    stateSurvivedSettingsBackAndReopen = $true
    pluginVersionVisible = $true
    dshSelectorRowsHaveVerticalGaps = ($selectorSpacingResults.Count -eq 3)
    notificationLevelControlsShareCompactGeometry = ($notificationLevelBounds.Count -eq 4)
    themeSwitchedToLightAndBack = $true
    notificationLevelAndMonitorUpdated = $true
    cardTaskNameToggleUpdated = $true
  }
  dshSelectorSpacing = $selectorSpacingResults
  notificationLevelBounds = $notificationLevelBounds
  settingsPages = $pageResults
  captures = @(
    'appearance-before.jpeg',
    'appearance-light.jpeg',
    'both-on.jpeg',
    'appearance-reopened.jpeg',
    'dsh-page.jpeg'
  )
}
$manifest |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

Write-Output "Settings appearance E2E passed. Evidence: $captureDir"
