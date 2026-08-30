class_name DroneLaserBlast
extends Node3D

## Red ground pulse fired from a laser drone. Travels along the terrain at high speed.

const DAMAGE := 35
const SPEED_MPS := 120.0
const GROUND_OFFSET_M := 0.45
const CORE_RADIUS_M := 0.85
const GLOW_RADIUS_M := 2.4
const IMPACT_FLASH_SEC := 0.28
const MAX_LIFE_SEC := 30.0

var _terrain: TerrainManager
var _target: Node3D
var _damage := DAMAGE
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _path_length := 0.0
var _traveled := 0.0
var _life := 0.0
var _spent := false
var _impacting := false
var _impact_left := 0.0
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _light: OmniLight3D


static func fire(
	tree: SceneTree,
	origin: Vector3,
	target: Node3D,
	terrain: TerrainManager = null,
	damage: int = DAMAGE
) -> DroneLaserBlast:
	var blast := DroneLaserBlast.new()
	if tree != null:
		var parent := tree.current_scene
		if parent == null:
			parent = tree.root
		if parent != null:
			parent.add_child(blast)
	blast.configure(origin, target, terrain, damage)
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


static func path_length_between(start: Vector3, end: Vector3) -> float:
	return Vector2(end.x - start.x, end.z - start.z).length()


func configure(
	origin: Vector3,
	target: Node3D,
	terrain: TerrainManager,
	damage: int = DAMAGE
) -> void:
	_terrain = terrain
	_target = target
	_damage = damage
	var impact := target.global_position if target != null else origin
	_start = ground_point(origin, _terrain)
	_end = ground_point(impact, _terrain)
	_path_length = path_length_between(_start, _end)
	_traveled = 0.0
	_spent = false
	_impacting = false
	_impact_left = 0.0
	_life = 0.0
	_ensure_visuals()
	global_position = _start
	_update_visual_scale(1.0)
	set_process(true)
	if _path_length <= 0.08:
		_trigger_impact()


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
		var flash := 1.0 + (1.0 - _impact_left / IMPACT_FLASH_SEC) * 2.5
		_update_visual_scale(flash)
		if _light != null:
			_light.light_energy = 18.0 * maxf(_impact_left / IMPACT_FLASH_SEC, 0.0)
		if _impact_left <= 0.0:
			queue_free()
		return
	if _spent:
		return
	_traveled += SPEED_MPS * delta
	if _path_length <= 0.001:
		_trigger_impact()
		return
	var t := clampf(_traveled / _path_length, 0.0, 1.0)
	var flat := _start.lerp(_end, t)
	global_position = ground_point(flat, _terrain)
	_face_along_path(t)
	if _light != null:
		_light.light_energy = 6.0 + sin(_life * 28.0) * 2.0
	if t >= 1.0:
		_trigger_impact()


func _trigger_impact() -> void:
	if _spent:
		return
	_spent = true
	_impacting = true
	_impact_left = IMPACT_FLASH_SEC
	global_position = _end
	var tree := get_tree()
	if tree != null:
		apply_damage(tree, _damage, _target)
	_update_visual_scale(2.5)
	if _light != null:
		_light.light_energy = 18.0


func _face_along_path(t: float) -> void:
	var ahead_t := minf(t + 0.05, 1.0)
	var ahead := ground_point(_start.lerp(_end, ahead_t), _terrain)
	var flat := global_position
	var dir := Vector3(ahead.x - flat.x, 0.0, ahead.z - flat.z)
	if dir.length_squared() < 0.0001:
		return
	look_at(flat + dir.normalized(), Vector3.UP)


func _ensure_visuals() -> void:
	if _core != null:
		return

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = CORE_RADIUS_M
	core_mesh.height = CORE_RADIUS_M * 2.0
	_core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.18, 0.1)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.22, 0.08)
	core_mat.emission_energy_multiplier = 4.5
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core.material_override = core_mat
	add_child(_core)

	_glow = MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = GLOW_RADIUS_M
	glow_mesh.height = GLOW_RADIUS_M * 2.0
	_glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.12, 0.06, 0.35)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.15, 0.06)
	glow_mat.emission_energy_multiplier = 2.5
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.material_override = glow_mat
	add_child(_glow)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.2, 0.1)
	_light.light_energy = 6.0
	_light.omni_range = 18.0
	_light.shadow_enabled = false
	add_child(_light)


func _update_visual_scale(mult: float) -> void:
	var core_scale := Vector3.ONE * mult
	var glow_scale := Vector3.ONE * mult * 1.15
	if _core != null:
		_core.scale = core_scale
	if _glow != null:
		_glow.scale = glow_scale
