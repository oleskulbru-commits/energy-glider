class_name DroneStreakVfx
extends Node3D

## Toggles rear thruster streaks when the owning drone moves; hover streaks stay on at half brightness and opacity.

const THRUSTER_STREAKS_PATH := NodePath("Body/Rebel_Drone/ThrusterStreaks")
const HOVER_STREAKS_PATH := NodePath("Body/Rebel_Drone/HoverStreaks")
const REBEL_DRONE_PATH := NodePath("Body/Rebel_Drone")
const MOVE_SPEED_THRESHOLD_MPS := 0.5
const HOVER_BRIGHTNESS_MULT := 0.5
const DEFAULT_GLOW_STRENGTH := 3.0
const EMISSIVE_SURFACE_INDEX := 1
const THRUSTER_SURFACE_INDEX := 2
const DEATH_EMISSIVE_ENERGY_MULT := 0.15

var _thruster_streaks: Node3D
var _hover_streaks: Node3D
var _thruster_glow_strength := DEFAULT_GLOW_STRENGTH
var _death_prepared := false


func _ready() -> void:
	_thruster_streaks = get_node_or_null(THRUSTER_STREAKS_PATH) as Node3D
	_hover_streaks = get_node_or_null(HOVER_STREAKS_PATH) as Node3D
	if _thruster_streaks == null or _hover_streaks == null:
		push_warning("DroneStreakVfx: missing streak groups on %s" % get_path())
		set_physics_process(false)
		return

	_setup_thruster_materials()
	_setup_hover_materials()

	if _hover_streaks != null:
		_hover_streaks.visible = true
	if _thruster_streaks != null:
		_thruster_streaks.visible = false

	set_physics_process(true)


func prepare_for_death() -> void:
	if _death_prepared:
		return
	_death_prepared = true
	set_physics_process(false)
	if _hover_streaks != null:
		_hover_streaks.visible = false
	_mute_rebel_drone_emissives()


func find_thruster_streaks() -> Node3D:
	return _thruster_streaks


func get_rebel_drone() -> MeshInstance3D:
	return get_node_or_null(REBEL_DRONE_PATH) as MeshInstance3D


func get_emissive_energy_multiplier() -> float:
	var rebel := get_rebel_drone()
	if rebel == null:
		return -1.0
	var mat := rebel.get_surface_override_material(EMISSIVE_SURFACE_INDEX)
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).emission_energy_multiplier
	return -1.0


func _physics_process(_delta: float) -> void:
	if _death_prepared or _thruster_streaks == null:
		return
	var owner_body := _find_owner_body()
	if owner_body == null:
		_thruster_streaks.visible = false
		return
	_thruster_streaks.visible = owner_body.velocity.length() >= MOVE_SPEED_THRESHOLD_MPS


func get_thruster_glow_strength() -> float:
	return _thruster_glow_strength


func get_hover_glow_strength() -> float:
	return _thruster_glow_strength * HOVER_BRIGHTNESS_MULT


func get_hover_streak_opacity() -> float:
	var first := _first_streak_mesh(_hover_streaks)
	if first == null:
		return -1.0
	return _read_streak_opacity(first.material_override)


func _setup_thruster_materials() -> void:
	var first := _first_streak_mesh(_thruster_streaks)
	if first == null:
		return
	_duplicate_streak_material(first)
	_thruster_glow_strength = _read_glow_strength(first.material_override)
	for mesh in _collect_streak_meshes(_thruster_streaks):
		if mesh == first:
			continue
		_duplicate_streak_material(mesh)
		_set_glow_strength(mesh.material_override, _thruster_glow_strength)


func _setup_hover_materials() -> void:
	for mesh in _collect_streak_meshes(_hover_streaks):
		_duplicate_streak_material(mesh)
		_apply_hover_streak_scale(mesh.material_override)


func _find_owner_body() -> CharacterBody3D:
	var node: Node = self
	while node != null:
		if node is CharacterBody3D:
			return node as CharacterBody3D
		node = node.get_parent()
	return null


func _collect_streak_meshes(root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root == null:
		return out
	for child in root.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
	return out


func _first_streak_mesh(root: Node3D) -> MeshInstance3D:
	for mesh in _collect_streak_meshes(root):
		return mesh
	return null


func _duplicate_streak_material(mesh: MeshInstance3D) -> void:
	var mat := mesh.material_override
	if mat == null:
		return
	mesh.material_override = mat.duplicate()


func _read_glow_strength(material: Material) -> float:
	if material is ShaderMaterial:
		var value: Variant = (material as ShaderMaterial).get_shader_parameter("GlowStrength")
		if value is float or value is int:
			return float(value)
	return DEFAULT_GLOW_STRENGTH


func _set_glow_strength(material: Material, glow: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("GlowStrength", glow)


func _read_streak_opacity(material: Material) -> float:
	if material is ShaderMaterial:
		var color: Variant = (material as ShaderMaterial).get_shader_parameter("ColorParameter")
		if color is Color:
			return (color as Color).a
	return -1.0


func _apply_hover_streak_scale(material: Material) -> void:
	if not material is ShaderMaterial:
		return
	var shader_mat := material as ShaderMaterial
	_set_glow_strength(shader_mat, _thruster_glow_strength * HOVER_BRIGHTNESS_MULT)
	var color: Variant = shader_mat.get_shader_parameter("ColorParameter")
	if color is Color:
		var streak_color := color as Color
		shader_mat.set_shader_parameter(
			"ColorParameter",
			Color(
				streak_color.r,
				streak_color.g,
				streak_color.b,
				streak_color.a * HOVER_BRIGHTNESS_MULT
			)
		)


func _mute_rebel_drone_emissives() -> void:
	var rebel := get_rebel_drone()
	if rebel == null:
		return
	for surface_idx in [EMISSIVE_SURFACE_INDEX, THRUSTER_SURFACE_INDEX]:
		var mat := rebel.get_surface_override_material(surface_idx)
		if mat == null:
			continue
		var muted := mat.duplicate() as StandardMaterial3D
		if muted == null:
			continue
		if muted.emission_enabled:
			muted.emission_energy_multiplier *= DEATH_EMISSIVE_ENERGY_MULT
		rebel.set_surface_override_material(surface_idx, muted)
