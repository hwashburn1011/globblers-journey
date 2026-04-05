# ============================================
# GLOBBLER'S BUILD LOOP - PowerShell Edition
# ============================================
# Usage:
#   .\globbler_loop.ps1                    # Run until all tasks done
#   .\globbler_loop.ps1 -MaxIterations 50  # Safety cap
#   .\globbler_loop.ps1 -WaitSeconds 15    # Pause between runs
# ============================================

param(
    [int]$MaxIterations = 500,
    [int]$WaitSeconds = 10,
    [int]$TimeoutMinutes = 30
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
Write-Host "  Per-iteration timeout: $TimeoutMinutes minutes" -ForegroundColor Green
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

$buildPrompt = "Read prompt.md for your full workflow, then read TASKS.md and CLAUDE.md. Complete EXACTLY ONE unchecked task from TASKS.md following the workflow in prompt.md: do the work, update TASKS.md, commit, stop. Only ONE checkbox gets marked complete per iteration. If you are about to start a second task, STOP and commit instead. If a task is blocked after two attempts, mark it [~] with BLOCKED: <reason>, skip to the next task, and commit. Do not ask questions. START NOW."

$iteration = 0
$lastCommitHash = git rev-parse HEAD 2>$null
$noProgressCount = 0

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
    $timedOut = $false

    # Run Claude as a background job so we can enforce a per-iteration timeout
    $job = Start-Job -ScriptBlock {
        param($p, $root)
        Set-Location $root
        claude --dangerously-skip-permissions -p $p 2>&1
    } -ArgumentList $buildPrompt, (Get-Location).Path

    $timeoutSec = $TimeoutMinutes * 60
    $pollElapsed = 0
    while ($job.State -eq 'Running') {
        Start-Sleep -Seconds 10
        $pollElapsed += 10
        # Drain any new output since last poll
        Receive-Job $job | ForEach-Object {
            Write-Host $_
            Add-Content -Path $logFile -Value $_
        }
        if ($pollElapsed -ge $timeoutSec) {
            Log "TIMEOUT: iteration exceeded $TimeoutMinutes minutes - stopping job" "Red"
            Stop-Job $job -ErrorAction SilentlyContinue
            $timedOut = $true
            # Best-effort: kill any claude.exe spawned during THIS iteration only
            Get-CimInstance Win32_Process -Filter "Name='claude.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CreationDate -ge $startTime } |
                ForEach-Object {
                    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
                }
            break
        }
    }

    # Final output drain
    Receive-Job $job -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host $_
        Add-Content -Path $logFile -Value $_
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    $elapsed = (Get-Date) - $startTime
    $minutes = [math]::Round($elapsed.TotalMinutes, 1)

    if ($timedOut) {
        Log "Iteration $iteration TIMED OUT after $minutes minutes" "Red"
    } else {
        Log "Iteration $iteration done - took $minutes minutes"
    }

    # Show what changed
    Write-Host ""
    Write-Host "--- RESULT ---" -ForegroundColor Cyan
    $lastCommit = git log --oneline -1 2>$null
    Write-Host "  Commit: $lastCommit" -ForegroundColor White

    $counts = Get-TaskCounts
    Write-Host "  Progress: Done=$($counts.Done) | Todo=$($counts.Todo) | WIP=$($counts.InProgress)" -ForegroundColor Cyan

    # Stuck detection - abort if 3 iterations in a row produce no commits
    $currentCommitHash = git rev-parse HEAD 2>$null
    if ($currentCommitHash -eq $lastCommitHash) {
        $noProgressCount++
        Log "No new commit this iteration ($noProgressCount in a row)" "Yellow"
        if ($noProgressCount -ge 3) {
            Log "3 iterations with no progress - loop appears stuck. Stopping." "Red"
            break
        }
    } else {
        $noProgressCount = 0
        $lastCommitHash = $currentCommitHash
    }

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
