<#
.SYNOPSIS
  One-click idempotent installer for agy-computeruse (Windows Hybrid Computer Use Skill).
  Installs agent-desktop CLI, deploys SKILL.md + references + PowerShell scripts,
  optionally registers the agent-desktop MCP server, and runs self-checks.
#>
param(
    [string]$SkillDir = "$env:USERPROFILE\.gemini\config\skills\open-computer-use",
    [string]$McpConfigPath = "$env:USERPROFILE\.gemini\antigravity\mcp_config.json",
    [switch]$SkipNpmInstall,
    [switch]$SkipMcpConfig
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== [1/4] Checking agent-desktop CLI ===" -ForegroundColor Cyan
$hasAgentDesktop = Get-Command agent-desktop -ErrorAction SilentlyContinue
if (-not $hasAgentDesktop) {
    if ($SkipNpmInstall) {
        throw "agent-desktop CLI not found and -SkipNpmInstall was specified. Install via: npm install -g agent-desktop"
    }
    $hasNpm = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $hasNpm) {
        throw "Neither 'agent-desktop' nor 'npm' was found on PATH. Please install Node.js (>=18) first, then re-run install.ps1."
    }
    Write-Host "Installing agent-desktop globally via npm..." -ForegroundColor Yellow
    npm install -g agent-desktop
    if ($LASTEXITCODE -ne 0) { throw "npm install -g agent-desktop failed (exit $LASTEXITCODE)." }
} else {
    Write-Host "Found agent-desktop: $($hasAgentDesktop.Source)" -ForegroundColor Green
}

Write-Host "`n=== [2/4] Deploying Skill & PowerShell Scripts ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "$SkillDir\scripts", "$SkillDir\references" | Out-Null
Copy-Item "$RepoRoot\SKILL.md" "$SkillDir\SKILL.md" -Force
Copy-Item "$RepoRoot\references\*" "$SkillDir\references\" -Force
Copy-Item "$RepoRoot\scripts\*" "$SkillDir\scripts\" -Force
Write-Host "Installed skill to: $SkillDir" -ForegroundColor Green

Write-Host "`n=== [3/4] Configuring MCP Server ===" -ForegroundColor Cyan
if (-not $SkipMcpConfig) {
    $mcpDir = Split-Path -Parent $McpConfigPath
    if (-not (Test-Path $mcpDir)) { New-Item -ItemType Directory -Force -Path $mcpDir | Out-Null }

    $configObj = if (Test-Path $McpConfigPath) {
        $raw = [System.IO.File]::ReadAllText($McpConfigPath, [System.Text.Encoding]::UTF8).Trim()
        if ($raw -ne "") { $raw | ConvertFrom-Json } else { [PSCustomObject]@{} }
    } else {
        [PSCustomObject]@{}
    }

    if ($null -eq $configObj.mcpServers) {
        $configObj | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    if ($null -eq $configObj.mcpServers.'agent-desktop') {
        $entry = [PSCustomObject]@{
            command = "agent-desktop"
            args    = @("mcp", "--headed")
        }
        $configObj.mcpServers | Add-Member -NotePropertyName "agent-desktop" -NotePropertyValue $entry -Force
        $jsonOut = $configObj | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($McpConfigPath, $jsonOut, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Registered 'agent-desktop' MCP in: $McpConfigPath" -ForegroundColor Green
    } else {
        Write-Host "'agent-desktop' MCP entry already exists in $McpConfigPath (kept existing)." -ForegroundColor Green
    }
} else {
    Write-Host "Skipped MCP config (-SkipMcpConfig)." -ForegroundColor Yellow
}

Write-Host "`n=== [4/4] Running Self-Check ===" -ForegroundColor Cyan
$statusOut = agent-desktop status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "agent-desktop status returned exit $LASTEXITCODE : $statusOut"
} else {
    Write-Host "agent-desktop status: OK" -ForegroundColor Green
}

foreach ($s in @("som_grid.ps1", "parse_uia.ps1", "verify_diff.ps1")) {
    $p = Join-Path "$SkillDir\scripts" $s
    if (-not (Test-Path $p)) { throw "Missing script after install: $p" }
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$null)
    Write-Host "Script syntax OK: $s" -ForegroundColor Green
}

Write-Host "`nREADY_TO_USE: agy-computeruse deployed successfully!" -ForegroundColor Cyan
Write-Host "Note: Restart or reload your AI client's MCP servers if 'agent-desktop' was newly added."
