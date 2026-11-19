# E:\ChessToDie\tasks\dispatch_sprint.ps1
$ErrorActionPreference = "Continue"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $projectRoot) { $projectRoot = "E:\ChessToDie" }
Set-Location $projectRoot

Write-Host "=== Auto-Dispatch Sprint 1 (Ag2 & Ag3) ==="
Write-Host "Working Directory: $projectRoot"

# Clean previous logs
"" | Set-Content -Path "tasks/ag2.log" -Encoding UTF8
"" | Set-Content -Path "tasks/ag2_err.log" -Encoding UTF8
"" | Set-Content -Path "tasks/ag3.log" -Encoding UTF8
"" | Set-Content -Path "tasks/ag3_err.log" -Encoding UTF8

# Start Ag2 (Coder) via Start-Job reading prompt from stdin
$jobAg2 = Start-Job -ScriptBlock {
    param($dir)
    Set-Location $dir
    Get-Content -Raw tasks/ag2_prompt.txt -Encoding UTF8 | agy --dangerously-skip-permissions > tasks/ag2.log 2> tasks/ag2_err.log
} -ArgumentList $projectRoot

# Start Ag3 (Artist) via Start-Job reading prompt from stdin
$jobAg3 = Start-Job -ScriptBlock {
    param($dir)
    Set-Location $dir
    Get-Content -Raw tasks/ag3_prompt.txt -Encoding UTF8 | agy --dangerously-skip-permissions > tasks/ag3.log 2> tasks/ag3_err.log
} -ArgumentList $projectRoot

Write-Host "Ag2 Job ID: $($jobAg2.Id), Ag3 Job ID: $($jobAg3.Id)"
Write-Host "Waiting for Ag2 and Ag3 to finish..."

Wait-Job -Job $jobAg2, $jobAg3

Receive-Job -Job $jobAg2, $jobAg3

Remove-Job -Job $jobAg2, $jobAg3 -Force

Write-Host "=== Auto-Dispatch Sprint 1 Finished ==="
