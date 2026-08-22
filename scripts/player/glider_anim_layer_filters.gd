class_name GliderAnimLayerFilters
extends RefCounted

## Blend2 path filters for the body/sail layer merge.
## Applied at runtime — Godot does not persist AnimationNode.filters via ResourceSaver.
##
## Filters belong on the root Blend2 node, not on the body/sail state machines.
## Filtered paths blend between body (input 0) and sail (input 1); all other
## tracks pass through from body only. With blend_amount = 1.0, sail wins on
## sail-layer paths while Eve locomotion keeps Hero_Rig, SailPivot, and GliderBoard.
## Skeleton bone tracks must use full paths (e.g. .../Skeleton3D:Bone.011) —
## node-only Skeleton3D filters do not cover bone properties, so Eve clips would
## keep bones like the solar panel stuck deployed.

const SAIL_CLIP_NAMES: PackedStringArray = ["Sail_Deploy", "Sail_Up", "Sail_Down"]
const SAIL_LAYER_PREFIX := "GliderRoot/SailPivot/"
const PIVOT_PATH := "GliderRoot/SailPivot"

const FALLBACK_SAIL_PATHS: PackedStringArray = [
	"GliderRoot/SailPivot/MastBase",
	"GliderRoot/SailPivot/MastBase/SailDeployRig",
]


static func apply(tree: AnimationTree) -> void:
	if tree == null:
		return
	var root := tree.tree_root as AnimationNodeBlendTree
	if root == null or not root.has_node(&"blend"):
		return

	if root.has_node(&"body"):
		root.get_node(&"body").filter_enabled = false
	if root.has_node(&"sail"):
		root.get_node(&"sail").filter_enabled = false

	var blend := root.get_node(&"blend")
	blend.filter_enabled = true
	for path in _collect_sail_blend_paths(tree):
		blend.set_filter_path(path, true)


static func _collect_sail_blend_paths(tree: AnimationTree) -> PackedStringArray:
	var player := tree.get_node_or_null(tree.anim_player) as AnimationPlayer
	if player == null:
		return FALLBACK_SAIL_PATHS

	var paths := {}
	for clip_name in SAIL_CLIP_NAMES:
		if not player.has_animation(clip_name):
			continue
		var anim: Animation = player.get_animation(clip_name)
		for i in anim.get_track_count():
			var track_path := str(anim.track_get_path(i))
			var node_path := track_path.split(":")[0]
			if node_path.begins_with(SAIL_LAYER_PREFIX) and node_path != PIVOT_PATH:
				paths[track_path] = true

	if paths.is_empty():
		for path in FALLBACK_SAIL_PATHS:
			paths[path] = true

	return PackedStringArray(paths.keys())
