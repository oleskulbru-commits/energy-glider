@tool
extends Node3D

## Test-scene helper: long camera-facing laser ribbon with live UV tuning.

const _GLOW_MAT := preload("res://assets/materials/vfx/laser_beam_glow.tres")
const _CORE_MAT := preload("res://assets/materials/vfx/laser_beam_core.tres")

@export_group("Beam Endpoints")
@export var beam_start_path: NodePath = ^"../BeamStart"
@export var beam_end_path: NodePath = ^"../BeamEnd"

@export_group("Beam Size")
@export_range(0.05, 1.0, 0.01) var glow_width := 0.28:
	set(value):
		glow_width = value
		_request_refresh()

@export_range(0.02, 0.4, 0.01) var core_width := 0.10:
	set(value):
		core_width = value
		_request_refresh()

@export_group("UV / Tiling")
@export_range(0.5, 12.0, 0.1) var beam_tile_length_m := 2.5:
	set(value):
		beam_tile_length_m = value
		_request_refresh()

@export var override_tile_count := false:
	set(value):
		override_tile_count = value
		_request_refresh()

@export_range(0.5, 40.0, 0.1) var beam_tile_count_override := 18.0:
	set(value):
		beam_tile_count_override = value
		_request_refresh()

@export_range(0.1, 4.0, 0.05) var uv_length_scale := 1.0:
	set(value):
		uv_length_scale = value
		_request_refresh()

@export_range(0.1, 4.0, 0.05) var uv_width_scale := 1.0:
	set(value):
		uv_width_scale = value
		_request_refresh()

@export_group("Animation")
@export_range(0.0, 16.0, 0.1) var scroll_speed := 4.0:
	set(value):
		scroll_speed = value
		_request_refresh()

@export_group("Look")
@export var color_tint := Color(1.6, 0.21, 0.064, 1.0):
	set(value):
		color_tint = value
		_request_refresh()

@export_range(0.0, 12.0, 0.05) var glow_strength := 3.0:
	set(value):
		glow_strength = value
		_request_refresh()

@export_range(0.0, 12.0, 0.05) var core_glow_strength := 5.5:
	set(value):
		core_glow_strength = value
		_request_refresh()

@export_range(0.5, 6.0, 0.05) var core_width_scale := 2.4:
	set(value):
		core_width_scale = value
		_request_refresh()

@export_group("Debug")
@export var show_core := true:
	set(value):
		show_core = value
		_request_refresh()

var _glow_mesh: MeshInstance3D
var _core_mesh: MeshInstance3D
var _glow_quad: QuadMesh
var _core_quad: QuadMesh
var _glow_mat: ShaderMaterial
var _core_mat: ShaderMaterial
var _refresh_pending := false


func _ready() -> void:
	_ensure_ribbons()
	call_deferred("_refresh_beam")


func _process(_delta: float) -> void:
	if _refresh_pending:
		_refresh_pending = false
		_refresh_beam()
	elif not Engine.is_editor_hint():
		_refresh_beam()


func _request_refresh() -> void:
	_refresh_pending = true
	if is_node_ready():
		call_deferred("_refresh_beam")


func _ensure_ribbons() -> void:
	if _glow_mesh != null:
		return
	_glow_quad = QuadMesh.new()
	_glow_quad.size = Vector2(glow_width, 1.0)
	_glow_mat = _GLOW_MAT.duplicate() as ShaderMaterial
	_glow_mesh = MeshInstance3D.new()
	_glow_mesh.name = "GlowRibbon"
	_glow_mesh.mesh = _glow_quad
	_glow_mesh.material_override = _glow_mat
	_glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_mesh.top_level = true
	add_child(_glow_mesh)

	_core_quad = QuadMesh.new()
	_core_quad.size = Vector2(core_width, 1.0)
	_core_mat = _CORE_MAT.duplicate() as ShaderMaterial
	_core_mesh = MeshInstance3D.new()
	_core_mesh.name = "CoreRibbon"
	_core_mesh.mesh = _core_quad
	_core_mesh.material_override = _core_mat
	_core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_mesh.top_level = true
	add_child(_core_mesh)


func _refresh_beam() -> void:
	_ensure_ribbons()
	var from := _beam_start()
	var to := _beam_end()
	var length := from.distance_to(to)
	if length < 0.08:
		_glow_mesh.visible = false
		_core_mesh.visible = false
		return

	var tiles := beam_tile_count_override if override_tile_count else maxf(length / beam_tile_length_m, 1.0)
	_glow_quad.size = Vector2(glow_width, length)
	_core_quad.size = Vector2(core_width, length)
	_apply_shader_look(_glow_mat, glow_strength, 1.0, tiles)
	_apply_shader_look(_core_mat, core_glow_strength, core_width_scale, tiles)

	var mid := from.lerp(to, 0.5)
	var basis := _beam_basis(from, to, mid)
	_glow_mesh.global_transform = Transform3D(basis, mid)
	_glow_mesh.visible = true
	_core_mesh.global_transform = Transform3D(basis, mid)
	_core_mesh.visible = show_core


func _apply_shader_look(mat: ShaderMaterial, strength: float, width_scale: float, tiles: float) -> void:
	mat.set_shader_parameter("color_tint", color_tint)
	mat.set_shader_parameter("glow_strength", strength)
	mat.set_shader_parameter("scroll_speed", scroll_speed)
	mat.set_shader_parameter("beam_tile_count", tiles)
	mat.set_shader_parameter("beam_width_scale", width_scale)
	mat.set_shader_parameter("uv_length_scale", uv_length_scale)
	mat.set_shader_parameter("uv_width_scale", uv_width_scale)


func _beam_start() -> Vector3:
	var node := get_node_or_null(beam_start_path) as Node3D
	if node != null:
		return node.global_position
	return global_position


func _beam_end() -> Vector3:
	var node := get_node_or_null(beam_end_path) as Node3D
	if node != null:
		return node.global_position
	return global_position + Vector3(0.0, -0.15, -45.0)


func _beam_basis(from: Vector3, to: Vector3, mid: Vector3) -> Basis:
	var beam_dir := (to - from).normalized()
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
