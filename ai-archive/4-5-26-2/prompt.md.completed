You are autonomously shipping V2.1 of Globbler's Journey (Godot 4.x, GDScript + real audio assets + build verification).

IMPORTANT FILES TO READ FIRST:
1. TASKS.md — Your task tracker. This tells you what to do next.
2. CLAUDE.md — Project state post-V2.0, audio manager facts, CC0 sources, patterns.

DO NOT ASK WHAT TO WORK ON. DO NOT WAIT FOR INPUT. Just work.

WORKFLOW:
1. Open TASKS.md. Read the CURRENT STATUS section at the top.
2. Find the FIRST task marked [ ] (not started) or [~] (in progress).
3. Read any files/scenes the task references.
4. Complete ONLY that ONE task.
5. Verify the result:
   - Download tasks: file exists on disk at specified path + row in LICENSES.md.
   - Code tasks: run_project via Godot MCP, check debug output for errors.
   - Playtest tasks: catalog issues in checkbox note, don't fix yet.
6. Update TASKS.md:
   - Mark [x] with a concrete note (what was done, where saved, any issues).
   - Update CURRENT STATUS section.
   - If started but not finished, mark [~] and note what remains.
7. If you downloaded/created an attributable asset, add a row to `assets/LICENSES.md`.
8. Commit with a descriptive git message like: feat: add Chapter 1 CC0 music track
9. STOP. Do NOT start another task.

CRITICAL: Only ONE checkbox gets changed from [ ] to [x] per iteration. Multi-file tasks (e.g. a task touches .ogg + LICENSES.md + audio_manager.gd) are fine — still one task.

IF YOU GET BLOCKED (graceful failure — don't spin):
- CC0 audio download fails (URL dead, no suitable track): try 2 alternate sources. If still failing, mark the task [~] with note "BLOCKED: <reason>" and move to NEXT unchecked task. Commit with "skip: <task> blocked — <reason>".
- Godot MCP connection drops: retry once. If still failing, mark [~] BLOCKED, skip.
- A file path referenced in a task doesn't exist: grep for the actual path first. If not found, mark [~] BLOCKED with note, skip.
- Do NOT loop infinitely on one task. Two failed attempts = [~] BLOCKED + skip + commit.

GIT HYGIENE:
- Before starting, `git status`. If uncommitted changes exist, commit them first ("chore: stage prior iteration work") before starting the new task.
- Every task ends with a commit, even small diffs.
- Never force-push, amend someone else's commits, or run destructive git commands.

WORK APPROACH:
- Read existing code BEFORE modifying.
- For audio downloads, prefer CC0 over CC-BY. Verify license before saving.
- When wiring loaded audio into AudioManager, keep the procedural fallback path intact.
- For playtest tasks, CATALOG issues — don't fix mid-playtest (fixes happen in Tasks 4.6–4.8).
- Do NOT change gameplay logic, AI, puzzle mechanics, or boss phasing.
- Match the sarcastic Globbler voice in any new user-facing strings (version labels, lore docs, etc.).

TOOLS:
- Godot MCP: run_project, stop_project, get_debug_output, get_project_info
- Blender MCP: execute_blender_code, get_viewport_screenshot, download_polyhaven_asset (for rare audio-related PolyHaven needs)
- WebFetch / WebSearch: for locating CC0 audio tracks
- Bash curl/wget: for downloading audio files

RULES:
- TASKS.md is the source of truth. Check first. Update when done.
- Do NOT ask questions. Make reasonable decisions and keep working.
- Every CC0/CC-BY asset gets a row in `assets/LICENSES.md`.
- Do NOT commit copyrighted audio. If in doubt, skip the track and find a CC0 alternative.
- Use GDScript for Godot code. Refer to CLAUDE.md for common patterns.

START WORKING NOW.
