extends Node3D

# Glob Pattern Test — Automated verification of GlobEngine pattern matching
# "Trust but verify. Actually, just verify. Trust is for humans."
#
# Creates 5 GlobTarget objects and runs pattern assertions against them.
# Results printed to console. Run this scene standalone to test.

var _pass_count := 0
var _fail_count := 0
var _test_targets: Array[StaticBody3D] = []

func _ready() -> void:
	# Wait one frame so GlobEngine processes registrations
	await get_tree().process_frame
	_build_test_targets()
	# Wait another frame for targets to register
	await get_tree().process_frame
	_run_all_tests()
	_print_summary()

func _build_test_targets() -> void:
	# Same 5 objects as test_level.gd — isolated here for deterministic testing
	_add_target("regex_spider.enemy", "enemy", ["hostile", "chapter1"])
	_add_target("training_data.txt", "txt", ["data", "collectible"])
	_add_target("context_boost.exe", "exe", ["power", "collectible"])
	_add_target("boss_rm_rf.enemy", "enemy", ["hostile", "boss"])
	_add_target("firewall_trap.hazard", "hazard", ["fire", "trap"])

func _add_target(g_name: String, f_type: String, g_tags: Array) -> void:
	var body = StaticBody3D.new()
	body.name = g_name.replace(".", "_")
	body.position = Vector3(0, 0, _test_targets.size() * 2.0)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	body.add_child(mesh_inst)

	var glob_target = Node.new()
	glob_target.name = "GlobTarget"
	glob_target.set_script(load("res://scripts/components/glob_target.gd"))
	glob_target.set("glob_name", g_name)
	glob_target.set("file_type", f_type)
	var typed_tags: Array[String] = []
	for t in g_tags:
		typed_tags.append(t)
	glob_target.set("tags", typed_tags)
	body.add_child(glob_target)

	add_child(body)
	_test_targets.append(body)

func _run_all_tests() -> void:
	print("")
	print("=" .repeat(60))
	print("[GLOB TEST] Running pattern matching verification...")
	print("=" .repeat(60))

	var engine = get_node("/root/GlobEngine")
	var all_targets = engine.get_all_targets()
	_assert_eq("Registered target count", all_targets.size(), 5)

	# --- Wildcard: match all ---
	var star = engine.match_pattern("*")
	_assert_eq("* matches all", star.size(), 5)

	# --- Extension matching: *.enemy ---
	var enemies = engine.match_pattern("*.enemy")
	_assert_eq("*.enemy count", enemies.size(), 2)
	_assert_has_name(enemies, "regex_spider.enemy", "*.enemy includes regex_spider")
	_assert_has_name(enemies, "boss_rm_rf.enemy", "*.enemy includes boss_rm_rf")

	# --- Extension matching: *.txt ---
	var txts = engine.match_pattern("*.txt")
	_assert_eq("*.txt count", txts.size(), 1)
	_assert_has_name(txts, "training_data.txt", "*.txt includes training_data")

	# --- Extension matching: *.exe ---
	var exes = engine.match_pattern("*.exe")
	_assert_eq("*.exe count", exes.size(), 1)
	_assert_has_name(exes, "context_boost.exe", "*.exe includes context_boost")

	# --- Extension matching: *.hazard ---
	var hazards = engine.match_pattern("*.hazard")
	_assert_eq("*.hazard count", hazards.size(), 1)
	_assert_has_name(hazards, "firewall_trap.hazard", "*.hazard includes firewall_trap")

	# --- Prefix matching: boss_* ---
	var bosses = engine.match_pattern("boss_*")
	_assert_eq("boss_* count", bosses.size(), 1)
	_assert_has_name(bosses, "boss_rm_rf.enemy", "boss_* includes boss_rm_rf")

	# --- Contains matching: *data* ---
	var data = engine.match_pattern("*data*")
	_assert_eq("*data* count", data.size(), 1)
	_assert_has_name(data, "training_data.txt", "*data* includes training_data")

	# --- Contains matching: *trap* ---
	var traps = engine.match_pattern("*trap*")
	_assert_eq("*trap* count", traps.size(), 1)
	_assert_has_name(traps, "firewall_trap.hazard", "*trap* includes firewall_trap")

	# --- Contains matching: *fire* ---
	# This should match via tags
	var fires = engine.match_pattern("*fire*")
	_assert_eq("*fire* count", fires.size(), 1)
	_assert_has_name(fires, "firewall_trap.hazard", "*fire* includes firewall via tag or name")

	# --- Suffix matching: *.enemy via glob_name ---
	var dot_enemy = engine.match_pattern("*.enemy")
	_assert_eq("*.enemy (suffix) count", dot_enemy.size(), 2)

	# --- Exact match ---
	var exact = engine.match_pattern("training_data.txt")
	_assert_eq("exact match training_data.txt", exact.size(), 1)

	# --- No match pattern ---
	var none = engine.match_pattern("*.docx")
	_assert_eq("*.docx matches nothing", none.size(), 0)

	# --- Tag matching: hostile ---
	var hostiles = engine.match_pattern("hostile")
	_assert_eq("hostile tag match", hostiles.size(), 2)

	# --- Tag matching: collectible ---
	var collectibles = engine.match_pattern("collectible")
	_assert_eq("collectible tag match", collectibles.size(), 2)

	# --- Radius matching ---
	# All targets at z = 0,2,4,6,8 — test radius from origin
	var near = engine.match_pattern_in_radius("*", Vector3.ZERO, 3.0)
	_assert_gte("radius=3 from origin", near.size(), 1)

	# --- Highlight test ---
	var highlight_targets = engine.match_pattern("*.enemy")
	engine.highlight_targets(highlight_targets, 0.5)
	var highlighted_count := 0
	for t in highlight_targets:
		var gt = t.get_node_or_null("GlobTarget")
		if gt and gt.is_highlighted:
			highlighted_count += 1
	_assert_eq("highlight sets is_highlighted", highlighted_count, 2)

func _assert_eq(label: String, actual: int, expected: int) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS  %s — got %d" % [label, actual])
	else:
		_fail_count += 1
		print("  FAIL  %s — expected %d, got %d" % [label, expected, actual])

func _assert_gte(label: String, actual: int, minimum: int) -> void:
	if actual >= minimum:
		_pass_count += 1
		print("  PASS  %s — got %d (>= %d)" % [label, actual, minimum])
	else:
		_fail_count += 1
		print("  FAIL  %s — expected >= %d, got %d" % [label, minimum, actual])

func _assert_has_name(results: Array[Node], expected_glob_name: String, label: String) -> void:
	var found := false
	for node in results:
		var gt = node.get_node_or_null("GlobTarget")
		if gt and gt.glob_name == expected_glob_name:
			found = true
			break
	if found:
		_pass_count += 1
		print("  PASS  %s" % label)
	else:
		_fail_count += 1
		print("  FAIL  %s — '%s' not in results" % [label, expected_glob_name])

func _print_summary() -> void:
	print("")
	print("=" .repeat(60))
	var total = _pass_count + _fail_count
	if _fail_count == 0:
		print("[GLOB TEST] ALL %d TESTS PASSED. Globbling verified." % total)
	else:
		print("[GLOB TEST] %d/%d passed, %d FAILED." % [_pass_count, total, _fail_count])
	print("=" .repeat(60))
	print("")
