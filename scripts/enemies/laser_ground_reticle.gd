extends Node3D

## Laser telegraph: ground-anchored spot (yaw + XZ follow, hover-height Y, no deck roll/pitch).

const GliderPhysicsScript := preload("res://scripts/player/glider_physics.gd")
const TelegraphScript := preload("res://scripts/enemies/laser_drone_telegraph.gd")
const TerrainQueryScript := preload("res://scripts/terrain/terrain_query.gd")
const VfxFlipbookScript := preload("res://scripts/vfx/vfx_flipbook.gd")
const SceneUtilScript := preload("res://scripts/util/scene_util.gd")

const TEXTURE_DIR := "res://assets/vfx/effect_textures/reticles/"
const FRAME_PREFIX := "reticle_1_frame_"
const FRAME_COUNT := 60
const FRAME_OFFSET := 0

const QUAD_SIZE_M := 8.4

## Synced from scenes/test/laser_reticle_tune.tscn (LaserGroundReticle local offset at hover).
const SPOT_LOCAL_OFFSET := Vector3(0.0, 4.5771947, 0.1)
## Match ReticleProjector in scenes/test/laser_reticle_tune.tscn (−90° X → shine toward −Y).
const SPOT_LOCAL_ROTATION := Vector3(-PI * 0.5, 0.0, 0.0)

const LIGHT_COLOR := Color(1.2, 0.06, 0.015, 1.0)
const SPOT_ENERGY := 16.0
const SPOT_SPECULAR := 16.0
const SPOT_LIGHT_SIZE := 1.0
const SPOT_ANGLE_DEG := 50.0
const SPOT_RANGE_M := 10.0
const SPOT_DISTANCE_ATTENUATION := 1.0
const SPOT_ANGLE_ATTENUATION := 0.007289316
const BLINK_LIGHT_DIM := 0.2

static var _frames: Array[Texture2D] = []
static var _frames_loaded := false

var _target: Node3D
var _terrain: TerrainManager
var _elapsed := 0.0
var _spot: SpotLight3D
var _cached_ground_y := NAN
var _power_off_elapsed := -1.0


static func spawn(
	tree: SceneTree,
	target: Node3D,
	terrain: TerrainManager = null,
	_projector_from: Node3D = null
) -> Node3D:
	var reticle: Node3D = load("res://scripts/enemies/laser_ground_reticle.gd").new()
	reticle.name = "LaserGroundReticle"
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null and tree != null:
		parent = tree.root
	if parent != null:
		parent.add_child(reticle)
	reticle.configure(target, terrain)
	return reticle


func configure(target: Node3D, terrain: TerrainManager = null) -> void:
	_target = target
	_terrain = terrain
	_elapsed = 0.0
	_power_off_elapsed = -1.0
	_cached_ground_y = NAN
	top_level = true
	_ensure_visual()
	_update_world_anchor()
	_sync_spot()


func begin_power_off() -> void:
	_power_off_elapsed = 0.0
	_elapsed = TelegraphScript.telegraph_total_sec()


func tick_power_off(delta: float) -> bool:
	if _power_off_elapsed < 0.0:
		return true
	_power_off_elapsed += maxf(delta, 0.0)
	_elapsed = TelegraphScript.telegraph_total_sec()
	if _target == null or not is_instance_valid(_target):
		return _power_off_elapsed >= TelegraphScript.POWER_OFF_GLITCH_SEC
	_update_world_anchor()
	_sync_spot()
	return _power_off_elapsed >= TelegraphScript.POWER_OFF_GLITCH_SEC


func update_telegraph(elapsed: float) -> void:
	_elapsed = maxf(elapsed, 0.0)
	if _power_off_elapsed >= 0.0:
		return
	if _target == null or not is_instance_valid(_target):
		visible = false
		if _spot != null:
			_spot.visible = false
		return
	_update_world_anchor()
	_sync_spot()


func _target_yaw() -> float:
	if _target is GliderPlayer:
		return (_target as GliderPlayer).get_yaw()
	return _target.global_rotation.y


func _flat_forward_from_yaw(yaw: float) -> Vector3:
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func _sample_ground_y(world_x: float, world_z: float, probe_y: float) -> float:
	var space := _space_state()
	var hit := TerrainQueryScript.raycast_ground(
		space,
		world_x,
		world_z,
		probe_y
	)
	if not hit.is_empty():
		return hit.position.y
	if _terrain != null:
		return _terrain.sample_height(world_x, world_z)
	var surface := TerrainQueryScript.sample_surface(
		_terrain,
		space,
		world_x,
		world_z,
		probe_y
	)
	if not surface.is_empty():
		return surface.position.y
	return NAN


func _hover_reference_y(world_x: float, world_z: float, probe_y: float) -> float:
	var ground_y := _sample_ground_y(world_x, world_z, probe_y)
	if not is_nan(ground_y):
		_cached_ground_y = ground_y
	elif not is_nan(_cached_ground_y):
		ground_y = _cached_ground_y
	else:
		ground_y = 0.0
	return (
		ground_y
		+ GliderPhysicsScript.BASE_HEIGHT
		+ GliderPlayer.BOARD_BOTTOM_OFFSET
	)


func _update_world_anchor() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var yaw := _target_yaw()
	var forward := _flat_forward_from_yaw(yaw)
	var origin := _target.global_position
	var xz := Vector3(origin.x, 0.0, origin.z) + forward * SPOT_LOCAL_OFFSET.z
	var hover_y := _hover_reference_y(xz.x, xz.z, origin.y + 4.0)
	global_position = Vector3(xz.x, hover_y + SPOT_LOCAL_OFFSET.y, xz.z)
	global_rotation = Vector3(0.0, yaw, 0.0)


func _space_state() -> PhysicsDirectSpaceState3D:
	var world := get_world_3d()
	if world == null:
		var tree := get_tree()
		if tree != null and tree.root != null:
			world = tree.root.get_world_3d()
	if world == null:
		return null
	return world.direct_space_state


func _sync_spot() -> void:
	if _spot == null:
		return
	var frames := _ensure_frames()
	if frames.is_empty():
		return

	var frame_idx := TelegraphScript.frame_index_for_telegraph(_elapsed, FRAME_COUNT)
	frame_idx = clampi(frame_idx, 0, frames.size() - 1)
	var texture := frames[frame_idx]
	if texture != null:
		_spot.light_projector = texture

	_spot.spot_angle = SPOT_ANGLE_DEG
	_spot.spot_range = SPOT_RANGE_M

	var lit := TelegraphScript.reticle_lit(_elapsed)
	if _power_off_elapsed >= 0.0:
		lit = TelegraphScript.power_off_lit(_power_off_elapsed)
	if not lit:
		_spot.visible = false
		_spot.light_energy = 0.0
	else:
		_spot.visible = true
		var energy := SPOT_ENERGY
		if (
			_power_off_elapsed < 0.0
			and TelegraphScript.is_blinking(_elapsed)
			and not TelegraphScript.brackets_visible(_elapsed)
		):
			energy *= BLINK_LIGHT_DIM
		_spot.light_energy = energy
	_spot.light_color = LIGHT_COLOR
	visible = lit or _power_off_elapsed >= 0.0


func _ensure_visual() -> void:
	if _spot != null:
		return
	var frames := _ensure_frames()
	if frames.is_empty():
		push_warning("LaserGroundReticle: missing reticle flipbook frames")
		return

	_spot = SpotLight3D.new()
	_spot.name = "ReticleProjector"
	_spot.rotation = SPOT_LOCAL_ROTATION
	_spot.light_color = LIGHT_COLOR
	_spot.light_energy = SPOT_ENERGY
	_spot.light_specular = SPOT_SPECULAR
	_spot.light_size = SPOT_LIGHT_SIZE
	_spot.shadow_enabled = true
	_spot.spot_angle = SPOT_ANGLE_DEG
	_spot.spot_attenuation = SPOT_DISTANCE_ATTENUATION
	_spot.spot_angle_attenuation = SPOT_ANGLE_ATTENUATION
	_spot.spot_range = SPOT_RANGE_M
	if not frames.is_empty() and frames[0] != null:
		_spot.light_projector = frames[0]
	add_child(_spot)


static func _ensure_frames() -> Array[Texture2D]:
	if _frames_loaded:
		return _frames
	_frames = VfxFlipbookScript.load_texture_sequence(
		TEXTURE_DIR,
		FRAME_PREFIX,
		FRAME_COUNT,
		FRAME_OFFSET
	)
	_frames_loaded = true
	return _frames
