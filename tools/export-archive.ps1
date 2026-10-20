<#
.SYNOPSIS
  Re-export the Codex capability archive from the local machine.

.DESCRIPTION
  Collects authored skills from ~/.codex/skills, indexes installed third-party
  skills from ~/.agents/skills, snapshots a redacted config.toml, and rebuilds
  INVENTORY.md plus the JSON metadata files.

  Every secret and private LAN address is replaced with a placeholder before the
  result is written. The script is idempotent; run it from a clean working tree
  so it does not clobber local edits.

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

# --- values that must never be published -------------------------------------
$redactions = [ordered]@{
  '1867252e76de3f97abef42da5d1ee98d187c944f79041a1b4b632650e1b4aed9' = '<LOCAL_KEY_32HEX>'
  '71fa3941f24e469e9f9dd96c0458fde6'                             = '<DEVICE_UID_32HEX>'
  'c10f670000bf'                                                   = '<DEVICE_ID>'
  '192.168.1.103' = '192.168.1.<YAMAHA>'
  '192.168.1.105' = '192.168.1.<ROBOT>'
  '192.168.1.107' = '192.168.1.<ROBOT_GATEWAY>'
  '192.168.1.102' = '192.168.1.<ZIDOO>'
  '192.168.1.119' = '192.168.1.<OTHER>'
}

function Protect-Text {
  param([string] $Text)
  foreach ($k in $redactions.Keys) { $Text = $Text.Replace($k, $redactions[$k]) }
  return $Text
}

# --- frontmatter parsing (handles folded YAML scalars) -----------------------
function Read-Frontmatter {
  param([string] $Path)
  $r = [ordered]@{ name = ''; description = '' }
  if (-not (Test-Path -LiteralPath $Path)) { return $r }
  $raw = Get-Content -LiteralPath $Path -Raw
  if ($raw -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') { return $r }
  $key = $null; $buf = @(); $mode = 'plain'
  foreach ($ln in ($Matches[1] -split "\r?\n")) {
    if ($ln -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
      if ($key) { Set-Fm $r $key $buf }
      $key = $Matches[1]; $val = $Matches[2].Trim()
      if ($val -match '^[>|][-+]?$') { $mode = 'block'; $buf = @() }
      else { $mode = 'plain'; $buf = @($val.Trim('"').Trim("'")) }
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
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $skillsDst $_.Name) -Recurse -Force
  }

# redact in place
Get-ChildItem -LiteralPath $skillsDst -Recurse -File -Include *.md,*.json,*.js,*.py,*.ps1,*.sh |
  ForEach-Object {
    $t = Get-Content -LiteralPath $_.FullName -Raw
    $n = Protect-Text $t
    if ($n -ne $t) { Set-Content -LiteralPath $_.FullName -Value $n -Encoding UTF8 -NoNewline }
  }
Write-Host "skills exported: $((Get-ChildItem -LiteralPath $skillsDst -Directory).Count)"

# --- 2. metadata -------------------------------------------------------------
$rows = @()
Get-ChildItem -LiteralPath $skillsDst -Directory | ForEach-Object {
  $fm    = Read-Frontmatter (Join-Path $_.FullName 'SKILL.md')
  $files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue)
  $rows += [pscustomobject]@{
    dir            = $_.Name
    name           = if ($fm.name) { $fm.name } else { $_.Name }
    description    = Protect-Text $fm.description
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
    $fm    = Read-Frontmatter (Join-Path $_.FullName 'SKILL.md')
    $files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue)
    [pscustomobject]@{
      name        = if ($fm.name) { $fm.name } else { $_.Name }
      description = Protect-Text $fm.description
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
  $cfg = Protect-Text $cfg
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
