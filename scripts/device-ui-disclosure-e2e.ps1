param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$OutputDir = '',
  [ValidateSet('light', 'dark', 'system')]
  [string]$Theme = 'dark',
  [switch]$ReduceMotion,
  [switch]$ReduceTransparency,
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
  $OutputDir = Join-Path $repo 'artifacts\device-e2e'
}
$captureDir = Join-Path $OutputDir 'disclosure-expansion-matrix'
$fixtureDir = Join-Path $OutputDir 'disclosure-expansion-fixtures'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null
New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
Get-ChildItem -LiteralPath $captureDir -File | Remove-Item -Force

if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; disclosure expansion E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$mockScript = Join-Path $PSScriptRoot 'device-ui-mock.ps1'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'
$bundle = 'io.github.stlin256.dshharmony'
$firstLaunch = $true

function Text-Hex {
  param([string]$Text)
  return [Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes($Text))
}

function Launch-Fixture {
  param(
    [string]$State
  )
  $screen = if ($State.startsWith('disclosure-sidebar-')) { 'sidebar' } else { 'disclosure' }
  $arguments = @{
    DevEcoHome = $DevEcoHome
    Device = $Device
    Screen = $screen
    State = $State
    Theme = $script:Theme
    OutputDir = $fixtureDir
  }
  if ($script:ReduceMotion) { $arguments.ReduceMotion = $true }
  if ($script:ReduceTransparency) { $arguments.ReduceTransparency = $true }
  if ($SkipBuild -or -not $firstLaunch) {
    $arguments.SkipBuild = $true
  }
  if ($SkipInstall -or -not $firstLaunch) {
    $arguments.SkipInstall = $true
  }
  & $mockScript @arguments | Out-Host
  $script:firstLaunch = $false
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-disclosure-$Name.json"
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
  $remote = "/data/local/tmp/dsh-disclosure-$Name.jpeg"
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
    [string]$Text,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'clickable',
    [int]$ExpectCount = 1,
    [bool]$ExactText = $true,
    [int]$MinimumY = -1,
    [int]$MaximumY = -1
  )
  $arguments = @(
    $Layout,
    '--find-text-hex',
    (Text-Hex $Text),
    '--target',
    $Target
  )
  if ($ExactText) {
    $arguments += '--exact-text'
  }
  if ($ExpectCount -ge 0) {
    $arguments += @('--expect-count', $ExpectCount)
  }
  if ($MinimumY -ge 0) {
    $arguments += @('--minimum-y', $MinimumY)
  }
  if ($MaximumY -ge 0) {
    $arguments += @('--maximum-y', $MaximumY)
  }
  $raw = & python $queryScript @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout query failed for '$Text': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Query-Node-ById {
  param(
    [string]$Layout,
    [string]$Id,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'text',
    [int]$ExpectCount = 1
  )
  $raw = & python $queryScript $Layout --find-id $Id --target $Target `
    --expect-count $ExpectCount 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout id query failed for '$Id': $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Wait-Query-Node {
  param(
    [string]$Name,
    [string]$Text,
    [ValidateSet('text', 'clickable', 'checkable')]
    [string]$Target = 'clickable',
    [int]$ExpectCount = 1,
    [bool]$ExactText = $true,
    [int]$MinimumY = -1,
    [int]$MaximumY = -1,
    [int]$TimeoutMilliseconds = 6000
  )
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
  $lastError = ''
  $attempt = 0
  do {
    $attempt++
    try {
      $layout = Dump-Layout "$Name-$attempt"
      return (Query-Node $layout $Text $Target $ExpectCount $ExactText $MinimumY $MaximumY)
    } catch {
      $lastError = $_.Exception.Message
      Start-Sleep -Milliseconds 250
    }
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "Layout wait failed for '$Text' after $TimeoutMilliseconds ms: $lastError"
}

function Assert-Ordered-Texts {
  param(
    [string]$State,
    [string]$Phase,
    [string[]]$Texts
  )
  $layout = Dump-Layout "$State-$Phase-ordered"
  $bounds = @()
  foreach ($text in $Texts) {
    $node = Query-Node $layout $text 'text' 1 $true
    $bounds += [pscustomobject]@{
      text = $text
      x = $node.x
      y = $node.y
      bounds = $node.bounds
    }
  }
  for ($index = 1; $index -lt $bounds.Count; $index++) {
    if ($bounds[$index - 1].y -ge $bounds[$index].y) {
      throw (
        "Visible process order failed during ${Phase}: {0} must be above {1}" -f
        $bounds[$index - 1].text, $bounds[$index].text
      )
    }
  }
  return $bounds
}

function Invoke-Click {
  param(
    [object]$Node,
    [int]$SettleMilliseconds = 650
  )
  if ($null -eq $Node.x -or $null -eq $Node.y) {
    throw "Cannot click a node without bounds: $($Node.text)"
  }
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Input click failed at $($Node.x),$($Node.y)"
  }
  Start-Sleep -Milliseconds $SettleMilliseconds
}

function Invoke-Control {
  param(
    [string]$State,
    [string]$Text,
    [string]$Target = 'clickable',
    [int]$MinimumY = -1
  )
  $node = Wait-Query-Node "$State-control" $Text $Target -1 $true $MinimumY
  Invoke-Click $node
}

function Invoke-Fixture-Action {
  param(
    [string]$State,
    [object]$Action
  )
  if ($Action -is [string]) {
    Invoke-Control $State $Action
    return
  }
  $target = if ($Action.PSObject.Properties.Name -contains 'Target') {
    [string]$Action.Target
  } else {
    'clickable'
  }
  $minimumY = if ($Action.PSObject.Properties.Name -contains 'MinimumY') {
    [int]$Action.MinimumY
  } else {
    -1
  }
  Invoke-Control $State ([string]$Action.Text) $target $minimumY
}

function Query-Rightmost-Near {
  param(
    [string]$Layout,
    [int]$AnchorX,
    [int]$AnchorY,
    [int]$Radius = 70
  )
  $raw = & python $queryScript $Layout `
    --rightmost-clickable-near $AnchorX $AnchorY $Radius 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Rightmost action query failed: $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Invoke-Diff-Control {
  param(
    [string]$State,
    [string]$Path
  )
  $layout = Dump-Layout "$State-diff-control"
  $normalized = $Path.Replace('\', '/')
  $fileName = ($normalized -split '/')[-1]
  $anchor = Query-Node $layout $fileName 'text' -1 $true
  $button = Query-Rightmost-Near $layout ([int]$anchor.x) ([int]$anchor.y) 70
  Invoke-Click $button
}

$scenarios = @(
  [pscustomobject]@{
    State = 'disclosure-task-plan'
    Actions = @(
      [pscustomobject]@{ Text = '任务计划'; MinimumY = 500 }
    )
    Expanded = '验证队列展开'
    Collapse = [pscustomobject]@{ Text = '任务计划'; MinimumY = 500 }
    Reopen = [pscustomobject]@{ Text = '任务计划'; MinimumY = 500 }
  },
  [pscustomobject]@{
    State = 'disclosure-process-reasoning'
    Actions = @('工作过程', '思考过程')
    Expanded = '推理正文只在展开后显示。'
    Collapse = '思考过程'
    Reopen = '思考过程'
    ProcessCollapse = $true
  },
  [pscustomobject]@{
    State = 'disclosure-process-order'
    Actions = @('工作过程')
    Expanded = 'first-order-detail'
    OrderedTexts = @('first-order-detail', 'NativeTaskDock.ets', 'second-order-detail')
    Collapse = '工作过程'
    Reopen = '工作过程'
  },
  [pscustomobject]@{
    State = 'disclosure-process-read'
    Actions = @('工作过程', '已读取文件')
    Expanded = 'const disclosureValue = 42;'
    Collapse = '已读取文件'
    Reopen = '已读取文件'
    ProcessCollapse = $true
  },
  [pscustomobject]@{
    State = 'disclosure-process-search'
    Actions = @('工作过程', '已搜索代码')
    Expanded = 'process-order-stable'
    Collapse = '已搜索代码'
    Reopen = '已搜索代码'
  },
  [pscustomobject]@{
    State = 'disclosure-process-terminal'
    Actions = @('工作过程', '执行了命令')
    Expanded = 'hvigorw assembleHap'
    Collapse = '执行了命令'
    Reopen = '执行了命令'
  },
  [pscustomobject]@{
    State = 'disclosure-process-diff'
    Actions = @('工作过程', '修改了文件')
    Expanded = 'const disclosureMiddleVisibleOnlyExpanded = 13;'
    DiffControl = $true
    DiffPath = 'harmony/entry/src/main/ets/components/NativeProcessStepView.ets'
  },
  [pscustomobject]@{
    State = 'disclosure-process-nested'
    Actions = @('工作过程', '执行了命令', '已读取文件')
    Expanded = 'const nestedDisclosureVisibleOnlyExpanded = true;'
    Collapse = '已读取文件'
    Reopen = '已读取文件'
  },
  [pscustomobject]@{
    State = 'disclosure-process-malformed'
    Actions = @('工作过程', '已读取文件')
    Expanded = 'malformed-structured-output-only'
    Collapse = '已读取文件'
    Reopen = '已读取文件'
  },
  [pscustomobject]@{
    State = 'disclosure-process-empty'
    Actions = @('工作过程', '已读取文件')
    Expanded = '工具没有返回内容'
    Collapse = '已读取文件'
    Reopen = '已读取文件'
  },
  [pscustomobject]@{
    State = 'disclosure-process-oversized'
    Actions = @('工作过程', '已调用工具')
    Expanded = '内容已截断'
    Collapse = '已调用工具'
    Reopen = '已调用工具'
  },
  [pscustomobject]@{
    State = 'disclosure-process-web'
    Actions = @('工作过程', '已搜索网页')
    Expanded = 'DSH Harmony 设计基线'
    Collapse = '已搜索网页'
    Reopen = '已搜索网页'
  },
  [pscustomobject]@{
    State = 'disclosure-process-web-fetch'
    Actions = @('工作过程', '已抓取网页')
    Expanded = 'web-fetch-body-only'
    Collapse = '已抓取网页'
    Reopen = '已抓取网页'
  },
  [pscustomobject]@{
    State = 'disclosure-process-goal'
    Actions = @('工作过程', '更新了计划')
    Expanded = '验证中'
    Collapse = '更新了计划'
    Reopen = '更新了计划'
  },
  [pscustomobject]@{
    State = 'disclosure-process-job'
    Actions = @('工作过程', '后台任务已结束')
    Expanded = 'hvigorw assembleHap'
    Collapse = '后台任务已结束'
    Reopen = '后台任务已结束'
  },
  [pscustomobject]@{
    State = 'disclosure-process-job-lifecycle'
    Actions = @('工作过程', '后台任务状态')
    Expanded = 'job-lifecycle-detail-only'
    Collapse = '后台任务状态'
    Reopen = '后台任务状态'
  },
  [pscustomobject]@{
    State = 'disclosure-process-read-image'
    Actions = @('工作过程', '已读取图片')
    Expanded = '1280 × 720'
    Collapse = '已读取图片'
    Reopen = '已读取图片'
  },
  [pscustomobject]@{
    State = 'disclosure-process-command'
    Actions = @('工作过程', '执行了命令')
    Expanded = 'slash-command-result-only'
    Collapse = '执行了命令'
    Reopen = '执行了命令'
  },
  [pscustomobject]@{
    State = 'disclosure-process-subagent'
    Actions = @('工作过程', '已协调子代理')
    Expanded = 'child-42'
    Collapse = '已协调子代理'
    Reopen = '已协调子代理'
  },
  [pscustomobject]@{
    State = 'disclosure-process-present'
    Actions = @('工作过程', '已调用工具')
    Expanded = '可交互文件卡与紧凑展开头'
    Collapse = '已调用工具'
    Reopen = '已调用工具'
  },
  [pscustomobject]@{
    State = 'disclosure-process-image'
    Actions = @('工作过程', '已调用工具')
    Expanded = '640 × 480'
    Collapse = '已调用工具'
    Reopen = '已调用工具'
  },
  [pscustomobject]@{
    State = 'disclosure-process-question'
    Actions = @('工作过程', '向用户提出了问题')
    Expanded = '始终保留'
    Collapse = '向用户提出了问题'
    Reopen = '向用户提出了问题'
  },
  [pscustomobject]@{
    State = 'disclosure-process-plugin'
    Actions = @('工作过程', '已调用工具')
    Expanded = '插件结果已渲染'
    Collapse = '已调用工具'
    Reopen = '已调用工具'
  },
  [pscustomobject]@{
    State = 'disclosure-process-plan'
    Actions = @('工作过程', '更新了计划')
    Expanded = '检查计划工具正文'
    Collapse = '更新了计划'
    Reopen = '更新了计划'
  },
  [pscustomobject]@{
    State = 'disclosure-reasoning'
    Actions = @('思考过程')
    Expanded = '第一行说明摘要。' + [char]10 + 'direct-reasoning-body-only'
    Collapse = '思考过程'
    Reopen = '思考过程'
  },
  [pscustomobject]@{
    State = 'disclosure-legacy-tool'
    Actions = @('执行了命令')
    Expanded = 'legacy-tool-output-only'
    Collapse = '执行了命令'
    Reopen = '执行了命令'
  },
  [pscustomobject]@{
    State = 'disclosure-diff'
    Actions = @()
    Expanded = 'const disclosureMiddleVisibleOnlyExpanded = 13;'
    DiffControl = $true
    DiffPath = 'harmony/entry/src/main/ets/components/NativeProcessStepView.ets'
  },
  [pscustomobject]@{
    State = 'disclosure-background-notice'
    Actions = @('后台任务')
    Expanded = '后台任务仍在运行。' + [char]10 + 'background-notice-body-only' +
      [char]10 + '构建完成后会保留此记录。'
    Collapse = '后台任务'
    Reopen = '后台任务'
  },
  [pscustomobject]@{
    State = 'disclosure-queue'
    Actions = @('3 条排队消息')
    Expanded = 'queue-expanded-row-one'
    Collapse = '3 条排队消息'
    Reopen = '3 条排队消息'
  }
)

$results = [System.Collections.Generic.List[object]]::new()
$orderedTextSequences = [System.Collections.Generic.List[object]]::new()
$orderedScenarioCount = @($scenarios | Where-Object {
  $_.PSObject.Properties.Name -contains 'OrderedTexts'
}).Count
$failedCount = 0

foreach ($scenario in $scenarios) {
  $startedAt = Get-Date
  $result = 'Passed'
  $message = ''
  try {
    Launch-Fixture -State $scenario.State
    $collapsed = Dump-Layout "$($scenario.State)-collapsed"
    $null = Query-Node $collapsed $scenario.State 'text' 1 $false
    $assertHidden = -not ($scenario.PSObject.Properties.Name -contains 'AssertHidden') -or
      $scenario.AssertHidden
    if ($assertHidden) {
      $null = Query-Node $collapsed $scenario.Expanded 'text' 0 $false
    }
    Capture-Screen "$($scenario.State)-collapsed"

    foreach ($action in $scenario.Actions) {
      Invoke-Fixture-Action $scenario.State $action
    }
    if ($scenario.PSObject.Properties.Name -contains 'OrderedTexts') {
      $orderedBounds = Assert-Ordered-Texts $scenario.State 'expanded' $scenario.OrderedTexts
      $orderedTextSequences.Add([pscustomobject]@{
        state = $scenario.State
        phase = 'expanded'
        texts = $orderedBounds
      })
    }
    if ($scenario.PSObject.Properties.Name -contains 'DiffControl' -and
        $scenario.DiffControl) {
      Invoke-Diff-Control $scenario.State $scenario.DiffPath
    }
    $null = Wait-Query-Node "$($scenario.State)-expanded" $scenario.Expanded 'text' 1 $false
    if ($scenario.State -eq 'disclosure-process-read') {
      $expandedLayout = Dump-Layout "$($scenario.State)-expanded-layout"
      $viewer = Query-Node-ById $expandedLayout 'document-code-viewer' 'text' 1
      $boundsMatch = [regex]::Match([string]$viewer.bounds,
        '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
      if (-not $boundsMatch.Success) {
        throw "Cannot read compact read-viewer bounds: $($viewer.bounds)"
      }
      $viewerHeight = [int]$boundsMatch.Groups[4].Value -
        [int]$boundsMatch.Groups[2].Value
      if ($viewerHeight -gt 140) {
        throw "Single-line read viewer is too tall: ${viewerHeight}px"
      }
    }
    Capture-Screen "$($scenario.State)-expanded"

    if ($scenario.PSObject.Properties.Name -contains 'DiffControl' -and
        $scenario.DiffControl) {
      Invoke-Diff-Control $scenario.State $scenario.DiffPath
    } else {
      Invoke-Fixture-Action $scenario.State $scenario.Collapse
    }
    $null = Wait-Query-Node "$($scenario.State)-collapsed-again" $scenario.Expanded 'text' 0 $false
    Capture-Screen "$($scenario.State)-collapsed-again"

    if ($scenario.PSObject.Properties.Name -contains 'DiffControl' -and
        $scenario.DiffControl) {
      Invoke-Diff-Control $scenario.State $scenario.DiffPath
    } else {
      Invoke-Fixture-Action $scenario.State $scenario.Reopen
    }
    $null = Wait-Query-Node "$($scenario.State)-reopened" $scenario.Expanded 'text' 1 $false
    Capture-Screen "$($scenario.State)-reopened"
    if ($scenario.PSObject.Properties.Name -contains 'OrderedTexts') {
      $reopenedBounds = Assert-Ordered-Texts $scenario.State 'reopened' $scenario.OrderedTexts
      $orderedTextSequences.Add([pscustomobject]@{
        state = $scenario.State
        phase = 'reopened'
        texts = $reopenedBounds
      })
    }

    if ($scenario.PSObject.Properties.Name -contains 'ProcessCollapse' -and
        $scenario.ProcessCollapse) {
      Invoke-Control $scenario.State '工作过程'
      $null = Wait-Query-Node "$($scenario.State)-process-collapsed" $scenario.Expanded 'text' 0 $false
      Capture-Screen "$($scenario.State)-process-collapsed"
      Invoke-Control $scenario.State '工作过程'
      $null = Wait-Query-Node "$($scenario.State)-process-reopened" $scenario.Expanded 'text' 1 $false
      Capture-Screen "$($scenario.State)-process-reopened"
    }
  } catch {
    $result = 'Failed'
    $message = $_.Exception.Message
    $failedCount++
  }
  $results.Add([pscustomobject]@{
    state = $scenario.State
    result = $result
    durationSeconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
    message = $message
  })
}

# Sidebar More uses the real drawer and auto-closes on system Back.
$moreState = 'disclosure-sidebar-more'
$moreStartedAt = Get-Date
$moreResult = 'Passed'
$moreMessage = ''
try {
  Launch-Fixture -State $moreState
  $before = Dump-Layout "$moreState-before"
  $null = Query-Node $before '文件浏览' 'text' 0 $true
  Capture-Screen "$moreState-collapsed"
  Invoke-Control $moreState '更多'
  $null = Wait-Query-Node "$moreState-expanded" '文件浏览' 'text' 1 $true
  $null = Query-Node (Dump-Layout "$moreState-expanded-layout") '应用设置' 'text' 1 $true
  Capture-Screen "$moreState-expanded"
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  $null = Wait-Query-Node "$moreState-collapsed-again" '文件浏览' 'text' 0 $true
  Capture-Screen "$moreState-collapsed-again"
  Launch-Fixture -State $moreState
  Invoke-Control $moreState '更多'
  $null = Wait-Query-Node "$moreState-reopened" '文件浏览' 'text' 1 $true
  Capture-Screen "$moreState-reopened"
} catch {
  $moreResult = 'Failed'
  $moreMessage = $_.Exception.Message
  $failedCount++
}
$results.Add([pscustomobject]@{
  state = $moreState
  result = $moreResult
  durationSeconds = [math]::Round(((Get-Date) - $moreStartedAt).TotalSeconds, 1)
  message = $moreMessage
})

# Workspace groups start expanded. Assert child visibility, collapse, reopen
# and stable chevron semantics through the real drawer.
$groupState = 'disclosure-sidebar-group'
$groupStartedAt = Get-Date
$groupResult = 'Passed'
$groupMessage = ''
try {
  Launch-Fixture -State $groupState
  $null = Wait-Query-Node "$groupState-expanded" '工作区文件预览与下载' 'text' 1 $true
  Capture-Screen "$groupState-expanded"
  Invoke-Control $groupState 'DSH Harmony 移动端' 'clickable' 1450
  $null = Wait-Query-Node "$groupState-collapsed" '工作区文件预览与下载' 'text' 0 $true
  Capture-Screen "$groupState-collapsed"
  Invoke-Control $groupState 'DSH Harmony 移动端' 'clickable' 1450
  $null = Wait-Query-Node "$groupState-reopened" '工作区文件预览与下载' 'text' 1 $true
  Capture-Screen "$groupState-reopened"
} catch {
  $groupResult = 'Failed'
  $groupMessage = $_.Exception.Message
  $failedCount++
}
$results.Add([pscustomobject]@{
  state = $groupState
  result = $groupResult
  durationSeconds = [math]::Round(((Get-Date) - $groupStartedAt).TotalSeconds, 1)
  message = $groupMessage
})

$processId = ((& $hdc -t $Device shell "pidof $bundle") -join ' ').Trim()
if (-not $processId) {
  $failedCount++
  $processFailure = 'The application process exited during disclosure E2E.'
} else {
  $processFailure = ''
}

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  device = $Device
  processId = $processId
  variant = 'mock'
  hapSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $repo 'harmony\entry\build\mock\outputs\mock\entry-mock-signed.hap')).Hash
  theme = $Theme
  reduceMotion = [bool]$ReduceMotion
  reduceTransparency = [bool]$ReduceTransparency
  result = if ($failedCount -eq 0) { 'Passed' } else { 'Failed' }
  processFailure = $processFailure
  scenarios = $results
  checked = [ordered]@{
    collapsedBaselineCaptured = $true
    expandedStateClicked = $true
    expandedOnlyContentAsserted = if ($failedCount -eq 0) { $true } else { $false }
    collapseAndReopenCovered = if ($failedCount -eq 0) { $true } else { $false }
    singleLineReadViewerIsCompact = $failedCount -eq 0
    sidebarMoreCovered = $moreResult -eq 'Passed'
    systemBackClosedDrawer = $moreResult -eq 'Passed'
    workspaceGroupCovered = $groupResult -eq 'Passed'
    liveProcessOrderCovered = $orderedScenarioCount -gt 0 -and
      $orderedTextSequences.Count -eq ($orderedScenarioCount * 2)
    processAliveAfterAllFlows = [bool]$processId
  }
  orderedTextSequences = $orderedTextSequences
}
$manifest |
  ConvertTo-Json -Depth 6 |
  Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8

$results | Format-Table -AutoSize | Out-Host
if ($failedCount -gt 0) {
  throw "$failedCount disclosure E2E checks failed. See $captureDir\manifest.json"
}
Write-Output "Disclosure expansion E2E passed. Evidence: $captureDir"
