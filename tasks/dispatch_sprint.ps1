# E:\ChessToDie\tasks\dispatch_sprint.ps1
# PowerShell / dispatch_sprint.ps1 / Windows PowerShell 5.1+ / ChessToDie Auto-Dispatch (Ag2-Ag5)
param(
    [string]$Model = "gemini-4-neon-medium"
)

$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = "E:\ChessToDie" }
Set-Location $root

Write-Host "=== Auto-Dispatch Sprint (Ag2-Ag5 | $Model) ==="
Write-Host "Working Directory: $root"

$jobs = @()
$dispatched = @()

# 1. Luong CPU/Code & Godot UI (Ag2 & Ag3 chay song song)
foreach ($ag in @("ag2", "ag3")) {
    $promptPath = Join-Path $root "tasks\${ag}_prompt.txt"
    if (Test-Path $promptPath) {
        "" | Set-Content -Path (Join-Path $root "tasks\${ag}.log") -Encoding UTF8
        "" | Set-Content -Path (Join-Path $root "tasks\${ag}_err.log") -Encoding UTF8
        $dispatched += $ag
        Write-Host "[CPU Lane] Starting $ag..."
        $jobs += Start-Job -Name $ag -ArgumentList $root, $ag, $Model -ScriptBlock {
            param($dir, $name, $mdl)
            Set-Location $dir
            Get-Content -Raw "tasks\${name}_prompt.txt" -Encoding UTF8 |
                agy --model $mdl --dangerously-skip-permissions > "tasks\${name}.log" 2> "tasks\${name}_err.log"
        }
    }
}

# 2. Luong GPU/Render (Ag4 Blender -> Ag5 SD Forge chay noi tiep de tranh tran 4GB VRAM)
$hasAg4 = Test-Path (Join-Path $root "tasks\ag4_prompt.txt")
$hasAg5 = Test-Path (Join-Path $root "tasks\ag5_prompt.txt")
if ($hasAg4 -or $hasAg5) {
    if ($hasAg4) {
        "" | Set-Content -Path (Join-Path $root "tasks\ag4.log") -Encoding UTF8
        "" | Set-Content -Path (Join-Path $root "tasks\ag4_err.log") -Encoding UTF8
        $dispatched += "ag4"
    }
    if ($hasAg5) {
        "" | Set-Content -Path (Join-Path $root "tasks\ag5.log") -Encoding UTF8
        "" | Set-Content -Path (Join-Path $root "tasks\ag5_err.log") -Encoding UTF8
        $dispatched += "ag5"
    }
    Write-Host "[GPU Lane] Starting sequential pipeline (Ag4=$hasAg4 -> Ag5=$hasAg5)..."
    $jobs += Start-Job -Name "gpu_pipeline" -ArgumentList $root, $hasAg4, $hasAg5, $Model -ScriptBlock {
        param($dir, $run4, $run5, $mdl)
        Set-Location $dir
        if ($run4) {
            Get-Content -Raw "tasks\ag4_prompt.txt" -Encoding UTF8 |
                agy --model $mdl --dangerously-skip-permissions > "tasks\ag4.log" 2> "tasks\ag4_err.log"
        }
        if ($run5) {
            Get-Content -Raw "tasks\ag5_prompt.txt" -Encoding UTF8 |
                agy --model $mdl --dangerously-skip-permissions > "tasks\ag5.log" 2> "tasks\ag5_err.log"
        }
    }
}

if ($jobs.Count -eq 0) {
    Write-Host "No prompt files found in tasks\ (ag2_prompt.txt .. ag5_prompt.txt). Nothing to dispatch."
    exit 0
}

Write-Host ("Dispatched agents: " + ($dispatched -join ", "))
Write-Host ("Active Jobs: " + (($jobs | ForEach-Object { "$($_.Name)#$($_.Id)" }) -join ", "))
Write-Host "Waiting for all jobs to finish..."

Wait-Job -Job $jobs | Out-Null
Receive-Job -Job $jobs
Remove-Job -Job $jobs -Force

Write-Host "=== Dispatch Summary ==="
foreach ($ag in $dispatched) {
    $logSize = (Get-Item (Join-Path $root "tasks\${ag}.log")).Length
    $errSize = (Get-Item (Join-Path $root "tasks\${ag}_err.log")).Length
    Write-Host (" - {0}: log={1} bytes, err={2} bytes" -f $ag, $logSize, $errSize)
}
Write-Host "=== Auto-Dispatch Sprint Finished ==="
