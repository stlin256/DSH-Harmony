param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$OutputDir = '',
  [ValidateRange(5, 120)]
  [int]$StartupTimeoutSeconds = 30,
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
if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; the fixture suite remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-mock'
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$scenarios = @(
  [pscustomobject]@{ Screen = 'conversation'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'live-change'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'live-change'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'attachments'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'attachments'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'streaming'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'streaming'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'stream-long'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'secret-masked'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'secret-masked'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'stream-repaired'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'stream-repaired'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'empty'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'empty'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'long-history'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'long-history'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-send-idle'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-send-idle'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-authoritative'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-authoritative'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-many'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-queue-many'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-send-error'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-quiet'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-quiet'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'light'; ReduceTransparency = $true },
  [pscustomobject]@{ Screen = 'conversation'; State = 'dock-material-elevated'; Theme = 'dark'; ReduceTransparency = $true },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-approval'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-approval'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-question'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'interaction-question'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-subagent'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-subagent'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-dock-overlay'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-dock-overlay'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'conversation'; State = 'plan-off-error'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'lineage'; State = 'plan-subagent'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'lineage'; State = 'plan-subagent'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-continuable'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-continuable'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-one-shot'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-one-shot'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-unknown'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-unknown'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-parent-offline'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'subagent'; State = 'subagent-parent-offline'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'process'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'process'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'sidebar'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'sidebar'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'browser'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'browser'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'preview'; State = 'document-preview'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'preview'; State = 'document-preview'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'preview'; State = 'text-config-preview'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'preview'; State = 'delimited-preview'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'preview'; State = 'tsv-preview'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'preview'; State = 'delimited-error-preview'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'preview'; State = 'binary-preview'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'settings'; State = 'completed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'settings'; State = 'completed'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'settings'; State = 'settings-search'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'settings'; State = 'settings-search'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-list'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-list'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-empty'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-error'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-detail'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-detail'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-restart'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'plugins'; State = 'plugins-install-failed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-list'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-list'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-empty'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-detail'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-detail'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-editor'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-history'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'automation'; State = 'automation-conflict'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'more'; State = 'more-actions'; Theme = 'light' },
  [pscustomobject]@{ Screen = 'more'; State = 'more-actions'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-task-plan'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-reasoning'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-read'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-search'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-terminal'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-diff'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-nested'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-malformed'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-empty'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-oversized'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-web'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-goal'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-job'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-web-fetch'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-job-lifecycle'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-read-image'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-command'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-subagent'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-present'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-image'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-question'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-plugin'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-plan'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-process-order'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-reasoning'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-legacy-tool'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-diff'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-background-notice'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'disclosure'; State = 'disclosure-queue'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'sidebar'; State = 'disclosure-sidebar-more'; Theme = 'dark' },
  [pscustomobject]@{ Screen = 'sidebar'; State = 'disclosure-sidebar-group'; Theme = 'dark' }
)

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$results = [System.Collections.Generic.List[object]]::new()
$firstRun = $true
$failedCount = 0

function Text-Hex {
  param([string]$Text)
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
}

function Get-ExpectedMarker {
  param([string]$Screen, [string]$State)
  switch ("$Screen/$State") {
    'conversation/completed' { return '发布检查完成' }
    'conversation/live-change' { return '底部 Dock 运行态' }
    'conversation/attachments' { return '附件与实时变更 Dock' }
    'conversation/streaming' { return '流式输出与标题更新' }
    'conversation/stream-long' { return '长流持续输出' }
    'conversation/secret-masked' { return '凭据已遮蔽' }
    'conversation/stream-repaired' { return '流式 Markdown' }
    'conversation/empty' { return '空运行态' }
    'conversation/long-history' { return '长会话与连续预取' }
    'conversation/dock-send-idle' { return 'Dock 空闲与发送' }
    'conversation/dock-queue-authoritative' { return '权威排队消息' }
    'conversation/dock-queue-many' { return '多行排队消息' }
    'conversation/dock-send-error' { return '发送失败与重试' }
    'conversation/dock-material-quiet' { return 'Dock 空闲与发送' }
    'conversation/dock-material-elevated' { return '渐变材质与实时变更' }
    'conversation/interaction-approval' { return '等待审批' }
    'conversation/interaction-question' { return '问题卡样式检查' }
    'conversation/plan-subagent' { return '计划与子智能体' }
    'conversation/plan-dock-overlay' { return '悬浮任务计划' }
    'conversation/plan-off-error' { return '计划退出失败' }
    'lineage/plan-subagent' { return '4 个子智能体' }
    'subagent/subagent-continuable' { return '可继续子会话' }
    'subagent/subagent-one-shot' { return '一次性子会话' }
    'subagent/subagent-unknown' { return '未知模式子会话' }
    'subagent/subagent-parent-offline' { return '父会话不可用' }
    'process/completed' { return '更新了计划' }
    'sidebar/completed' { return '置顶' }
    'browser/completed' { return '工作区根目录' }
    'preview/document-preview' { return 'diagram.svg' }
    'preview/text-config-preview' { return 'app.conf' }
    'preview/delimited-preview' { return 'users.csv' }
    'preview/tsv-preview' { return 'report.tsv' }
    'preview/delimited-error-preview' { return 'malformed.csv' }
    'preview/binary-preview' { return 'archive.zip' }
    'settings/completed' { return '外观与动效' }
    'settings/settings-search' { return '搜索设置' }
    'plugins/plugins-list' { return 'Workspace Tools' }
    'plugins/plugins-empty' { return '还没有可显示的插件' }
    'plugins/plugins-error' { return '插件服务暂不可用' }
    'plugins/plugins-detail' { return '包名' }
    'plugins/plugins-restart' { return 'DSH 重启后生效' }
    'plugins/plugins-install-failed' { return '无法读取插件包' }
    'automation/automation-list' { return '每日检查构建状态' }
    'automation/automation-empty' { return '还没有自动化任务' }
    'automation/automation-detail' { return '任务指令' }
    'automation/automation-editor' { return '编辑任务' }
    'automation/automation-history' { return '投递记录' }
    'automation/automation-conflict' { return '任务已在其他设备更新' }
    'more/more-actions' { return '文件浏览' }
    'disclosure/disclosure-task-plan' { return 'disclosure-task-plan' }
    'disclosure/disclosure-process-reasoning' { return 'disclosure-process-reasoning' }
    'disclosure/disclosure-process-read' { return 'disclosure-process-read' }
    'disclosure/disclosure-process-search' { return 'disclosure-process-search' }
    'disclosure/disclosure-process-terminal' { return 'disclosure-process-terminal' }
    'disclosure/disclosure-process-diff' { return 'disclosure-process-diff' }
    'disclosure/disclosure-process-nested' { return 'disclosure-process-nested' }
    'disclosure/disclosure-process-malformed' { return 'disclosure-process-malformed' }
    'disclosure/disclosure-process-empty' { return 'disclosure-process-empty' }
    'disclosure/disclosure-process-oversized' { return 'disclosure-process-oversized' }
    'disclosure/disclosure-process-web' { return 'disclosure-process-web' }
    'disclosure/disclosure-process-goal' { return 'disclosure-process-goal' }
    'disclosure/disclosure-process-job' { return 'disclosure-process-job' }
    'disclosure/disclosure-process-web-fetch' { return 'disclosure-process-web-fetch' }
    'disclosure/disclosure-process-job-lifecycle' { return 'disclosure-process-job-lifecycle' }
    'disclosure/disclosure-process-read-image' { return 'disclosure-process-read-image' }
    'disclosure/disclosure-process-command' { return 'disclosure-process-command' }
    'disclosure/disclosure-process-subagent' { return 'disclosure-process-subagent' }
    'disclosure/disclosure-process-present' { return 'disclosure-process-present' }
    'disclosure/disclosure-process-image' { return 'disclosure-process-image' }
    'disclosure/disclosure-process-question' { return 'disclosure-process-question' }
    'disclosure/disclosure-process-plugin' { return 'disclosure-process-plugin' }
    'disclosure/disclosure-process-plan' { return 'disclosure-process-plan' }
    'disclosure/disclosure-process-order' { return 'disclosure-process-order' }
    'disclosure/disclosure-reasoning' { return 'disclosure-reasoning' }
    'disclosure/disclosure-legacy-tool' { return 'disclosure-legacy-tool' }
    'disclosure/disclosure-diff' { return 'disclosure-diff' }
    'disclosure/disclosure-background-notice' { return 'disclosure-background-notice' }
    'disclosure/disclosure-queue' { return 'disclosure-queue' }
    'sidebar/disclosure-sidebar-more' { return '更多' }
    'sidebar/disclosure-sidebar-group' { return 'DSH Harmony 移动端' }
    default { return '' }
  }
}

function Assert-LayoutMarker {
  param(
    [string]$LayoutPath,
    [string]$Marker,
    [bool]$MustExist = $true
  )
  if (-not $Marker -or -not (Test-Path -LiteralPath $LayoutPath)) { return }
  $output = & python $queryScript $LayoutPath `
    --find-text-hex (Text-Hex $Marker) `
    --target text 2>&1
  $found = $LASTEXITCODE -eq 0
  if ($found -ne $MustExist) {
    $mode = if ($MustExist) { 'missing' } else { 'unexpected' }
    throw "Fixture marker $mode '$Marker': $($output -join [Environment]::NewLine)"
  }
}

foreach ($scenario in $scenarios) {
  $startedAt = Get-Date
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Screen = $scenario.Screen
    State = $scenario.State
    Theme = $scenario.Theme
    OutputDir = $OutputDir
    StartupTimeoutSeconds = $StartupTimeoutSeconds
  }
  if ($Device) {
    $arguments.Device = $Device
  }
  if ($scenario.PSObject.Properties.Name -contains 'ReduceTransparency' -and
      $scenario.ReduceTransparency) {
    $arguments.ReduceTransparency = $true
  }

  # Build and install once. Reinstalling between graphical scenarios only
  # introduces unrelated process-termination noise.
  if ($SkipBuild -or -not $firstRun) {
    $arguments.SkipBuild = $true
  }
  if ($SkipInstall -or -not $firstRun) {
    $arguments.SkipInstall = $true
  }

  $message = ''
  try {
    & $mockScript @arguments | Out-Host
    $captureDir = Join-Path $OutputDir "$($scenario.State)-$($scenario.Theme)-$($scenario.Screen)"
    if ($scenario.PSObject.Properties.Name -contains 'ReduceTransparency' -and
        $scenario.ReduceTransparency) {
      $captureDir += '-reduced-transparency'
    }
    if ($scenario.PSObject.Properties.Name -contains 'ReduceMotion' -and
        $scenario.ReduceMotion) {
      $captureDir += '-reduced-motion'
    }
    Assert-LayoutMarker `
      -LayoutPath (Join-Path $captureDir 'layout.json') `
      -Marker (Get-ExpectedMarker -Screen $scenario.Screen -State $scenario.State)
    if ($scenario.Screen -in @('plugins', 'automation')) {
      Assert-LayoutMarker `
        -LayoutPath (Join-Path $captureDir 'layout.json') `
        -Marker 'Invalid URL format or missing URL' `
        -MustExist $false
    }
    $result = 'Passed'
  } catch {
    $result = 'Failed'
    $message = $_.Exception.Message
    $failedCount++
  }

  $results.Add([pscustomobject]@{
    screen = $scenario.Screen
    state = $scenario.State
    theme = $scenario.Theme
    result = $result
    durationSeconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
    message = $message
  })
  $firstRun = $false
}

$summary = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  bundleName = 'io.github.stlin256.dshharmony'
  product = 'mock'
  hap = [ordered]@{
    path = 'harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap'
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (
      Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap'
    )).Hash.ToLowerInvariant()
  }
  scenarios = $results
}
$summaryPath = Join-Path $OutputDir 'suite-summary.json'
$summary |
  ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath $summaryPath -Encoding utf8

$contactSheet = Join-Path $OutputDir 'dock-material-contact-sheet.png'
& python (Join-Path $PSScriptRoot 'compose-dock-contact-sheet.py') `
  --root $OutputDir `
  --out $contactSheet
if ($LASTEXITCODE -ne 0) {
  throw "Dock material contact sheet failed: $LASTEXITCODE"
}

$materialAssert = Join-Path $PSScriptRoot 'device-ui-material-assert.py'
foreach ($theme in @('light', 'dark')) {
  $captureDir = Join-Path $OutputDir "dock-material-elevated-$theme-conversation"
  & python $materialAssert `
    (Join-Path $captureDir 'layout.json') `
    (Join-Path $captureDir 'screen.jpeg') `
    --theme $theme `
    --json-out (Join-Path $OutputDir "dock-material-$theme-assert.json")
  if ($LASTEXITCODE -ne 0) {
    throw "Dock material pixel assertion failed for $theme."
  }
}

$results | Format-Table -AutoSize | Out-Host
if ($failedCount -gt 0) {
  throw "$failedCount fixture scenarios failed. See $summaryPath"
}
Write-Output "All $($results.Count) fixture scenarios passed. Evidence: $summaryPath"
