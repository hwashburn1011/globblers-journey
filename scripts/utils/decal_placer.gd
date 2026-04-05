class_name DecalPlacer
extends RefCounted
## Utility for placing themed floor/wall decals in chapter rooms.
## Each chapter calls place_chapter_decals() with its room data and theme config.

const DECAL_TEXTURES := {
	"oil_puddle": "res://assets/textures/decals/decal_oil_puddle.png",
	"scorch_mark": "res://assets/textures/decals/decal_scorch_mark.png",
	"circuit_traces": "res://assets/textures/decals/decal_circuit_traces.png",
	"circuit_emission": "res://assets/textures/decals/decal_circuit_emission.png",
	"warning_stripes": "res://assets/textures/decals/decal_warning_stripes.png",
	"runic_circle": "res://assets/textures/decals/decal_runic_circle.png",
	"ember_glow": "res://assets/textures/decals/decal_ember_glow.png",
	"dust_patch": "res://assets/textures/decals/decal_dust_patch.png",
	"light_pool": "res://assets/textures/decals/decal_light_pool.png",
}

## Place decals into a parent node based on room data and a theme config.
## theme_config: Array of dicts with keys:
##   "texture": key from DECAL_TEXTURES
##   "emission": optional key from DECAL_TEXTURES for emission channel
##   "emission_energy": float (default 2.0)
##   "size": Vector3 extents for the decal (default Vector3(2, 1, 2))
##   "count_per_room": int (default 1)
##   "floor": bool — true for floor decals, false for wall (default true)
##   "modulate": Color (default white)
static func place_chapter_decals(parent: Node3D, rooms: Dictionary, theme_config: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = parent.get_instance_id()  # Deterministic per instance

	for room_key in rooms:
		var room = rooms[room_key]
		var room_pos: Vector3 = room["pos"]
		var room_size: Vector2 = room["size"]

		for cfg in theme_config:
			var tex_key: String = cfg.get("texture", "oil_puddle")
			var emission_key: String = cfg.get("emission", "")
			var emission_energy: float = cfg.get("emission_energy", 2.0)
			var decal_size: Vector3 = cfg.get("size", Vector3(2.0, 1.0, 2.0))
			var count: int = cfg.get("count_per_room", 1)
			var is_floor: bool = cfg.get("floor", true)
			var modulate: Color = cfg.get("modulate", Color.WHITE)

			for i in range(count):
				var decal := Decal.new()
				decal.name = "Decal_%s_%s_%d" % [room_key, tex_key, i]

				# Load textures
				var albedo_tex = load(DECAL_TEXTURES.get(tex_key, ""))
				if albedo_tex:
					decal.texture_albedo = albedo_tex

				if emission_key != "":
					var emit_tex = load(DECAL_TEXTURES.get(emission_key, ""))
					if emit_tex:
						decal.texture_emission = emit_tex
						decal.emission_energy = emission_energy

				decal.size = decal_size
				decal.modulate = modulate

				# Position within room bounds
				var half_x := room_size.x * 0.4
				var half_z := room_size.y * 0.4
				var offset_x := rng.randf_range(-half_x, half_x)
				var offset_z := rng.randf_range(-half_z, half_z)

				if is_floor:
					decal.position = room_pos + Vector3(offset_x, 0.05, offset_z)
					# Floor decals project downward (default)
				else:
					# Wall decal — pick a random wall
					var wall_side := rng.randi_range(0, 3)
					var wall_pos := room_pos
					var wall_h: float = room.get("wall_h", 6.0)
					var y_offset := rng.randf_range(1.0, wall_h * 0.7)
					match wall_side:
						0: # +X wall
							wall_pos += Vector3(room_size.x * 0.5, y_offset, offset_z)
							decal.rotation.z = PI / 2
						1: # -X wall
							wall_pos += Vector3(-room_size.x * 0.5, y_offset, offset_z)
							decal.rotation.z = -PI / 2
						2: # +Z wall
							wall_pos += Vector3(offset_x, y_offset, room_size.y * 0.5)
							decal.rotation.x = -PI / 2
						3: # -Z wall
							wall_pos += Vector3(offset_x, y_offset, -room_size.y * 0.5)
							decal.rotation.x = PI / 2
					decal.position = wall_pos

				# Random Y rotation for floor decals
				if is_floor:
					decal.rotation.y = rng.randf_range(0, TAU)

				# Random scale variation ±20%
				var scale_var := rng.randf_range(0.8, 1.2)
				decal.size *= scale_var

				parent.add_child(decal)
