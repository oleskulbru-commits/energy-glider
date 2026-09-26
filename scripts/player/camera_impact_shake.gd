class_name CameraImpactShake
extends RefCounted

## Proximity-scaled trauma requests for GliderCamera impact shake.

const MIN_TRAUMA := 0.015
const FOOTSTEP_SHAKE_COOLDOWN_SEC := 0.045
const FOOTSTEP_STRENGTH_THRESHOLD := 0.12

static var _last_footstep_shake_sec := -1.0


static func request(
	tree: SceneTree,
	world_pos: Vector3,
	strength: float,
	radius_m: float
) -> void:
	if tree == null or strength < MIN_TRAUMA or radius_m <= 0.0:
		return
	if strength <= FOOTSTEP_STRENGTH_THRESHOLD and not _footstep_cooldown_ready(tree):
		return
	var player_pos := _find_player_position(tree)
	var dist := player_pos.distance_to(world_pos)
	var trauma := compute_trauma(strength, dist, radius_m)
	if trauma < MIN_TRAUMA:
		return
	var camera := _find_camera(tree)
	if camera == null:
		return
	camera.add_impact_trauma(trauma)
	if strength <= FOOTSTEP_STRENGTH_THRESHOLD:
		_last_footstep_shake_sec = _tree_time_sec(tree)


static func compute_falloff(dist: float, radius_m: float) -> float:
	var t := clampf(1.0 - dist / radius_m, 0.0, 1.0)
	return t * t


static func compute_trauma(strength: float, dist: float, radius_m: float) -> float:
	return strength * compute_falloff(dist, radius_m)


static func _footstep_cooldown_ready(tree: SceneTree) -> bool:
	if _last_footstep_shake_sec < 0.0:
		return true
	return _tree_time_sec(tree) - _last_footstep_shake_sec >= FOOTSTEP_SHAKE_COOLDOWN_SEC


static func _tree_time_sec(tree: SceneTree) -> float:
	return float(Time.get_ticks_msec()) * 0.001


static func _find_camera(tree: SceneTree) -> GliderCamera:
	var rig := tree.get_first_node_in_group("player_rig") as PlayerRig
	if rig != null:
		var rig_cam := rig.get_follow_camera()
		if rig_cam != null:
			return rig_cam
	for node in tree.get_nodes_in_group("glider_camera"):
		if node is GliderCamera:
			return node as GliderCamera
	return tree.root.find_child("GliderCamera", true, false) as GliderCamera


static func _find_player_position(tree: SceneTree) -> Vector3:
	var rig := tree.get_first_node_in_group("player_rig") as PlayerRig
	if rig != null:
		return rig.get_tracking_position()
	var glider := tree.root.find_child("Glider", true, false) as Node3D
	if glider != null:
		return glider.global_position
	return Vector3.ZERO
