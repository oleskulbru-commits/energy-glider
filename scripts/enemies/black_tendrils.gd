class_name BlackTendrils
extends Node3D

## Three tall black walls that shoot from the boss toward the glider.

signal finished

const NightPortalScript := preload("res://scripts/enemies/night_portal.gd")

const WALL_COUNT := 3
const LINE_COUNT := WALL_COUNT
const WIDTH_M := NightPortalScript.BASE_WIDTH_M
const HEIGHT_M := 120.0
const CONE_DEG := 45.0
const OVERSHOOT_M := 120.0
const SPEED_M_S := 252.0
const EXTEND_SPEED_M_S := SPEED_M_S
const LINGER_SEC := 3.0
const DAMAGE := 30
## Strong enough to eject the glider from the 6 m wall at surf speeds.
const SHOVE_SPEED := 48.0
const SHOVE_UP := 4.0
const HIT_COOLDOWN_SEC := 0.35
const MIN_DIR_SEP_DEG := 3.0
const PLAYER_LAYER := 2
const WALL_COLOR := Color(0.02, 0.03, 0.05, 0.98)

enum Phase { SHOOTING, LINGERING, DONE }

var _boss: SunEater
var _terrain: TerrainManager
var _phase := Phase.SHOOTING
var _phase_t := 0.0
var _origin := Vector3.ZERO
var _dirs: PackedVector3Array = PackedVector3Array()
var _max_length_m := 1.0
var _reach_m := 1.0
var _traveled := 0.0
var _hit_cooldown: Dictionary = {}
var _walls: Array[Area3D] = []
var _meshes: Array[MeshInstance3D] = []
var _box_meshes: Array[BoxMesh] = []
var _box_shapes: Array[BoxShape3D] = []
var _mat: StandardMaterial3D


static func build_dirs(axis_xz: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
	var axis := Vector3(axis_xz.x, 0.0, axis_xz.z)
	if axis.length_squared() < 0.0001:
		axis = Vector3(-1.0, 0.0, 0.0)
	else:
		axis = axis.normalized()
	var dirs := PackedVector3Array()
	dirs.append(axis)
	var half := deg_to_rad(CONE_DEG * 0.5)
	var min_sep := deg_to_rad(MIN_DIR_SEP_DEG)
	for _i in WALL_COUNT - 1:
		var yaw := 0.0
		if rng != null:
			yaw = rng.randf_range(-half, half)
			var tries := 0
			while absf(yaw) < min_sep and tries < 12:
				yaw = rng.randf_range(-half, half)
				tries += 1
		else:
			yaw = half * (1.0 if _i == 0 else -1.0) * 0.5
		dirs.append(axis.rotated(Vector3.UP, yaw).normalized())
	return dirs


func configure(
	boss: SunEater,
	origin: Vector3,
	dirs: PackedVector3Array,
	max_length_m: float,
	reach_m: float,
	terrain: TerrainManager = null
) -> void:
	_boss = boss
	_terrain = terrain
	_origin = origin
	_dirs = PackedVector3Array()
	for i in mini(dirs.size(), WALL_COUNT):
		var d := Vector3(dirs[i].x, 0.0, dirs[i].z)
		if d.length_squared() < 0.0001:
			d = Vector3(-1.0, 0.0, 0.0)
		else:
			d = d.normalized()
		_dirs.append(d)
	while _dirs.size() < WALL_COUNT:
		_dirs.append(Vector3(-1.0, 0.0, 0.0))
	_max_length_m = maxf(max_length_m, 1.0)
	_reach_m = clampf(reach_m, 0.5, _max_length_m)
	_traveled = 0.0
	_hit_cooldown.clear()
	_phase = Phase.SHOOTING
	_phase_t = 0.0
	global_position = Vector3(_origin.x, _ground_y(_origin.x, _origin.z), _origin.z)
	_ensure_walls()
	_update_wall_transforms()


func phase() -> Phase:
	return _phase


func dirs() -> PackedVector3Array:
	return _dirs


func current_length() -> float:
	return _traveled


func traveled_m() -> float:
	return _traveled


func max_length_m() -> float:
	return _max_length_m


func reach_m() -> float:
	return _reach_m


func is_done() -> bool:
	return _phase == Phase.DONE or is_queued_for_deletion()


func is_lingering() -> bool:
	return _phase == Phase.LINGERING


func walls() -> Array[Area3D]:
	return _walls


func apply_hit_for_test(body: Node3D) -> void:
	_try_hit_body(body)


func _physics_process(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	_phase_t += delta
	_tick_hit_cooldowns(delta)
	match _phase:
		Phase.SHOOTING:
			_advance(delta)
			_update_wall_transforms()
			_poll_wall_overlaps()
			if _traveled + 0.0001 >= _reach_m:
				_phase = Phase.LINGERING
				_phase_t = 0.0
		Phase.LINGERING:
			_advance(delta)
			_update_wall_transforms()
			_poll_wall_overlaps()
			if _phase_t >= LINGER_SEC:
				_finish()


func _advance(delta: float) -> void:
	if _traveled >= _max_length_m:
		return
	_traveled = minf(_traveled + SPEED_M_S * delta, _max_length_m)


func _ensure_walls() -> void:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = WALL_COLOR
		_mat.emission_enabled = true
		_mat.emission = Color(WALL_COLOR.r, WALL_COLOR.g, WALL_COLOR.b)
		_mat.emission_energy_multiplier = 0.55
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	while _walls.size() < WALL_COUNT:
		var index := _walls.size()
		var area := Area3D.new()
		area.name = "TendrilWall_%d" % index
		area.monitoring = true
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = PLAYER_LAYER
		area.body_entered.connect(_on_wall_body_entered.bind(index))
		area.body_exited.connect(_on_wall_body_exited)
		var shape_node := CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(WIDTH_M, HEIGHT_M, 0.01)
		shape_node.shape = box
		area.add_child(shape_node)
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "Mesh"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(WIDTH_M, HEIGHT_M, 0.01)
		mesh_inst.mesh = mesh
		mesh_inst.material_override = _mat
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		area.add_child(mesh_inst)
		add_child(area)
		_walls.append(area)
		_meshes.append(mesh_inst)
		_box_meshes.append(mesh)
		_box_shapes.append(box)


func _update_wall_transforms() -> void:
	_ensure_walls()
	var length := maxf(_traveled, 0.05)
	var ground_y := _ground_y(_origin.x, _origin.z)
	for i in WALL_COUNT:
		if i >= _dirs.size() or i >= _walls.size():
			continue
		var dir: Vector3 = _dirs[i]
		# Solid slab from the boss out to the leading edge.
		var mid := _origin + dir * (length * 0.5)
		mid.y = ground_y
		var end := _origin + dir * length
		end.y = ground_y
		var area := _walls[i]
		_box_meshes[i].size = Vector3(WIDTH_M, HEIGHT_M, length)
		_box_shapes[i].size = Vector3(WIDTH_M, HEIGHT_M, length)
		area.global_position = mid
		if Vector2(dir.x, dir.z).length_squared() > 0.0001:
			area.look_at(end, Vector3.UP)


func _on_wall_body_entered(body: Node, wall_index: int) -> void:
	if _phase == Phase.DONE:
		return
	if body == null or not (body is Node3D):
		return
	_try_hit_body(body as Node3D, wall_index)


func _on_wall_body_exited(body: Node) -> void:
	if body == null:
		return
	_hit_cooldown.erase(body.get_instance_id())


func _tick_hit_cooldowns(delta: float) -> void:
	var keys: Array = _hit_cooldown.keys()
	for id in keys:
		var left: float = float(_hit_cooldown[id]) - delta
		if left <= 0.0:
			_hit_cooldown.erase(id)
		else:
			_hit_cooldown[id] = left


func _poll_wall_overlaps() -> void:
	## Growing slabs can swallow the glider without a fresh enter signal.
	for i in _walls.size():
		var wall := _walls[i]
		if wall == null or not is_instance_valid(wall) or not wall.monitoring:
			continue
		for body in wall.get_overlapping_bodies():
			if body is Node3D:
				_try_hit_body(body as Node3D, i)


func _try_hit_body(body: Node3D, wall_index: int = 0) -> void:
	if body == null or not is_instance_valid(body):
		return
	var id := body.get_instance_id()
	if float(_hit_cooldown.get(id, 0.0)) > 0.0001:
		return
	_hit_cooldown[id] = HIT_COOLDOWN_SEC

	var tree := get_tree()
	if tree != null:
		var health := tree.get_first_node_in_group("player_health")
		if health != null and health.has_method("take_damage"):
			health.call("take_damage", DAMAGE)

	var knock_target := _resolve_knockback_body(body)
	if knock_target == null or not knock_target.has_method("queue_knockback"):
		return
	var dir := Vector3(-1.0, 0.0, 0.0)
	if wall_index >= 0 and wall_index < _dirs.size():
		dir = _dirs[wall_index]
	elif not _dirs.is_empty():
		dir = _dirs[0]
	var side := Vector3(-dir.z, 0.0, dir.x)
	if side.length_squared() < 0.0001:
		side = Vector3(0.0, 0.0, 1.0)
	else:
		side = side.normalized()
	var along := (knock_target.global_position - _origin).dot(dir)
	along = clampf(along, 0.0, maxf(_traveled, 0.05))
	var nearest := _origin + dir * along
	var offset := knock_target.global_position - nearest
	offset.y = 0.0
	var side_dot := offset.dot(side)
	if absf(side_dot) < 0.15:
		## Near the centerline: push opposite current lateral velocity if any.
		var vel := Vector3.ZERO
		if knock_target is RigidBody3D:
			vel = (knock_target as RigidBody3D).linear_velocity
		elif knock_target.get("velocity") != null:
			vel = knock_target.velocity as Vector3
		var lat := vel.dot(side)
		if absf(lat) > 0.5:
			side = -side if lat > 0.0 else side
		else:
			side = side if randf() < 0.5 else -side
	elif side_dot < 0.0:
		side = -side
	knock_target.call(
		"queue_knockback",
		Vector3(side.x * SHOVE_SPEED, SHOVE_UP, side.z * SHOVE_SPEED)
	)


func _resolve_knockback_body(body: Node3D) -> Node3D:
	var node: Node = body
	while node != null:
		if node.has_method("queue_knockback"):
			return node as Node3D
		node = node.get_parent()
	var tree := get_tree()
	if tree != null:
		var player := tree.get_first_node_in_group("player")
		if player is Node3D and player.has_method("queue_knockback"):
			return player as Node3D
	return body


func _ground_y(x: float, z: float) -> float:
	if _terrain != null:
		return _terrain.sample_height(x, z)
	return _origin.y


func _finish() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	for wall in _walls:
		if wall != null and is_instance_valid(wall):
			wall.monitoring = false
	finished.emit()
	queue_free()
