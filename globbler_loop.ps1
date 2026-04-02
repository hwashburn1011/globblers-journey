# ============================================
# GLOBBLER'S BUILD LOOP - PowerShell Edition
# ============================================
# Usage:
#   .\globbler_loop.ps1                                                       # Fresh start
#   .\globbler_loop.ps1 -SessionId "d4817235-1970-478c-83ca-ec1ebf83a5b9"     # Resume session
#   .\globbler_loop.ps1 -Iterations 30
#   .\globbler_loop.ps1 -WaitSeconds 30
# ============================================

param(
    [string]$SessionId = "",
    [int]$Iterations = 15,
    [int]$WaitSeconds = 10
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  GLOBBLER'S JOURNEY - BUILD LOOP" -ForegroundColor Green
Write-Host "  Running $Iterations iterations" -ForegroundColor Green
if ($SessionId) {
    Write-Host "  Resuming session: $SessionId" -ForegroundColor Green
}
else {
    Write-Host "  Starting fresh session" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Safety checks
if (-not (Test-Path "project.godot")) {
    Write-Host "ERROR: No project.godot found!" -ForegroundColor Red
    Write-Host "Run this script from your Godot project root." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "CLAUDE.md")) {
    Write-Host "ERROR: No CLAUDE.md found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "prompt.md")) {
    Write-Host "ERROR: No prompt.md found!" -ForegroundColor Red
    exit 1
}

# Make sure we are on a feature branch
$branch = git branch --show-current 2>$null
if ($branch -eq "main" -or $branch -eq "master") {
    Write-Host "WARNING: You are on $branch. Creating a build branch..." -ForegroundColor Yellow
    $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
    git checkout -b "globbler-build-$timestamp"
}

$currentBranch = git branch --show-current
Write-Host "Branch: $currentBranch" -ForegroundColor Cyan
Write-Host ""

# Track the session ID across iterations
$currentSessionId = $SessionId

for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Green
    Write-Host "  ITERATION $i of $Iterations" -ForegroundColor Green
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "  $now" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    Write-Host ""

    if ($currentSessionId) {
        Write-Host "Resuming session: $currentSessionId" -ForegroundColor Cyan
        claude --dangerously-skip-permissions --resume $currentSessionId -p (Get-Content prompt.md -Raw)
    }
    else {
        Write-Host "Starting new session..." -ForegroundColor Cyan
        claude --dangerously-skip-permissions -p (Get-Content prompt.md -Raw)

        # After first run, find the session ID so we can resume it
        # Look at the .claude/projects directory for the most recent session
        Write-Host ""
        Write-Host "First run complete. Trying to find session ID..." -ForegroundColor Yellow
        Write-Host "Check Claude Code output above for a session ID." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If you see a session ID in the output, you can restart with:" -ForegroundColor Yellow
        Write-Host "  .\globbler_loop.ps1 -SessionId YOUR-SESSION-ID -Iterations $($Iterations - $i)" -ForegroundColor White
        Write-Host ""
        Write-Host "Or to find your latest session ID, run:" -ForegroundColor Yellow
        Write-Host "  claude sessions list" -ForegroundColor White
        Write-Host ""

        # Try to auto-detect: run claude sessions list and grab first UUID
        try {
            $sessionOutput = (claude sessions list 2>$null) | Out-String
            $uuidPattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
            $match = [regex]::Match($sessionOutput, $uuidPattern)
            if ($match.Success) {
                $currentSessionId = $match.Value
                Write-Host "AUTO-DETECTED session ID: $currentSessionId" -ForegroundColor Cyan
                Write-Host "Resuming this session for remaining iterations." -ForegroundColor Cyan
            }
            else {
                Write-Host "Could not auto-detect session ID. Each iteration will start fresh." -ForegroundColor Yellow
                Write-Host "This still works but Claude won't have context from previous iterations." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Could not run claude sessions list. Continuing without resume." -ForegroundColor Yellow
        }
    }

    # Check exit code
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Claude exited with error code $LASTEXITCODE" -ForegroundColor Yellow
        Write-Host "Continuing to next iteration..." -ForegroundColor Yellow
    }

    # Brief pause between iterations
    if ($i -lt $Iterations) {
        Write-Host ""
        Write-Host "Pausing $WaitSeconds seconds before next iteration..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $WaitSeconds
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD LOOP COMPLETE" -ForegroundColor Green
Write-Host "  $Iterations iterations finished" -ForegroundColor Green
if ($currentSessionId) {
    Write-Host "  Session: $currentSessionId" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Review changes:" -ForegroundColor Cyan
Write-Host "  git log --oneline -20" -ForegroundColor White
Write-Host ""
if ($currentSessionId) {
    Write-Host "Resume later:" -ForegroundColor Cyan
    Write-Host "  .\globbler_loop.ps1 -SessionId `"$currentSessionId`"" -ForegroundColor White
    Write-Host ""
}
