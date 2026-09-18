class_name DroneLaserBlast
extends Node3D

## Red ground pulse fired from a laser drone. Homes along terrain toward the player at high speed.

const BLAST_SCENE := preload("res://scenes/effects/drone_laser_blast.tscn")
const MuzzleFlashScript := preload("res://scripts/vfx/muzzle_flash.gd")
const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")

const DAMAGE := 35
const SPEED_MPS := 120.0
const GROUND_OFFSET_M := 0.55
const IMPACT_RADIUS_M := 1.35
const IMPACT_FLASH_SEC := 0.35
const IMPACT_FIRE_SCALE := 2.0
const MAX_LIFE_SEC := 30.0
const TRACER_VISUAL_SCALE := 4.0
const TRACER_PULSE_AMPLITUDE := 0.08
const TRACER_PULSE_HZ := 18.0
const TRACER_DISPLACEMENT_STRENGTH := 0.09
const TRACER_DISPLACEMENT_PULSE := 0.08

var _terrain: TerrainManager
var _target: Node3D
var _damage := DAMAGE
var _life := 0.0
var _spent := false
var _impacting := false
var _impact_left := 0.0
var _air_mode := false
var _air_impact := Vector3.ZERO

@onready var _tracer: MeshInstance3D = $Tracer
@onready var _muzzle_flash: MuzzleFlashScript = $MuzzleFlash
@onready var _light: OmniLight3D = $TravelLight


static func fire(
	tree: SceneTree,
	origin: Vector3,
	target: Node3D,
	terrain: TerrainManager = null,
	damage: int = DAMAGE
) -> DroneLaserBlast:
	var blast := _spawn(tree)
	blast.configure(origin, target, terrain, damage)
	return blast


static func fire_at_point(
	tree: SceneTree,
	origin: Vector3,
	impact: Vector3,
	damage: int = DAMAGE
) -> DroneLaserBlast:
	var blast := _spawn(tree)
	blast.configure_air(origin, impact, damage)
	return blast


static func _spawn(tree: SceneTree) -> DroneLaserBlast:
	var blast := BLAST_SCENE.instantiate() as DroneLaserBlast
	if tree != null:
		var parent := SceneUtilScript.world_parent(tree)
		if parent == null:
			parent = tree.root
		if parent != null:
			parent.add_child(blast)
	return blast


static func apply_damage(tree: SceneTree, amount: int, target: Node3D = null) -> void:
	if amount <= 0 or tree == null:
		return
	var health := find_player_health(tree, target)
	if health != null and health.has_method("take_damage"):
		health.take_damage(amount)


static func find_player_health(tree: SceneTree, target: Node3D = null) -> Node:
	if target != null:
		var parent := target.get_parent()
		if parent != null:
			for child in parent.get_children():
				if child.is_in_group("player_health"):
					return child
			var named := parent.get_node_or_null("PlayerHealth")
			if named != null:
				return named
	if tree == null:
		return null
	return tree.get_first_node_in_group("player_health")


static func ground_point(world: Vector3, terrain: TerrainManager) -> Vector3:
	var ground_y := 0.0
	if terrain != null:
		ground_y = terrain.sample_height(world.x, world.z)
	return Vector3(world.x, ground_y + GROUND_OFFSET_M, world.z)


func configure(
	origin: Vector3,
	target: Node3D,
	terrain: TerrainManager,
	damage: int = DAMAGE
) -> void:
	_air_mode = false
	_terrain = terrain
	_target = target
	_damage = damage
	_spent = false
	_impacting = false
	_impact_left = 0.0
	_life = 0.0
	global_position = ground_point(origin, _terrain)
	_update_tracer_scale(1.0)
	if _muzzle_flash != null:
		_muzzle_flash.flash()
	set_process(true)
	_try_impact_if_close()


func configure_air(origin: Vector3, impact: Vector3, damage: int = DAMAGE) -> void:
	_air_mode = true
	_air_impact = impact
	_terrain = null
	_target = null
	_damage = damage
	_spent = false
	_impacting = false
	_impact_left = 0.0
	_life = 0.0
	global_position = origin
	_update_tracer_scale(1.0)
	_face_toward(impact - origin)
	if _muzzle_flash != null:
		_muzzle_flash.flash()
	set_process(true)


func is_finished() -> bool:
	return _spent


func get_bolt_visual() -> Node3D:
	return _tracer


func advance(delta: float) -> void:
	_process(delta)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_life += delta
	if _life >= MAX_LIFE_SEC:
		queue_free()
		return
	if _impacting:
		_impact_left = maxf(_impact_left - delta, 0.0)
		if _light != null:
			_light.light_energy = 24.0 * maxf(_impact_left / IMPACT_FLASH_SEC, 0.0)
		if _impact_left <= 0.0:
			queue_free()
		return
	if _spent:
		return
	if _air_mode:
		_process_air(delta)
		return

	var aim := _current_target_ground()
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var aim_flat := Vector3(aim.x, 0.0, aim.z)
	var to := aim_flat - flat
	var dist := to.length()
	if dist <= IMPACT_RADIUS_M:
		global_position = aim
		_trigger_impact()
		return

	var step := SPEED_MPS * delta
	if step >= dist:
		global_position = aim
		_face_toward(aim_flat - flat)
		_trigger_impact()
		return

	var dir := to / dist
	var next_flat := flat + dir * step
	global_position = ground_point(next_flat, _terrain)
	_face_toward(dir)
	if _light != null:
		_light.light_energy = 8.0 + sin(_life * 32.0) * 3.0
	var pulse := 1.0 + sin(_life * TRACER_PULSE_HZ) * TRACER_PULSE_AMPLITUDE
	_update_tracer_scale(pulse)


func _process_air(delta: float) -> void:
	var to := _air_impact - global_position
	var dist := to.length()
	if dist <= IMPACT_RADIUS_M:
		global_position = _air_impact
		_trigger_impact()
		return
	var step := SPEED_MPS * delta
	if step >= dist:
		global_position = _air_impact
		_face_toward(to)
		_trigger_impact()
		return
	var dir := to / dist
	global_position += dir * step
	_face_toward(dir)
	if _light != null:
		_light.light_energy = 8.0 + sin(_life * 32.0) * 3.0
	var pulse := 1.0 + sin(_life * TRACER_PULSE_HZ) * TRACER_PULSE_AMPLITUDE
	_update_tracer_scale(pulse)


func _current_target_ground() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		return global_position
	return ground_point(_target.global_position, _terrain)


func _try_impact_if_close() -> void:
	var aim := _current_target_ground()
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var aim_flat := Vector3(aim.x, 0.0, aim.z)
	if flat.distance_to(aim_flat) <= IMPACT_RADIUS_M:
		global_position = aim
		_trigger_impact()


func _trigger_impact() -> void:
	if _spent:
		return
	_spent = true
	_impacting = true
	_impact_left = IMPACT_FLASH_SEC
	if _air_mode:
		global_position = _air_impact
	else:
		global_position = _current_target_ground()
	_set_travel_visible(false)
	var tree := get_tree()
	if tree != null:
		_spawn_impact_fire(tree)
	if not _air_mode and tree != null and _target != null and is_instance_valid(_target):
		apply_damage(tree, _damage, _target)
	if _light != null:
		_light.light_energy = 24.0


func _spawn_impact_fire(tree: SceneTree) -> void:
	SandImpactDustScript.spawn(
		tree,
		global_position,
		_terrain,
		SandParticleVfxScript.BurstPreset.LASER,
		IMPACT_FIRE_SCALE
	)


func _face_toward(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var look := dir.normalized()
	if absf(look.dot(Vector3.UP)) > 0.98:
		look_at(global_position + look, Vector3.FORWARD)
		return
	look_at(global_position + look, Vector3.UP)


func _update_tracer_scale(mult: float) -> void:
	if _tracer == null:
		return
	_tracer.scale = Vector3.ONE * TRACER_VISUAL_SCALE * mult
	var mat := _tracer.material_override as ShaderMaterial
	if mat != null:
		var pulse := (mult - 1.0) / TRACER_PULSE_AMPLITUDE
		var displacement := TRACER_DISPLACEMENT_STRENGTH * (
			1.0 + pulse * TRACER_DISPLACEMENT_PULSE
		)
		mat.set_shader_parameter("displacement_strength", displacement)


func _set_travel_visible(is_visible: bool) -> void:
	if _tracer != null:
		_tracer.visible = is_visible
	if _muzzle_flash != null:
		_muzzle_flash.visible = is_visible
