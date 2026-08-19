class_name PlayerHealthBar
extends Node3D

## World-space HP bar above the glider (billboarded toward the active camera).

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")

const BAR_WIDTH := 1.4
const BAR_HEIGHT := 0.14
const OFFSET_Y := 1.8

@export var player_health_path: NodePath

var _health: PlayerHealthScript
var _bg: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mesh: QuadMesh
var _float_root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = Vector3(0.0, OFFSET_Y, 0.0)
	_rng.randomize()
	_build_meshes()
	_float_root = Node3D.new()
	_float_root.name = "DamageFloats"
	add_child(_float_root)
	visible = true
	call_deferred("_connect_health")


func _process(_delta: float) -> void:
	_billboard()


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
	_spawn_damage_float(amount)


func _spawn_damage_float(amount: int) -> void:
	DamageFloat.spawn(_float_root, amount, _rng)


func _on_health_changed(current: int, max_health: int) -> void:
	var ratio := 0.0
	if max_health > 0:
		ratio = clampf(float(current) / float(max_health), 0.0, 1.0)
	if _fill_mesh != null:
		_fill_mesh.size = Vector2(BAR_WIDTH * maxf(ratio, 0.001), BAR_HEIGHT)
	if _fill != null:
		_fill.position.x = -BAR_WIDTH * 0.5 + BAR_WIDTH * ratio * 0.5
		_fill.visible = ratio > 0.001
		var mat := _fill.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(
				lerpf(0.95, 0.2, ratio),
				lerpf(0.15, 0.85, ratio),
				0.12,
				1.0
			)
	visible = true


func _billboard() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	look_at(cam.global_position, Vector3.UP)
	rotate_object_local(Vector3.UP, PI)


func _build_meshes() -> void:
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.1, 0.85)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bg = MeshInstance3D.new()
	_bg.mesh = bg_mesh
	_bg.material_override = bg_mat
	_bg.position = Vector3(0.0, 0.0, -0.01)
	add_child(_bg)

	_fill_mesh = QuadMesh.new()
	_fill_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.2, 0.85, 0.25, 1.0)
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill = MeshInstance3D.new()
	_fill.mesh = _fill_mesh
	_fill.material_override = fill_mat
	add_child(_fill)
