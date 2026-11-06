param(
  [string]$DevEcoHome = '',
  [string]$Device = '',
  [string]$OutputDir = '',
  [switch]$SkipBuild,
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$FixtureState = 'showcase-plan'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'resolve-deveco-home.ps1')
$DevEcoHome = Resolve-DevEcoHome -ExplicitHome $DevEcoHome
$hdc = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path -LiteralPath $hdc)) {
  throw "HDC not found: $hdc"
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $repo 'artifacts\device-ui-store-review-e2e'
}
if (-not [IO.Path]::IsPathRooted($OutputDir)) {
  $OutputDir = Join-Path $repo $OutputDir
}
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$captureDir = Join-Path $OutputDir 'review-entry'
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null

$accessKey = $env:DSH_STORE_REVIEW_ACCESS_KEY
if (-not $accessKey) {
  throw 'Set DSH_STORE_REVIEW_ACCESS_KEY for this process; do not place it in the repository.'
}
if (-not $Device) {
  $ready = @(& $hdc list targets -v | Where-Object {
    $_ -match '\tUSB\t(?:Ready|Connected)\t' -and $_ -notmatch '\tOffline\t'
  })
  if ($ready.Count -eq 0) {
    throw 'No ready USB HarmonyOS device is available; store review E2E remains pending.'
  }
  $Device = ($ready[0] -split "`t")[0]
}

$bundle = 'io.github.stlin256.dshharmony'
$buildScript = Join-Path $PSScriptRoot 'build-harmony.ps1'
$queryScript = Join-Path $PSScriptRoot 'device-ui-layout-query.py'

if (-not $SkipBuild) {
  & $buildScript -DevEcoHome $DevEcoHome -Product store -BuildMode release | Out-Host
}
if (-not $SkipInstall) {
  $hap = Join-Path $repo 'harmony\entry\build\default\outputs\default\entry-default-signed.hap'
  if (-not (Test-Path -LiteralPath $hap)) {
    throw "Store HAP not found: $hap"
  }
  & $hdc -t $Device install -r $hap | Out-Host
  if ($LASTEXITCODE -ne 0) { throw 'Store HAP installation failed.' }
}

function Dump-Layout {
  param([string]$Name)
  $remote = "/data/local/tmp/dsh-store-review-$Name.json"
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
  $remote = "/data/local/tmp/dsh-store-review-$Name.jpeg"
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
    [string]$Id = '',
    [string]$Text = '',
    [string]$Target = 'clickable'
  )
  $arguments = @($queryScript, $Layout, '--target', $Target, '--expect-count', '1')
  if ($Id) {
    $arguments += @('--find-id', $Id)
  } else {
    $arguments += @('--find-text-hex',
      ([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', ''))
  }
  $raw = & python @arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Layout query failed: $($raw -join [Environment]::NewLine)"
  }
  return (($raw -join '') | ConvertFrom-Json)
}

function Tap-Node {
  param([object]$Node)
  & $hdc -t $Device shell "uitest uiInput click $($Node.x) $($Node.y)" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Tap failed.' }
  Start-Sleep -Milliseconds 350
}

function Try-Tap-Text {
  param([string]$Text)
  try {
    $layout = Dump-Layout ('try-' + [DateTime]::UtcNow.Ticks)
    $node = Query-Node -Layout $layout -Text $Text
    Tap-Node $node
    return $true
  } catch {
    return $false
  }
}

function Try-Tap-Id {
  param([string]$Id)
  try {
    $layout = Dump-Layout ('try-id-' + [DateTime]::UtcNow.Ticks)
    $node = Query-Node -Layout $layout -Id $Id
    Tap-Node $node
    return $true
  } catch {
    return $false
  }
}

function Tap-Text {
  param([string]$Text)
  $layout = Dump-Layout ('tap-text-' + [DateTime]::UtcNow.Ticks)
  Tap-Node (Query-Node -Layout $layout -Text $Text)
}

function Tap-Id {
  param([string]$Id)
  $layout = Dump-Layout ('tap-id-' + [DateTime]::UtcNow.Ticks)
  Tap-Node (Query-Node -Layout $layout -Id $Id)
}

function Assert-Text {
  param([string]$Text)
  $layout = Dump-Layout ('assert-text-' + [DateTime]::UtcNow.Ticks)
  $null = Query-Node -Layout $layout -Text $Text -Target 'any'
}

function Assert-Id {
  param([string]$Id)
  $layout = Dump-Layout ('assert-id-' + [DateTime]::UtcNow.Ticks)
  $null = Query-Node -Layout $layout -Id $Id -Target 'any'
}

function Choose-Select {
  param(
    [string]$Id,
    [string]$Label
  )
  Tap-Id $Id
  Start-Sleep -Milliseconds 450
  Tap-Text $Label
  Start-Sleep -Milliseconds 500
}

function Restart-App {
  & $hdc -t $Device shell "aa force-stop $bundle" | Out-Null
  & $hdc -t $Device shell "aa start -a EntryAbility -b $bundle -m entry" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Application restart failed.' }
  Start-Sleep -Seconds 3
}

function Open-WorkspaceDrawer {
  Tap-Id 'workspace-sidebar'
}

$localSecret = Join-Path ([IO.Path]::GetTempPath()) ('dsh-store-review-' + [Guid]::NewGuid().ToString('N') + '.txt')
$remoteSecret = '/data/local/tmp/dsh-store-review-' + [Guid]::NewGuid().ToString('N') + '.txt'
try {
  [IO.File]::WriteAllText($localSecret, $accessKey, [Text.UTF8Encoding]::new($false))
  & $hdc -t $Device file send $localSecret $remoteSecret | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Credential transfer failed.' }

  Restart-App

  $null = Try-Tap-Text '我已知晓，继续'
  $null = Try-Tap-Text '直接进入'

  $loginLayout = Dump-Layout 'login'
  $address = Query-Node -Layout $loginLayout -Id 'launch-login-address'
  $key = Query-Node -Layout $loginLayout -Id 'launch-login-access-key'
  $connect = Query-Node -Layout $loginLayout -Id 'launch-login-connect'
  Tap-Node $address
  & $hdc -t $Device shell "uitest uiInput inputText $($address.x) $($address.y) https://dsh.dshoh.com" | Out-Null
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  $preSecretLayout = Dump-Layout 'pre-secret'
  $key = Query-Node -Layout $preSecretLayout -Id 'launch-login-access-key'
  $connect = Query-Node -Layout $preSecretLayout -Id 'launch-login-connect'
  Tap-Node $key
  $secretInput = 'uitest uiInput inputText ' + $key.x + ' ' + $key.y + ' $(cat ' + $remoteSecret + ')'
  & $hdc -t $Device shell $secretInput | Out-Null
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Tap-Node $connect

  Start-Sleep -Seconds 3
  Assert-Text '整理离线与同步状态'
  Capture-Screen 'workspace'

  # File browser: switch directories, open a config preview and exercise the
  # preview/source control before returning to the workspace.
  Open-WorkspaceDrawer
  Tap-Id 'sidebar-more'
  Tap-Id 'sidebar-files'
  Start-Sleep -Milliseconds 700
  Assert-Text 'README.md'
  Capture-Screen 'files-root'
  Tap-Id 'file-entry-config'
  Start-Sleep -Milliseconds 500
  Assert-Text 'app.conf'
  Capture-Screen 'files-config'
  Tap-Id 'file-entry-app.conf'
  Start-Sleep -Milliseconds 800
  Assert-Text '[server]'
  Capture-Screen 'file-preview-source'
  Tap-Id 'document-mode-toggle'
  Start-Sleep -Milliseconds 500
  Capture-Screen 'file-preview-mode'
  Tap-Id 'document-close'
  Start-Sleep -Milliseconds 350
  Tap-Id 'file-browser-close'
  Start-Sleep -Milliseconds 500

  # Plugins: mutate a component toggle, inspect/update/remove an installed
  # bundle, then install a second bundle from the available inventory.
  Open-WorkspaceDrawer
  Tap-Id 'sidebar-plugins'
  Start-Sleep -Milliseconds 800
  Assert-Text 'API Inspector'
  Assert-Text 'Markdown Check'
  Capture-Screen 'plugins'
  Tap-Id 'plugin-bundle-toggle-@dsh/api-inspector'
  Start-Sleep -Milliseconds 700
  Capture-Screen 'plugins-toggle'
  Tap-Id 'plugin-bundle-@dsh/api-inspector'
  Start-Sleep -Milliseconds 500
  Tap-Id 'plugin-detail-toggle'
  Start-Sleep -Milliseconds 600
  Try-Tap-Text '检查更新' | Out-Null
  Start-Sleep -Milliseconds 700
  Tap-Id 'plugin-update'
  Start-Sleep -Milliseconds 800
  Capture-Screen 'plugin-updated'
  Tap-Id 'plugin-remove'
  Start-Sleep -Milliseconds 350
  Tap-Text '移除'
  Start-Sleep -Milliseconds 800
  Tap-Id 'plugin-install-@dsh/markdown-check'
  Start-Sleep -Milliseconds 400
  Tap-Id 'plugin-install-inspect'
  Start-Sleep -Milliseconds 650
  Tap-Id 'plugin-install-confirm'
  Start-Sleep -Milliseconds 850
  Assert-Text 'Markdown Check'
  Capture-Screen 'plugin-installed'
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 500

  # Automation: run and pause an existing task, then create/edit/delete a task
  # through the normal editor.
  Open-WorkspaceDrawer
  Tap-Id 'sidebar-automation'
  Start-Sleep -Milliseconds 800
  Assert-Text '每日检查构建状态'
  Capture-Screen 'automation'
  Tap-Id 'automation-task-automation-docs'
  Start-Sleep -Milliseconds 500
  Tap-Id 'automation-run'
  Start-Sleep -Milliseconds 800
  Assert-Text '上次投递'
  Capture-Screen 'automation-run'
  Tap-Id 'automation-active'
  Start-Sleep -Milliseconds 700
  Assert-Text '已暂停'
  Capture-Screen 'automation-paused'
  Tap-Id 'automation-active'
  Start-Sleep -Milliseconds 500
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 450
  Tap-Id 'automation-create'
  Start-Sleep -Milliseconds 400
  $titleNode = Query-Node -Layout (Dump-Layout 'automation-create-form') -Id 'automation-title'
  Tap-Node $titleNode
  & $hdc -t $Device shell "uitest uiInput inputText $($titleNode.x) $($titleNode.y) Review_automation" | Out-Null
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  $promptNode = Query-Node -Layout (Dump-Layout 'automation-prompt') -Id 'automation-prompt'
  Tap-Node $promptNode
  & $hdc -t $Device shell "uitest uiInput inputText $($promptNode.x) $($promptNode.y) Check_release_status" | Out-Null
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Tap-Id 'automation-save'
  Start-Sleep -Milliseconds 900
  Assert-Text 'Review_automation'
  Capture-Screen 'automation-created'
  Try-Tap-Text '编辑' | Out-Null
  Start-Sleep -Milliseconds 400
  $titleNode = Query-Node -Layout (Dump-Layout 'automation-edit-form') -Id 'automation-title'
  Tap-Node $titleNode
  & $hdc -t $Device shell "uitest uiInput inputText $($titleNode.x) $($titleNode.y) _updated" | Out-Null
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Tap-Id 'automation-save'
  Start-Sleep -Milliseconds 800
  Tap-Id 'automation-delete'
  Start-Sleep -Milliseconds 350
  Tap-Text '删除'
  Start-Sleep -Milliseconds 800
  Capture-Screen 'automation-deleted'
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 450

  # Local and Host settings: persist theme, reduced motion/transparency,
  # notification levels, widget details and all writable DSH namespaces.
  Open-WorkspaceDrawer
  Tap-Id 'workspace-settings'
  Start-Sleep -Milliseconds 600
  Assert-Text '外观与动效'
  Capture-Screen 'settings'
  Tap-Id 'settings-open-appearance'
  Start-Sleep -Milliseconds 400
  Tap-Id 'settings-theme-dark'
  Tap-Id 'settings-toggle-reduceMotion'
  # Default is ON; toggle off (immersive) and back on so the persisted state
  # asserted after relaunch stays the pre-immersive default.
  Tap-Id 'settings-toggle-reduceTransparency'
  Tap-Id 'settings-toggle-reduceTransparency'
  Start-Sleep -Milliseconds 600
  Capture-Screen 'settings-appearance'
  Tap-Id 'settings-back'
  Tap-Id 'settings-open-notifications'
  Start-Sleep -Milliseconds 400
  Tap-Id 'settings-notification-completed-standard'
  Tap-Id 'settings-notification-failed-prominent'
  Start-Sleep -Milliseconds 600
  Capture-Screen 'settings-notifications'
  Tap-Id 'settings-back'
  Tap-Id 'settings-open-cards'
  Start-Sleep -Milliseconds 400
  Tap-Id 'settings-toggle-widgetDetails'
  Start-Sleep -Milliseconds 500
  Capture-Screen 'settings-cards'
  Tap-Id 'settings-back'
  Tap-Id 'settings-open-dsh'
  Start-Sleep -Milliseconds 800
  Assert-Text '工作步骤展示'
  Choose-Select 'settings-ui-chat-transcriptView' '简洁'
  Choose-Select 'settings-ui-chat-collapseTiming' '下次发送时'
  Choose-Select 'settings-ui-chat-foldedReplies' '仅最终回答'
  Choose-Select 'settings-ui-conversation-busyEnter' '立即干预'
  Choose-Select 'settings-permission-defaultPreset' '仅可查看'
  Start-Sleep -Milliseconds 650
  Assert-Text '简洁'
  Assert-Text '立即干预'
  Capture-Screen 'settings-dsh'
  Tap-Id 'settings-back'
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 500

  # A cold relaunch must restore the non-secret review session and preserve the
  # local presentation values without exposing the credential.
  Restart-App
  Assert-Text '整理离线与同步状态'
  Capture-Screen 'restored'
  Open-WorkspaceDrawer
  Tap-Id 'workspace-settings'
  Start-Sleep -Milliseconds 550
  Tap-Id 'settings-open-appearance'
  Start-Sleep -Milliseconds 350
  Assert-Id 'settings-theme-state-dark-selected'
  Assert-Id 'settings-toggle-state-reduceMotion-on'
  Assert-Id 'settings-toggle-state-reduceTransparency-on'
  Capture-Screen 'settings-restored'
  Tap-Id 'settings-back'
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  Start-Sleep -Milliseconds 500

  # Sending must pass through the standard busy state, then surface the
  # structured 402 error while retaining the draft.
  $composerLayout = Dump-Layout 'composer'
  $composer = Query-Node -Layout $composerLayout -Id 'composer-input'
  Tap-Node $composer
  & $hdc -t $Device shell "uitest uiInput inputText $($composer.x) $($composer.y) review_balance_probe" | Out-Null
  & $hdc -t $Device shell 'uitest uiInput keyEvent Back' | Out-Null
  $send = Query-Node -Layout (Dump-Layout 'send-ready') -Id 'composer-send'
  Tap-Node $send
  Start-Sleep -Milliseconds 1800
  Assert-Text '账户余额不足，请充值后重试'
  Assert-Text 'review_balance_probe'
  Capture-Screen 'balance-error'

  # Logout clears the review mode. A subsequent cold launch must return to the
  # ordinary login flow instead of restoring the in-process workspace.
  Open-WorkspaceDrawer
  Tap-Id 'workspace-settings'
  Start-Sleep -Milliseconds 500
  Tap-Id 'settings-open-connection'
  Start-Sleep -Milliseconds 400
  Tap-Id 'settings-action-logout'
  Start-Sleep -Milliseconds 350
  Tap-Text '退出'
  Start-Sleep -Seconds 1
  Assert-Id 'launch-login-address'
  Capture-Screen 'logged-out'
  Restart-App
  Assert-Id 'launch-login-address'
  Capture-Screen 'logged-out-relaunch'

  [ordered]@{
    fixtureState = $FixtureState
    device = $Device
    bundle = $bundle
    capturedAt = (Get-Date).ToUniversalTime().ToString('o')
    credentialPersisted = $false
    credentialProcessArguments = $false
    screenshots = @(
      (Join-Path $captureDir 'workspace.jpeg'),
      (Join-Path $captureDir 'files-root.jpeg'),
      (Join-Path $captureDir 'files-config.jpeg'),
      (Join-Path $captureDir 'file-preview-source.jpeg'),
      (Join-Path $captureDir 'file-preview-mode.jpeg'),
      (Join-Path $captureDir 'plugins.jpeg'),
      (Join-Path $captureDir 'plugins-toggle.jpeg'),
      (Join-Path $captureDir 'plugin-updated.jpeg'),
      (Join-Path $captureDir 'plugin-installed.jpeg'),
      (Join-Path $captureDir 'automation.jpeg'),
      (Join-Path $captureDir 'automation-run.jpeg'),
      (Join-Path $captureDir 'automation-paused.jpeg'),
      (Join-Path $captureDir 'automation-created.jpeg'),
      (Join-Path $captureDir 'automation-deleted.jpeg'),
      (Join-Path $captureDir 'settings.jpeg'),
      (Join-Path $captureDir 'settings-appearance.jpeg'),
      (Join-Path $captureDir 'settings-notifications.jpeg'),
      (Join-Path $captureDir 'settings-cards.jpeg'),
      (Join-Path $captureDir 'settings-dsh.jpeg'),
      (Join-Path $captureDir 'settings-restored.jpeg'),
      (Join-Path $captureDir 'balance-error.jpeg'),
      (Join-Path $captureDir 'restored.jpeg'),
      (Join-Path $captureDir 'logged-out.jpeg'),
      (Join-Path $captureDir 'logged-out-relaunch.jpeg')
    )
    verified = @(
      'review entry',
      'file browser directory and preview mutation',
      'plugin open, toggle, install, update and remove',
      'automation run, pause, create, edit and delete',
      'local persistence and in-session DSH settings mutation',
      'settings revision conflict (executable contract)',
      'structured balance error and draft retention',
      'review restore',
      'logout clearing and cold-relaunch rejection'
    )
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $captureDir 'manifest.json') -Encoding utf8
} finally {
  try { & $hdc -t $Device shell "rm -f $remoteSecret" | Out-Null } catch {}
  if (Test-Path -LiteralPath $localSecret) {
    Remove-Item -LiteralPath $localSecret -Force
  }
}
