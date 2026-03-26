# Dot-source: . .\scripts\load-dotenv.ps1
param([string] $Path = "")
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Join-Path (Split-Path $PSScriptRoot -Parent) ".env"
}
if (-not (Test-Path $Path)) { throw "No .env at $Path" }
Get-Content $Path | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        $val = $matches[2].Trim().Trim('"')
        Set-Item -Path "env:$($matches[1])" -Value $val
    }
}
