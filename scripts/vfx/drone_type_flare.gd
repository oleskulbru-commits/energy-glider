class_name DroneTypeFlare
extends Node3D

## Type-colored billboard lens flare for combat drones at range.

const LENS_FLARE_TEXTURE := preload("res://assets/vfx/effect_textures/lens_flare_2.png")

@export var flare_color: Color = Color(0.455, 0.798, 1.6, 1.0)
@export var base_quad_size: Vector2 = Vector2(3.5, 3.5)
@export var halo_scale: float = 1.6
@export var ref_distance_m: float = 100.0
@export var min_scale: float = 1.0
@export var max_scale: float = 3.0
@export var near_full_fade_m: float = 35.0
@export var far_full_strength_m: float = 100.0
@export var near_glint_strength: float = 0.12
@export var near_max_distance_scale: float = 0.65
@export var base_emission_energy: float = 1.5
@export var halo_emission_energy: float = 0.6
@export var proximity_fade_distance: float = 2.0
@export var pulse_hz: float = 1.35
@export var base_light_energy: float = 2.8
@export var charge_light_boost: float = 4.5
@export var reload_light_scale: float = 0.35
@export var light_range_m: float = 95.0

var _core: MeshInstance3D
var _halo: MeshInstance3D
var _core_quad: QuadMesh
var _halo_quad: QuadMesh
var _core_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _light: OmniLight3D
var _pulse := 0.0
var _charge_boost := 1.0
var _reload_scale := 1.0
var _base_core_size := Vector2.ZERO
var _base_halo_size := Vector2.ZERO
var _distance_scale := 1.0
var _proximity_alpha := 1.0
var _presentation_strength := 1.0


func _ready() -> void:
	_ensure_visuals()
	_apply_presentation()


func _process(delta: float) -> void:
	_update_distance_scale()
	_update_pulse(delta)


func get_flare_color() -> Color:
	return flare_color


func set_acquire_phase(active: bool) -> void:
	_reload_scale = 1.0
	if active:
		_charge_boost = 0.35
	else:
		_charge_boost = 0.2


func set_charge_phase(active: bool, telegraph_ratio: float = 0.0) -> void:
	_reload_scale = 1.0
	if active:
		var ratio := clampf(telegraph_ratio, 0.0, 1.0)
		_charge_boost = 0.65 + ratio * 0.95
	else:
		_charge_boost = 0.2


func set_reload_phase(active: bool) -> void:
	if active:
		_reload_scale = reload_light_scale
		_charge_boost = 0.15
	else:
		_reload_scale = 1.0


func _ensure_visuals() -> void:
	if _core != null:
		return

	_base_core_size = base_quad_size
	_base_halo_size = base_quad_size * halo_scale

	_core_quad = QuadMesh.new()
	_core_quad.size = _base_core_size
	_core_mat = _make_textured_glow_material(base_emission_energy)
	_core_quad.material = _core_mat

	_core = MeshInstance3D.new()
	_core.name = "CoreFlare"
	_core.mesh = _core_quad
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_halo_quad = QuadMesh.new()
	_halo_quad.size = _base_halo_size
	_halo_mat = _make_textured_glow_material(halo_emission_energy)
	_halo_quad.material = _halo_mat

	_halo = MeshInstance3D.new()
	_halo.name = "HaloFlare"
	_halo.mesh = _halo_quad
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)

	_light = OmniLight3D.new()
	_light.name = "MarkerLight"
	_light.shadow_enabled = false
	_light.omni_range = light_range_m
	add_child(_light)


func _make_textured_glow_material(energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = LENS_FLARE_TEXTURE
	mat.emission_enabled = true
	mat.emission_texture = LENS_FLARE_TEXTURE
	mat.emission_energy_multiplier = energy
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.disable_fog = true
	return mat


func _apply_presentation() -> void:
	if _core_mat == null or _halo_mat == null or _light == null:
		return
	var tint := Color(flare_color.r, flare_color.g, flare_color.b, 1.0)
	_apply_texture_presentation(_core_mat, tint, base_emission_energy, _presentation_strength)
	_apply_texture_presentation(
		_halo_mat, tint, halo_emission_energy, _presentation_strength * 0.35
	)
	_light.light_color = tint


func _apply_texture_presentation(
	mat: StandardMaterial3D,
	tint: Color,
	base_energy: float,
	strength: float
) -> void:
	var alpha := clampf(strength, 0.0, 1.0)
	mat.albedo_color = Color(tint.r * alpha, tint.g * alpha, tint.b * alpha, 1.0)
	mat.emission = Color(tint.r, tint.g, tint.b, 1.0)
	mat.emission_energy_multiplier = base_energy * alpha


func _compute_range_visibility(dist: float) -> float:
	var range_t := inverse_lerp(near_full_fade_m, far_full_strength_m, dist)
	return lerpf(near_glint_strength, 1.0, clampf(range_t, 0.0, 1.0))


func _apply_near_size_cap(dist: float, distance_scale: float) -> float:
	if dist >= near_full_fade_m:
		return distance_scale
	var near_t := inverse_lerp(proximity_fade_distance, near_full_fade_m, dist)
	return lerpf(near_max_distance_scale, distance_scale, clampf(near_t, 0.0, 1.0))


func _update_distance_scale() -> void:
	if _core_quad == null or _halo_quad == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var cam := viewport.get_camera_3d()
	if cam == null:
		return
	var dist := global_position.distance_to(cam.global_position)
	var raw_distance_scale := clampf(dist / ref_distance_m, min_scale, max_scale)
	_distance_scale = _apply_near_size_cap(dist, raw_distance_scale)
	_proximity_alpha = clampf(dist / proximity_fade_distance, 0.0, 1.0)
	_presentation_strength = _compute_range_visibility(dist) * _proximity_alpha
	_core_quad.size = _base_core_size * _distance_scale
	_halo_quad.size = _base_halo_size * _distance_scale
	_apply_presentation()


func _update_pulse(delta: float) -> void:
	if _light == null:
		return
	_pulse += delta * TAU * pulse_hz
	var pulse := 0.78 + 0.22 * sin(_pulse)
	var energy := (base_light_energy + _charge_boost * charge_light_boost) * pulse * _reload_scale
	_light.light_energy = energy * _presentation_strength
