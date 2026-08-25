class_name HeroRagdoll
extends Node3D

## Detached hero ragdoll spawned on player death.

const SKIN_SCENE := preload(
	"res://assets/3dmodels/player_models/Glider/The_Glider_Animated_Skin.glb"
)
const SelfScript := preload("res://scripts/player/hero_ragdoll.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")

const LIFETIME_SEC := 4.0
const IMPULSE_STRENGTH := 4.0
const RAGDOLL_COLLISION_LAYER := 4
const TERRAIN_COLLISION_MASK := 1
const RAGDOLL_COLLISION_MASK := TERRAIN_COLLISION_MASK | RAGDOLL_COLLISION_LAYER
const MIN_BONE_LENGTH := 0.08
const MIN_BONE_RADIUS := 0.05
const RAGDOLL_COLLISION_PRIORITY := 2.0
const ROOT_BONE_NAME_HINTS := ["hips", "pelvis", "root"]
const IMPULSE_BLEND := 0.2
const RAGDOLL_ANGULAR_DAMP := 0.35
const POSE_SPRING_K := 14.0
const POSE_DAMP_K := 3.5

## 0 = full ragdoll flop, 1 = frozen spawn pose. 0.25 keeps silhouette readable.
@export_range(0.0, 1.0, 0.01) var pose_stiffness := 0.25

const _SKIP_BONE_HINTS := [
	"headtop_end",
	"toe_end",
	"handthumb",
	"handindex",
	"handmiddle",
	"handring",
	"handpinky",
]

var _skeleton: Skeleton3D
var _root_physical_bone: PhysicalBone3D
var _spawn_bone_basis: Dictionary = {}
var _simulating := false
var _lifetime_left := LIFETIME_SEC
var _auto_expire := true


static func spawn(
	tree: SceneTree,
	xf: Transform3D,
	velocity: Vector3,
	impulse: Vector3,
	pose_source: Skeleton3D = null
) -> Node3D:
	if tree == null:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null
	var ragdoll: Node3D = SelfScript.new()
	ragdoll.name = "HeroRagdoll"
	parent.add_child(ragdoll)
	ragdoll.global_transform = xf
	ragdoll._build_from_skin()
	if pose_source != null:
		ragdoll._apply_skeleton_pose(pose_source)
	ragdoll._cache_spawn_pose()
	ragdoll._start_simulation()
	ragdoll._apply_launch(velocity, impulse)
	return ragdoll


func _ready() -> void:
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _simulating and pose_stiffness > 0.0:
		_apply_pose_stiffness(delta)
	if not _auto_expire or _lifetime_left <= 0.0:
		return
	_lifetime_left = maxf(_lifetime_left - delta, 0.0)
	if _lifetime_left <= 0.0:
		queue_free()


func disable_auto_expire() -> void:
	_auto_expire = false
	_lifetime_left = 0.0


func cleanup() -> void:
	if _simulating and _skeleton != null:
		_skeleton.physical_bones_stop_simulation()
	_simulating = false
	queue_free()


func get_physical_bone_count() -> int:
	if _skeleton == null:
		return 0
	var count := 0
	for child in _skeleton.get_children():
		if child is PhysicalBone3D:
			count += 1
	return count


func get_camera_anchor() -> Node3D:
	if _root_physical_bone != null and is_instance_valid(_root_physical_bone):
		return _root_physical_bone
	if _skeleton != null:
		return _skeleton
	return self


func get_follow_velocity() -> Vector3:
	if _root_physical_bone != null and is_instance_valid(_root_physical_bone):
		return _root_physical_bone.linear_velocity
	return Vector3.ZERO


func get_pose_deviation_rad() -> float:
	if _skeleton == null or _spawn_bone_basis.is_empty():
		return 0.0
	var total := 0.0
	var count := 0
	for child in _skeleton.get_children():
		if not child is PhysicalBone3D:
			continue
		var pb := child as PhysicalBone3D
		if not _spawn_bone_basis.has(pb.bone_name):
			continue
		var target_basis: Basis = _spawn_bone_basis[pb.bone_name]
		var current_basis := pb.global_transform.basis.orthonormalized()
		var error_q := (
			target_basis.get_rotation_quaternion().inverse()
			* current_basis.get_rotation_quaternion()
		)
		total += absf(error_q.get_angle())
		count += 1
	return total / maxf(count, 1)


func _cache_spawn_pose() -> void:
	_spawn_bone_basis.clear()
	if _skeleton == null:
		return
	_skeleton.force_update_all_bone_transforms()
	for child in _skeleton.get_children():
		if not child is PhysicalBone3D:
			continue
		var pb := child as PhysicalBone3D
		var bone_idx := _skeleton.find_bone(pb.bone_name)
		if bone_idx < 0:
			continue
		var body_xf := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone_idx) * pb.body_offset
		_spawn_bone_basis[pb.bone_name] = body_xf.basis.orthonormalized()


func _apply_pose_stiffness(delta: float) -> void:
	if _skeleton == null or _spawn_bone_basis.is_empty():
		return
	var stiffness := pose_stiffness * delta
	for child in _skeleton.get_children():
		if not child is PhysicalBone3D:
			continue
		var pb := child as PhysicalBone3D
		if not pb.is_simulating_physics() or not _spawn_bone_basis.has(pb.bone_name):
			continue
		var target_basis: Basis = _spawn_bone_basis[pb.bone_name]
		var current_basis := pb.global_transform.basis.orthonormalized()
		var error_q := (
			target_basis.get_rotation_quaternion()
			* current_basis.get_rotation_quaternion().inverse()
		)
		if error_q.w < 0.0:
			error_q = Quaternion(-error_q.x, -error_q.y, -error_q.z, -error_q.w)
		var axis_angle: Vector3 = error_q.get_axis() * error_q.get_angle()
		if axis_angle.length_squared() <= 0.000001:
			continue
		var spring: Vector3 = axis_angle * POSE_SPRING_K * pose_stiffness
		var damp: Vector3 = pb.angular_velocity * POSE_DAMP_K * pose_stiffness
		pb.angular_velocity += (spring - damp) * stiffness


func _build_from_skin() -> void:
	var imported: Node = SKIN_SCENE.instantiate()
	if imported == null:
		push_warning("HeroRagdoll: failed to instantiate skin GLB")
		return
	add_child(imported)
	var hero: Node3D = imported.get_node_or_null("GliderRoot/Hero_Rig") as Node3D
	if hero == null:
		push_warning("HeroRagdoll: Hero_Rig not found in skin GLB")
		imported.queue_free()
		return
	_skeleton = hero.get_node_or_null("Skeleton3D") as Skeleton3D
	if _skeleton == null:
		push_warning("HeroRagdoll: Hero_Rig Skeleton3D missing")
		imported.queue_free()
		return
	hero.reparent(self)
	imported.queue_free()
	_ensure_physical_bones(_skeleton)
	_cache_root_physical_bone()


func _apply_skeleton_pose(source: Skeleton3D) -> void:
	if _skeleton == null or source == null:
		return
	for bone_idx in _skeleton.get_bone_count():
		var bone_name := _skeleton.get_bone_name(bone_idx)
		if bone_name.is_empty():
			continue
		var source_idx := source.find_bone(bone_name)
		if source_idx < 0:
			continue
		_skeleton.set_bone_pose_position(bone_idx, source.get_bone_pose_position(source_idx))
		_skeleton.set_bone_pose_rotation(bone_idx, source.get_bone_pose_rotation(source_idx))
		_skeleton.set_bone_pose_scale(bone_idx, source.get_bone_pose_scale(source_idx))
	_skeleton.force_update_all_bone_transforms()


func _cache_root_physical_bone() -> void:
	_root_physical_bone = null
	if _skeleton == null:
		return
	for child in _skeleton.get_children():
		if not child is PhysicalBone3D:
			continue
		var name_lower: String = (child as PhysicalBone3D).bone_name.to_lower()
		for hint in ROOT_BONE_NAME_HINTS:
			if name_lower.contains(hint):
				_root_physical_bone = child as PhysicalBone3D
				return
	var root_bone_name := _skeleton_root_bone_name()
	if not root_bone_name.is_empty():
		for child in _skeleton.get_children():
			if child is PhysicalBone3D and (child as PhysicalBone3D).bone_name == root_bone_name:
				_root_physical_bone = child as PhysicalBone3D
				return
	for child in _skeleton.get_children():
		if child is PhysicalBone3D:
			_root_physical_bone = child as PhysicalBone3D
			return


func _skeleton_root_bone_name() -> String:
	if _skeleton == null:
		return ""
	for bone_idx in _skeleton.get_bone_count():
		if _skeleton.get_bone_parent(bone_idx) == -1:
			return _skeleton.get_bone_name(bone_idx)
	return ""


func _ensure_physical_bones(skeleton: Skeleton3D) -> void:
	for child in skeleton.get_children():
		if child is PhysicalBone3D:
			return
	for bone_idx in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_idx)
		if bone_name.is_empty() or not _should_ragdoll_bone(bone_name):
			continue
		var collision_data := _build_bone_collision(skeleton, bone_idx)
		if collision_data.is_empty():
			continue
		var pb := PhysicalBone3D.new()
		pb.name = bone_name
		pb.bone_name = bone_name
		pb.collision_layer = RAGDOLL_COLLISION_LAYER
		pb.collision_mask = RAGDOLL_COLLISION_MASK
		pb.collision_priority = RAGDOLL_COLLISION_PRIORITY
		pb.angular_damp = RAGDOLL_ANGULAR_DAMP
		pb.body_offset = collision_data["body_offset"]
		pb.joint_offset = collision_data["joint_offset"]
		_configure_bone_joint(pb, bone_name)
		pb.add_child(collision_data["collision"])
		if pb.get("continuous_cd") != null:
			pb.set("continuous_cd", true)
		skeleton.add_child(pb)
		pb.owner = skeleton.owner if skeleton.owner != null else self


func _pick_shape_child_bone(skeleton: Skeleton3D, bone_idx: int) -> int:
	var best_idx := -1
	var best_len := 0.0
	for child_idx in skeleton.get_bone_count():
		if skeleton.get_bone_parent(child_idx) != bone_idx:
			continue
		var child_rest: Transform3D = skeleton.get_bone_rest(child_idx)
		var child_len := child_rest.origin.length()
		if child_len <= 0.001:
			continue
		if best_idx < 0 or child_len > best_len:
			best_idx = child_idx
			best_len = child_len
	return best_idx


func _build_bone_collision(skeleton: Skeleton3D, bone_idx: int) -> Dictionary:
	var child_idx := _pick_shape_child_bone(skeleton, bone_idx)
	if child_idx < 0:
		return {}
	var child_rest: Transform3D = skeleton.get_bone_rest(child_idx)
	var bone_vec := child_rest.origin
	var length := maxf(bone_vec.length(), MIN_BONE_LENGTH)
	var half_height := length * 0.5
	var radius := maxf(half_height * 0.2, MIN_BONE_RADIUS)

	var capsule := CapsuleShape3D.new()
	capsule.height = length
	capsule.radius = radius

	var col := CollisionShape3D.new()
	col.shape = capsule
	col.transform = Transform3D(
		Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0)),
		Vector3.ZERO
	)

	var up := Vector3.UP
	if up.cross(bone_vec).is_zero_approx():
		up = Vector3.FORWARD

	var body_transform := Transform3D()
	body_transform.basis = Basis.looking_at(bone_vec, up)
	body_transform.origin = body_transform.basis * Vector3(0.0, 0.0, -half_height)

	var joint_transform := Transform3D()
	joint_transform.origin = Vector3(0.0, 0.0, half_height)

	return {
		"collision": col,
		"body_offset": body_transform,
		"joint_offset": joint_transform,
	}


func _should_ragdoll_bone(bone_name: String) -> bool:
	var lower := bone_name.to_lower()
	for hint in _SKIP_BONE_HINTS:
		if lower.contains(hint):
			return false
	return true


func _configure_bone_joint(pb: PhysicalBone3D, bone_name: String) -> void:
	var lower := bone_name.to_lower()
	if lower.contains("forearm") or lower.contains("leg") and not lower.contains("upleg"):
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		pb.set("joint_constraints/angular_limit_enabled", true)
		pb.set("joint_constraints/angular_limit_lower", -8.0)
		pb.set("joint_constraints/angular_limit_upper", 145.0)
		return
	pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
	var swing_span := 35.0
	var twist_span := 45.0
	if lower.contains("spine"):
		swing_span = 22.0
		twist_span = 18.0
	elif lower.contains("neck"):
		swing_span = 28.0
		twist_span = 55.0
	elif lower.contains("head"):
		swing_span = 35.0
		twist_span = 40.0
	elif lower.contains("shoulder") or lower.contains("upleg"):
		swing_span = 42.0
		twist_span = 35.0
	elif lower.contains("arm") and not lower.contains("forearm"):
		swing_span = 48.0
		twist_span = 90.0
	elif lower.contains("hand"):
		swing_span = 25.0
		twist_span = 30.0
	elif lower.contains("foot") or lower.contains("toe"):
		swing_span = 25.0
		twist_span = 20.0
	elif lower.contains("hips"):
		swing_span = 38.0
		twist_span = 30.0
	pb.set("joint_constraints/swing_span", swing_span)
	pb.set("joint_constraints/twist_span", twist_span)


func get_bone_lowest_y(pb: PhysicalBone3D) -> float:
	var lowest := pb.global_position.y
	for child in pb.get_children():
		if not child is CollisionShape3D:
			continue
		var col := child as CollisionShape3D
		if col.shape == null or not col.shape is CapsuleShape3D:
			continue
		var cap := col.shape as CapsuleShape3D
		var shape_xf := pb.global_transform * col.transform
		var half_h := cap.height * 0.5
		var end_a := shape_xf * Vector3(0.0, half_h, 0.0)
		var end_b := shape_xf * Vector3(0.0, -half_h, 0.0)
		lowest = minf(lowest, minf(end_a.y, end_b.y) - cap.radius)
	return lowest


func _apply_launch(velocity: Vector3, impulse: Vector3) -> void:
	if _skeleton == null or not _simulating:
		return
	var launch := velocity + impulse * IMPULSE_STRENGTH * IMPULSE_BLEND
	if _root_physical_bone == null:
		_cache_root_physical_bone()
	for child in _skeleton.get_children():
		if not child is PhysicalBone3D:
			continue
		var pb := child as PhysicalBone3D
		pb.linear_velocity = launch
		pb.angular_velocity = Vector3(
			randf_range(-2.0, 2.0),
			randf_range(-2.0, 2.0),
			randf_range(-2.0, 2.0)
		)


func _start_simulation() -> void:
	if _skeleton == null:
		return
	_skeleton.physical_bones_start_simulation()
	_simulating = true
