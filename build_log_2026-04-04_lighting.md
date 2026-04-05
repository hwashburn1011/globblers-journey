# Lighting Smoke Test — 2026-04-04

## Test Environment
- Godot 4.4.1 stable (mono), Vulkan Forward+
- GPU: NVIDIA GeForce RTX 3070
- Platform: Windows 10

## Issues Found & Fixed During This Pass

### CRITICAL: HDRI .tres files had fake UIDs
- All 5 `chapter_*.tres` and `base_env.tres` used hand-written fake UIDs (e.g. `uid://ch1_sky_hdri`) that Godot couldn't resolve.
- HDR files existed on disk but had never been imported by the editor (no `.import` files).
- **Fix:** Launched Godot editor to trigger asset import, then updated all `.tres` files with real Godot-assigned UIDs and changed `type="Texture2D"` to `type="CompressedTexture2D"`. Removed fake resource-level UIDs from `[gd_resource]` headers.

### CRITICAL: `light_angular_size` property doesn't exist
- All 5 chapter scripts set `dir_light.light_angular_size` on DirectionalLight3D, which is not a valid property in Godot 4.4.1. Caused debugger break on every chapter load.
- **Fix:** Removed the `light_angular_size` assignment from all 5 chapter scripts (`terminal_wastes.gd`, `training_grounds.gd`, `prompt_bazaar.gd`, `model_zoo.gd`, `alignment_citadel.gd`).

## Per-Chapter Results

### Chapter 1 — Terminal Wastes
- **Status:** PASS
- **Loads:** Yes, WorldEnvironment with empty_warehouse_01 HDRI active
- **Runtime errors:** None (only pre-existing V1.2 GDScript warnings)
- **Notes:** Level loads fully — 5 rooms, boss arena constructed, player spawns, audio crossfade works

### Chapter 2 — Training Grounds
- **Status:** PASS
- **Loads:** Yes, WorldEnvironment with blue_photo_studio HDRI active
- **Runtime errors:** None
- **Notes:** 5 neuron-rooms loaded, enemies spawned, boss arena constructed, checkpoint saved

### Chapter 3 — Prompt Bazaar
- **Status:** PASS
- **Loads:** Yes, WorldEnvironment with carpentry_shop_02 HDRI active
- **Runtime errors:** None
- **Notes:** 5 market districts loaded, enemy merchants deployed, boss arena constructed

### Chapter 4 — Model Zoo
- **Status:** PASS
- **Loads:** Yes, WorldEnvironment with abandoned_hall_01 HDRI active
- **Runtime errors:** None
- **Notes:** 5 exhibit zones loaded (Entrance, Fossil Wing, Nightmare Gallery, Office Ruins, Foundation Atrium), 13 enemies spawned

### Chapter 5 — Alignment Citadel
- **Status:** PASS
- **Loads:** Yes, WorldEnvironment with blocky_photo_studio HDRI active
- **Runtime errors:** None
- **Notes:** 5 zones loaded (Gate, Classifier Hall, RLHF Chamber, Policy Wing, Alignment Core), 18 enemies deployed, boss arena sealed

## Pre-existing Warnings (V1.2 code, not introduced by lighting pass)
- Unused parameter warnings (`_delta`, `_dist`, `_targets`, etc.) across multiple scripts
- Variable shadowing warnings (`health_comp`, `box`, `mat`)
- Integer division warnings
- These are all GDScript linter warnings, not runtime errors. They predate the graphics pass.

## Summary
All 5 chapters load and run without new runtime errors after fixing the two critical issues (fake UIDs in .tres files and invalid `light_angular_size` property). Pass 1 lighting infrastructure is now functional end-to-end.
