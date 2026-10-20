<#
.SYNOPSIS
  Re-export the Codex capability archive from the local machine.

.DESCRIPTION
  Collects authored skills from ~/.codex/skills, indexes installed third-party
  skills from ~/.agents/skills, snapshots a redacted config.toml, and rebuilds
  INVENTORY.md plus the JSON metadata files.

  SECURITY
  Personal values (device keys, IDs, LAN addresses) are NEVER hardcoded here.
  They live in .redaction.local.json at the repo root, which is gitignored.
  Only generic safety-net patterns run when that file is absent.

.EXAMPLE
  pwsh tools/export-archive.ps1
#>
[CmdletBinding()]
param(
  [string] $CodexHome = "$env:USERPROFILE\.codex",
  [string] $AgentsHome = "$env:USERPROFILE\.agents",
  [string] $OutDir    = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------
# Per-skill placeholder for private hosts, keyed by skill directory name so the
# mapping itself carries no real address.
$skillHostPlaceholder = [ordered]@{
  '功放'       = '192.168.1.<YAMAHA>'
  '芝杜'       = '192.168.1.<ZIDOO>'
  '扫地机器人' = '192.168.1.<ROBOT>'
}

function Get-RedactionMap {
  $local = Join-Path $OutDir '.redaction.local.json'
  $map = [ordered]@{}
  if (Test-Path -LiteralPath $local) {
    $obj = Get-Content -LiteralPath $local -Raw | ConvertFrom-Json
    if ($obj.exact) {
      foreach ($p in $obj.exact.PSObject.Properties) { $map[$p.Name] = $p.Value }
    }
    Write-Host "redaction: loaded $($map.Count) exact value(s) from .redaction.local.json"
  }
  else {
    Write-Warning "redaction: .redaction.local.json not found - only generic patterns run. Create it before publishing."
  }
  return $map
}

$exactMap = Get-RedactionMap

function Protect-Text {
  param([string] $Text, [string] $SkillName = '')
  if (-not $Text) { return $Text }

  # 1. exact personal values from the local, uncommitted map
  foreach ($k in $exactMap.Keys) { $Text = $Text.Replace($k, $exactMap[$k]) }

  # 2. generic safety net: a 32-byte hex key is never legitimate content here
  $Text = [regex]::Replace($Text, '\b[0-9a-fA-F]{64}\b', '<LOCAL_KEY_32HEX>')

  # 3. private hosts inside device skills, resolved by folder name
  if ($SkillName -and $skillHostPlaceholder.Contains($SkillName)) {
    $Text = [regex]::Replace($Text, '\b192\.168\.1\.\d{1,3}\b', $skillHostPlaceholder[$SkillName])
  }
  return $Text
}

# --- frontmatter parsing (handles folded YAML scalars) -----------------------
function Read-Frontmatter {
  param([string] $Path)
  $r = [ordered]@{ name = ''; description = '' }
  if (-not (Test-Path -LiteralPath $Path)) { return $r }
  $raw = Get-Content -LiteralPath $Path -Raw
  if ($raw -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') { return $r }
  $key = $null; $buf = @()
  foreach ($ln in ($Matches[1] -split "\r?\n")) {
    if ($ln -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
      if ($key) { Set-Fm $r $key $buf }
      $key = $Matches[1]; $val = $Matches[2].Trim()
      if ($val -match '^[>|][-+]?$') { $buf = @() }
      else { $buf = @($val.Trim('"').Trim("'")) }
    }
    elseif ($key -and $ln.Trim()) { $buf += $ln.Trim() }
  }
  if ($key) { Set-Fm $r $key $buf }
  return $r
}
function Set-Fm($r, $key, $buf) {
  $v = (($buf -join ' ') -replace '\s+', ' ').Trim()
  if     ($key -eq 'name')        { $r.name = $v }
  elseif ($key -eq 'description') { $r.description = $v }
}

# --- 1. copy authored skills -------------------------------------------------
$skillsSrc = Join-Path $CodexHome 'skills'
$skillsDst = Join-Path $OutDir    'skills\codex'
New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null

Get-ChildItem -LiteralPath $skillsSrc -Directory |
  Where-Object { $_.Name -ne '.system' } |
  ForEach-Object {
    $name = $_.Name
    $dest = Join-Path $skillsDst $name
    # Wipe first: Copy-Item into an existing directory nests a copy inside it,
    # which silently duplicated every skill on a second run.
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    # robocopy excludes nested VCS metadata so an upstream skill repo does not
    # land in the archive as a gitlink with none of its files.
    & robocopy $_.FullName $dest /E /XD .git node_modules __pycache__ /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) for $name" }

    # redact that skill's files, scoped by folder name
    Get-ChildItem -LiteralPath $dest -Recurse -File |
      Where-Object { $_.Extension -in @('.md','.json','.js','.ts','.py','.ps1','.sh','.yml','.yaml','.txt','.css','.html') } |
      ForEach-Object {
        $t = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $t) { return }
        $n = Protect-Text -Text $t -SkillName $name
        if ($n -ne $t) { Set-Content -LiteralPath $_.FullName -Value $n -Encoding UTF8 -NoNewline }
      }
  }
Write-Host "skills exported: $((Get-ChildItem -LiteralPath $skillsDst -Directory).Count)"

# --- 2. metadata -------------------------------------------------------------
$rows = @()
Get-ChildItem -LiteralPath $skillsDst -Directory | ForEach-Object {
  $name  = $_.Name
  $fm    = Read-Frontmatter (Join-Path $_.FullName 'SKILL.md')
  $files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue)
  $rows += [pscustomobject]@{
    dir            = $name
    name           = if ($fm.name) { $fm.name } else { $name }
    description    = Protect-Text -Text $fm.description -SkillName $name
    file_count     = $files.Count
    total_bytes    = ($files | Measure-Object Length -Sum).Sum
    has_scripts    = Test-Path -LiteralPath (Join-Path $_.FullName 'scripts')
    has_references = Test-Path -LiteralPath (Join-Path $_.FullName 'references')
  }
}
$rows | ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $OutDir 'skills.codex.json') -Encoding UTF8

# --- 3. third-party index ----------------------------------------------------
$agents = @()
$agentsRoot = Join-Path $AgentsHome 'skills'
if (Test-Path -LiteralPath $agentsRoot) {
  $agents = @(Get-ChildItem -LiteralPath $agentsRoot -Directory | ForEach-Object {
    $name  = $_.Name
    $fm    = Read-Frontmatter (Join-Path $_.FullName 'SKILL.md')
    $files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue)
    [pscustomobject]@{
      name        = if ($fm.name) { $fm.name } else { $name }
      description = Protect-Text -Text $fm.description -SkillName $name
      file_count  = $files.Count
      total_bytes = ($files | Measure-Object Length -Sum).Sum
    }
  })
  $agents | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $OutDir 'skills.agents.json') -Encoding UTF8
}

# --- 4. redacted config snapshot ---------------------------------------------
$cfgPath = Join-Path $CodexHome 'config.toml'
if (Test-Path -LiteralPath $cfgPath) {
  $cfg = Get-Content -LiteralPath $cfgPath -Raw
  $cfg = [regex]::Replace($cfg,
    '(?m)^(\s*(?:experimental_bearer_token|MINIMAX_API_KEY|api_key|token|password|secret|client_secret)\s*=\s*")[^"]*(".*)$',
    '$1***REDACTED***$2')
  $cfg = Protect-Text -Text $cfg
  $hdr = @(
    '# ARCHIVED REDACTED COPY of ~/.codex/config.toml',
    '# Secret values replaced with ***REDACTED*** before publishing.',
    '# Do not edit here; re-export from the local machine to refresh.',
    ''
  ) -join "`n"
  New-Item -ItemType Directory -Path (Join-Path $OutDir 'config') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $OutDir 'config\config.redacted.toml') -Value ($hdr + $cfg) -Encoding UTF8
  Write-Host 'config snapshot written (redacted)'
}

# --- 5. INVENTORY.md ---------------------------------------------------------
$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine('# Skill Inventory')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('Auto-generated by `tools/export-archive.ps1`. Counts reflect what is on disk.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('## Authored skills (`skills/codex/`)')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('| Skill | Files | Size | Description |')
$null = $sb.AppendLine('| --- | ---: | ---: | --- |')
foreach ($s in ($rows | Sort-Object name)) {
  $d = $s.description -replace '\|', '/'
  if ($d.Length -gt 160) { $d = $d.Substring(0,157) + '...' }
  $null = $sb.AppendLine("| ``$($s.name)`` | $($s.file_count) | $([math]::Round($s.total_bytes/1KB,1)) KB | $d |")
}
$null = $sb.AppendLine('')
$null = $sb.AppendLine("**Total:** $($rows.Count) skills, $([math]::Round((($rows | Measure-Object total_bytes -Sum).Sum/1MB),2)) MB.")
if ($agents.Count) {
  $null = $sb.AppendLine('')
  $null = $sb.AppendLine('## Installed third-party skills')
  $null = $sb.AppendLine('')
  $null = $sb.AppendLine('Indexed in `skills.agents.json`, not vendored. Restored by the skill installer.')
  $null = $sb.AppendLine('')
  $null = $sb.AppendLine("**Total:** $($agents.Count) skills, $([math]::Round((($agents | Measure-Object total_bytes -Sum).Sum/1MB),2)) MB (name-level index only).")
}
Set-Content -LiteralPath (Join-Path $OutDir 'INVENTORY.md') -Value $sb.ToString() -Encoding UTF8

Write-Host "done -> $OutDir"
