class_name PlayerHealthBar
extends Node3D

## World-space HP bar above the glider (billboarded toward the active camera).

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")
const EonDirectorScript = preload("res://scripts/game/eon_director.gd")

const BAR_WIDTH := 1.4
const BAR_HEIGHT := 0.14
const OFFSET_Y := 1.8

const FLOAT_DURATION_SEC := 0.75
const FLOAT_FALL_M := 0.85
const FLOAT_SPREAD_X := 0.55
const FLOAT_FONT_SIZE := 48
const FLOAT_PIXEL_SIZE := 0.012

@export var player_health_path: NodePath

var _health: PlayerHealthScript
var _bg: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mesh: QuadMesh
var _float_root: Node3D
var _visible_for_run := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = Vector3(0.0, OFFSET_Y, 0.0)
	_rng.randomize()
	_build_meshes()
	_float_root = Node3D.new()
	_float_root.name = "DamageFloats"
	add_child(_float_root)
	visible = false
	call_deferred("_connect_health")
	call_deferred("_connect_director")


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


func _connect_director() -> void:
	var director := get_tree().get_first_node_in_group("eon_director") as EonDirectorScript
	if director == null:
		return
	if director.has_signal("run_started") and not director.run_started.is_connected(_on_run_started):
		director.run_started.connect(_on_run_started)
	if director.has_signal("player_died") and not director.player_died.is_connected(_on_player_died):
		director.player_died.connect(_on_player_died)
	if director.is_run_active():
		_on_run_started()


func _on_run_started() -> void:
	_visible_for_run = true
	visible = true


func _on_player_died(_pos: Vector3) -> void:
	_visible_for_run = false
	visible = false


func _on_damaged(amount: int) -> void:
	if amount <= 0 or not _visible_for_run:
		return
	_spawn_damage_float(amount)


func _spawn_damage_float(amount: int) -> void:
	var label := Label3D.new()
	label.text = "-%d" % amount
	label.modulate = Color(1.0, 0.18, 0.16, 1.0)
	label.outline_modulate = Color(0.15, 0.02, 0.02, 0.9)
	label.font_size = FLOAT_FONT_SIZE
	label.pixel_size = FLOAT_PIXEL_SIZE
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.position = Vector3(
		_rng.randf_range(-FLOAT_SPREAD_X * 0.35, FLOAT_SPREAD_X * 0.35),
		0.12,
		0.02
	)
	_float_root.add_child(label)

	var end_x := label.position.x + _rng.randf_range(-FLOAT_SPREAD_X, FLOAT_SPREAD_X)
	var end_y := label.position.y - FLOAT_FALL_M
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:x", end_x, FLOAT_DURATION_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", end_y, FLOAT_DURATION_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "outline_modulate:a", 0.0, FLOAT_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


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
	visible = _visible_for_run


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
