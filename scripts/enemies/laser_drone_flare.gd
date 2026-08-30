class_name LaserDroneFlare
extends Node3D

## Bright red lens-flare marker so the glass-cannon drone stays visible at range.

const FLARE_COLOR := Color(1.0, 0.16, 0.07)
const HALO_COLOR := Color(1.0, 0.1, 0.05, 0.42)
const STREAK_COLOR := Color(1.0, 0.2, 0.08, 0.55)
const PULSE_HZ := 1.35
const BASE_LIGHT_ENERGY := 2.8
const CHARGE_LIGHT_BOOST := 4.5
const RELOAD_LIGHT_SCALE := 0.35
const LIGHT_RANGE_M := 95.0

var _core: MeshInstance3D
var _halo: MeshInstance3D
var _streak_a: MeshInstance3D
var _streak_b: MeshInstance3D
var _light: OmniLight3D
var _pulse := 0.0
var _charge_boost := 1.0
var _reload_scale := 1.0


func _ready() -> void:
	_ensure_visuals()


func _process(delta: float) -> void:
	_pulse += delta * TAU * PULSE_HZ
	var pulse := 0.78 + 0.22 * sin(_pulse)
	var energy := (BASE_LIGHT_ENERGY + _charge_boost * CHARGE_LIGHT_BOOST) * pulse * _reload_scale
	if _light != null:
		_light.light_energy = energy


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
		_reload_scale = RELOAD_LIGHT_SCALE
		_charge_boost = 0.15
	else:
		_reload_scale = 1.0


func _ensure_visuals() -> void:
	if _core != null:
		return

	_core = _make_billboard_quad(Vector2(2.4, 2.4), _flare_material(FLARE_COLOR, 18.0, false))
	_core.name = "CoreFlare"
	add_child(_core)

	_halo = _make_billboard_quad(Vector2(7.5, 7.5), _flare_material(HALO_COLOR, 6.5, true))
	_halo.name = "HaloFlare"
	add_child(_halo)

	_streak_a = _make_billboard_quad(Vector2(11.0, 1.1), _flare_material(STREAK_COLOR, 9.0, true))
	_streak_a.name = "StreakA"
	_streak_a.rotation_degrees = Vector3(0.0, 0.0, 18.0)
	add_child(_streak_a)

	_streak_b = _make_billboard_quad(Vector2(9.0, 0.85), _flare_material(STREAK_COLOR, 7.0, true))
	_streak_b.name = "StreakB"
	_streak_b.rotation_degrees = Vector3(0.0, 0.0, -32.0)
	add_child(_streak_b)

	_light = OmniLight3D.new()
	_light.name = "MarkerLight"
	_light.light_color = FLARE_COLOR
	_light.light_energy = BASE_LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE_M
	_light.shadow_enabled = false
	add_child(_light)


func _make_billboard_quad(size: Vector2, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh_inst.mesh = quad
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_inst


func _flare_material(color: Color, emission_energy: float, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = emission_energy
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
