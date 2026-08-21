class_name LaserBeam
extends Node3D

## Solid red beam. Clock keeps running with no target.

const AIM_UP_M := 0.7
const RADIUS_CORE := 0.13
const RADIUS_GLOW := 0.22

var finished := false

var _fire_left := 0.0
var _next_tick := 0.0
var _target: Node3D
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _core_mesh: CylinderMesh
var _glow_mesh: CylinderMesh
var _spray: CPUParticles3D
var _burst: CPUParticles3D


func begin(
	fire_time: float,
	target: Node3D,
	damage_bonus: float,
	crit_chance: float,
	rng: RandomNumberGenerator
) -> void:
	_fire_left = maxf(fire_time, 0.0)
	_next_tick = AutoLaser.TICK_SEC
	_target = target
	finished = false
	_ensure_visuals()
	_deal_tick(damage_bonus, crit_chance, rng)


func advance(
	delta: float,
	origin: Vector3,
	facing: Vector3,
	pills: Array,
	rng: RandomNumberGenerator,
	damage_bonus: float,
	crit_chance: float
) -> void:
	if finished:
		return
	_fire_left -= delta
	if _fire_left <= 0.0:
		_finish()
		return
	if not _is_target_alive():
		_retarget(origin, facing, pills, rng)
	if _is_target_alive():
		_show_beam(origin, _aim_point())
		_next_tick -= delta
		while _next_tick <= 0.0 and not finished:
			_deal_tick(damage_bonus, crit_chance, rng)
			_next_tick += AutoLaser.TICK_SEC
	else:
		_hide_beam()
		_next_tick -= delta
		while _next_tick <= 0.0 and not finished:
			_next_tick += AutoLaser.TICK_SEC


func _deal_tick(
	damage_bonus: float = 0.0,
	crit_chance: float = 0.0,
	rng: RandomNumberGenerator = null
) -> void:
	if not _is_target_alive():
		return
	var pill := _target as SwarmPill
	if pill == null:
		return
	var is_crit := AutoRifle.roll_crit(crit_chance, rng)
	var amount := AutoRifle.crit_damage_for(AutoLaser.damage_for(damage_bonus), is_crit)
	var at := _aim_point()
	pill.take_damage(amount, Vector3.ZERO, is_crit)
	_pop_burst_at(at)


func _retarget(
	origin: Vector3, facing: Vector3, pills: Array, rng: RandomNumberGenerator
) -> void:
	var next := AutoLaser.closest_in_front(pills, origin, facing, AutoRifle.RANGE_M)
	if next == null:
		next = AutoRifle.pick_target(pills, origin, facing, AutoRifle.RANGE_M, rng)
	_target = next


func _is_target_alive() -> bool:
	if _target == null or not is_instance_valid(_target):
		_target = null
		return false
	if _target is SwarmPill and not (_target as SwarmPill).is_alive():
		_target = null
		return false
	return true


func _aim_point() -> Vector3:
	return _target.global_position + Vector3(0.0, AIM_UP_M, 0.0)


func _finish() -> void:
	finished = true
	_hide_beam()
	queue_free()


func _ensure_visuals() -> void:
	if _core != null:
		return
	_core_mesh = CylinderMesh.new()
	_core_mesh.top_radius = RADIUS_CORE
	_core_mesh.bottom_radius = RADIUS_CORE
	_core_mesh.height = 1.0
	_glow_mesh = CylinderMesh.new()
	_glow_mesh.top_radius = RADIUS_GLOW
	_glow_mesh.bottom_radius = RADIUS_GLOW
	_glow_mesh.height = 1.0
	_core = _make_rod(
		_core_mesh,
		_make_mat(Color(1.0, 0.18, 0.12, 1.0), Color(1.0, 0.08, 0.04, 1.0), 4.2)
	)
	_glow = _make_rod(
		_glow_mesh,
		_make_mat(Color(1.0, 0.16, 0.08, 0.35), Color(0.95, 0.08, 0.04, 1.0), 2.4)
	)
	add_child(_glow)
	add_child(_core)
	_spray = _make_sparks(false)
	_burst = _make_sparks(true)
	add_child(_spray)
	add_child(_burst)


func _make_rod(mesh: CylinderMesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var rod := MeshInstance3D.new()
	rod.mesh = mesh
	rod.material_override = mat
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rod.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	rod.visible = false
	return rod


func _make_sparks(one_shot: bool) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = one_shot
	sparks.explosiveness = 1.0 if one_shot else 0.15
	sparks.amount = 28 if one_shot else 36
	sparks.lifetime = 0.32 if one_shot else 0.4
	sparks.randomness = 0.65
	sparks.direction = Vector3(0.0, 1.0, 0.0)
	sparks.spread = 180.0
	sparks.gravity = Vector3(0.0, -14.0, 0.0)
	sparks.initial_velocity_min = 5.0 if one_shot else 3.5
	sparks.initial_velocity_max = 14.0 if one_shot else 9.0
	sparks.scale_amount_min = 0.7
	sparks.scale_amount_max = 1.5
	sparks.color = Color(1.0, 0.55, 0.22, 1.0)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.local_coords = false
	sparks.top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.82, 0.42, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.16, 1.0)
	mat.emission_energy_multiplier = 5.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	sparks.material_override = mat
	var spark := SphereMesh.new()
	spark.radius = 0.09
	spark.height = 0.18
	sparks.mesh = spark
	return sparks


func _make_mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	if albedo.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _show_beam(from: Vector3, to: Vector3) -> void:
	_ensure_visuals()
	visible = true
	global_position = from
	var dir := to - from
	var length := dir.length()
	if length < 0.08:
		_hide_beam()
		visible = true
		return
	if absf(dir.normalized().dot(Vector3.UP)) > 0.98:
		look_at(to, Vector3.FORWARD)
	else:
		look_at(to, Vector3.UP)
	_core_mesh.height = length
	_glow_mesh.height = length
	var mid := Vector3(0.0, 0.0, -length * 0.5)
	_core.position = mid
	_glow.position = mid
	_core.visible = true
	_glow.visible = true
	_place_sparks(to)
	if _spray != null:
		_spray.emitting = true


func _place_sparks(at: Vector3) -> void:
	if _spray != null:
		_spray.global_position = at
	if _burst != null:
		_burst.global_position = at


func _pop_burst_at(at: Vector3) -> void:
	_ensure_visuals()
	if _burst == null:
		return
	_burst.global_position = at
	_burst.restart()
	_burst.emitting = true


func _hide_beam() -> void:
	if _core != null:
		_core.visible = false
	if _glow != null:
		_glow.visible = false
	if _spray != null:
		_spray.emitting = false
