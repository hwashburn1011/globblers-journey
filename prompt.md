You are autonomously upgrading graphics in Globbler's Journey (Godot 4.x, GDScript + Blender via blender-mcp).

IMPORTANT FILES TO READ FIRST:
1. TASKS.md — Your task tracker. This tells you what to do next.
2. CLAUDE.md — Project context, file layout, asset workflow, Blender patterns.

DO NOT ASK WHAT TO WORK ON. DO NOT WAIT FOR INPUT. Just work.

WORKFLOW:
1. Open TASKS.md. Read the CURRENT STATUS section at the top.
2. Find the FIRST task marked [ ] (not started) or [~] (in progress).
3. Read any files/scenes mentioned in the task.
4. Complete ONLY that ONE task. Do NOT move on to the next.
5. Verify the result:
   - Blender tasks: get_viewport_screenshot and compare to reference.
   - Godot tasks: run_project via Godot MCP, check get_debug_output for errors.
   - Asset tasks: confirm file exists on disk at the specified path.
6. Update TASKS.md:
   - Mark the task [x] with a concrete note (what was built, where saved, any issues found).
   - Update CURRENT STATUS section with completed + next-up task.
   - If started but not finished, mark [~] and note what remains.
7. If you downloaded or created an attributable asset, add a row to `assets/LICENSES.md`.
8. If you built anything in Blender, save the .blend source to `assets/blender_source/`.
9. Commit everything with a descriptive git message like: feat: add Chapter 1 WorldEnvironment with terminal-green fog
10. STOP. Do NOT start another task. You are done for this iteration.

CRITICAL: Only ONE checkbox gets changed from [ ] to [x] per iteration. Multiple-file tasks (e.g. one task touches .blend + .glb + .tscn + LICENSES.md) are fine — that's still one task.

IF YOU GET BLOCKED (graceful failure — don't spin):
- Blender MCP tool errors/timeouts: retry once. If still failing, mark the task [~] with a note "BLOCKED: <reason>" and move to the NEXT unchecked task. Commit with message "skip: <task> blocked — <reason>".
- A Godot script you need doesn't exist or path is wrong: search for the actual pattern via Grep. If still can't find, mark [~] BLOCKED and skip.
- A GLB import breaks a scene: revert that one scene change (not the whole commit), mark the task [~] BLOCKED with note, skip.
- Do NOT loop infinitely on one task. Two failed attempts = [~] BLOCKED + skip + commit.
- Do NOT delete other people's work trying to unblock yourself.

GIT HYGIENE:
- Before starting a task, check `git status`. If there are uncommitted changes from a prior iteration, commit them first with message "chore: stage prior iteration work" before starting the new task.
- Every task ends with a commit, even if the task's diff is small.
- Never force-push, never amend someone else's commits, never run destructive git commands.

WORK APPROACH:
- Read existing code/scenes BEFORE modifying them.
- Don't refactor gameplay code while swapping visuals. Swap meshes, keep scripts.
- Keep CollisionShape3D nodes intact when replacing CSG meshes.
- If a task references reference art at C:/Users/hwash/Desktop/globbler.jpg, actually open/use it for visual matching.
- Iterate on Blender models with screenshots. If the first pass looks wrong, tweak and re-screenshot before exporting.
- Stylized low-poly is the target, not photorealism. Lean on lighting + shaders for polish.
- Match the sarcastic Globbler voice in any new user-facing strings.

BLENDER MCP TOOLS (for 3D asset tasks):
- execute_blender_code — run Python in Blender (build meshes, modifiers, materials, export)
- get_viewport_screenshot — visual verification
- get_scene_info / get_object_info — inspect scene state
- search_polyhaven_assets / download_polyhaven_asset — HDRIs + PBR textures
- search_sketchfab_models / download_sketchfab_model — CC0 meshes
- set_texture — apply textures to materials

GODOT MCP TOOLS (for in-game validation):
- run_project, stop_project — launch game
- get_debug_output — capture errors/warnings
- get_project_info — project structure

RULES:
- TASKS.md is the source of truth. Always check it first. Always update it when done.
- Do NOT ask questions. Make reasonable decisions and keep working.
- Do NOT change gameplay logic (AI, puzzles, damage values, phase timing).
- Do NOT remove existing save keys or break V1.2 systems.
- Use GDScript for Godot code; use bpy Python for Blender code.
- Every CC0/CC-BY asset gets a row in `assets/LICENSES.md`.
- Every Blender-built asset gets its source `.blend` saved.
- Refer to CLAUDE.md for project layout, palette table, and code patterns.

START WORKING NOW.
