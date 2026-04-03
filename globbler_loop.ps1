# ============================================
# GLOBBLER'S BUILD LOOP - PowerShell Edition
# ============================================
# Usage:
#   .\globbler_loop.ps1                    # Run until all tasks done
#   .\globbler_loop.ps1 -MaxIterations 50  # Safety cap
#   .\globbler_loop.ps1 -WaitSeconds 15    # Pause between runs
# ============================================

param(
    [int]$MaxIterations = 100,
    [int]$WaitSeconds = 10
)

$logFile = "build_log_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"

function Log {
    param([string]$msg, [string]$color = "Green")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $logFile -Value $line
}

function Get-TaskCounts {
    $done = 0
    $todo = 0
    $wip = 0
    if (Test-Path "TASKS.md") {
        $lines = Get-Content "TASKS.md"
        foreach ($line in $lines) {
            if ($line -match "- \[x\]") { $done++ }
            elseif ($line -match "- \[ \]") { $todo++ }
            elseif ($line -match "- \[~\]") { $wip++ }
        }
    }
    return @{ Done = $done; Todo = $todo; InProgress = $wip }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  GLOBBLER'S JOURNEY - BUILD LOOP" -ForegroundColor Green
Write-Host "  Runs until all tasks complete" -ForegroundColor Green
Write-Host "  Safety cap: $MaxIterations iterations" -ForegroundColor Green
Write-Host "  Log: $logFile" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (-not (Test-Path "project.godot")) {
    Write-Host "ERROR: No project.godot found! Run from project root." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "TASKS.md")) {
    Write-Host "ERROR: No TASKS.md found!" -ForegroundColor Red
    exit 1
}

# Feature branch check
$branch = git branch --show-current 2>$null
if ($branch -eq "main" -or $branch -eq "master") {
    $ts = Get-Date -Format "yyyyMMdd-HHmm"
    git checkout -b "globbler-build-$ts"
}

Log "Branch: $(git branch --show-current)"

# Show starting status
$counts = Get-TaskCounts
Write-Host "Starting: Done=$($counts.Done) | Todo=$($counts.Todo) | WIP=$($counts.InProgress)" -ForegroundColor Cyan
Write-Host ""

$buildPrompt = "STRICT RULES - READ CAREFULLY: 1. Open TASKS.md. Read the CURRENT STATUS section. 2. Find the FIRST single task marked with an unchecked box or a tilde box. 3. Build ONLY that ONE task. Do NOT move on to the next task. 4. When that ONE task is complete, update TASKS.md: mark that task with an x in the box, and update CURRENT STATUS with what you did and what the next task is. 5. Commit with a descriptive git message. 6. STOP. Do NOT start another task. You are done for this iteration. CRITICAL: Only ONE checkbox gets marked complete per iteration. If you find yourself about to start a second task, STOP and commit instead. Reference CLAUDE.md for design details. Use GDScript only. CSG primitives for 3D placeholders. Dark gray plus neon green number 39FF14. Sarcastic code comments. Do not ask questions. START NOW."

$iteration = 0

while ($true) {
    $iteration++

    # Check if all tasks are done
    $counts = Get-TaskCounts
    if ($counts.Todo -eq 0 -and $counts.InProgress -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  ALL TASKS COMPLETE!" -ForegroundColor Green
        Write-Host "  $($counts.Done) tasks finished in $iteration iterations" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        break
    }

    # Safety cap
    if ($iteration -gt $MaxIterations) {
        Write-Host ""
        Log "Hit safety cap of $MaxIterations iterations. Stopping." "Yellow"
        break
    }

    Write-Host ""
    Write-Host "======================================" -ForegroundColor Green
    Log "ITERATION $iteration (Done=$($counts.Done) | Left=$($counts.Todo + $counts.InProgress))"
    Write-Host "  (running silently - may take 5-15 min)" -ForegroundColor Yellow
    Write-Host "======================================" -ForegroundColor Green

    $startTime = Get-Date

    # Run Claude
    claude --dangerously-skip-permissions -p $buildPrompt 2>&1 | Tee-Object -FilePath $logFile -Append

    $elapsed = (Get-Date) - $startTime
    $minutes = [math]::Round($elapsed.TotalMinutes, 1)

    Log "Iteration $iteration done - took $minutes minutes"

    # Show what changed
    Write-Host ""
    Write-Host "--- RESULT ---" -ForegroundColor Cyan
    $lastCommit = git log --oneline -1 2>$null
    Write-Host "  Commit: $lastCommit" -ForegroundColor White

    $counts = Get-TaskCounts
    Write-Host "  Progress: Done=$($counts.Done) | Todo=$($counts.Todo) | WIP=$($counts.InProgress)" -ForegroundColor Cyan

    # Show current status from TASKS.md
    $statusLines = Get-Content "TASKS.md" | Where-Object { $_ -match "Last|Next|Known" }
    foreach ($line in $statusLines) {
        Write-Host "  $($line.Trim())" -ForegroundColor White
    }

    # Pause
    Write-Host ""
    Write-Host "  Pausing $WaitSeconds seconds..." -ForegroundColor DarkGray
    Start-Sleep -Seconds $WaitSeconds
}

Write-Host ""
Write-Host "Review:" -ForegroundColor Cyan
Write-Host "  git log --oneline -30" -ForegroundColor White
Write-Host "  cat TASKS.md" -ForegroundColor White
Write-Host "  Full log: $logFile" -ForegroundColor White
Write-Host ""
