class_name SceneUtil
extends RefCounted

## Scene-tree helpers for pixel-viewport setups (SubViewportContainer + SubViewport).


## Parent for world-space 3D nodes (debris, particles, bullets).
## When the main scene is a SubViewportContainer, returns the 3D root inside SubViewport.
static func world_parent(tree: SceneTree, fallback: Node = null) -> Node:
	if tree == null:
		return fallback
	var scene := tree.current_scene
	if scene == null:
		return tree.root if fallback == null else fallback
	var sub := scene.get_node_or_null("SubViewport") as SubViewport
	if sub != null and sub.get_child_count() > 0:
		return sub.get_child(0)
	return scene
