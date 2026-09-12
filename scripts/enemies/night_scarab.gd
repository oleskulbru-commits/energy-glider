class_name NightScarab
extends SwarmPill

## Purple pill. By day it fills night spheres; at clock night the stream hunts the glider.

const MOVE_SPEED := 12.0
const NIGHT_MOVE_SPEED := 21.0
const SCARAB_CONTACT_DAMAGE := 2
const SCARAB_MAX_HEALTH := 15
const STREAM_AHEAD_MIN_M := 20.0
const STREAM_AHEAD_MAX_M := 80.0
const STREAM_CAP := 200
const PILL_COLOR := Color(0.42, 0.05, 0.72)
const PILL_MESH_RADIUS := 0.18
const PILL_MESH_HEIGHT := 0.52
const COLLISION_RADIUS_M := 0.16
const COLLISION_HEIGHT_M := 0.4
const COLLISION_CENTER_Y_M := 0.22
const CONTACT_RADIUS := 0.7
const CONTACT_Y_ABOVE_M := 1.1
const WANDER_RETARGET_SEC := 2.5
const WANDER_ARRIVE_M := 2.0
const WANDER_MARGIN_M := 2.0
const CLAMP_MARGIN_M := 1.0
const ESCAPE_EVERY := 10
const FULL_SIM_RANGE_M := 50.0
const FULL_SIM_RANGE_SQ := FULL_SIM_RANGE_M * FULL_SIM_RANGE_M
const VISIBLE_RANGE_M := 100.0
const VISIBLE_RANGE_SQ := VISIBLE_RANGE_M * VISIBLE_RANGE_M


var _pill: MeshInstance3D
var _home: NightVolume
var _unshackled := false
var _hunting := false
var _wander_goal := Vector3.ZERO
var _has_wander := false
var _wander_t := 0.0
var _collision: CollisionShape3D
var _full_sim := true
var _stream_hunter := false


func _ready() -> void:
	super._ready()
	add_to_group("night_scarab")
	contact_damage = SCARAB_CONTACT_DAMAGE
	_max_health = SCARAB_MAX_HEALTH
	_hp = SCARAB_MAX_HEALTH
	move_speed = MOVE_SPEED
	collision_mask = 0
	_collision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_ensure_pill_visual()
	_apply_scarab_hitbox()


func configure(terrain: TerrainManager, target: Node3D, _speed: float = MOVE_SPEED) -> void:
	super.configure(terrain, target, MOVE_SPEED)


func apply_level_hp(_level: int) -> void:
	pass


func apply_difficulty(_bonus: float) -> void:
	pass


func bind_sphere(volume: NightVolume, can_leave: bool = false) -> void:
	_home = volume
	_unshackled = can_leave
	_hunting = can_leave
	_has_wander = false
	_wander_t = 0.0
	if not _unshackled:
		_pick_wander()


func unshackle() -> void:
	_unshackled = true
	_hunting = true


func apply_night_speed() -> void:
	move_speed = NIGHT_MOVE_SPEED


func mark_stream_hunter() -> void:
	_stream_hunter = true


func _blocks_behind_despawn() -> bool:
	return not _stream_hunter


func is_unshackled() -> bool:
	return _unshackled


func is_hunting_in_sphere() -> bool:
	return _hunting and not _unshackled


func home_volume() -> NightVolume:
	return _home


static func is_escape_spawn(spawn_index: int, every: int = ESCAPE_EVERY) -> bool:
	return spawn_index > 0 and spawn_index % every == 0


static func should_hunt_player(player_in_sphere: bool, unshackled: bool) -> bool:
	return unshackled or player_in_sphere


func _ensure_pill_visual() -> void:
	var old_visual := get_node_or_null("Visual")
	if old_visual != null:
		old_visual.queue_free()
	_pill = get_node_or_null("Pill") as MeshInstance3D
	if _pill == null:
		_pill = MeshInstance3D.new()
		_pill.name = "Pill"
		var mesh := CapsuleMesh.new()
		mesh.radius = PILL_MESH_RADIUS
		mesh.height = PILL_MESH_HEIGHT
		_pill.mesh = mesh
		_pill.position.y = PILL_MESH_HEIGHT * 0.5
		add_child(_pill)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PILL_COLOR
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = PILL_COLOR
	mat.emission_energy_multiplier = 1.35
	_pill.material_override = mat


func _apply_scarab_hitbox() -> void:
	contact_radius_m = CONTACT_RADIUS
	contact_max_above_m = CONTACT_Y_ABOVE_M
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = COLLISION_RADIUS_M
	capsule.height = COLLISION_HEIGHT_M
	col.shape = capsule
	col.position = Vector3(0.0, COLLISION_CENTER_Y_M, 0.0)
	_collision_bottom_y = _compute_collision_bottom_y()


func _apply_visual_scale() -> void:
	pass


func _apply_hitbox_scale() -> void:
	_apply_scarab_hitbox()


func _sync_anim_speed() -> void:
	pass


func _is_spawn_active() -> bool:
	return false


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_retarget_player()
	if _target == null or not is_instance_valid(_target):
		_set_pill_visible(true)
		_update_chase(delta)
		_after_move(delta)
		return
	if not _blocks_behind_despawn() and is_behind_facing(
		_target.global_position, _target_facing_xz(), global_position
	):
		queue_free()
		return
	var far_visible := _is_beyond_visible_range()
	_set_pill_visible(not far_visible)
	if far_visible and not _unshackled:
		_refresh_hunt_state()
		if not _hunting:
			_set_full_sim(false)
			return
	if _is_far_from_target():
		_set_full_sim(false)
		_cheap_move(delta)
		return
	_set_full_sim(true)
	super._physics_process(delta)


func _is_far_from_target() -> bool:
	return _xz_distance_sq_to_target() > FULL_SIM_RANGE_SQ


func _is_beyond_visible_range() -> bool:
	return _xz_distance_sq_to_target() > VISIBLE_RANGE_SQ


func _xz_distance_sq_to_target() -> float:
	var dx := _target.global_position.x - global_position.x
	var dz := _target.global_position.z - global_position.z
	return dx * dx + dz * dz


func _set_pill_visible(on: bool) -> void:
	if _pill == null:
		_pill = get_node_or_null("Pill") as MeshInstance3D
	if _pill != null:
		_pill.visible = on


func _set_full_sim(on: bool) -> void:
	if _full_sim == on:
		return
	_full_sim = on
	if _collision != null:
		_collision.disabled = not on


func _cheap_move(delta: float) -> void:
	_update_chase(delta)
	var to_target := _seek_offset_xz()
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		_last_seek_dir = to_target.normalized()
		var step := _get_move_speed() * delta
		global_position.x += _last_seek_dir.x * step
		global_position.z += _last_seek_dir.z * step
	_snap_to_terrain()
	_after_move(delta)


func _retarget_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var director := tree.get_first_node_in_group("boss_director")
	if director != null and director.has_method("player_body"):
		var body: Variant = director.call("player_body")
		if body is Node3D and is_instance_valid(body):
			_target = body as Node3D
			return
	var health := tree.get_first_node_in_group("player_health")
	if health == null:
		return
	var rig := health.get_parent()
	if rig == null or not rig.has_method("get_glider"):
		return
	var glider: Variant = rig.call("get_glider")
	if glider is Node3D and is_instance_valid(glider):
		_target = glider as Node3D


func _update_chase(delta: float) -> void:
	_refresh_hunt_state()
	if _unshackled or _hunting:
		return
	_wander_t += delta
	if (
		not _has_wander
		or _wander_t >= WANDER_RETARGET_SEC
		or _xz_distance(_wander_goal) <= WANDER_ARRIVE_M
	):
		_pick_wander()


func _seek_offset_xz() -> Vector3:
	_refresh_hunt_state()
	if _unshackled or _hunting:
		return super._seek_offset_xz()
	if not _has_wander:
		_pick_wander()
	var to_goal := _wander_goal - global_position
	to_goal.y = 0.0
	return to_goal


func _after_move(_delta: float) -> void:
	if _unshackled or _home == null or not is_instance_valid(_home):
		return
	var clamped := _home.clamp_xz(global_position, CLAMP_MARGIN_M)
	global_position.x = clamped.x
	global_position.z = clamped.z


func _refresh_hunt_state() -> void:
	if _unshackled:
		_hunting = true
		return
	if _home == null or not is_instance_valid(_home):
		unshackle()
		return
	if _target != null and is_instance_valid(_target) and _home.contains_xz(_target.global_position):
		_hunting = true
	else:
		_hunting = false


func _pick_wander() -> void:
	_wander_t = 0.0
	if _home == null or not is_instance_valid(_home):
		_has_wander = false
		return
	_wander_goal = _home.random_point_xz(_rng, WANDER_MARGIN_M)
	_has_wander = true


func _xz_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _die(_from_pos: Vector3) -> void:
	set_physics_process(false)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = true
	if _pill != null:
		_pill.visible = false
	died.emit()
	queue_free()
