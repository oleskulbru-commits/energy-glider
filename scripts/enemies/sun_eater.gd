class_name SunEater
extends SwarmPill

## Stationary DPS-check boss. Rises from underground, then stands still.

signal health_changed(current: int, max_hp: int)

const PILL_COLOR := Color(0.02, 0.02, 0.03)
const TOWER_HEIGHT_M := 100.0
const HEIGHT_M := TOWER_HEIGHT_M
const RADIUS_M := 7.0
const ASCENT_SEC := 3.0
const BRING_THE_NIGHT_SEC := 8.0
const CHILD_DIAMETER_M := 80.0
const CHILD_RADIUS_M := CHILD_DIAMETER_M * 0.5
const SPREAD_RADIUS_M := 400.0
const SPREAD_WAIT_SEC := 6.0
const CHILD_FORM_SEC := 6.0
const PLACE_TRIES := 64
const DAMAGE_FLOAT_Y_M := 9.0
const SCARAB_CAP := 100
const SCARAB_DAY_RATE := 1.0
const NIGHT_RAMP_STEP_SEC := 5.0
const ESCAPE_EVERY := 10

const NightScarabScene := preload("res://scenes/enemies/night_scarab.tscn")
const NightScarabScript := preload("res://scripts/enemies/night_scarab.gd")

var tower_index := 0
var _pill: MeshInstance3D
var _night_volume: NightVolume
var _child_volumes: Array[NightVolume] = []
var _forming_child: NightVolume
var _ground_y := 0.0
var _rise_t := 0.0
var _night_t := 0.0
var _spread_wait_t := 0.0
var _rising := false
var _bringing_night := false
var _spreading := false
var _spread_full := false
var _night_unleashed := false
var _night_ramp_t := 0.0
var _scarabs: Array = []
var _spawn_acc: Dictionary = {}
var _spawn_counts: Dictionary = {}


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	add_to_group("sun_eater")
	contact_damage = 0
	move_speed = 0.0
	_strip_crawler_visual()
	_ensure_pill_visual()
	_ensure_night_volume()
	_apply_boss_hitbox()


func configure(terrain: TerrainManager, target: Node3D, _speed: float = 0.0) -> void:
	_terrain = terrain
	_target = target
	move_speed = 0.0


func configure_encounter(index: int, max_hp: int) -> void:
	tower_index = index
	_max_health = maxi(max_hp, 1)
	_hp = _max_health
	health_changed.emit(_hp, _max_health)


func begin_ascent(ground_y: float) -> void:
	_ground_y = ground_y
	_rise_t = 0.0
	_night_t = 0.0
	_spread_wait_t = 0.0
	_rising = true
	_bringing_night = false
	_spreading = false
	_spread_full = false
	_forming_child = null
	_night_unleashed = false
	_night_ramp_t = 0.0
	_spawn_acc.clear()
	_spawn_counts.clear()
	_clear_scarabs()
	_clear_child_spheres()
	global_position.y = buried_y(ground_y)
	_sync_night_volume()


func standing_ground_y() -> float:
	return _ground_y


func has_finished_ascent() -> bool:
	return not _rising and _rise_t >= ASCENT_SEC


func is_night_unleashed() -> bool:
	return _night_unleashed


func night_ramp_elapsed() -> float:
	return _night_ramp_t


func spawn_rate_per_sphere() -> float:
	if not _night_unleashed:
		return SCARAB_DAY_RATE
	return night_spawn_rate(_night_ramp_t)


static func night_spawn_rate(elapsed_sec: float) -> float:
	return 1.0 + floorf(maxf(elapsed_sec, 0.0) / NIGHT_RAMP_STEP_SEC)


func living_scarab_count() -> int:
	_cull_scarabs()
	return _scarabs.size()


func living_scarabs() -> Array:
	_cull_scarabs()
	return _scarabs


func begin_clock_night() -> void:
	if _night_unleashed:
		_hide_night_visuals()
		return
	_night_unleashed = true
	_night_ramp_t = 0.0
	_hide_night_visuals()
	for scarab in living_scarabs():
		scarab.unshackle()


func ascent_fade() -> float:
	return clampf(_rise_t / ASCENT_SEC, 0.0, 1.0)


## Opacity of Bring the Night. 0 until the boss finishes rising, then 0→1 over 8s.
func bring_the_night_fade() -> float:
	return clampf(_night_t / BRING_THE_NIGHT_SEC, 0.0, 1.0)


static func buried_y(ground_y: float) -> float:
	return ground_y - HEIGHT_M


static func standing_y(ground_y: float) -> float:
	return ground_y


static func rise_y(ground_y: float, elapsed_sec: float) -> float:
	var t := clampf(elapsed_sec / ASCENT_SEC, 0.0, 1.0)
	return lerpf(buried_y(ground_y), standing_y(ground_y), t)


func apply_level_hp(_level: int) -> void:
	pass


func apply_difficulty(_bonus: float) -> void:
	pass


func take_damage(
	amount: int,
	hit_dir: Vector3 = Vector3.ZERO,
	is_crit: bool = false,
	_knockback_speed: float = 0.0,
	weapon_family: StringName = &""
) -> bool:
	var killed := super.take_damage(amount, hit_dir, is_crit, 0.0, weapon_family)
	health_changed.emit(get_health(), get_max_health())
	return killed


func hit_radius() -> float:
	return RADIUS_M


func _physics_process(delta: float) -> void:
	velocity = Vector3.ZERO
	_hit_velocity = Vector3.ZERO
	if _rising:
		_rise_t = minf(_rise_t + delta, ASCENT_SEC)
		global_position.y = rise_y(_ground_y, _rise_t)
		if _rise_t >= ASCENT_SEC:
			_rising = false
			_bringing_night = true
	elif _bringing_night:
		_night_t = minf(_night_t + delta, BRING_THE_NIGHT_SEC)
		if _night_t >= BRING_THE_NIGHT_SEC:
			_bringing_night = false
			_spreading = true
			_spread_wait_t = 0.0
	elif _spreading:
		_tick_spread(delta)
	_tick_scarab_spawns(delta)
	_sync_night_volume()


func _apply_visual_scale() -> void:
	pass


func _apply_hitbox_scale() -> void:
	_apply_boss_hitbox()


func _die(_from_pos: Vector3) -> void:
	set_physics_process(false)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = true
	if _pill != null:
		_pill.visible = false
	if _night_volume != null:
		_night_volume.set_fade(0.0)
		_night_volume.visible = false
	_clear_scarabs()
	_clear_child_spheres()
	died.emit()
	queue_free()


func _spawn_damage_float(amount: int, is_crit: bool = false) -> void:
	DamageFloat.spawn_world(self, amount, _rng, DAMAGE_FLOAT_Y_M, is_crit)


func _strip_crawler_visual() -> void:
	var old_visual := get_node_or_null("Visual")
	if old_visual != null:
		old_visual.queue_free()


func _ensure_night_volume() -> void:
	_night_volume = get_node_or_null("NightVolume") as NightVolume
	if _night_volume == null:
		_night_volume = NightVolume.new()
		_night_volume.name = "NightVolume"
		add_child(_night_volume)
	_night_volume.configure(NightVolume.RADIUS_M, true)
	_sync_night_volume()


func _sync_night_volume() -> void:
	if _night_volume == null:
		return
	_night_volume.snap_to_standing(global_position, _ground_y)
	_night_volume.set_fade(bring_the_night_fade())


func _tick_spread(delta: float) -> void:
	if _spread_full:
		return
	if _forming_child != null and is_instance_valid(_forming_child):
		_forming_child.advance_fade(delta)
		if _forming_child.fade >= 1.0:
			_forming_child = null
			_spread_wait_t = 0.0
		return
	_spread_wait_t += delta
	if _spread_wait_t < SPREAD_WAIT_SEC:
		return
	_spread_wait_t = 0.0
	if not _spawn_child_sphere():
		_spread_full = true


func _spawn_child_sphere() -> bool:
	var xz := try_pick_child_xz(
		_rng,
		Vector2(global_position.x, global_position.z),
		occupied_spheres_xz()
	)
	if not xz.is_finite():
		return false
	var ground_y := _ground_y
	if _terrain != null:
		ground_y = _terrain.sample_height(xz.x, xz.y)
	var child := NightVolume.new()
	child.name = "NightSphere_%d" % _child_volumes.size()
	add_child(child)
	child.configure(CHILD_RADIUS_M, false)
	child.snap_to_standing(Vector3(xz.x, 0.0, xz.y), ground_y)
	child.begin_self_fade(CHILD_FORM_SEC)
	if _night_unleashed:
		child.set_visuals_enabled(false)
	_child_volumes.append(child)
	_forming_child = child
	return true


func child_night_volumes() -> Array[NightVolume]:
	return _child_volumes


func is_night_spread_full() -> bool:
	return _spread_full


func occupied_spheres_xz() -> Array[Dictionary]:
	var occupied: Array[Dictionary] = []
	var boss_xz := Vector2(global_position.x, global_position.z)
	occupied.append({"xz": boss_xz, "r": NightVolume.RADIUS_M})
	for child in _child_volumes:
		if child == null or not is_instance_valid(child):
			continue
		occupied.append({
			"xz": Vector2(child.global_position.x, child.global_position.z),
			"r": child.radius_m,
		})
	return occupied


func _clear_child_spheres() -> void:
	for child in _child_volumes:
		if child != null and is_instance_valid(child):
			child.queue_free()
	_child_volumes.clear()
	_forming_child = null


func _tick_scarab_spawns(delta: float) -> void:
	_maybe_begin_clock_night()
	if _target == null or not is_instance_valid(_target):
		return
	var rate := spawn_rate_per_sphere()
	for volume in formed_night_volumes():
		_tick_volume_spawn(volume, rate, delta)
	if _night_unleashed:
		_night_ramp_t += delta


func _maybe_begin_clock_night() -> void:
	if _night_unleashed:
		_hide_night_visuals()
		return
	if not _clock_is_night():
		return
	begin_clock_night()


func _clock_is_night() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var cycle := tree.get_first_node_in_group("day_night_cycle")
	return cycle != null and cycle.has_method("is_night") and bool(cycle.call("is_night"))


func _hide_night_visuals() -> void:
	if _night_volume != null and is_instance_valid(_night_volume):
		_night_volume.set_visuals_enabled(false)
	for child in _child_volumes:
		if child != null and is_instance_valid(child):
			child.set_visuals_enabled(false)


func formed_night_volumes() -> Array[NightVolume]:
	var formed: Array[NightVolume] = []
	if _night_volume != null and is_instance_valid(_night_volume) and _night_volume.is_formed():
		formed.append(_night_volume)
	for child in _child_volumes:
		if child != null and is_instance_valid(child) and child.is_formed():
			formed.append(child)
	return formed


func _tick_volume_spawn(volume: NightVolume, rate: float, delta: float) -> void:
	var id := volume.get_instance_id()
	var acc := float(_spawn_acc.get(id, 0.0)) + rate * delta
	var spawned := 0
	while acc >= 1.0 and living_scarab_count() < SCARAB_CAP:
		acc -= 1.0
		if not _spawn_scarab(volume):
			break
		spawned += 1
	_spawn_acc[id] = acc
	if spawned <= 0 and living_scarab_count() >= SCARAB_CAP:
		_spawn_acc[id] = minf(acc, 0.999)


func _spawn_scarab(volume: NightVolume) -> bool:
	if living_scarab_count() >= SCARAB_CAP:
		return false
	var id := volume.get_instance_id()
	var count := int(_spawn_counts.get(id, 0)) + 1
	_spawn_counts[id] = count
	var can_leave := NightScarabScript.is_escape_spawn(count, ESCAPE_EVERY) or _night_unleashed
	var scarab := NightScarabScene.instantiate()
	add_child(scarab)
	scarab.top_level = true
	var pos := volume.random_point_xz(_rng)
	if _terrain != null:
		pos.y = _terrain.sample_height(pos.x, pos.z)
	else:
		pos.y = volume.global_position.y
	scarab.global_position = pos
	scarab.configure(_terrain, _target, NightScarabScript.MOVE_SPEED)
	scarab.bind_sphere(volume, can_leave)
	if _night_unleashed:
		scarab.unshackle()
	if not scarab.died.is_connected(_on_scarab_died):
		scarab.died.connect(_on_scarab_died)
	_scarabs.append(scarab)
	return true


func _on_scarab_died() -> void:
	_cull_scarabs()


func _cull_scarabs() -> void:
	var living: Array = []
	for scarab in _scarabs:
		if scarab != null and is_instance_valid(scarab) and scarab.is_alive():
			living.append(scarab)
	_scarabs = living


func _clear_scarabs() -> void:
	for scarab in _scarabs:
		if scarab != null and is_instance_valid(scarab):
			if scarab.died.is_connected(_on_scarab_died):
				scarab.died.disconnect(_on_scarab_died)
			scarab.queue_free()
	_scarabs.clear()


static func spheres_overlap_xz(a: Vector2, ra: float, b: Vector2, rb: float) -> bool:
	return a.distance_to(b) < ra + rb


static func can_place_xz(point: Vector2, radius: float, occupied: Array[Dictionary]) -> bool:
	for entry in occupied:
		var other: Vector2 = entry.get("xz", Vector2.ZERO)
		var other_r := float(entry.get("r", 0.0))
		if spheres_overlap_xz(point, radius, other, other_r):
			return false
	return true


static func try_pick_child_xz(
	rng: RandomNumberGenerator,
	origin: Vector2,
	occupied: Array[Dictionary],
	spread_radius: float = SPREAD_RADIUS_M,
	child_radius: float = CHILD_RADIUS_M,
	tries: int = PLACE_TRIES
) -> Vector2:
	for _i in tries:
		var dist := spread_radius * sqrt(rng.randf())
		var ang := rng.randf() * TAU
		var point := origin + Vector2(cos(ang), sin(ang)) * dist
		if can_place_xz(point, child_radius, occupied):
			return point
	return Vector2(NAN, NAN)


func _ensure_pill_visual() -> void:
	_pill = get_node_or_null("Pill") as MeshInstance3D
	if _pill == null:
		_pill = MeshInstance3D.new()
		_pill.name = "Pill"
		var mesh := CapsuleMesh.new()
		mesh.radius = RADIUS_M
		mesh.height = HEIGHT_M
		_pill.mesh = mesh
		_pill.position.y = HEIGHT_M * 0.5
		add_child(_pill)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PILL_COLOR
	mat.roughness = 0.62
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.06, 0.07)
	mat.emission_energy_multiplier = 0.28
	_pill.material_override = mat


func _apply_boss_hitbox() -> void:
	contact_radius_m = RADIUS_M
	contact_max_above_m = HEIGHT_M
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS_M
	capsule.height = HEIGHT_M
	col.shape = capsule
	col.position = Vector3(0.0, HEIGHT_M * 0.5, 0.0)
