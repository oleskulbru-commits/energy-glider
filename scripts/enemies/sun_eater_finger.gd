class_name SunEaterFinger
extends SwarmPill

## Black spear weak point slammed by the Sun Eater. Hits redirect into the boss.

const GROUP := &"sun_eater_finger"
const PILL_COLOR := Color(0.02, 0.02, 0.03)
const HEIGHT_M := 22.0
const RADIUS_M := 0.85
const IMPACT_RADIUS_M := 10.0
const CENTER_DAMAGE := 100
const EDGE_DAMAGE := 30
const SLAM_SEC := 0.25
const LINGER_SEC := 10.0
const FADE_SEC := 1.0
const EMBED_DEPTH_M := 4.0
const BLAST_MAX_ABOVE_M := 80.0
const DAMAGE_FLOAT_Y_M := 12.0
const FingerShockwaveScript := preload("res://scripts/enemies/finger_shockwave.gd")

var _boss: SunEater
var _pill: MeshInstance3D
var _slam_from := Vector3.ZERO
var _slam_to := Vector3.ZERO
var _slam_t := 0.0
var _slamming := false
var _embedded := false
var _fading := false
var _linger_t := 0.0
var _fade_t := 0.0
var _impact := Vector3.ZERO
var _reticle
var _mat: StandardMaterial3D
var _homing := false


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	contact_damage = 0
	move_speed = 0.0
	collision_mask = 0
	_max_health = 1
	_hp = 1
	_strip_crawler_visual()
	_ensure_pill_visual()
	_apply_finger_hitbox()


func apply_level_hp(_level: int) -> void:
	pass


func apply_difficulty(_bonus: float) -> void:
	pass


func hit_radius() -> float:
	return RADIUS_M


func is_alive() -> bool:
	return _embedded and _hp > 0 and not is_queued_for_deletion()


func is_slamming() -> bool:
	return _slamming


func is_embedded() -> bool:
	return _embedded


func is_fading() -> bool:
	return _fading


func slam_impact() -> Vector3:
	return _impact


func is_homing() -> bool:
	return _homing


func _blocks_behind_despawn() -> bool:
	return true


func _spawn_damage_float(amount: int, is_crit: bool = false) -> void:
	DamageFloat.spawn_world(self, amount, _rng, DAMAGE_FLOAT_Y_M, is_crit)


func _apply_visual_scale() -> void:
	pass


func _apply_hitbox_scale() -> void:
	_apply_finger_hitbox()


static func impact_damage_at(dist_m: float) -> int:
	if dist_m > IMPACT_RADIUS_M:
		return 0
	var t := clampf(dist_m / IMPACT_RADIUS_M, 0.0, 1.0)
	return int(round(lerpf(float(CENTER_DAMAGE), float(EDGE_DAMAGE), t)))


static func redirect_hit(amount: int, natural_crit: bool) -> Dictionary:
	var dealt := maxi(amount, 0) * 2
	if natural_crit:
		dealt = int(round(float(maxi(amount, 0)) * 1.5))
	return {"amount": dealt, "is_crit": true}


func begin_slam(
	boss: SunEater,
	from: Vector3,
	impact: Vector3,
	reticle = null,
	homing: bool = false
) -> void:
	_boss = boss
	_reticle = reticle
	_homing = homing
	_impact = impact
	_slam_from = from
	_slam_to = Vector3(impact.x, impact.y - EMBED_DEPTH_M, impact.z)
	_slam_t = 0.0
	_slamming = true
	_embedded = false
	_fading = false
	global_position = from
	rotation = Vector3.ZERO
	if _homing:
		_retarget_homing_impact()


func take_damage(
	amount: int,
	hit_dir: Vector3 = Vector3.ZERO,
	is_crit: bool = false,
	_knockback_speed: float = 0.0,
	weapon_family: StringName = &""
) -> bool:
	if amount <= 0 or not is_alive():
		return false
	if not _embedded:
		return false
	var boss := _living_boss()
	if boss == null:
		return false
	var hit := redirect_hit(amount, is_crit)
	var dealt := int(hit["amount"])
	var crit := bool(hit["is_crit"])
	_spawn_damage_float(dealt, crit)
	return boss.apply_finger_hit(dealt, hit_dir, crit, weapon_family)


func _physics_process(delta: float) -> void:
	if _slamming:
		_tick_slam(delta)
		return
	if _fading:
		_tick_fade(delta)
		return
	if _embedded:
		_tick_linger(delta)


func _tick_slam(delta: float) -> void:
	if _homing:
		_retarget_homing_impact()
	_slam_t = minf(_slam_t + delta, SLAM_SEC)
	var t := 1.0
	if SLAM_SEC > 0.0:
		t = clampf(_slam_t / SLAM_SEC, 0.0, 1.0)
	global_position = _slam_from.lerp(_slam_to, t)
	if _slam_t < SLAM_SEC:
		return
	_finish_slam()


func _retarget_homing_impact() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var pos := _target.global_position
	var ground_y := pos.y
	if _terrain != null:
		ground_y = _terrain.sample_height(pos.x, pos.z)
	_impact = Vector3(pos.x, ground_y, pos.z)
	_slam_to = Vector3(_impact.x, _impact.y - EMBED_DEPTH_M, _impact.z)


func _finish_slam() -> void:
	_slamming = false
	_embedded = true
	_linger_t = 0.0
	rotation = Vector3.ZERO
	global_position = _slam_to
	_clear_reticle()
	FingerShockwaveScript.spawn(get_tree(), _impact, _terrain)
	_hurt_player_at_impact()


func _tick_linger(delta: float) -> void:
	_linger_t += delta
	if _linger_t < LINGER_SEC:
		return
	_fading = true
	_fade_t = 0.0


func _tick_fade(delta: float) -> void:
	_fade_t += delta
	var t := 1.0
	if FADE_SEC > 0.0:
		t = clampf(_fade_t / FADE_SEC, 0.0, 1.0)
	_set_fade_alpha(1.0 - t)
	if _fade_t < FADE_SEC:
		return
	_despawn()


func _hurt_player_at_impact() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var health := tree.get_first_node_in_group("player_health")
	if health == null or not health.has_method("take_damage"):
		return
	var pos := _impact
	if _target != null and is_instance_valid(_target):
		pos = _target.global_position
	elif health.get_parent() is Node3D:
		pos = (health.get_parent() as Node3D).global_position
	var dy := pos.y - _impact.y
	if dy > BLAST_MAX_ABOVE_M or dy < -4.0:
		return
	var dist := Vector2(pos.x - _impact.x, pos.z - _impact.z).length()
	var dmg := impact_damage_at(dist)
	if dmg > 0:
		health.call("take_damage", dmg)


func _living_boss() -> SunEater:
	if _boss != null and is_instance_valid(_boss) and _boss.is_alive():
		return _boss
	var tree := get_tree()
	if tree == null:
		return null
	var node := tree.get_first_node_in_group("sun_eater")
	if node is SunEater and (node as SunEater).is_alive():
		_boss = node as SunEater
		return _boss
	return null


func _set_fade_alpha(alpha: float) -> void:
	if _mat == null:
		return
	var color := PILL_COLOR
	color.a = clampf(alpha, 0.0, 1.0)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = color
	_mat.emission_energy_multiplier = 0.28 * color.a
	if _pill != null:
		_pill.visible = color.a > 0.02


func _clear_reticle() -> void:
	if _reticle != null and is_instance_valid(_reticle):
		_reticle.queue_free()
	_reticle = null


func _despawn() -> void:
	_hp = 0
	_embedded = false
	_fading = false
	_slamming = false
	_clear_reticle()
	queue_free()


func _strip_crawler_visual() -> void:
	var old_visual := get_node_or_null("Visual")
	if old_visual != null:
		old_visual.queue_free()


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
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = PILL_COLOR
	_mat.roughness = 0.62
	_mat.emission_enabled = true
	_mat.emission = Color(0.06, 0.06, 0.07)
	_mat.emission_energy_multiplier = 0.28
	_pill.material_override = _mat


func _apply_finger_hitbox() -> void:
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


func _exit_tree() -> void:
	_clear_reticle()
