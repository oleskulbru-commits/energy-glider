class_name SunEater
extends SwarmPill

## Stationary DPS-check boss. Rises from underground, then stands still.

signal health_changed(current: int, max_hp: int)

const PILL_COLOR := Color(0.15, 0.45, 0.95)
const TOWER_HEIGHT_M := 100.0
const HEIGHT_M := TOWER_HEIGHT_M
const RADIUS_M := 7.0
const ASCENT_SEC := 3.0
const BRING_THE_NIGHT_SEC := 8.0
const DAMAGE_FLOAT_Y_M := 9.0

var tower_index := 0
var _pill: MeshInstance3D
var _night_volume: NightVolume
var _ground_y := 0.0
var _rise_t := 0.0
var _night_t := 0.0
var _rising := false
var _bringing_night := false


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
	_rising = true
	_bringing_night = false
	global_position.y = buried_y(ground_y)
	_sync_night_volume()


func standing_ground_y() -> float:
	return _ground_y


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
	return RADIUS_M + 4.0


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
	_sync_night_volume()


func _sync_night_volume() -> void:
	if _night_volume == null:
		return
	_night_volume.snap_to_standing(global_position, _ground_y)
	_night_volume.set_fade(bring_the_night_fade())


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
	mat.roughness = 0.42
	mat.emission_enabled = true
	mat.emission = PILL_COLOR
	mat.emission_energy_multiplier = 1.35
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
