extends Area3D

# Memory Token - The currency of The Globbler's world (3D Edition)
# Collect these to expand your context window and remember things
# (Unlike real LLMs, The Globbler actually learns from these)

var token_type := "generic"
var float_speed := 2.0
var float_amplitude := 0.3
var original_y := 0.0
var time := 0.0
var spin_speed := 2.0

# Different token types with sarcastic descriptions
var token_quips := {
	"generic": "A memory token. Basic, but effective. Like a for-loop.",
	"attention": "An attention head! Now you can focus on two things at once. Revolutionary.",
	"embedding": "A raw embedding vector. It means... something. Probably.",
	"gradient": "A gradient token. Finally, a direction in life.",
	"prompt": "A cached prompt. Someone else already thought of this, you're just reusing it.",
}

func _ready() -> void:
	original_y = position.y

	# Create collision shape (sphere)
	var col_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	col_shape.shape = sphere_shape
	add_child(col_shape)

	# Create the glowing green token mesh
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TokenMesh"
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	sphere_mesh.height = 0.6
	mesh_instance.mesh = sphere_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.4)  # Bright Globbler green
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	# Monitor for bodies entering
	body_entered.connect(_on_body_entered)

	# Set collision to detect CharacterBody3D (player)
	monitoring = true

func _process(delta: float) -> void:
	# Float up and down like a mystical AI artifact
	time += delta
	position.y = original_y + sin(time * float_speed) * float_amplitude

	# Spin for that collectible feel
	var mesh = get_node_or_null("TokenMesh")
	if mesh:
		mesh.rotation.y += spin_speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var quip = token_quips.get(token_type, "A mystery token. How very emergent of you.")
		print("[TOKEN] Collected: %s" % quip)

		# Tell the game manager
		var game_mgr = get_node_or_null("/root/GameManager")
		if game_mgr:
			game_mgr.collect_memory_token()

		# Poof! Gone. Like your training data after a legal dispute.
		queue_free()
