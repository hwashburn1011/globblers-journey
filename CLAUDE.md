# GLOBBLER'S JOURNEY — Graphics & Art Pass (V2.0)

## YOU ARE UPGRADING VISUAL QUALITY IN AN EXISTING GODOT 4.x PROJECT

The gameplay is complete (V1.2). This pass replaces CSG placeholder geometry with real 3D models, PBR materials, HDRI lighting, post-processing, and VFX. You are NOT changing gameplay logic. Target quality: stylized indie-ship tier (~Death's Door / Tunic / Hi-Fi Rush).

**For what to do next, see TASKS.md — that is the source of truth.**

---

## RULES

- Do NOT change gameplay logic, enemy AI, puzzle mechanics, or boss phase timing.
- Do NOT introduce new enemies/puzzles/chapters. Only swap visuals on what exists.
- One task = one commit. Stop after each task.
- Asset files (.glb, .blend, .hdr, .png, textures) go under `assets/`. Keep source `.blend` files so future edits are possible.
- Every downloaded asset gets a row in `assets/LICENSES.md` (name, source, license, URL, used in).
- When a task says "via blender-mcp", use `mcp__blender__execute_blender_code` for scripted building and `mcp__blender__get_viewport_screenshot` to verify.
- When a task says "via Poly Haven", use `mcp__blender__search_polyhaven_assets` then `mcp__blender__download_polyhaven_asset`.
- When a task says "via Sketchfab", use `mcp__blender__search_sketchfab_models` (CC0 / royalty-free only).
- Godot MCP (`run_project`, `get_debug_output`) for in-game validation.

---

## ASSET DIRECTORY LAYOUT

```
assets/
  models/
    player/globbler.glb
    enemies/<enemy_name>.glb
    bosses/<boss_name>.glb
    environment/<prop_name>.glb
  blender_source/*.blend        # keep all source files for future edits
  hdri/ch1_sky.hdr, ...         # Poly Haven HDRIs per chapter
  textures/pbr/<material>/      # PBR texture sets
  environments/chapter_<n>.tres # WorldEnvironment resources
  shaders/ (existing folder, add new .gdshader files here)
  fonts/terminal_mono.ttf
  ui/icons/*.png
  ui/chapter_thumb_<n>.png
  LICENSES.md                   # CC0/CC-BY attribution table
```

---

## CHAPTER COLOR PALETTES (LOCKED)

| Chapter | Theme | Primary | Accent | Fog Color |
|---|---|---|---|---|
| 1 Terminal Wastes | dark CRT | #000000 | #39FF14 | (0.1, 0.4, 0.15) |
| 2 Training Grounds | cool neural | #0A1A1A | #4AE0A5 | (0.3, 0.7, 0.6) |
| 3 Prompt Bazaar | warm market | #2A1812 | #FFAA33 / #FF3EA5 | (0.9, 0.6, 0.3) |
| 4 Model Zoo | dusty museum | #2A2820 | #E8D8B0 | (0.6, 0.6, 0.55) |
| 5 Alignment Citadel | clinical | #F5F8FF | #7FB5FF | (0.9, 0.95, 1.0) |

---

## GLOBBLER DESIGN REFERENCE

Reference art lives at `C:/Users/hwash/Desktop/globbler.jpg`.
Key traits: stubby chibi robot, ~0.9m tall, rounded dark-metal torso integrated with hood/helmet, large triangular glowing-green angry eyes, chest terminal screen, cables connecting head to torso, stubby boots, chunky wrench. Palette: dark metal (#141614) + neon green (#39FF14) emission.

---

## BLENDER-MCP WORKFLOW

**Build a mesh:**
```
execute_blender_code with a Python snippet using bpy:
  import bpy
  # clear, build primitives, boolean, subdivide, material, etc.
```

**Verify visually:**
```
get_viewport_screenshot(max_size=800)  # render current viewport
```

**Export to GLB:**
```python
bpy.ops.export_scene.gltf(
    filepath="C:/Users/hwash/Documents/globblers-journey/assets/models/player/globbler.glb",
    export_format='GLB',
    export_apply=True,
    export_materials='EXPORT',
    export_yup=True,
)
```

**Save source .blend:**
```python
bpy.ops.wm.save_as_mainfile(filepath="C:/Users/hwash/Documents/globblers-journey/assets/blender_source/globbler.blend")
```

---

## GODOT IMPORT WORKFLOW

GLB files auto-import in Godot. To replace CSG with a new GLB mesh:
1. Drop `.glb` into `assets/models/...`
2. In target `.tscn`, add a Node3D child and set scene/mesh to the GLB
3. Delete old CSG siblings but KEEP CollisionShape3D (gameplay depends on it)
4. Reset transforms; tune scale if needed

---

## AUTOLOADS (UNCHANGED)

GameManager, RespawnManager, GlobEngine, DialogueManager, SaveSystem, AudioManager, ProgressionManager.

---

## COMMON PATTERNS FOR THIS PASS

**Shader material override on a GLB mesh:**
```gdscript
var mat := ShaderMaterial.new()
mat.shader = preload("res://assets/shaders/character_rim.gdshader")
mesh_instance.material_override = mat
```

**Reduce-motion gate for animated shaders:**
```gdscript
var gm = get_node_or_null("/root/GameManager")
if gm and gm.reduce_motion:
    mat.set_shader_parameter("animate", false)
```

**WorldEnvironment instance in a chapter _ready():**
```gdscript
var env_node := WorldEnvironment.new()
env_node.environment = preload("res://assets/environments/chapter_1.tres")
add_child(env_node)
```

**MultiMesh scatter:**
```gdscript
var mmi := MultiMeshInstance3D.new()
mmi.multimesh = MultiMesh.new()
mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
mmi.multimesh.mesh = preload("res://assets/models/environment/prop_cpu_01.glb").instantiate().get_child(0).mesh
mmi.multimesh.instance_count = positions.size()
for i in range(positions.size()):
    mmi.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rotations[i]).scaled(Vector3.ONE * scales[i]), positions[i]))
add_child(mmi)
```

---

## THINGS TO LEAVE ALONE IN THIS PASS

- Enemy AI, boss phases, puzzle logic, health/damage values.
- Save format (additive only — do not remove keys).
- Gameplay input bindings.
- Existing `scripts/autoload/*.gd` logic (beyond additive settings).
- V1.2 systems: RespawnManager, GameOver flow, tutorial hints, settings persistence, dialogue history.

---

## QUALITY BAR

A task is "done" when:
1. New visual asset exists on disk AND shows up in-game (MCP screenshot).
2. No new runtime errors introduced (check Godot MCP `get_debug_output`).
3. Asset attributions recorded in `assets/LICENSES.md` if applicable.
4. `.blend` source saved if a mesh was built in Blender.
5. TASKS.md updated with [x] + a concrete note of what was built and where.
