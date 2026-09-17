class_name LaserBeam
extends Node3D

## Scrolling streak beam, camera-facing ribbon. Clock keeps running with no target.

const AIM_UP_M := 0.7
const BEAM_GLOW_WIDTH := 0.28
const BEAM_CORE_WIDTH := 0.10
const BEAM_TILE_LENGTH_M := 2.5

const _GLOW_MAT := preload("res://assets/materials/vfx/laser_beam_glow.tres")
const _CORE_MAT := preload("res://assets/materials/vfx/laser_beam_core.tres")

var finished := false

var _fire_left := 0.0
var _next_tick := 0.0
var _target: Node3D
var _glow_ribbon: _BeamRibbon
var _core_ribbon: _BeamRibbon
var _spray: CPUParticles3D
var _burst: CPUParticles3D
var _bounce_count := 0
var _bounce_range := 0.0
var _acquire_range := 0.0
var _hops: Array[Node3D] = []
var _hop_glow_ribbons: Array[_BeamRibbon] = []
var _hop_core_ribbons: Array[_BeamRibbon] = []


func begin(
	fire_time: float,
	target: Node3D,
	damage_bonus: float,
	crit_chance: float,
	rng: RandomNumberGenerator,
	bounce_count: int = 0,
	bounce_range: float = 0.0,
	pills: Array = [],
	acquire_range: float = 0.0
) -> void:
	_fire_left = maxf(fire_time, 0.0)
	_next_tick = AutoLaser.TICK_SEC
	_target = target
	_bounce_count = maxi(bounce_count, 0)
	_bounce_range = maxf(bounce_range, 0.0)
	_acquire_range = maxf(acquire_range, 0.0)
	finished = false
	_ensure_visuals()
	_rebuild_hops(pills, rng)
	_deal_tick(damage_bonus, crit_chance, rng)


func advance(
	delta: float,
	origin: Vector3,
	facing: Vector3,
	pills: Array,
	rng: RandomNumberGenerator,
	damage_bonus: float,
	crit_chance: float,
	acquire_range: float = -1.0
) -> void:
	if acquire_range >= 0.0:
		_acquire_range = acquire_range
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
		_show_hops()
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
	_hurt_living(_target, damage_bonus, crit_chance, rng, true)
	_drop_dead_hops()
	for hop in _hops:
		_hurt_living(hop, damage_bonus, crit_chance, rng, false)


func _retarget(
	origin: Vector3, facing: Vector3, pills: Array, rng: RandomNumberGenerator
) -> void:
	var owner := get_parent() as AutoLaser
	var exclude: Dictionary = {}
	if owner != null:
		owner._release_primary(self)
		exclude = owner._claimed_lock_ids()
	var next := AutoLaser.pick_unique_target(
		pills, origin, facing, _acquire_range, exclude, rng
	)
	_target = next
	if owner != null and next != null:
		owner._claim_primary(self, next)
	_rebuild_hops(pills, rng)


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
	var owner := get_parent() as AutoLaser
	if owner != null:
		owner._release_primary(self)
	_hide_beam()
	queue_free()


func _ensure_visuals() -> void:
	if _glow_ribbon != null:
		return
	_glow_ribbon = _make_beam_ribbon(BEAM_GLOW_WIDTH, _GLOW_MAT)
	_core_ribbon = _make_beam_ribbon(BEAM_CORE_WIDTH, _CORE_MAT)
	add_child(_glow_ribbon.mesh_instance)
	add_child(_core_ribbon.mesh_instance)
	_spray = _make_sparks(false)
	_burst = _make_sparks(true)
	add_child(_spray)
	add_child(_burst)


func _make_beam_ribbon(width: float, mat_template: ShaderMaterial) -> _BeamRibbon:
	var ribbon := _BeamRibbon.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, 1.0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = quad
	var mat := mat_template.duplicate() as ShaderMaterial
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visible = false
	mesh_instance.top_level = true
	ribbon.mesh_instance = mesh_instance
	ribbon.mesh = quad
	ribbon.mat = mat
	return ribbon


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


func _show_beam(from: Vector3, to: Vector3) -> void:
	_ensure_visuals()
	visible = true
	global_position = from
	var length := from.distance_to(to)
	if length < 0.08:
		_hide_beam()
		visible = true
		return
	_apply_beam_ribbon(_glow_ribbon, from, to, length)
	_apply_beam_ribbon(_core_ribbon, from, to, length)
	_place_sparks(to)
	if _spray != null:
		_spray.emitting = true


func _beam_basis(from: Vector3, to: Vector3) -> Basis:
	var beam_dir := (to - from).normalized()
	var mid := from.lerp(to, 0.5)
	var to_cam := Vector3.UP
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var raw := cam.global_position - mid
		if raw.length_squared() > 0.0001:
			to_cam = raw.normalized()
	var side := beam_dir.cross(to_cam)
	if side.length_squared() < 0.0001:
		side = beam_dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = beam_dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var normal := side.cross(beam_dir).normalized()
	return Basis(side, beam_dir, normal)


func _apply_beam_ribbon(ribbon: _BeamRibbon, from: Vector3, to: Vector3, length: float) -> void:
	ribbon.mesh.size.y = length
	var mid := from.lerp(to, 0.5)
	ribbon.mesh_instance.global_transform = Transform3D(_beam_basis(from, to), mid)
	ribbon.mesh_instance.visible = true
	var tiles := maxf(length / BEAM_TILE_LENGTH_M, 1.0)
	ribbon.mat.set_shader_parameter("beam_tile_count", tiles)


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
	if _glow_ribbon != null:
		_glow_ribbon.mesh_instance.visible = false
	if _core_ribbon != null:
		_core_ribbon.mesh_instance.visible = false
	if _spray != null:
		_spray.emitting = false
	_hide_hops()


func _hurt_living(
	node: Variant,
	damage_bonus: float,
	crit_chance: float,
	rng: RandomNumberGenerator,
	pop_burst: bool
) -> void:
	if not _is_living(node):
		return
	var pill := node as SwarmPill
	if pill == null:
		return
	var is_crit := AutoRifle.roll_crit(crit_chance, rng)
	var amount := AutoRifle.crit_damage_for(AutoLaser.damage_for(damage_bonus), is_crit)
	var at := pill.global_position + Vector3(0.0, AIM_UP_M, 0.0)
	pill.take_damage(amount, Vector3.ZERO, is_crit, SwarmPill.HIT_KNOCKBACK_SPEED, UpgradeCatalog.FAMILY_LASER)
	if pop_burst:
		_pop_burst_at(at)


func _is_living(node: Variant) -> bool:
	## Untyped on purpose: a typed Node3D arg crashes if the hop was already freed.
	if node == null or not is_instance_valid(node):
		return false
	if not (node is Node3D):
		return false
	if node is SwarmPill and not (node as SwarmPill).is_alive():
		return false
	return true


func _rebuild_hops(pills: Array, rng: RandomNumberGenerator) -> void:
	_hops.clear()
	if _is_living(_target) and _bounce_count > 0:
		_hops = AutoRifle.build_bounce_chain(_target, pills, _bounce_count, _bounce_range, rng)
	_ensure_hop_visuals(_hops.size())
	_hide_hops()


func _ensure_hop_visuals(count: int) -> void:
	while _hop_glow_ribbons.size() < count:
		var glow_ribbon := _make_beam_ribbon(BEAM_GLOW_WIDTH, _GLOW_MAT)
		var core_ribbon := _make_beam_ribbon(BEAM_CORE_WIDTH, _CORE_MAT)
		add_child(glow_ribbon.mesh_instance)
		add_child(core_ribbon.mesh_instance)
		_hop_glow_ribbons.append(glow_ribbon)
		_hop_core_ribbons.append(core_ribbon)


func _drop_dead_hops() -> void:
	var keep: Array[Node3D] = []
	for hop in _hops:
		if _is_living(hop):
			keep.append(hop)
	_hops = keep


func _show_hops() -> void:
	_drop_dead_hops()
	if not _is_living(_target):
		_hide_hops()
		return
	var from := _aim_point()
	var prev_alive := true
	for i in _hops.size():
		var hop := _hops[i]
		var hop_alive := _is_living(hop)
		if i >= _hop_glow_ribbons.size() or not prev_alive or not hop_alive:
			if i < _hop_glow_ribbons.size():
				_hide_hop_segment(i)
			prev_alive = hop_alive
			if hop_alive:
				from = hop.global_position + Vector3(0.0, AIM_UP_M, 0.0)
			continue
		var to := hop.global_position + Vector3(0.0, AIM_UP_M, 0.0)
		_place_hop_segment(i, from, to)
		from = to
		prev_alive = true
	for i in range(_hops.size(), _hop_glow_ribbons.size()):
		_hide_hop_segment(i)


func _place_hop_segment(index: int, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.08:
		_hide_hop_segment(index)
		return
	_apply_beam_ribbon(_hop_glow_ribbons[index], from, to, length)
	_apply_beam_ribbon(_hop_core_ribbons[index], from, to, length)


func _hide_hop_segment(index: int) -> void:
	if index < _hop_glow_ribbons.size():
		_hop_glow_ribbons[index].mesh_instance.visible = false
	if index < _hop_core_ribbons.size():
		_hop_core_ribbons[index].mesh_instance.visible = false


func _hide_hops() -> void:
	for i in _hop_glow_ribbons.size():
		_hide_hop_segment(i)


class _BeamRibbon:
	var mesh_instance: MeshInstance3D
	var mesh: QuadMesh
	var mat: ShaderMaterial
