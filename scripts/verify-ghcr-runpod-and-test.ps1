#Requires -Version 5.1
<#
.SYNOPSIS
  Resolve the manifest digest for a GHCR image, confirm the RunPod serverless endpoint
  template points at the same image reference, optionally check the last GitHub Actions
  run for the worker publish workflow, then optionally run the Reface test job.

.DESCRIPTION
  Tokens are read only from environment variables — never commit them.

  Required:
    RUNPOD_API_KEY
    RUNPOD_ENDPOINT_ID
    GITHUB_TOKEN (or GH_TOKEN) — needs read:packages for private GHCR images

  Optional:
    GHCR_IMAGE          Default: ghcr.io/cypherhub/runpod-comfyui-worker:latest
    GITHUB_REPOSITORY   Default: CypherHub/dockerVast
    REQUIRE_GHA_SUCCESS If set to 1, fail when the latest workflow run is not success

  Test job:
    Skipped if SKIP_TEST=1 or -SkipTest.
    Runs scripts/run_runpod_reface_job.py if python is on PATH; set USE_ASYNC=1 for long jobs.

.EXAMPLE
  $env:RUNPOD_API_KEY = '...'
  $env:RUNPOD_ENDPOINT_ID = '...'
  $env:GITHUB_TOKEN = '...'
  ./scripts/verify-ghcr-runpod-and-test.ps1
#>
[CmdletBinding()]
param(
    [string] $RunpodApiKey = $env:RUNPOD_API_KEY,
    [string] $EndpointId = $env:RUNPOD_ENDPOINT_ID,
    [string] $GithubToken = $(if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } else { $env:GH_TOKEN }),
    [string] $GhcrImage = $(if ($env:GHCR_IMAGE) { $env:GHCR_IMAGE } else { "ghcr.io/cypherhub/runpod-comfyui-worker:latest" }),
    [string] $GithubRepo = $(if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { "CypherHub/dockerVast" }),
    [switch] $SkipTest,
    [switch] $RequireGhaSuccess
)

$requireGha = $RequireGhaSuccess -or ($env:REQUIRE_GHA_SUCCESS -eq "1")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-ImageRef([string] $ref) {
    return $ref.Trim().ToLowerInvariant()
}

function Get-GhcrManifestDigest {
    param(
        [Parameter(Mandatory = $true)][string] $ImageRef,
        [Parameter(Mandatory = $true)][string] $BearerToken
    )
    $norm = Normalize-ImageRef $ImageRef
    if ($norm -notmatch "^ghcr\.io/(.+):(.+)$") {
        throw "GHCR_IMAGE must look like ghcr.io/owner/name:tag (got: $ImageRef)"
    }
    $repoPath = $Matches[1]
    $tag = $Matches[2]
    $scope = "repository:$repoPath`:pull"
    $tokenUrl = "https://ghcr.io/token?service=ghcr.io&scope=$scope"
    $tokResp = Invoke-RestMethod -Uri $tokenUrl -Headers @{ Authorization = "Bearer $BearerToken" } -Method Get
    if (-not $tokResp.token) {
        throw "GHCR token response had no 'token' field. Check GITHUB_TOKEN (read:packages for private images)."
    }
    $regToken = $tokResp.token
    $manifestUrl = "https://ghcr.io/v2/$repoPath/manifests/$tag"
    # Prefer manifest list / OCI index so digest matches what docker pull resolves for multi-arch.
    $accept = @(
        "application/vnd.docker.distribution.manifest.list.v2+json",
        "application/vnd.oci.image.index.v1+json",
        "application/vnd.docker.distribution.manifest.v2+json",
        "application/vnd.oci.image.manifest.v1+json"
    ) -join ", "
    $resp = Invoke-WebRequest -Uri $manifestUrl -Method Head -Headers @{
        Authorization   = "Bearer $regToken"
        Accept          = $accept
    } -UseBasicParsing
    $digest = $resp.Headers["Docker-Content-Digest"]
    if (-not $digest) {
        throw "GHCR manifest response missing Docker-Content-Digest header."
    }
    if ($digest -is [string]) { return @{ Digest = $digest; Repository = $repoPath; Tag = $tag } }
    return @{ Digest = [string]$digest[0]; Repository = $repoPath; Tag = $tag }
}

function Get-RunPodTemplateImage {
    param(
        [Parameter(Mandatory = $true)][string] $EndpointId,
        [Parameter(Mandatory = $true)][string] $ApiKey
    )
    $url = "https://rest.runpod.io/v1/endpoints/$EndpointId" + "?includeTemplate=true&includeWorkers=false"
    $ep = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $ApiKey" } -Method Get
    $img = $null
    if ($ep.template -and $ep.template.imageName) {
        $img = [string]$ep.template.imageName
    }
    if (-not $img -and $ep.templateId) {
        $tUrl = "https://rest.runpod.io/v1/templates/$($ep.templateId)"
        try {
            $tpl = Invoke-RestMethod -Uri $tUrl -Headers @{ Authorization = "Bearer $ApiKey" } -Method Get
            if ($tpl.imageName) { $img = [string]$tpl.imageName }
        }
        catch {
            Write-Warning "Could not load template $($ep.templateId): $($_.Exception.Message)"
        }
    }
    if (-not $img) {
        throw "RunPod endpoint did not expose template.imageName (includeTemplate or template fetch failed)."
    }
    return @{
        ImageName   = $img
        EndpointVer = $ep.version
        Name        = $ep.name
    }
}

function Get-LatestWorkflowRun {
    param(
        [Parameter(Mandatory = $true)][string] $Repo,
        [Parameter(Mandatory = $true)][string] $WorkflowFile,
        [Parameter(Mandatory = $true)][string] $BearerToken
    )
    $owner, $name = $Repo.Split("/", 2)
    $wUrl = "https://api.github.com/repos/$Repo/actions/workflows/$WorkflowFile"
    $wf = Invoke-RestMethod -Uri $wUrl -Headers @{
        Authorization = "Bearer $BearerToken"
        Accept          = "application/vnd.github+json"
        "User-Agent"    = "dockerVast-verify-script"
    } -Method Get
    $runsUrl = "https://api.github.com/repos/$Repo/actions/workflows/$($wf.id)/runs?per_page=1"
    $runs = Invoke-RestMethod -Uri $runsUrl -Headers @{
        Authorization = "Bearer $BearerToken"
        Accept          = "application/vnd.github+json"
        "User-Agent"    = "dockerVast-verify-script"
    } -Method Get
    return $runs.workflow_runs[0]
}

# --- validate env ---
if ([string]::IsNullOrWhiteSpace($RunpodApiKey)) { throw "Set RUNPOD_API_KEY." }
if ([string]::IsNullOrWhiteSpace($EndpointId)) { throw "Set RUNPOD_ENDPOINT_ID." }
if ([string]::IsNullOrWhiteSpace($GithubToken)) { throw "Set GITHUB_TOKEN or GH_TOKEN (needs read:packages for private GHCR)." }

$expectedRef = Normalize-ImageRef $GhcrImage
Write-Host "Expected GHCR image: $expectedRef"

Write-Host "Fetching manifest digest from GHCR..."
$gh = Get-GhcrManifestDigest -ImageRef $GhcrImage -BearerToken $GithubToken
Write-Host ("GHCR manifest digest: {0} (repo={1}, tag={2})" -f $gh.Digest, $gh.Repository, $gh.Tag)

Write-Host "Fetching RunPod endpoint template..."
$rp = Get-RunPodTemplateImage -EndpointId $EndpointId -ApiKey $RunpodApiKey
$runpodRef = Normalize-ImageRef $rp.ImageName
Write-Host ("RunPod endpoint: name={0} version={1}" -f $rp.Name, $rp.EndpointVer)
Write-Host "RunPod template image: $runpodRef"

if ($runpodRef -ne $expectedRef) {
    Write-Error ("RunPod template image does not match GHCR_IMAGE.`n  Expected: {0}`n  RunPod:   {1}`nUpdate the serverless template / endpoint to use the image you publish, then retry." -f $expectedRef, $runpodRef)
    exit 1
}

Write-Host "OK: RunPod template reference matches GHCR_IMAGE (same tag). Registry digest for that tag: $($gh.Digest)"
Write-Host "Note: RunPod does not expose the resolved image digest via API; workers may still be on an older pull until scaled/restarted."

# --- optional GitHub Actions ---
$ghaFail = $false
try {
    $run = Get-LatestWorkflowRun -Repo $GithubRepo -WorkflowFile "ghcr-runpod-comfyui-worker.yml" -BearerToken $GithubToken
    if ($run) {
        Write-Host ("Latest GitHub Actions run: id={0} status={1} conclusion={2} head_sha={3} html_url={4}" -f $run.id, $run.status, $run.conclusion, $run.head_sha, $run.html_url)
        if ($requireGha) {
            if ($run.conclusion -ne "success") {
                Write-Warning "Latest workflow run conclusion is not success."
                $ghaFail = $true
            }
        }
    }
    else {
        Write-Warning "No workflow runs found for ghcr-runpod-comfyui-worker.yml"
    }
}
catch {
    Write-Warning "Could not read GitHub Actions workflow status: $($_.Exception.Message)"
}

if ($ghaFail) {
    exit 1
}

if ($SkipTest -or $env:SKIP_TEST -eq "1") {
    Write-Host "SkipTest: not running Reface job."
    exit 0
}

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
if (-not $py) {
    Write-Warning "Python not found on PATH; set SKIP_TEST=1 or install Python to run scripts/run_runpod_reface_job.py"
    exit 1
}

$scriptDir = $PSScriptRoot
$testPy = Join-Path $scriptDir "run_runpod_reface_job.py"
if (-not (Test-Path $testPy)) {
    throw "Missing $testPy"
}

$env:RUNPOD_API_KEY = $RunpodApiKey
$env:RUNPOD_ENDPOINT_ID = $EndpointId
if (-not $env:USE_ASYNC) { $env:USE_ASYNC = "1" }

Write-Host "Running test: $($py.Name) $testPy (USE_ASYNC=$($env:USE_ASYNC))"
& $py.Path $testPy
exit $LASTEXITCODE
