class_name DroneLaserBlast
extends Node3D

## Red ground pulse fired from a laser drone. Homes along terrain toward the player at high speed.

const DAMAGE := 35
const SPEED_MPS := 120.0
const GROUND_OFFSET_M := 0.55
const IMPACT_RADIUS_M := 1.35
const CORE_RADIUS_M := 1.15
const GLOW_RADIUS_M := 3.6
const WAKE_RADIUS_M := 5.5
const IMPACT_FLASH_SEC := 0.35
const MAX_LIFE_SEC := 30.0

var _terrain: TerrainManager
var _target: Node3D
var _damage := DAMAGE
var _life := 0.0
var _spent := false
var _impacting := false
var _impact_left := 0.0
var _air_mode := false
var _air_impact := Vector3.ZERO
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _wake: MeshInstance3D
var _light: OmniLight3D


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
	var blast := DroneLaserBlast.new()
	if tree != null:
		var parent := tree.current_scene
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
	_ensure_visuals()
	global_position = ground_point(origin, _terrain)
	_update_visual_scale(1.0)
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
	_ensure_visuals()
	global_position = origin
	_update_visual_scale(1.0)
	_face_toward(impact - origin)
	set_process(true)


func is_finished() -> bool:
	return _spent


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
		var flash := 1.0 + (1.0 - _impact_left / IMPACT_FLASH_SEC) * 3.0
		_update_visual_scale(flash)
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
	if _wake != null:
		_wake.scale = Vector3.ONE * (1.0 + sin(_life * 18.0) * 0.08)


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
	_update_visual_scale(1.0 + sin(_life * 18.0) * 0.06)


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
	var tree := get_tree()
	if not _air_mode and tree != null and _target != null and is_instance_valid(_target):
		if find_player_health(tree, _target) != null:
			apply_damage(tree, _damage, _target)
			_trigger_hit_hue(tree)
	_update_visual_scale(3.0)
	if _light != null:
		_light.light_energy = 24.0


func _trigger_hit_hue(tree: SceneTree) -> void:
	if tree == null:
		return
	var hud := tree.get_first_node_in_group("glider_hud")
	if hud != null and hud.has_method("play_laser_drone_hit_hue"):
		hud.play_laser_drone_hit_hue()


func _face_toward(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var look := dir.normalized()
	if absf(look.dot(Vector3.UP)) > 0.98:
		look_at(global_position + look, Vector3.FORWARD)
		return
	look_at(global_position + look, Vector3.UP)


func _ensure_visuals() -> void:
	if _core != null:
		return

	_wake = MeshInstance3D.new()
	var wake_mesh := SphereMesh.new()
	wake_mesh.radius = WAKE_RADIUS_M
	wake_mesh.height = WAKE_RADIUS_M * 2.0
	_wake.mesh = wake_mesh
	var wake_mat := StandardMaterial3D.new()
	wake_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.18)
	wake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wake_mat.emission_enabled = true
	wake_mat.emission = Color(1.0, 0.12, 0.05)
	wake_mat.emission_energy_multiplier = 1.8
	wake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wake_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wake.material_override = wake_mat
	_wake.scale = Vector3(1.0, 0.22, 1.0)
	add_child(_wake)

	_glow = MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = GLOW_RADIUS_M
	glow_mesh.height = GLOW_RADIUS_M * 2.0
	_glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.12, 0.06, 0.42)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.18, 0.06)
	glow_mat.emission_energy_multiplier = 3.5
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow.material_override = glow_mat
	_glow.scale = Vector3(1.0, 0.35, 1.0)
	add_child(_glow)

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = CORE_RADIUS_M
	core_mesh.height = CORE_RADIUS_M * 2.0
	_core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.22, 0.1)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.28, 0.08)
	core_mat.emission_energy_multiplier = 6.5
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core.material_override = core_mat
	_core.scale = Vector3(1.0, 0.55, 1.0)
	add_child(_core)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.24, 0.1)
	_light.light_energy = 10.0
	_light.omni_range = 28.0
	_light.shadow_enabled = false
	add_child(_light)


func _update_visual_scale(mult: float) -> void:
	var core_scale := Vector3.ONE * mult
	var glow_scale := Vector3.ONE * mult * 1.12
	var wake_scale := Vector3.ONE * mult * 1.25
	if not _air_mode:
		core_scale = Vector3(1.0, 0.55, 1.0) * mult
		glow_scale = Vector3(1.0, 0.35, 1.0) * mult * 1.12
		wake_scale = Vector3(1.0, 0.22, 1.0) * mult * 1.25
	if _core != null:
		_core.scale = core_scale
	if _glow != null:
		_glow.scale = glow_scale
	if _wake != null:
		_wake.scale = wake_scale
