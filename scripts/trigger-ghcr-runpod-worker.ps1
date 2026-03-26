#Requires -Version 5.1
# Trigger GitHub Actions workflow that builds and pushes ghcr.io/<owner>/runpod-comfyui-worker
# Requires GITHUB_TOKEN with workflow scope (or repo + workflow). Loads repo .env if present.
[CmdletBinding()]
param(
    [string] $Repo = "CypherHub/dockerVast",
    [string] $Workflow = "ghcr-runpod-comfyui-worker.yml",
    [string] $Ref = "main"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $repoRoot ".env"
if (Test-Path $envFile) {
    . (Join-Path $PSScriptRoot "load-dotenv.ps1") -Path $envFile
}

$tok = $env:GITHUB_TOKEN
if ([string]::IsNullOrWhiteSpace($tok)) { throw "Set GITHUB_TOKEN (workflow scope) in environment or .env" }

$hdr = @{
    Authorization             = "Bearer $tok"
    Accept                    = "application/vnd.github+json"
    "X-GitHub-Api-Version"    = "2022-11-28"
}
$dispatchUrl = "https://api.github.com/repos/$Repo/actions/workflows/$Workflow/dispatches"
$body = @{ ref = $Ref } | ConvertTo-Json
Write-Host "Dispatching workflow $Workflow on $Repo @ $Ref ..."
Invoke-RestMethod -Uri $dispatchUrl -Method Post -Headers $hdr -Body $body -ContentType "application/json"
Write-Host "Dispatch accepted (204). Waiting for latest run to complete..."

Start-Sleep -Seconds 8
$runsUrl = "https://api.github.com/repos/$Repo/actions/workflows/$Workflow/runs?per_page=3"
$deadline = (Get-Date).AddMinutes(25)
$run = $null
while ((Get-Date) -lt $deadline) {
    $r = Invoke-RestMethod -Uri $runsUrl -Headers $hdr -Method Get
    $run = $r.workflow_runs[0]
    Write-Host ("Run {0} status={1} conclusion={2} created={3}" -f $run.id, $run.status, $run.conclusion, $run.created_at)
    if ($run.status -eq "completed") {
        if ($run.conclusion -ne "success") {
            Write-Error "Workflow finished with conclusion=$($run.conclusion) - see $($run.html_url)"
            exit 1
        }
        Write-Host "OK: workflow succeeded."
        exit 0
    }
    Start-Sleep -Seconds 20
}
Write-Error "Timed out waiting for workflow."
exit 1
