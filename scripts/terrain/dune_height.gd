class_name DuneHeight
extends RefCounted

const LevelTerrainResolverScript = preload("res://scripts/game/level_terrain_resolver.gd")

const DETAIL_AMPLITUDE := 0.34
const CREST_FLOOR := 0.08
const CREST_OVERSHOOT := 1.0
const MACRO_AMPLITUDE_MIN := 0.58
const MACRO_AMPLITUDE_MAX := 1.32
const ENVELOPE_FREQUENCY := 0.0018
const ENVELOPE_MIN := 0.76
const ENVELOPE_MAX := 1.26
const PEAK_FREQUENCY := 0.0036
const PEAK_MIN := 0.88
const PEAK_MAX := 1.18
const PEAK_CREST_START := 0.52
const PEAK_CREST_FULL := 0.86
const PEAK_VALLEY_BLEND := 0.62
const Z_TRAVEL_COMPRESSION := 0.72
const FLAT_FIELD_FREQUENCY := 0.00032
const FLAT_FIELD_START := 0.66
const FLAT_FIELD_END := 0.88
const FLAT_MACRO_SUPPRESS := 0.72
const FLAT_DETAIL_SUPPRESS := 0.15
## Radial start peak under the home tower — gentle dome, ~500 m falloff.
const START_PEAK_RADIUS_M := 500.0
const START_PEAK_RISE_M := 70.0

var world_seed: int = 0
var run_origin: Vector2 = Vector2.ZERO

var _warp_noise: FastNoiseLite
var _base_noise: FastNoiseLite
var _macro_noise: FastNoiseLite
var _flat_noise: FastNoiseLite
var _envelope_noise: FastNoiseLite
var _peak_noise: FastNoiseLite
var _detail_noise: FastNoiseLite


func _init(seed_value: int = 0) -> void:
	world_seed = seed_value
	_setup_noise()


func _setup_noise() -> void:
	_warp_noise = FastNoiseLite.new()
	_warp_noise.seed = world_seed
	_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_warp_noise.frequency = 0.0012

	_base_noise = FastNoiseLite.new()
	_base_noise.seed = world_seed + 1
	_base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_base_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_base_noise.fractal_octaves = 3
	_base_noise.frequency = 0.0020

	_macro_noise = FastNoiseLite.new()
	_macro_noise.seed = world_seed + 2
	_macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_macro_noise.frequency = 0.00095

	_flat_noise = FastNoiseLite.new()
	_flat_noise.seed = world_seed + 4
	_flat_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_flat_noise.frequency = FLAT_FIELD_FREQUENCY

	_envelope_noise = FastNoiseLite.new()
	_envelope_noise.seed = world_seed + 6
	_envelope_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_envelope_noise.frequency = ENVELOPE_FREQUENCY

	_peak_noise = FastNoiseLite.new()
	_peak_noise.seed = world_seed + 5
	_peak_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_peak_noise.frequency = PEAK_FREQUENCY

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = world_seed + 3
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.03


func set_run_origin(origin: Vector2) -> void:
	run_origin = origin


func sample_height(world_x: float, world_z: float) -> float:
	var blend: Dictionary = LevelTerrainResolverScript.param_blend_at_world_x(world_x, run_origin.x)
	var a: Dictionary = blend.a
	var b: Dictionary = blend.b
	var t := float(blend.t)
	var dune := 0.0
	if t <= 0.0001:
		dune = _sample_dune(world_x, world_z, a)
	elif LevelTerrainResolverScript.same_noise_domain(a, b):
		dune = _sample_dune(world_x, world_z, LevelTerrainResolverScript.params_at_world_x(world_x, run_origin.x))
	else:
		dune = lerpf(
			_sample_dune(world_x, world_z, a),
			_sample_dune(world_x, world_z, b),
			t
		)
	return dune + _start_peak_rise(world_x, world_z)


func _sample_dune(world_x: float, world_z: float, params: Dictionary) -> float:
	var amplitude: float = params.amplitude
	var warp_strength: float = params.warp_strength
	var ridge_power: float = params.ridge_power
	var frequency_scale: float = params.frequency_scale
	var z_scale: float = params.z_scale
	var flat_bias: float = params.flat_bias
	var crest_sharpness: float = params.crest_sharpness

	var sample_x := world_x * frequency_scale
	var sample_z := world_z * frequency_scale * z_scale

	var warp_x := _warp_noise.get_noise_2d(sample_x, sample_z) * warp_strength
	var warp_z := _warp_noise.get_noise_2d(sample_x + 100.0, sample_z + 100.0) * warp_strength

	var wx := sample_x + warp_x
	var wz := (sample_z + warp_z) * Z_TRAVEL_COMPRESSION

	var ridge := 1.0 - absf(_base_noise.get_noise_2d(wx, wz))
	ridge = pow(ridge, ridge_power)
	ridge = clampf((ridge - CREST_FLOOR) / (1.0 - CREST_FLOOR), 0.0, CREST_OVERSHOOT)
	ridge = pow(ridge, crest_sharpness)

	var macro := (_macro_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5
	var flat_field := (_flat_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5
	flat_field = clampf(flat_field + flat_bias, 0.0, 1.0)
	var flat_mask := smoothstep(FLAT_FIELD_START, FLAT_FIELD_END, flat_field)
	var macro_amplitude := lerpf(MACRO_AMPLITUDE_MIN, MACRO_AMPLITUDE_MAX, macro)
	macro_amplitude *= lerpf(1.0, FLAT_MACRO_SUPPRESS, flat_mask)

	var envelope := (_envelope_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5
	var envelope_scale := lerpf(ENVELOPE_MIN, ENVELOPE_MAX, envelope)

	var peak := (_peak_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5
	var peak_scale := lerpf(PEAK_MIN, PEAK_MAX, peak)
	var crest_mask := smoothstep(PEAK_CREST_START, PEAK_CREST_FULL, ridge)
	var valley_mask := 1.0 - crest_mask
	peak_scale = lerpf(peak_scale, 1.0, valley_mask * PEAK_VALLEY_BLEND)

	var detail := _detail_noise.get_noise_2d(sample_x, sample_z) * DETAIL_AMPLITUDE
	detail *= lerpf(1.0, FLAT_DETAIL_SUPPRESS, flat_mask)

	return ridge * amplitude * macro_amplitude * envelope_scale * peak_scale + detail


func _start_peak_rise(world_x: float, world_z: float) -> float:
	var dist := Vector2(world_x, world_z).distance_to(run_origin)
	if dist >= START_PEAK_RADIUS_M or START_PEAK_RADIUS_M <= 0.0:
		return 0.0
	var t := dist / START_PEAK_RADIUS_M
	# Cosine dome: 1 at center, 0 at radius — lifts dunes without erasing them.
	var dome := cos(t * PI * 0.5)
	dome *= dome
	return START_PEAK_RISE_M * dome


func sample_normal(world_x: float, world_z: float, epsilon: float = 1.0) -> Vector3:
	var h_l := sample_height(world_x - epsilon, world_z)
	var h_r := sample_height(world_x + epsilon, world_z)
	var h_d := sample_height(world_x, world_z - epsilon)
	var h_u := sample_height(world_x, world_z + epsilon)
	return Vector3(h_l - h_r, 2.0 * epsilon, h_d - h_u).normalized()
