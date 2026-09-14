class_name AerialExplosionVfx
extends Node3D

## One-shot aerial explosion flipbook on a camera-facing billboard quad.
## Tweak [member preset] or the preset's ShaderMaterial resource.

const VfxFlipbookScript := preload("res://scripts/vfx/vfx_flipbook.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")
const SandImpactDustScript := preload("res://scripts/enemies/sand_impact_dust.gd")
const CameraImpactShakeScript := preload("res://scripts/player/camera_impact_shake.gd")
const ExplosionSparkVfxScript := preload("res://scripts/vfx/explosion_spark_vfx.gd")
const GroundBurnDecalVfxScript := preload("res://scripts/vfx/ground_burn_decal_vfx.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const ExplosionShader := preload("res://assets/vfx/shaders/aerial_explosion.gdshader")
const DefaultPresetPath := "res://assets/vfx/explosions/presets/aerial_explode_1.tres"
const DroneExplosionPresetPath := "res://assets/vfx/explosions/presets/aerial_explode_drone.tres"
## Player default world_scale; keeps hover-dust parity at scale_mult 1.0.
const PROXIMITY_FADE_REFERENCE_WORLD_SCALE := 12.0
## QuadMesh spans 1 unit; world_scale maps directly to outer size.
const MESH_UNIT_EXTENT := 1.0

const FREE_BUFFER_SEC := 0.05
## Hold the final flipbook frame so the smoke tail reads before cleanup (~2.0s + hold).
const LAST_FRAME_HOLD_SEC := 0.25

@export var preset: AerialExplosionPreset
@export var play_on_ready := false

var _preset: AerialExplosionPreset
var _impact_dir := Vector3.ZERO
var _scale_mult := 1.0
var _frame := 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _color_textures: Array[Texture2D] = []
var _flash_light: OmniLight3D
var _last_frame_hold_left := -1.0


static func spawn(
	tree: SceneTree,
	world_pos: Vector3,
	preset_override: AerialExplosionPreset = null,
	scale_mult: float = 1.0,
	terrain: TerrainManager = null,
	impact_dir: Vector3 = Vector3.ZERO,
	hit_body: Node = null,
	playback_variation: bool = false
) -> AerialExplosionVfx:
	if tree == null:
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null
	var resolved := preset_override if preset_override != null else _load_default_preset()
	var resolved_scale := maxf(scale_mult, 0.01)
	var frame_start := 0.0
	if playback_variation and resolved != null:
		resolved_scale *= randf_range(0.85, 1.15)
		var max_start := mini(12.0, float(resolved.frame_count - 1) * 0.3)
		frame_start = randf_range(0.0, max_start)
	var fx := AerialExplosionVfx.new()
	parent.add_child(fx)
	fx.global_position = world_pos
	fx._impact_dir = impact_dir
	_maybe_spawn_ground_sand(tree, world_pos, resolved, resolved_scale, terrain)
	_maybe_spawn_ground_burn_decal(tree, world_pos, resolved, resolved_scale, terrain, hit_body)
	_maybe_spawn_impact_sparks(tree, world_pos, resolved, resolved_scale, impact_dir)
	fx.configure(resolved, resolved_scale, frame_start)
	return fx


static func make_billboard_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return quad


static func mesh_uniform_scale_for(
	preset: AerialExplosionPreset,
	scale_mult: float = 1.0
) -> float:
	if preset == null:
		return 0.0
	return preset.world_scale * maxf(scale_mult, 0.01) * (1.0 / MESH_UNIT_EXTENT)


static func configure_billboard_mesh(
	mesh_instance: MeshInstance3D,
	preset: AerialExplosionPreset,
	scale_mult: float = 1.0
) -> void:
	if mesh_instance == null or preset == null:
		return
	if mesh_instance.mesh == null or not mesh_instance.mesh is QuadMesh:
		mesh_instance.mesh = make_billboard_quad()
	var scale := mesh_uniform_scale_for(preset, scale_mult)
	mesh_instance.scale = Vector3(scale, scale, scale)
	mesh_instance.position = Vector3.ZERO
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func spark_spray_dir(impact_dir: Vector3) -> Vector3:
	if impact_dir.length_squared() < 0.0001:
		return Vector3.UP
	return impact_dir.normalized()


static func proximity_fade_distance_for(
	preset: AerialExplosionPreset,
	scale_mult: float = 1.0
) -> float:
	if preset == null:
		return SandParticleVfxScript.PROXIMITY_FADE_DISTANCE
	var world_size := preset.world_scale * maxf(scale_mult, 0.01)
	var size_ratio := world_size / PROXIMITY_FADE_REFERENCE_WORLD_SCALE
	return preset.proximity_fade_distance * size_ratio


static func apply_preset_look(
	material: ShaderMaterial,
	preset: AerialExplosionPreset,
	scale_mult: float = 1.0
) -> void:
	material.set_shader_parameter(
		"color_tint",
		Vector3(preset.color_tint.r, preset.color_tint.g, preset.color_tint.b)
	)
	material.set_shader_parameter(
		"smoke_tint",
		Vector3(preset.smoke_tint.r, preset.smoke_tint.g, preset.smoke_tint.b)
	)
	material.set_shader_parameter("smoke_mix", preset.smoke_mix)
	material.set_shader_parameter("emission_strength", preset.emission_strength)
	material.set_shader_parameter("alpha_scale", preset.alpha_scale)
	material.set_shader_parameter("proximity_fade_enabled", preset.proximity_fade_enabled)
	material.set_shader_parameter(
		"proximity_fade_distance",
		proximity_fade_distance_for(preset, scale_mult)
	)


static func set_frame_texture(material: ShaderMaterial, texture: Texture2D) -> void:
	material.set_shader_parameter("color_tex", texture)


static func duplicate_material(
	preset: AerialExplosionPreset,
	scale_mult: float = 1.0
) -> ShaderMaterial:
	var material: ShaderMaterial
	if preset.material != null:
		material = preset.material.duplicate() as ShaderMaterial
	else:
		material = ShaderMaterial.new()
		material.shader = ExplosionShader
	apply_preset_look(material, preset, scale_mult)
	return material


static func should_spawn_ground_burn(
	preset: AerialExplosionPreset,
	clearance: float,
	hit_body: Node = null
) -> bool:
	if preset == null or not preset.spawn_ground_burn_decal:
		return false
	if hit_body != null and hit_body.has_method("suppress_ground_burn_decal"):
		if hit_body.call("suppress_ground_burn_decal"):
			return false
	return clearance <= preset.ground_burn_max_clearance_m


static func ground_clearance_m(
	world_pos: Vector3,
	terrain: TerrainManager,
	tree: SceneTree
) -> float:
	var resolved_terrain := terrain if terrain != null else _resolve_terrain(tree)
	var space := _resolve_space(tree)
	var surface := TerrainQuery.sample_surface(
		resolved_terrain,
		space,
		world_pos.x,
		world_pos.z,
		world_pos.y + 2.0
	)
	if surface.is_empty():
		return INF
	return world_pos.y - (surface.position as Vector3).y


static func _maybe_spawn_impact_sparks(
	tree: SceneTree,
	world_pos: Vector3,
	preset: AerialExplosionPreset,
	scale_mult: float,
	impact_dir: Vector3 = Vector3.ZERO
) -> void:
	if preset == null or not preset.spawn_sparks:
		return
	ExplosionSparkVfxScript.spawn_from_preset(
		tree,
		world_pos,
		preset,
		scale_mult,
		spark_spray_dir(impact_dir)
	)


static func _maybe_spawn_ground_burn_decal(
	tree: SceneTree,
	world_pos: Vector3,
	preset: AerialExplosionPreset,
	scale_mult: float,
	terrain: TerrainManager,
	hit_body: Node = null
) -> void:
	if preset == null:
		return
	var clearance := ground_clearance_m(world_pos, terrain, tree)
	if not should_spawn_ground_burn(preset, clearance, hit_body):
		return
	GroundBurnDecalVfxScript.spawn_from_preset(tree, world_pos, preset, scale_mult, terrain)


static func _maybe_spawn_ground_sand(
	tree: SceneTree,
	world_pos: Vector3,
	preset: AerialExplosionPreset,
	scale_mult: float,
	terrain: TerrainManager
) -> void:
	if preset == null or not preset.spawn_ground_sand:
		return
	var clearance := ground_clearance_m(world_pos, terrain, tree)
	if clearance > preset.ground_sand_max_clearance_m:
		return
	var resolved_terrain := terrain if terrain != null else _resolve_terrain(tree)
	var proximity := 1.0 - clampf(clearance / preset.ground_sand_max_clearance_m, 0.0, 1.0)
	var dust_scale := maxf(scale_mult, 0.01) * preset.ground_sand_scale_mult * lerpf(0.65, 1.0, proximity)
	SandImpactDustScript.spawn(
		tree,
		world_pos,
		resolved_terrain,
		_ground_sand_burst_preset(preset),
		dust_scale
	 )


static func _ground_sand_burst_preset(preset: AerialExplosionPreset) -> SandParticleVfxScript.BurstPreset:
	match preset.ground_sand_burst:
		AerialExplosionPreset.GroundSandBurst.LIGHT:
			return SandParticleVfxScript.BurstPreset.LIGHT
		AerialExplosionPreset.GroundSandBurst.MG:
			return SandParticleVfxScript.BurstPreset.MG
		AerialExplosionPreset.GroundSandBurst.DEATH:
			return SandParticleVfxScript.BurstPreset.DEATH
		AerialExplosionPreset.GroundSandBurst.EXPLOSION:
			return SandParticleVfxScript.BurstPreset.EXPLOSION
		_:
			return SandParticleVfxScript.BurstPreset.HEAVY


static func _resolve_terrain(tree: SceneTree) -> TerrainManager:
	if tree == null:
		return null
	return tree.get_first_node_in_group("terrain_manager") as TerrainManager


static func _resolve_space(tree: SceneTree) -> PhysicsDirectSpaceState3D:
	if tree == null or tree.root == null:
		return null
	var world := tree.root.get_world_3d()
	return world.direct_space_state if world != null else null


static func _load_default_preset() -> AerialExplosionPreset:
	return ResourceLoader.load(DefaultPresetPath) as AerialExplosionPreset


func _ready() -> void:
	if play_on_ready and preset != null:
		configure(preset)


func configure(
	preset_override: AerialExplosionPreset,
	scale_mult: float = 1.0,
	frame_start: float = 0.0
) -> void:
	_preset = preset_override
	preset = preset_override
	_scale_mult = maxf(scale_mult, 0.01)
	_frame = maxf(frame_start, 0.0)
	if not _load_sequences():
		queue_free()
		return
	_build_billboard_mesh()
	if _preset.spawn_light:
		_add_flash_light()
	if _preset.shake_strength > 0.0 and _preset.shake_radius_m > 0.0:
		CameraImpactShakeScript.request(
			get_tree(),
			global_position,
			_preset.shake_strength,
			_preset.shake_radius_m
		)
	var frame_idx := clampi(int(_frame), 0, _preset.frame_count - 1)
	_set_frame(frame_idx)


func _process(delta: float) -> void:
	if _preset == null or _color_textures.is_empty():
		return
	_billboard_mesh()
	_frame += delta * _preset.fps
	var frame_idx := mini(int(_frame), _preset.frame_count - 1)
	_set_frame(frame_idx)
	if _frame < float(_preset.frame_count):
		return
	if _last_frame_hold_left < 0.0:
		_last_frame_hold_left = LAST_FRAME_HOLD_SEC
	_last_frame_hold_left -= delta
	if _last_frame_hold_left <= 0.0:
		queue_free()


func _load_sequences() -> bool:
	if _preset == null:
		return false
	_color_textures = VfxFlipbookScript.load_texture_sequence(
		_preset.texture_dir,
		_preset.color_prefix,
		_preset.frame_count,
		_preset.color_frame_offset
	)
	return _color_textures.size() == _preset.frame_count


func _billboard_mesh() -> void:
	if _mesh == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_mesh.look_at(cam.global_position, Vector3.UP)
	_mesh.rotate_object_local(Vector3.UP, PI)


func _build_billboard_mesh() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "ExplosionBillboard"
	configure_billboard_mesh(_mesh, _preset, _scale_mult)
	_material = duplicate_material(_preset, _scale_mult)
	_mesh.material_override = _material
	add_child(_mesh)


func _add_flash_light() -> void:
	_flash_light = OmniLight3D.new()
	_flash_light.name = "FlashLight"
	_flash_light.light_color = _preset.light_color
	_flash_light.light_energy = _preset.light_energy
	_flash_light.omni_range = _preset.light_range_m
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	var duration := (
		float(_preset.frame_count) / maxf(_preset.fps, 0.001)
		+ LAST_FRAME_HOLD_SEC
		+ FREE_BUFFER_SEC
	)
	var tween := create_tween()
	tween.tween_property(_flash_light, "light_energy", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_frame(frame_idx: int) -> void:
	if _material == null:
		return
	var idx := clampi(frame_idx, 0, _preset.frame_count - 1)
	set_frame_texture(_material, _color_textures[idx])
