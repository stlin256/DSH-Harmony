function Find-ShowcaseNode {
  param(
    [object]$Node,
    [string]$Id = '',
    [string]$Text = ''
  )

  foreach ($candidate in @($Node)) {
    if ($null -eq $candidate) { continue }
    $attributes = $candidate.attributes
    if ($Id -and $attributes.id -eq $Id) { return $candidate }
    if ($Text -and ($attributes.text -eq $Text -or
      $attributes.originalText -eq $Text -or
      $attributes.description -eq $Text)) {
      return $candidate
    }
    $found = Find-ShowcaseNode -Node $candidate.children -Id $Id -Text $Text
    if ($null -ne $found) { return $found }
  }
  return $null
}

function Get-ShowcaseBounds {
  param([object]$Node)

  $match = [regex]::Match([string]$Node.attributes.bounds,
    '^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$')
  if (-not $match.Success) {
    throw "Invalid fixture bounds: $($Node.attributes.bounds)"
  }
  return [ordered]@{
    left = [int]$match.Groups[1].Value
    top = [int]$match.Groups[2].Value
    right = [int]$match.Groups[3].Value
    bottom = [int]$match.Groups[4].Value
  }
}

function Read-ShowcaseLayout {
  param(
    [string]$BundleName,
    [string]$RemotePath,
    [string]$LocalPath
  )

  Remove-Item -LiteralPath $LocalPath -Force -ErrorAction SilentlyContinue
  & $hdc -t $Device shell "uitest dumpLayout -p $RemotePath -i -b $BundleName" | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Fixture layout dump failed: $RemotePath"
  }
  Start-Sleep -Milliseconds 220
  & $hdc -t $Device file recv $RemotePath $LocalPath | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $LocalPath)) {
    throw "Fixture layout receive failed: $RemotePath"
  }
  return @(Get-Content -LiteralPath $LocalPath -Raw -Encoding UTF8 | ConvertFrom-Json)[0]
}

function Move-ShowcaseToTail {
  param(
    [string]$BundleName,
    [string]$RemotePath,
    [string]$LocalPath
  )

  $root = Read-ShowcaseLayout -BundleName $BundleName -RemotePath $RemotePath -LocalPath $LocalPath
  $scroll = Find-ShowcaseNode -Node $root -Id 'transcript-scroll'
  if ($null -eq $scroll) {
    # Without the scroll container the tail position cannot be verified, so the
    # capture must fail instead of silently claiming the transcript is at its tail.
    return [ordered]@{ attempted = $false; atTail = $false; swipes = 0 }
  }

  $bounds = Get-ShowcaseBounds -Node $scroll
  $x = [int](($bounds.left + $bounds.right) / 2)
  $height = $bounds.bottom - $bounds.top
  $startY = $bounds.top + [int]($height * 0.76)
  $endY = $bounds.top + [int]($height * 0.24)
  $swipeCount = 1
  for ($index = 0; $index -lt $swipeCount; $index++) {
    & $hdc -t $Device shell "uitest uiInput swipe $x $startY $x $endY 820" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Fixture tail swipe failed: $x/$startY -> $x/$endY"
    }
    Start-Sleep -Milliseconds 260
  }
  Start-Sleep -Milliseconds 650

  $settled = Read-ShowcaseLayout -BundleName $BundleName -RemotePath $RemotePath -LocalPath $LocalPath
  $backText = -join @([char]0x56DE, [char]0x5230, [char]0x5E95, [char]0x90E8)
  $backNewText = -join @([char]0x56DE, [char]0x5230, [char]0x5E95, [char]0x90E8,
    [char]0xFF0C, [char]0x6709, [char]0x65B0, [char]0x5185, [char]0x5BB9)
  $back = Find-ShowcaseNode -Node $settled -Text $backText
  if ($null -eq $back) {
    $back = Find-ShowcaseNode -Node $settled -Text $backNewText
  }
  if ($null -ne $back) {
    $button = Get-ShowcaseBounds -Node $back
    $buttonX = [int](($button.left + $button.right) / 2)
    $buttonY = [int](($button.top + $button.bottom) / 2)
    & $hdc -t $Device shell "uitest uiInput click $buttonX $buttonY" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Fixture return-to-tail click failed: $buttonX/$buttonY"
    }
    Start-Sleep -Milliseconds 850
    $settled = Read-ShowcaseLayout -BundleName $BundleName -RemotePath $RemotePath -LocalPath $LocalPath
    $back = Find-ShowcaseNode -Node $settled -Text $backText
    if ($null -eq $back) {
      $back = Find-ShowcaseNode -Node $settled -Text $backNewText
    }
  }

  return [ordered]@{
    attempted = $true
    atTail = $null -eq $back
    swipes = $swipeCount
  }
}
