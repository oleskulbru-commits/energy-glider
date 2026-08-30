class_name GliderHeadlights
extends Node3D

const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")

const VISIBILITY_THRESHOLD := 0.02
const MIN_EMISSION_ENERGY := 3.0

@export var spot_light_path: NodePath = ^"SpotLight3D"
@export var emission_energy := 3.0
@export var emission_color := Color(1.0, 0.95, 0.82, 1.0)
@export var emission_surface_names: Array[String] = ["Headlights"]

var _spot_light: SpotLight3D
var _day_night: DayNightCycle
var _base_energy := -1.0
var _mesh_entries: Array[Dictionary] = []
var _current_emission_energy := 0.0


func _ready() -> void:
	_ensure_spot_light()
	_discover_meshes()
	_resolve_day_night()
	_sync_headlights()


func _process(_delta: float) -> void:
	_sync_headlights()


func get_emission_energy() -> float:
	return _current_emission_energy


func _ensure_spot_light() -> void:
	if _spot_light == null or not is_instance_valid(_spot_light):
		_spot_light = get_node_or_null(spot_light_path) as SpotLight3D


func _resolve_day_night() -> void:
	if _day_night == null or not is_instance_valid(_day_night):
		_day_night = get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle


func _discover_meshes() -> void:
	_mesh_entries.clear()
	_collect_meshes(self)


func _collect_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_register_mesh(child as MeshInstance3D)
		_collect_meshes(child)


func _register_mesh(mesh: MeshInstance3D) -> void:
	if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		for surface_index in mesh.mesh.get_surface_count():
			if not _is_emission_surface(mesh, surface_index):
				continue
			var source := mesh.get_surface_override_material(surface_index)
			if source == null:
				source = mesh.mesh.surface_get_material(surface_index)
			var material: StandardMaterial3D
			if source is StandardMaterial3D:
				material = (source as StandardMaterial3D).duplicate()
			else:
				material = StandardMaterial3D.new()
			_mesh_entries.append({
				"mesh": mesh,
				"surface": surface_index,
				"material": material,
			})
		return

	var override := mesh.material_override
	if override is StandardMaterial3D:
		_mesh_entries.append({
			"mesh": mesh,
			"surface": -1,
			"material": (override as StandardMaterial3D).duplicate(),
		})


func _is_emission_surface(mesh: MeshInstance3D, surface_index: int) -> bool:
	if emission_surface_names.is_empty():
		return false

	var array_mesh := mesh.mesh as ArrayMesh
	if array_mesh != null:
		var surface_name := array_mesh.surface_get_name(surface_index)
		if surface_name in emission_surface_names:
			return true

	var source := mesh.get_surface_override_material(surface_index)
	if source == null and mesh.mesh != null:
		source = mesh.mesh.surface_get_material(surface_index)
	if source != null and source.resource_name in emission_surface_names:
		return true

	return false


func _sync_headlights() -> void:
	_ensure_spot_light()
	if _spot_light == null:
		return

	if _base_energy < 0.0:
		_base_energy = _spot_light.light_energy

	_resolve_day_night()
	var night := _day_night.get_night_blend() if _day_night != null else 0.0

	var glider := _find_glider()
	if glider != null and glider.is_run_ended():
		night = 0.0

	_spot_light.light_energy = _base_energy * night
	_spot_light.visible = night > VISIBILITY_THRESHOLD
	_sync_mesh_emission(night)


func _sync_mesh_emission(night: float) -> void:
	var enabled := night > VISIBILITY_THRESHOLD
	var energy := maxf(emission_energy, MIN_EMISSION_ENERGY) * night
	_current_emission_energy = energy

	for entry in _mesh_entries:
		var material: StandardMaterial3D = entry.material
		material.emission_enabled = enabled
		material.emission = emission_color
		material.emission_energy_multiplier = energy

		var mesh: MeshInstance3D = entry.mesh
		var surface_index: int = entry.surface
		if surface_index < 0:
			mesh.material_override = material
		else:
			mesh.set_surface_override_material(surface_index, material)


func _find_glider() -> GliderPlayerScript:
	var node: Node = self
	while node != null:
		if node is GliderPlayerScript:
			return node as GliderPlayerScript
		node = node.get_parent()
	return null
