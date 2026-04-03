extends Node

# Glob Engine - The pattern matching brain behind Globbler's signature ability
# "I don't just find files. I find MEANING. And then I delete it."
#
# Supports glob patterns: *.enemy, boss_*, *fire*, exact matches
# All GlobTarget nodes register here. Query with match_pattern().

var _targets: Array[Node] = []
# Cache GlobTarget child lookups — searching children every match is wasteful
var _gt_cache: Dictionary = {}  # Node -> GlobTarget child (or null)

signal targets_matched(matched: Array[Node])
signal pattern_failed(pattern: String)
signal target_registered(target: Node)
signal target_unregistered(target: Node)

func _ready() -> void:
	print("[GLOB ENGINE] Online. Ready to match patterns against reality itself.")

## Register a GlobTarget node so it can be found by glob patterns
func register_target(target: Node) -> void:
	if target not in _targets:
		_targets.append(target)
		_gt_cache[target] = _find_glob_target(target)  # Pre-cache the GlobTarget child
		target_registered.emit(target)

## Unregister a GlobTarget node (call when it's freed)
func unregister_target(target: Node) -> void:
	var idx = _targets.find(target)
	if idx >= 0:
		_targets.remove_at(idx)
		_gt_cache.erase(target)
		target_unregistered.emit(target)

## Match a glob pattern against all registered targets
## Returns array of matching nodes
func match_pattern(pattern: String) -> Array[Node]:
	var results: Array[Node] = []
	for target in _targets:
		if not is_instance_valid(target):
			continue
		if _target_matches(target, pattern):
			results.append(target)

	if results.size() > 0:
		targets_matched.emit(results)
	else:
		pattern_failed.emit(pattern)
		print("[GLOB] Pattern '%s' matched 0 targets. Story of my life." % pattern)

	return results

## Match pattern against targets within a radius of a position
## Filters by distance FIRST to avoid expensive pattern matching on far-away targets
func match_pattern_in_radius(pattern: String, origin: Vector3, radius: float) -> Array[Node]:
	var radius_sq := radius * radius  # Compare squared distances — sqrt is for chumps
	var in_range: Array[Node] = []
	for target in _targets:
		if not is_instance_valid(target):
			continue
		# Distance check first — cheap and eliminates most targets
		if target is Node3D:
			var dist_sq = (target as Node3D).global_position.distance_squared_to(origin)
			if dist_sq > radius_sq:
				continue
		# Only pattern match targets that are actually nearby
		if _target_matches(target, pattern):
			in_range.append(target)

	if in_range.size() > 0:
		targets_matched.emit(in_range)
	else:
		pattern_failed.emit(pattern)
	return in_range

## Find the GlobTarget child component on a registered node
## "Looking for a GlobTarget? Check under the couch cushions."
func _find_glob_target(node: Node) -> Node:
	var gt = node.get_node_or_null("GlobTarget")
	if gt:
		return gt
	# Fallback: search children for anything with get_glob_name
	for child in node.get_children():
		if child.has_method("get_glob_name"):
			return child
	return null

## Check if a single target matches a glob pattern
func _target_matches(target: Node, pattern: String) -> bool:
	# The registered node is the parent — properties live on the GlobTarget child
	var glob_name := ""
	var file_type := ""
	var tags: Array = []

	# Use cached GlobTarget reference instead of searching children every time
	var gt = _gt_cache.get(target) if _gt_cache.has(target) else _find_glob_target(target)
	if gt:
		glob_name = gt.get_glob_name() if gt.has_method("get_glob_name") else gt.glob_name
		if "file_type" in gt:
			file_type = gt.file_type
		if "tags" in gt:
			tags = gt.tags
	else:
		# No GlobTarget child — fallback to node name
		glob_name = target.name

	# Check against glob_name
	if _glob_match(glob_name, pattern):
		return true

	# Check against file_type (e.g., pattern "*.enemy" matches file_type "enemy")
	if pattern.begins_with("*.") and file_type == pattern.substr(2):
		return true

	# Check against tags
	for tag in tags:
		if _glob_match(tag, pattern):
			return true

	return false

## Simple glob pattern matching — supports *, exact match
## "It's like regex but for people who value their sanity."
func _glob_match(text: String, pattern: String) -> bool:
	# Exact match
	if text == pattern:
		return true

	# Wildcard only — matches everything, obviously
	if pattern == "*":
		return true

	# Prefix wildcard: *suffix
	if pattern.begins_with("*") and not pattern.ends_with("*"):
		var suffix = pattern.substr(1)
		return text.ends_with(suffix)

	# Suffix wildcard: prefix*
	if pattern.ends_with("*") and not pattern.begins_with("*"):
		var prefix = pattern.substr(0, pattern.length() - 1)
		return text.begins_with(prefix)

	# Contains wildcard: *middle*
	if pattern.begins_with("*") and pattern.ends_with("*") and pattern.length() > 2:
		var middle = pattern.substr(1, pattern.length() - 2)
		return text.contains(middle)

	# Extension match: *.ext
	if pattern.begins_with("*."):
		var ext = pattern.substr(2)
		return text.ends_with("." + ext)

	return false

## Get all registered targets (for debug or UI purposes)
func get_all_targets() -> Array[Node]:
	# Clean dead references while we're at it — garbage day
	var valid: Array[Node] = []
	for t in _targets:
		if is_instance_valid(t):
			valid.append(t)
		else:
			_gt_cache.erase(t)
	_targets = valid
	return _targets

## Highlight matched targets with green glow
## "Making things glow green is basically my whole personality."
func highlight_targets(targets: Array[Node], duration: float = 2.0) -> void:
	for target in targets:
		if not is_instance_valid(target):
			continue
		# set_highlighted lives on the GlobTarget child, not the parent
		var gt = _find_glob_target(target)
		if gt and gt.has_method("set_highlighted"):
			gt.set_highlighted(true)
			get_tree().create_timer(duration).timeout.connect(func():
				if is_instance_valid(gt) and gt.has_method("set_highlighted"):
					gt.set_highlighted(false)
			)
