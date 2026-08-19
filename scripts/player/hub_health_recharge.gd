class_name HubHealthRecharge
extends Node

## Heals PlayerHealth by TOWER_HEAL when entering any upgrade-tower hub (once per visit).

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")
const EonDirectorScript = preload("res://scripts/game/eon_director.gd")

@export var player_rig_path: NodePath
@export var player_health_path: NodePath

var _rig: PlayerRig
var _health: PlayerHealthScript
var _director: EonDirectorScript
var _inside_hub := false


func _ready() -> void:
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if player_health_path != NodePath():
		_health = get_node_or_null(player_health_path) as PlayerHealthScript
	if _health == null:
		_health = get_parent().get_node_or_null("PlayerHealth") as PlayerHealthScript
	if _rig == null:
		_rig = get_parent() as PlayerRig
	call_deferred("_resolve_director")


func _resolve_director() -> void:
	_director = get_tree().get_first_node_in_group("eon_director") as EonDirectorScript


func _physics_process(_delta: float) -> void:
	if _health == null or _rig == null:
		return
	var glider := _rig.get_glider()
	var run_ended := glider != null and glider.is_run_ended()
	var run_active := _director != null and _director.is_run_active()
	var bootstrapped := _director != null and _director.has_collected_eon()
	if not PlayerHealthScript.should_process_hub_heal(run_active, bootstrapped, run_ended):
		_inside_hub = false
		return

	var body := _rig.get_active_body()
	if body == null:
		_inside_hub = false
		return

	var inside_now := _any_hub_contains(body.global_position)
	if PlayerHealthScript.should_heal_on_hub_edge(_inside_hub, inside_now):
		_health.heal(PlayerHealthScript.TOWER_HEAL)
	_inside_hub = inside_now


func _any_hub_contains(world_pos: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("upgrade_tower"):
		if not (node is Node3D):
			continue
		var hub := node as Node3D
		var xz := Vector2(world_pos.x - hub.global_position.x, world_pos.z - hub.global_position.z)
		if xz.length() <= AntennaState.HUB_RADIUS_M:
			return true
	return false
