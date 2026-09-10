class_name PlayerHealthBar
extends Node3D

## World-space HP bar above the glider. Stays a local child so it cannot drift
## at large westbound coordinates; billboards without writing global_transform.

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")

const BAR_WIDTH := 1.4
const BAR_HEIGHT := 0.14
const OFFSET_Y := 1.8
const LOCAL_OFFSET := Vector3(0.0, OFFSET_Y, 0.0)

@export var player_health_path: NodePath

var _health: PlayerHealthScript
var _bg: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mesh: QuadMesh
var _float_root: Node3D
var _rng := RandomNumberGenerator.new()
var _shown := false


func _ready() -> void:
	position = LOCAL_OFFSET
	_rng.randomize()
	_build_meshes()
	_float_root = Node3D.new()
	_float_root.name = "DamageFloats"
	add_child(_float_root)
	call_deferred("_connect_health")


func _process(_delta: float) -> void:
	sync_follow()


func sync_follow() -> void:
	# Re-pin every frame so look/billboard math cannot accumulate origin error.
	position = LOCAL_OFFSET
	_billboard_local()
	position = LOCAL_OFFSET


func _connect_health() -> void:
	if player_health_path != NodePath():
		_health = get_node_or_null(player_health_path) as PlayerHealthScript
	if _health == null:
		_health = get_tree().get_first_node_in_group("player_health") as PlayerHealthScript
	if _health == null:
		return
	if not _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.connect(_on_health_changed)
	if _health.has_signal("damaged") and not _health.damaged.is_connected(_on_damaged):
		_health.damaged.connect(_on_damaged)
	_on_health_changed(_health.get_current(), _health.get_max())


func _on_damaged(amount: int) -> void:
	if amount <= 0:
		return
	DamageFloat.spawn(_float_root, amount, _rng)


func _on_health_changed(current: int, max_health: int) -> void:
	var ratio := 0.0
	if max_health > 0:
		ratio = clampf(float(current) / float(max_health), 0.0, 1.0)
	apply_fill_ratio(ratio)
	_show_bar()


func apply_fill_ratio(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if _fill_mesh != null:
		_fill_mesh.size = fill_size(clamped)
	if _fill != null:
		_fill.position.x = fill_offset_x(clamped)
		_fill.visible = _shown and clamped > 0.001
		var mat := _fill.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(
				lerpf(0.95, 0.2, clamped),
				lerpf(0.15, 0.85, clamped),
				0.12,
				1.0
			)


static func fill_size(ratio: float) -> Vector2:
	var clamped := clampf(ratio, 0.0, 1.0)
	return Vector2(BAR_WIDTH * maxf(clamped, 0.001), BAR_HEIGHT)


static func fill_offset_x(ratio: float) -> float:
	var clamped := clampf(ratio, 0.0, 1.0)
	return -BAR_WIDTH * 0.5 + BAR_WIDTH * clamped * 0.5


func get_fill_width() -> float:
	if _fill_mesh == null:
		return 0.0
	return _fill_mesh.size.x


func _show_bar() -> void:
	if _shown:
		return
	_shown = true
	if _bg != null:
		_bg.visible = true
	if _fill != null and _fill_mesh != null:
		_fill.visible = _fill_mesh.size.x > BAR_WIDTH * 0.001


func _billboard_local() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	var parent_3d := get_parent() as Node3D
	if parent_3d == null:
		return
	var origin := parent_3d.to_global(LOCAL_OFFSET)
	var to_cam := cam.global_position - origin
	if to_cam.length_squared() < 0.0001:
		return
	# QuadMesh faces +Z. looking_at aims -Z at the camera, then flip 180°.
	var global_basis := Basis.looking_at(to_cam, Vector3.UP).rotated(Vector3.UP, PI)
	var parent_basis := parent_3d.global_transform.basis
	if parent_basis.determinant() == 0.0:
		return
	basis = parent_basis.inverse() * global_basis


func _build_meshes() -> void:
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.1, 0.85)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_mat.no_depth_test = true
	bg_mat.render_priority = 8
	_bg = MeshInstance3D.new()
	_bg.mesh = bg_mesh
	_bg.material_override = bg_mat
	_bg.position = Vector3(0.0, 0.0, -0.01)
	_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bg.visible = false
	add_child(_bg)

	_fill_mesh = QuadMesh.new()
	_fill_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.2, 0.85, 0.25, 1.0)
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.no_depth_test = true
	fill_mat.render_priority = 9
	_fill = MeshInstance3D.new()
	_fill.mesh = _fill_mesh
	_fill.material_override = fill_mat
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.visible = false
	add_child(_fill)
