class_name SandParticleVfx
extends RefCounted

## Shared Mars-sand puff look for hover, contact, and impact dust.

const SAND_ALBEDO := Color(0.5803922, 0.27058825, 0.16078432, 1.0)
const PUFF_TEXTURE := preload("res://assets/vfx/noise_textures/radial_smoke_puff.png")

const IMPACT_QUAD_SIZE := Vector2(1.0, 1.0)
const GLIDER_QUAD_SIZE := Vector2(1.0, 1.0)
const DEFAULT_VISIBILITY_AABB := AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 4.0, 8.0))


static func make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SAND_ALBEDO
	mat.albedo_texture = PUFF_TEXTURE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.disable_receive_shadows = true
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	return sanitize_material(mat)


static func sanitize_material(mat: StandardMaterial3D) -> StandardMaterial3D:
	var copy := mat.duplicate() as StandardMaterial3D
	copy.vertex_color_use_as_albedo = false
	copy.detail_enabled = false
	copy.grow = false
	copy.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	return copy


static func make_quad_mesh(size: Vector2 = IMPACT_QUAD_SIZE) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = make_material()
	return quad


static func make_fade_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.7, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	return gradient


static func apply_to(particles: CPUParticles3D, quad_size: Vector2 = IMPACT_QUAD_SIZE) -> void:
	if particles == null:
		return
	var quad := particles.mesh as QuadMesh
	if quad == null:
		quad = make_quad_mesh(quad_size)
		particles.mesh = quad
	else:
		var mat := quad.material as StandardMaterial3D
		if mat == null:
			quad.material = make_material()
		else:
			quad.material = sanitize_material(mat)
		quad.size = quad_size
	particles.visibility_aabb = DEFAULT_VISIBILITY_AABB
