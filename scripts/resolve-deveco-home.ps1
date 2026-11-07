function Test-DevEcoHome {
  param([AllowEmptyString()][string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }
  $hdc = Join-Path $Path 'sdk\default\openharmony\toolchains\hdc.exe'
  return Test-Path -LiteralPath $hdc -PathType Leaf
}

function Resolve-DevEcoHome {
  param([AllowEmptyString()][string]$ExplicitHome = '')

  if (-not [string]::IsNullOrWhiteSpace($ExplicitHome)) {
    if (-not (Test-DevEcoHome $ExplicitHome)) {
      throw "DevEco Studio home does not contain the OpenHarmony HDC tool: $ExplicitHome"
    }
    return (Resolve-Path -LiteralPath $ExplicitHome).Path
  }

  $environmentCandidates = @(
    $env:DEVECO_STUDIO_HOME
    $env:DEVECO_HOME
  )
  foreach ($candidate in $environmentCandidates) {
    if (Test-DevEcoHome $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
  $programRoots = @(
    $env:ProgramFiles
    ${env:ProgramFiles(x86)}
    $env:ProgramW6432
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

  $searchParents = [Collections.Generic.List[string]]::new()
  foreach ($root in $programRoots) {
    $searchParents.Add((Join-Path $root 'Huawei'))
    $searchParents.Add((Join-Path $root 'DevEco Studio'))
  }
  if (-not [string]::IsNullOrWhiteSpace($localAppData)) {
    $searchParents.Add((Join-Path $localAppData 'Huawei'))
    $searchParents.Add((Join-Path $localAppData 'Programs'))
    $searchParents.Add((Join-Path $localAppData 'Programs\Huawei'))
    $searchParents.Add((Join-Path $localAppData 'Programs\DevEco Studio'))
  }

  $discovered = [Collections.Generic.List[string]]::new()
  foreach ($parent in ($searchParents | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
      continue
    }
    if (Test-DevEcoHome $parent) {
      $discovered.Add($parent)
    }
    Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'DevEcoStudio-*' -or $_.Name -like 'DevEco Studio*' } |
      Sort-Object Name -Descending |
      ForEach-Object {
        if (Test-DevEcoHome $_.FullName) {
          $discovered.Add($_.FullName)
        }
      }
  }

  $match = $discovered | Select-Object -Unique -First 1
  if (-not $match) {
    throw 'DevEco Studio was not found. Set DEVECO_STUDIO_HOME or pass -DevEcoHome explicitly.'
  }
  return (Resolve-Path -LiteralPath $match).Path
}
