class_name ExplosionFireballVfx
extends Node3D

## Displaced fireball shells (fire_v5/v4/v3 noise) plus smoke puff GPU burst.

const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const FireCoreMaterial := preload("res://assets/materials/vfx/explosion_fire_core.tres")
const FireMidMaterial := preload("res://assets/materials/vfx/explosion_fire_mid.tres")
const FireOuterMaterial := preload("res://assets/materials/vfx/explosion_fire_outer.tres")
const SmokeMaterial := preload("res://assets/materials/vfx/explosion_smoke_particle.tres")

const REFERENCE_WORLD_SCALE := 12.0
const LIFETIME_SEC := 1.55
const SMOKE_LIFETIME_SEC := 2.0
const FREE_BUFFER_SEC := 0.25
const SPHERE_RADIAL_SEGMENTS := 48
const SPHERE_RINGS := 24
const SMOKE_QUAD_SIZE := Vector2(2.8, 2.8)

var _elapsed := 0.0
var _scale_mult := 1.0
var _world_size := REFERENCE_WORLD_SCALE
var _shells: Array[Dictionary] = []
var _smoke: GPUParticles3D
var _light: OmniLight3D


static func spawn(
	tree: SceneTree,
	world_pos: Vector3,
	scale_mult: float = 1.0,
	world_scale: float = REFERENCE_WORLD_SCALE
) -> ExplosionFireballVfx:
	if tree == null:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null
	var fx: ExplosionFireballVfx = load("res://scripts/vfx/explosion_fireball_vfx.gd").new()
	parent.add_child(fx)
	fx.global_position = world_pos
	fx.configure(scale_mult, world_scale)
	return fx


func configure(scale_mult: float = 1.0, world_scale: float = REFERENCE_WORLD_SCALE) -> void:
	add_to_group("explosion_fireball_vfx")
	_scale_mult = maxf(scale_mult, 0.01)
	_world_size = maxf(world_scale, 0.01)
	_build_fire_shells()
	_build_smoke_burst()
	_build_flash_light()
	_apply_animation(0.0)
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	_apply_animation(_elapsed)
	_update_light()
	if _elapsed >= maxf(LIFETIME_SEC, SMOKE_LIFETIME_SEC) + FREE_BUFFER_SEC:
		queue_free()


func _build_fire_shells() -> void:
	_add_shell(
		"FireCore",
		FireCoreMaterial,
		0.34,
		0.28,
		0.22
	)
	_add_shell(
		"FireMid",
		FireMidMaterial,
		0.52,
		0.38,
		0.28
	)
	_add_shell(
		"FireOuter",
		FireOuterMaterial,
		0.82,
		0.22,
		0.18
	)


func _add_shell(
	shell_name: String,
	source_material: ShaderMaterial,
	radius_ratio: float,
	peak_displacement: float,
	displacement_peak_at: float
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = shell_name
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.mesh = _make_sphere_mesh()
	var material := source_material.duplicate() as ShaderMaterial
	mesh_instance.material_override = material
	add_child(mesh_instance)
	_shells.append(
		{
			"node": mesh_instance,
			"material": material,
			"radius_ratio": radius_ratio,
			"peak_displacement": peak_displacement,
			"displacement_peak_at": displacement_peak_at,
		}
	)


func _build_smoke_burst() -> void:
	var size_ratio := _world_size * _scale_mult / REFERENCE_WORLD_SCALE
	var aabb_half := 5.5 * maxf(size_ratio, 0.75)
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.18 * maxf(size_ratio, 0.75)
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 48.0
	proc.initial_velocity_min = 1.5 * maxf(sqrt(size_ratio), 0.85)
	proc.initial_velocity_max = 4.5 * maxf(sqrt(size_ratio), 0.85)
	proc.gravity = Vector3(0.0, -1.8, 0.0)
	proc.damping_min = 0.35
	proc.damping_max = 0.9
	proc.scale_min = 0.55 * maxf(size_ratio, 0.75)
	proc.scale_max = 1.15 * maxf(size_ratio, 0.9)
	proc.scale_curve = _smoke_scale_curve()
	proc.color = Color(1.0, 1.0, 1.0, 0.82)
	proc.color_ramp = _smoke_color_ramp()

	_smoke = GPUParticles3D.new()
	_smoke.name = "SmokeBurst"
	_smoke.emitting = false
	_smoke.amount = int(lerpf(18.0, 36.0, clampf(size_ratio, 0.75, 1.5)))
	_smoke.lifetime = SMOKE_LIFETIME_SEC
	_smoke.one_shot = true
	_smoke.explosiveness = 0.92
	_smoke.randomness = 0.55
	_smoke.visibility_aabb = AABB(
		Vector3(-aabb_half, -aabb_half, -aabb_half),
		Vector3(aabb_half * 2.0, aabb_half * 2.0, aabb_half * 2.0)
	)
	_smoke.local_coords = false
	_smoke.process_material = proc
	var quad := QuadMesh.new()
	quad.size = SMOKE_QUAD_SIZE * maxf(size_ratio, 0.75)
	quad.material = SmokeMaterial.duplicate() as ShaderMaterial
	_smoke.draw_pass_1 = quad
	add_child(_smoke)
	_smoke.restart()
	_smoke.emitting = true


func _build_flash_light() -> void:
	var size_ratio := _world_size * _scale_mult / REFERENCE_WORLD_SCALE
	_light = OmniLight3D.new()
	_light.name = "FireballLight"
	_light.light_color = Color(1.0, 0.55, 0.18)
	_light.light_energy = 0.0
	_light.omni_range = 22.0 * maxf(size_ratio, 0.85)
	_light.shadow_enabled = false
	add_child(_light)


func _apply_animation(elapsed: float) -> void:
	var life_t := clampf(elapsed / LIFETIME_SEC, 0.0, 1.0)
	var pop_t := clampf(elapsed / 0.12, 0.0, 1.0)
	var grow_t := clampf((elapsed - 0.06) / 0.42, 0.0, 1.0)
	var fade_t := clampf((elapsed - 0.55) / 0.95, 0.0, 1.0)
	var size_ratio := _world_size * _scale_mult / REFERENCE_WORLD_SCALE
	var base_size := _world_size * _scale_mult * 0.5
	var scale_factor := lerpf(0.12, 1.12, ease(pop_t, -2.0)) * lerpf(1.0, 1.08, grow_t)
	var alpha := (1.0 - ease(fade_t, 2.0)) * ease(pop_t, -1.5)

	for shell in _shells:
		var node := shell["node"] as MeshInstance3D
		var material := shell["material"] as ShaderMaterial
		var radius: float = shell["radius_ratio"] * base_size * scale_factor
		var disp_peak: float = shell["peak_displacement"] * base_size
		var disp_peak_at: float = shell["displacement_peak_at"]
		var disp_t := clampf((elapsed - 0.02) / disp_peak_at, 0.0, 1.0)
		var disp_fade := 1.0 - ease(fade_t, 1.4)
		var displacement := disp_peak * ease(disp_t, -1.2) * disp_fade
		node.scale = Vector3.ONE * radius
		material.set_shader_parameter("displacement_strength", displacement)
		material.set_shader_parameter("alpha_scale", alpha)
		material.set_shader_parameter("emission_strength", lerpf(2.0, 6.5, 1.0 - fade_t))


func _update_light() -> void:
	if _light == null:
		return
	var flash := clampf(1.0 - _elapsed / 0.45, 0.0, 1.0)
	var fade := clampf(1.0 - maxf(_elapsed - 0.25, 0.0) / 0.9, 0.0, 1.0)
	var size_ratio := _world_size * _scale_mult / REFERENCE_WORLD_SCALE
	_light.light_energy = 28.0 * flash * fade * maxf(size_ratio, 0.85)


static func _make_sphere_mesh() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = SPHERE_RADIAL_SEGMENTS
	sphere.rings = SPHERE_RINGS
	return sphere


static func _smoke_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.18, 0.72))
	curve.add_point(Vector2(0.55, 1.0))
	curve.add_point(Vector2(1.0, 1.18))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _smoke_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.75),
		Color(1.0, 1.0, 1.0, 0.62),
		Color(1.0, 1.0, 1.0, 0.28),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
