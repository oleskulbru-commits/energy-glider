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
const RELOCATE_PERIOD_SEC := 60.0
const BURIED_WAIT_SEC := 2.0
const MIN_RELOCATE_SEP_M := 100.0
const BOSS_PLACE_TRIES := 128
const BOSS_RIM_SAMPLES := 16
const DAMAGE_FLOAT_Y_M := 9.0
const NIGHT_REGEN_PER_SEC := 30.0
## Daytime sphere army. Clock night uses the crawler-style stream instead.
const SCARAB_CAP := 500
const SCARAB_DAY_RATE := 1.0
const ESCAPE_EVERY := 10
const SCARAB_LIVE_ENTER_PAD_M := 100.0
const SCARAB_LIVE_LEAVE_PAD_M := 140.0
const MATERIALIZE_PER_FRAME := 24

const NightScarabScene := preload("res://scenes/enemies/night_scarab.tscn")
const NightScarabScript := preload("res://scripts/enemies/night_scarab.gd")

var tower_index := 0
var _pill: MeshInstance3D
var _night_volume: NightVolume
var _child_volumes: Array[NightVolume] = []
var _forming_children: Array[NightVolume] = []
var _ground_y := 0.0
var _rise_t := 0.0
var _sink_t := 0.0
var _buried_t := 0.0
var _night_t := 0.0
var _spread_wait_t := 0.0
var _stand_t := 0.0
var _rising := false
var _sinking := false
var _buried_waiting := false
var _bringing_night := false
var _spreading := false
var _spread_full := false
var _night_unleashed := false
var _night_ramp_t := 0.0
var _encounter_started := false
var _relocate_count := 0
var _batch_size := 1
var _origin_xz := Vector2.ZERO
var _previous_xz: Array[Vector2] = []
var _scarabs: Array = []
var _spawn_acc: Dictionary = {}
var _spawn_counts: Dictionary = {}
var _volume_hot: Dictionary = {}
var _virtual_counts: Dictionary = {}
var _regen_accum := 0.0


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
	_origin_xz = Vector2(global_position.x, global_position.z)
	_previous_xz.clear()
	_previous_xz.append(_origin_xz)
	_rise_t = 0.0
	_sink_t = 0.0
	_buried_t = 0.0
	_night_t = 0.0
	_spread_wait_t = 0.0
	_stand_t = 0.0
	_rising = true
	_sinking = false
	_buried_waiting = false
	_bringing_night = false
	_spreading = false
	_spread_full = false
	_forming_children.clear()
	_night_unleashed = false
	_night_ramp_t = 0.0
	_encounter_started = false
	_relocate_count = 0
	_batch_size = 1
	_spawn_acc.clear()
	_spawn_counts.clear()
	_volume_hot.clear()
	_virtual_counts.clear()
	_regen_accum = 0.0
	_clear_scarabs()
	_clear_child_spheres()
	global_position.y = buried_y(ground_y)
	_ensure_night_volume()
	if _night_volume != null:
		_night_volume.configure(NightVolume.RADIUS_M, true)
	_sync_night_volume()


func standing_ground_y() -> float:
	return _ground_y


func has_finished_ascent() -> bool:
	return not _rising and not _sinking and not _buried_waiting and _rise_t >= ASCENT_SEC


func is_blocking_stream() -> bool:
	return _encounter_started


func is_sinking() -> bool:
	return _sinking


func is_buried_waiting() -> bool:
	return _buried_waiting


func relocate_count() -> int:
	return _relocate_count


func batch_size() -> int:
	return _batch_size


func origin_xz() -> Vector2:
	return _origin_xz


func previous_positions() -> Array[Vector2]:
	return _previous_xz


func follow_night_volume() -> NightVolume:
	return _night_volume


static func diameter_for_relocate(_relocate_index: int) -> float:
	return NightVolume.DIAMETER_M


func night_sphere_diameter() -> float:
	return diameter_for_relocate(_relocate_count)


func is_night_unleashed() -> bool:
	return _night_unleashed


func night_ramp_elapsed() -> float:
	return _night_ramp_t


static func night_regen_heal(elapsed_sec: float) -> int:
	return int(floorf(NIGHT_REGEN_PER_SEC * maxf(elapsed_sec, 0.0)))


func living_scarab_count() -> int:
	_cull_scarabs()
	return _scarabs.size()


func living_scarabs() -> Array:
	_cull_scarabs()
	return _scarabs


func virtual_scarab_count(volume: NightVolume = null) -> int:
	if volume != null:
		return int(_virtual_counts.get(volume, 0))
	var total := 0
	for key in _virtual_counts:
		total += int(_virtual_counts[key])
	return total


func scarab_population() -> int:
	return living_scarab_count() + virtual_scarab_count()


func is_volume_hot(volume: NightVolume) -> bool:
	return bool(_volume_hot.get(volume, false))


func begin_clock_night() -> void:
	if _night_unleashed:
		_hide_night_visuals()
		return
	_night_unleashed = true
	_night_ramp_t = 0.0
	_hide_night_visuals()
	_clear_scarabs()
	_spawn_acc.clear()
	_virtual_counts.clear()
	_volume_hot.clear()


func _tick_night_regen(delta: float) -> void:
	if not _night_unleashed or not is_alive():
		return
	var cap := get_max_health()
	if _hp >= cap:
		_regen_accum = 0.0
		return
	_regen_accum += NIGHT_REGEN_PER_SEC * delta
	var heal := int(floorf(_regen_accum))
	if heal <= 0:
		return
	_regen_accum -= float(heal)
	var next_hp := mini(_hp + heal, cap)
	if next_hp == _hp:
		return
	_hp = next_hp
	health_changed.emit(_hp, cap)


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


static func sink_y(ground_y: float, elapsed_sec: float) -> float:
	var t := clampf(elapsed_sec / ASCENT_SEC, 0.0, 1.0)
	return lerpf(standing_y(ground_y), buried_y(ground_y), t)


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
	_advance_child_fades(delta)
	if _rising:
		_tick_rise(delta)
	elif _sinking:
		_tick_sink(delta)
	elif _buried_waiting:
		_tick_buried(delta)
	elif _bringing_night:
		_tick_bring_night(delta)
	elif _spreading:
		_tick_spread(delta)
	if _is_standing():
		_stand_t += delta
		if _stand_t >= RELOCATE_PERIOD_SEC:
			_begin_sink()
	_tick_scarab_spawns(delta)
	_tick_night_regen(delta)
	_sync_night_volume()


func _is_standing() -> bool:
	return not _rising and not _sinking and not _buried_waiting


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
	if _night_volume != null and is_instance_valid(_night_volume):
		_night_volume.set_fade(0.0)
		_night_volume.visible = false
		if _night_volume.get_parent() != self:
			_night_volume.queue_free()
	_night_volume = null
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
	if _night_volume == null or not is_instance_valid(_night_volume):
		return
	if not _night_volume.follow_host:
		return
	_night_volume.snap_to_standing(global_position, _ground_y)
	_night_volume.set_fade(bring_the_night_fade())


func _tick_rise(delta: float) -> void:
	_rise_t = minf(_rise_t + delta, ASCENT_SEC)
	global_position.y = rise_y(_ground_y, _rise_t)
	if _rise_t < ASCENT_SEC:
		return
	_rising = false
	_bringing_night = true
	_encounter_started = true


func _tick_bring_night(delta: float) -> void:
	_night_t = minf(_night_t + delta, BRING_THE_NIGHT_SEC)
	if _night_t < BRING_THE_NIGHT_SEC:
		return
	_bringing_night = false
	_spreading = true
	_spread_wait_t = 0.0


func _tick_sink(delta: float) -> void:
	_sink_t = minf(_sink_t + delta, ASCENT_SEC)
	global_position.y = sink_y(_ground_y, _sink_t)
	if _sink_t < ASCENT_SEC:
		return
	_sinking = false
	_buried_waiting = true
	_buried_t = 0.0
	global_position.y = buried_y(_ground_y)


func _tick_buried(delta: float) -> void:
	_buried_t = minf(_buried_t + delta, BURIED_WAIT_SEC)
	if _buried_t < BURIED_WAIT_SEC:
		return
	_begin_relocate_ascent()


func _begin_sink() -> void:
	if _sinking or _buried_waiting or _rising:
		return
	_detach_follow_sphere()
	_sinking = true
	_bringing_night = false
	_spreading = false
	_sink_t = 0.0
	_stand_t = 0.0
	_rise_t = ASCENT_SEC


func _begin_relocate_ascent() -> void:
	_buried_waiting = false
	_relocate_count += 1
	_batch_size = 1 + _relocate_count
	var next_xz := try_pick_boss_xz(_rng, _origin_xz, _previous_xz)
	if not next_xz.is_finite():
		next_xz = Vector2(global_position.x, global_position.z)
	_apply_relocate_position(next_xz)
	_create_follow_sphere(diameter_for_relocate(_relocate_count) * 0.5)
	_night_t = 0.0
	_rise_t = 0.0
	_rising = true
	_stand_t = 0.0


func _apply_relocate_position(xz: Vector2) -> void:
	var ground_y := _ground_y
	if _terrain != null:
		ground_y = _terrain.sample_height(xz.x, xz.y)
	_ground_y = ground_y
	global_position = Vector3(xz.x, buried_y(ground_y), xz.y)
	_previous_xz.append(xz)


func _detach_follow_sphere() -> void:
	if _night_volume == null or not is_instance_valid(_night_volume):
		return
	var leftover := _night_volume
	leftover.follow_host = false
	leftover.mark_formed()
	var host := _scarab_host()
	if leftover.get_parent() != host:
		if leftover.get_parent() != null:
			leftover.reparent(host, true)
		else:
			host.add_child(leftover)
	leftover.top_level = true
	if _night_unleashed:
		leftover.set_visuals_enabled(false)
	_child_volumes.append(leftover)
	_night_volume = null


func _create_follow_sphere(radius_m: float) -> void:
	var volume := NightVolume.new()
	volume.name = "NightVolume_%d" % _relocate_count
	volume.follow_host = true
	var host := _scarab_host()
	host.add_child(volume)
	volume.top_level = true
	volume.configure(maxf(radius_m, 0.01), true)
	if _night_unleashed:
		volume.set_visuals_enabled(false)
	_night_volume = volume
	_sync_night_volume()


func _advance_child_fades(delta: float) -> void:
	for child in _child_volumes:
		if child != null and is_instance_valid(child):
			child.advance_fade(delta)


func _tick_spread(delta: float) -> void:
	if _forming_wave_pending():
		if _forming_wave_formed():
			for child in _forming_children:
				if child != null and is_instance_valid(child):
					child.mark_formed()
			_forming_children.clear()
			_spread_wait_t = 0.0
		return
	if _spread_full or not _can_plant_children():
		return
	_spread_wait_t += delta
	if _spread_wait_t < SPREAD_WAIT_SEC:
		return
	_spread_wait_t = 0.0
	if not _spawn_child_wave():
		_spread_full = true


func _can_plant_children() -> bool:
	return not _rising and not _sinking and not _buried_waiting and not _bringing_night


func _forming_wave_pending() -> bool:
	for child in _forming_children:
		if child != null and is_instance_valid(child):
			return true
	return false


func _forming_wave_formed() -> bool:
	if _forming_children.is_empty():
		return false
	for child in _forming_children:
		if child == null or not is_instance_valid(child) or not child.is_formed():
			return false
	return true


func _spawn_child_wave() -> bool:
	var planted := 0
	for _i in _batch_size:
		if not _spawn_child_sphere():
			break
		planted += 1
	return planted > 0


func _spawn_child_sphere() -> bool:
	var xz := try_pick_child_xz(
		_rng,
		_origin_xz,
		occupied_spheres_xz()
	)
	if not xz.is_finite():
		return false
	var ground_y := _ground_y
	if _terrain != null:
		ground_y = _terrain.sample_height(xz.x, xz.y)
	var child := NightVolume.new()
	child.name = "NightSphere_%d" % _child_volumes.size()
	child.follow_host = false
	var host := _scarab_host()
	host.add_child(child)
	child.top_level = true
	child.configure(CHILD_RADIUS_M, false)
	child.snap_to_standing(Vector3(xz.x, 0.0, xz.y), ground_y)
	child.begin_self_fade(CHILD_FORM_SEC)
	if _night_unleashed:
		child.set_visuals_enabled(false)
	_child_volumes.append(child)
	_forming_children.append(child)
	return true


func child_night_volumes() -> Array[NightVolume]:
	return _child_volumes


func is_night_spread_full() -> bool:
	return _spread_full


func occupied_spheres_xz() -> Array[Dictionary]:
	var occupied: Array[Dictionary] = []
	if _night_volume != null and is_instance_valid(_night_volume):
		occupied.append({
			"xz": Vector2(_night_volume.global_position.x, _night_volume.global_position.z),
			"r": _night_volume.radius_m,
		})
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
	_forming_children.clear()


func _tick_scarab_spawns(delta: float) -> void:
	_maybe_begin_clock_night()
	if _night_unleashed:
		_night_ramp_t += delta
		return
	_resolve_hunt_target()
	var rate := SCARAB_DAY_RATE
	var budget := MATERIALIZE_PER_FRAME
	for volume in formed_night_volumes():
		budget = _sync_volume_presence(volume, budget)
	var population := scarab_population()
	for volume in formed_night_volumes():
		population = _tick_volume_spawn(volume, rate, delta, population)


func _volume_should_be_hot(volume: NightVolume) -> bool:
	if _target == null or not is_instance_valid(_target):
		return true
	var dist := volume.xz_distance_to(_target.global_position)
	if bool(_volume_hot.get(volume, false)):
		return dist <= volume.radius_m + SCARAB_LIVE_LEAVE_PAD_M
	return dist < volume.radius_m + SCARAB_LIVE_ENTER_PAD_M


func _sync_volume_presence(volume: NightVolume, budget: int) -> int:
	var want_hot := _volume_should_be_hot(volume)
	var was_hot := bool(_volume_hot.get(volume, false))
	if was_hot and not want_hot:
		_fold_volume_scarabs(volume)
	_volume_hot[volume] = want_hot
	if want_hot:
		budget = _materialize_virtual(volume, budget)
	return budget


func _materialize_virtual(volume: NightVolume, budget: int) -> int:
	var pending := int(_virtual_counts.get(volume, 0))
	while pending > 0 and budget > 0:
		if not _instantiate_scarab(volume, false):
			break
		pending -= 1
		budget -= 1
	_virtual_counts[volume] = pending
	return budget


func _fold_volume_scarabs(volume: NightVolume) -> void:
	_cull_scarabs()
	var kept: Array = []
	var folded := 0
	for scarab in _scarabs:
		if scarab.home_volume() != volume or scarab.is_unshackled():
			kept.append(scarab)
			continue
		if scarab.died.is_connected(_on_scarab_died):
			scarab.died.disconnect(_on_scarab_died)
		scarab.queue_free()
		folded += 1
	_scarabs = kept
	_virtual_counts[volume] = int(_virtual_counts.get(volume, 0)) + folded


func _tick_volume_spawn(volume: NightVolume, rate: float, delta: float, population: int) -> int:
	var acc := float(_spawn_acc.get(volume, 0.0)) + rate * delta
	var spawned := 0
	var hot := bool(_volume_hot.get(volume, true))
	while acc >= 1.0 and population < SCARAB_CAP:
		acc -= 1.0
		if not _credit_scarab_spawn(volume, hot):
			break
		spawned += 1
		population += 1
	_spawn_acc[volume] = acc
	if spawned <= 0 and population >= SCARAB_CAP:
		_spawn_acc[volume] = minf(acc, 0.999)
	return population


func _credit_scarab_spawn(volume: NightVolume, hot: bool) -> bool:
	var count := int(_spawn_counts.get(volume, 0)) + 1
	_spawn_counts[volume] = count
	var can_leave := NightScarabScript.is_escape_spawn(count, ESCAPE_EVERY)
	if hot or can_leave:
		return _instantiate_scarab(volume, can_leave)
	_virtual_counts[volume] = int(_virtual_counts.get(volume, 0)) + 1
	return true


func _instantiate_scarab(volume: NightVolume, can_leave: bool) -> bool:
	var scarab := NightScarabScene.instantiate()
	scarab.configure(_terrain, _target, NightScarabScript.MOVE_SPEED)
	scarab.bind_sphere(volume, can_leave)
	var host := _scarab_host()
	host.add_child(scarab)
	scarab.top_level = true
	var pos := volume.random_point_xz(_rng)
	if _terrain != null:
		pos.y = _terrain.sample_height(pos.x, pos.z)
	else:
		pos.y = volume.global_position.y
	scarab.global_position = pos
	if not scarab.died.is_connected(_on_scarab_died):
		scarab.died.connect(_on_scarab_died)
	_scarabs.append(scarab)
	return true


func _resolve_hunt_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	_target = _find_player_body()


func _find_player_body() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var director := tree.get_first_node_in_group("boss_director")
	if director != null and director.has_method("player_body"):
		var body: Variant = director.call("player_body")
		if body is Node3D and is_instance_valid(body):
			return body as Node3D
	var health := tree.get_first_node_in_group("player_health")
	if health != null:
		var rig := health.get_parent()
		if rig != null and rig.has_method("get_glider"):
			var glider: Variant = rig.call("get_glider")
			if glider is Node3D and is_instance_valid(glider):
				return glider as Node3D
	return null


func _on_scarab_died() -> void:
	_cull_scarabs()


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
	if _night_volume != null and is_instance_valid(_night_volume) and _night_volume.is_spawn_ready():
		formed.append(_night_volume)
	for child in _child_volumes:
		if child != null and is_instance_valid(child) and child.is_spawn_ready():
			formed.append(child)
	return formed


func _scarab_host() -> Node:
	var host := get_parent()
	if host != null:
		return host
	return self


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


func _exit_tree() -> void:
	_clear_scarabs()
	_clear_child_spheres()
	if _night_volume != null and is_instance_valid(_night_volume) and _night_volume.get_parent() != self:
		_night_volume.queue_free()
		_night_volume = null


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


static func min_distance_to_points(point: Vector2, previous: Array[Vector2]) -> float:
	if previous.is_empty():
		return INF
	var best := INF
	for other in previous:
		best = minf(best, point.distance_to(other))
	return best


static func _sample_spread_disk(
	rng: RandomNumberGenerator,
	origin: Vector2,
	spread_radius: float
) -> Vector2:
	var dist := spread_radius * sqrt(rng.randf())
	var ang := rng.randf() * TAU
	return origin + Vector2(cos(ang), sin(ang)) * dist


static func try_pick_boss_xz(
	rng: RandomNumberGenerator,
	origin: Vector2,
	previous: Array[Vector2],
	spread_radius: float = SPREAD_RADIUS_M,
	min_sep: float = MIN_RELOCATE_SEP_M,
	tries: int = BOSS_PLACE_TRIES
) -> Vector2:
	var valid: Array[Vector2] = []
	var best := origin
	var best_min := -1.0
	for _i in tries:
		var point := _sample_spread_disk(rng, origin, spread_radius)
		var dmin := min_distance_to_points(point, previous)
		if dmin >= min_sep:
			valid.append(point)
		if dmin > best_min:
			best_min = dmin
			best = point
	for i in BOSS_RIM_SAMPLES:
		var ang := TAU * float(i) / float(BOSS_RIM_SAMPLES)
		var point := origin + Vector2(cos(ang), sin(ang)) * spread_radius
		var dmin := min_distance_to_points(point, previous)
		if dmin >= min_sep:
			valid.append(point)
		if dmin > best_min:
			best_min = dmin
			best = point
	if not valid.is_empty():
		return valid[rng.randi() % valid.size()]
	return best


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
