class_name NightPortal
extends Area3D

## Standing doorway hazard. Opens ahead of the glider and teleports into a night sphere.

signal finished

const OPEN_SEC := 0.5
const LIVE_SEC := 2.5
const CLOSE_SEC := 0.3
const BASE_WIDTH_M := 6.0
const WIDTH_STEP_M := 4.0
const HEIGHT_M := 8.0
const DEPTH_M := 0.45
const GROUND_LIFT_M := 0.08
const DOOR_COLOR := Color(0.03, 0.05, 0.09, 0.92)
const RIM_COLOR := Color(0.25, 0.45, 0.85, 0.85)
## Glider RigidBody3D lives on collision layer 2.
const PLAYER_LAYER := 2

enum Phase { OPENING, LIVE, CLOSING, DONE }

var _boss: SunEater
var _phase := Phase.OPENING
var _phase_t := 0.0
var _delivered := false
var _width_m := BASE_WIDTH_M
var _door: MeshInstance3D
var _rim: MeshInstance3D
var _mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _facing := Vector3(-1.0, 0.0, 0.0)


static func width_for_spawn(spawn_index: int) -> float:
	return BASE_WIDTH_M + WIDTH_STEP_M * float(maxi(spawn_index, 0))


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	body_entered.connect(_on_body_entered)
	_ensure_visual()
	_ensure_collision()
	_set_enterable(false)
	_apply_visual_progress(0.0)


func configure(boss: SunEater, world_pos: Vector3, facing_xz: Vector3, width_m: float = BASE_WIDTH_M) -> void:
	_boss = boss
	_width_m = maxf(width_m, 0.5)
	_facing = Vector3(facing_xz.x, 0.0, facing_xz.z)
	if _facing.length_squared() < 0.0001:
		_facing = Vector3(-1.0, 0.0, 0.0)
	else:
		_facing = _facing.normalized()
	global_position = world_pos + Vector3(0.0, GROUND_LIFT_M, 0.0)
	look_at(global_position + _facing, Vector3.UP)
	_phase = Phase.OPENING
	_phase_t = 0.0
	_delivered = false
	_ensure_visual()
	_ensure_collision()
	_apply_width()
	_set_enterable(false)
	_apply_visual_progress(0.0)


func width_m() -> float:
	return _width_m


func is_live() -> bool:
	return _phase == Phase.LIVE


func is_done() -> bool:
	return _phase == Phase.DONE or is_queued_for_deletion()


func facing_xz() -> Vector3:
	return _facing


func _physics_process(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	_phase_t += delta
	match _phase:
		Phase.OPENING:
			var t := 1.0
			if OPEN_SEC > 0.0:
				t = clampf(_phase_t / OPEN_SEC, 0.0, 1.0)
			_apply_visual_progress(t)
			if _phase_t >= OPEN_SEC:
				_phase = Phase.LIVE
				_phase_t = 0.0
				_set_enterable(true)
				_apply_visual_progress(1.0)
		Phase.LIVE:
			_apply_visual_progress(1.0)
			if _phase_t >= LIVE_SEC:
				_begin_close()
		Phase.CLOSING:
			var t := 1.0
			if CLOSE_SEC > 0.0:
				t = clampf(_phase_t / CLOSE_SEC, 0.0, 1.0)
			_apply_visual_progress(1.0 - t)
			if _phase_t >= CLOSE_SEC:
				_finish()


func begin_close() -> void:
	if _phase == Phase.CLOSING or _phase == Phase.DONE:
		return
	_begin_close()


func _begin_close() -> void:
	_phase = Phase.CLOSING
	_phase_t = 0.0
	_set_enterable(false)


func _finish() -> void:
	_phase = Phase.DONE
	finished.emit()
	queue_free()


func _on_body_entered(body: Node) -> void:
	if _delivered or _phase != Phase.LIVE:
		return
	if body == null or not is_instance_valid(body):
		return
	if not (body is Node3D):
		return
	if _boss == null or not is_instance_valid(_boss):
		return
	if not _boss.has_method("deliver_portal_teleport"):
		return
	_delivered = true
	_boss.deliver_portal_teleport(body as Node3D)
	_begin_close()


func _set_enterable(on: bool) -> void:
	monitoring = on
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = not on


func _apply_visual_progress(progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var scale_xz := lerpf(0.08, 1.0, t)
	var alpha := lerpf(0.0, DOOR_COLOR.a, t)
	if _door != null:
		_door.scale = Vector3(scale_xz, t, 1.0)
		_door.position.y = HEIGHT_M * 0.5 * t
	if _rim != null:
		_rim.scale = Vector3(scale_xz, t, 1.0)
		_rim.position.y = HEIGHT_M * 0.5 * t
	if _mat != null:
		var color := DOOR_COLOR
		color.a = alpha
		_mat.albedo_color = color
		_mat.emission_energy_multiplier = 0.6 * t
	if _rim_mat != null:
		var rim := RIM_COLOR
		rim.a = lerpf(0.0, RIM_COLOR.a, t)
		_rim_mat.albedo_color = rim
		_rim_mat.emission_energy_multiplier = 2.2 * t


func _ensure_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		shape_node.shape = box
		add_child(shape_node)
	shape_node.position = Vector3(0.0, HEIGHT_M * 0.5, 0.0)
	_apply_width()


func _ensure_visual() -> void:
	if _door == null:
		_door = MeshInstance3D.new()
		_door.name = "Door"
		var door_mesh := BoxMesh.new()
		_door.mesh = door_mesh
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.emission_enabled = true
		_mat.emission = Color(DOOR_COLOR.r, DOOR_COLOR.g, DOOR_COLOR.b)
		_mat.albedo_color = DOOR_COLOR
		_door.material_override = _mat
		_door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_door)

	if _rim == null:
		_rim = MeshInstance3D.new()
		_rim.name = "Rim"
		var rim_mesh := BoxMesh.new()
		_rim.mesh = rim_mesh
		_rim_mat = StandardMaterial3D.new()
		_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rim_mat.emission_enabled = true
		_rim_mat.emission = Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b)
		_rim_mat.albedo_color = RIM_COLOR
		_rim.material_override = _rim_mat
		_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_rim)
	_apply_width()


func _apply_width() -> void:
	if _door != null and _door.mesh is BoxMesh:
		(_door.mesh as BoxMesh).size = Vector3(_width_m, HEIGHT_M, DEPTH_M)
	if _rim != null and _rim.mesh is BoxMesh:
		(_rim.mesh as BoxMesh).size = Vector3(_width_m + 0.35, HEIGHT_M + 0.35, DEPTH_M * 0.35)
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is BoxShape3D:
		(shape_node.shape as BoxShape3D).size = Vector3(_width_m, HEIGHT_M, DEPTH_M * 2.0)
		shape_node.position = Vector3(0.0, HEIGHT_M * 0.5, 0.0)
