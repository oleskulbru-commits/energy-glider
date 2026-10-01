class_name GroundReticle
extends Node3D

## Static ground reticle for incoming missile-drone rockets.

const TerrainQueryScript := preload("res://scripts/terrain/terrain_query.gd")
const ReticleShader := preload("res://assets/vfx/shaders/ground_reticle.gdshader")
const ReticleMaterial := preload("res://assets/materials/vfx/ground_reticle_material.tres")
const FrameTexture := preload("res://assets/vfx/effect_textures/reticles/reticle_2_frame_.png")

const LIFE_SEC := 1.5
const GROUND_LIFT_M := 0.12
const QUAD_SIZE_M := 5.4
## Matches rebel_drone_streak_blue ColorParameter, dimmed for ground readability.
const COLOR_TINT := Vector3(0.45483235, 0.7983809, 1.5999943)
const BRIGHTNESS_MULT := 0.75
const GLOW_STRENGTH := 2.25
const ALPHA_SCALE := 0.75

var _life := LIFE_SEC
var _mesh: MeshInstance3D
var _material: ShaderMaterial


func place(
	world_pos: Vector3,
	life_sec: float = LIFE_SEC,
	terrain: TerrainManager = null,
	color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	_life = maxf(life_sec, 0.2)
	_align_to_ground(world_pos, terrain)
	_ensure_visual()
	if color.a > 0.001:
		_apply_color_tint(color)


func _ready() -> void:
	_ensure_visual()


func _process(delta: float) -> void:
	if _material == null:
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _align_to_ground(world_pos: Vector3, terrain: TerrainManager) -> void:
	if not is_inside_tree():
		global_position = Vector3(world_pos.x, world_pos.y + GROUND_LIFT_M, world_pos.z)
		global_basis = Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
		return
	var tree := get_tree()
	var space: PhysicsDirectSpaceState3D = null
	if tree != null and tree.root != null:
		var world := tree.root.get_world_3d()
		if world != null:
			space = world.direct_space_state
	var surface := TerrainQueryScript.sample_surface(
		terrain,
		space,
		world_pos.x,
		world_pos.z,
		world_pos.y + 2.0
	)
	if surface.is_empty():
		global_position = Vector3(world_pos.x, world_pos.y + GROUND_LIFT_M, world_pos.z)
		global_basis = Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
		return
	var normal: Vector3 = surface.normal
	var center: Vector3 = surface.position
	global_position = center + normal * GROUND_LIFT_M
	global_basis = TerrainQueryScript.basis_from_up(normal) * Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))


func _ensure_visual() -> void:
	if _mesh != null:
		return
	if FrameTexture == null:
		push_warning("GroundReticle: missing reticle texture")
		return

	_material = ReticleMaterial.duplicate() as ShaderMaterial
	_material.shader = ReticleShader
	_material.set_shader_parameter("frame_tex", FrameTexture)
	_material.set_shader_parameter("color_tint", COLOR_TINT)
	_material.set_shader_parameter("glow_strength", GLOW_STRENGTH)
	_material.set_shader_parameter("alpha_scale", ALPHA_SCALE)

	_mesh = MeshInstance3D.new()
	_mesh.name = "ReticleQuad"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_SIZE_M, QUAD_SIZE_M)
	quad.material = _material
	_mesh.mesh = quad
	add_child(_mesh)
	set_process(true)


func _apply_color_tint(color: Color) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(
		"color_tint",
		Vector3(color.r, color.g, color.b) * (COLOR_TINT.length() / maxf(Vector3(color.r, color.g, color.b).length(), 0.001))
	)
