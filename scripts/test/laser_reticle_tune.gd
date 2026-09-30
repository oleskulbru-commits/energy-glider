@tool
extends Node3D

## Looping laser telegraph for tuning spot placement (F6 scenes/test/laser_reticle_tune.tscn).
## Copy `spot_local_y` / `spot_local_z` into LaserGroundReticleScript.SPOT_LOCAL_OFFSET when satisfied.

const ReticleScript := preload("res://scripts/enemies/laser_ground_reticle.gd")
const TelegraphScript := preload("res://scripts/enemies/laser_drone_telegraph.gd")
const DefaultProjectorFrame := preload(
	"res://assets/vfx/effect_textures/reticles/reticle_1_frame_0060.png"
)

@export_group("Placement")
@export_range(-2.0, 0.5, 0.001, "or_greater", "or_less")
var spot_local_y: float = ReticleScript.SPOT_LOCAL_OFFSET.y:
	set(value):
		spot_local_y = value
		_apply_spot_placement()

@export_range(-2.0, 2.0, 0.001, "or_greater", "or_less")
var spot_local_z: float = ReticleScript.SPOT_LOCAL_OFFSET.z:
	set(value):
		spot_local_z = value
		_apply_spot_placement()

@export_group("Telegraph")
@export var loop_telegraph: bool = true
@export var play_speed: float = 1.0

@export_group("Spot (runtime defaults)")
@export var spot_energy: float = ReticleScript.SPOT_ENERGY
@export var spot_specular: float = ReticleScript.SPOT_SPECULAR

var _elapsed := 0.0
var _spot: SpotLight3D


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("laser_reticle_tune")
	_resolve_spot()
	_apply_spot_placement()
	_apply_spot_baseline()
	_sync_spot()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_elapsed += delta * maxf(play_speed, 0.001)
	if loop_telegraph:
		var total := TelegraphScript.telegraph_total_sec()
		if total > 0.0:
			_elapsed = fmod(_elapsed, total)
	_sync_spot()


func _apply_spot_placement() -> void:
	position = Vector3(0.0, spot_local_y, spot_local_z)


func _resolve_spot() -> void:
	if _spot != null and is_instance_valid(_spot):
		return
	_spot = get_node_or_null("ReticleProjector") as SpotLight3D


func _apply_spot_baseline() -> void:
	_resolve_spot()
	if _spot == null:
		return
	_spot.rotation = ReticleScript.SPOT_LOCAL_ROTATION
	_spot.light_color = ReticleScript.LIGHT_COLOR
	_spot.light_size = ReticleScript.SPOT_LIGHT_SIZE
	_spot.shadow_enabled = false
	_spot.spot_angle = ReticleScript.SPOT_ANGLE_DEG
	_spot.spot_range = ReticleScript.SPOT_RANGE_M
	_spot.spot_attenuation = ReticleScript.SPOT_DISTANCE_ATTENUATION
	_spot.spot_angle_attenuation = ReticleScript.SPOT_ANGLE_ATTENUATION
	if _spot.light_projector == null and DefaultProjectorFrame != null:
		_spot.light_projector = DefaultProjectorFrame


func _sync_spot() -> void:
	_resolve_spot()
	if _spot == null:
		return

	if not Engine.is_editor_hint():
		var frames := ReticleScript._ensure_frames()
		if not frames.is_empty():
			var frame_idx := TelegraphScript.frame_index_for_telegraph(
				_elapsed,
				ReticleScript.FRAME_COUNT
			)
			frame_idx = clampi(frame_idx, 0, frames.size() - 1)
			var texture := frames[frame_idx]
			if texture != null:
				_spot.light_projector = texture

	var lit := TelegraphScript.reticle_lit(_elapsed)
	if not lit:
		_spot.visible = false
		_spot.light_energy = 0.0
	else:
		_spot.visible = true
		_spot.light_energy = spot_energy
		if (
			TelegraphScript.is_blinking(_elapsed)
			and not TelegraphScript.brackets_visible(_elapsed)
		):
			_spot.light_energy = spot_energy * ReticleScript.BLINK_LIGHT_DIM
	_spot.light_specular = spot_specular
