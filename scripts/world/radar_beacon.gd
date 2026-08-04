class_name RadarBeacon
extends Node3D

const BEAM_HEIGHT := 140.0
const BEAM_BOTTOM_RADIUS := 0.55
const BEAM_TOP_RADIUS := 0.35
const BEAM_COLOR := Color(1.0, 0.82, 0.28, 0.55)
const FADE_IN_SEC := 0.15
const RENDER_PRIORITY := 10

var _beam: MeshInstance3D
var _material: StandardMaterial3D
var _fade_tween: Tween


func _ready() -> void:
	_build_beam()
	hide_beam()


func reveal(duration: float) -> void:
	if _beam == null:
		_build_beam()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()

	_beam.visible = true
	_set_alpha(0.0)

	_fade_tween = create_tween()
	var hold := maxf(duration - FADE_IN_SEC - 0.8, 0.2)
	var fade_out := maxf(duration - FADE_IN_SEC - hold, 0.4)
	_fade_tween.tween_method(_set_alpha, 0.0, BEAM_COLOR.a, FADE_IN_SEC)
	_fade_tween.tween_interval(hold)
	_fade_tween.tween_method(_set_alpha, BEAM_COLOR.a, 0.0, fade_out)
	_fade_tween.tween_callback(hide_beam)


func hide_beam() -> void:
	if _beam != null:
		_beam.visible = false
	if _material != null:
		_material.albedo_color.a = 0.0


func is_revealing() -> bool:
	return _beam != null and _beam.visible


func _build_beam() -> void:
	if _beam != null:
		return

	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	var cylinder := CylinderMesh.new()
	cylinder.height = BEAM_HEIGHT
	cylinder.top_radius = BEAM_TOP_RADIUS
	cylinder.bottom_radius = BEAM_BOTTOM_RADIUS
	cylinder.radial_segments = 12
	_beam.mesh = cylinder
	_beam.position = Vector3(0.0, BEAM_HEIGHT * 0.5, 0.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = BEAM_COLOR
	_material.render_priority = RENDER_PRIORITY
	_beam.material_override = _material
	add_child(_beam)


func _set_alpha(alpha: float) -> void:
	if _material == null:
		return
	_material.albedo_color.a = alpha
