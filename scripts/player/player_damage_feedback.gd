class_name PlayerDamageFeedback
extends Node

## Camera shake, HUD flash, land reaction, and body flash when PlayerHealth takes damage.

const CameraImpactShakeScript := preload("res://scripts/player/camera_impact_shake.gd")

const HEAVY_DAMAGE_THRESHOLD := 10
const SHAKE_STRENGTH_HEAVY := 0.85
const SHAKE_RADIUS_HEAVY := 38.0
const SHAKE_STRENGTH_LIGHT := 0.28
const SHAKE_RADIUS_LIGHT := 20.0
const FLASH_LIGHT_COLOR := Color(1.0, 0.12, 0.04)
const FLASH_LIGHT_RANGE := 5.5
const FLASH_LIGHT_PEAK := 12.0
const FLASH_LIGHT_FADE_SEC := 0.2

@export var health_path: NodePath = NodePath("../PlayerHealth")
@export var glider_path: NodePath = NodePath("../Glider")
@export var hud_path: NodePath = NodePath("../GliderHUD")

var _health: PlayerHealth
var _glider: GliderPlayer
var _hud: GliderHUD
var _flash_light: OmniLight3D
var _flash_tween: Tween


func _ready() -> void:
	_health = get_node_or_null(health_path) as PlayerHealth
	_glider = get_node_or_null(glider_path) as GliderPlayer
	_hud = get_node_or_null(hud_path) as GliderHUD
	if _health != null and not _health.damaged.is_connected(_on_damaged):
		_health.damaged.connect(_on_damaged)


func _on_damaged(amount: int) -> void:
	if amount <= 0:
		return
	var tree := get_tree()
	if tree == null:
		return
	var world_pos := _player_world_pos()
	_request_shake(tree, amount, world_pos)
	if _hud != null:
		_hud.play_damage_flash(amount)
	if amount >= HEAVY_DAMAGE_THRESHOLD:
		if _glider != null:
			_glider.play_hit_reaction()
		_flash_character()


static func shake_strength_for(amount: int) -> float:
	if amount >= HEAVY_DAMAGE_THRESHOLD:
		return SHAKE_STRENGTH_HEAVY
	return SHAKE_STRENGTH_LIGHT


static func shake_radius_for(amount: int) -> float:
	if amount >= HEAVY_DAMAGE_THRESHOLD:
		return SHAKE_RADIUS_HEAVY
	return SHAKE_RADIUS_LIGHT


func _request_shake(tree: SceneTree, amount: int, world_pos: Vector3) -> void:
	CameraImpactShakeScript.request(
		tree,
		world_pos,
		shake_strength_for(amount),
		shake_radius_for(amount)
	)


func _player_world_pos() -> Vector3:
	if _glider != null:
		return _glider.global_position
	return Vector3.ZERO


func _flash_character() -> void:
	if _glider == null:
		return
	var visual := _glider.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var light := _ensure_flash_light(visual)
	light.global_position = _glider.global_position + Vector3(0.0, 1.1, 0.0)
	light.visible = true
	light.light_energy = FLASH_LIGHT_PEAK
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(light, "light_energy", 0.0, FLASH_LIGHT_FADE_SEC).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	_flash_tween.finished.connect(func() -> void: light.visible = false, CONNECT_ONE_SHOT)


func _ensure_flash_light(parent: Node3D) -> OmniLight3D:
	if _flash_light != null and is_instance_valid(_flash_light):
		return _flash_light
	_flash_light = OmniLight3D.new()
	_flash_light.name = "DamageFlashLight"
	_flash_light.light_color = FLASH_LIGHT_COLOR
	_flash_light.omni_range = FLASH_LIGHT_RANGE
	_flash_light.light_energy = 0.0
	_flash_light.visible = false
	_flash_light.shadow_enabled = false
	parent.add_child(_flash_light)
	return _flash_light
