class_name TowerVisitController
extends Node

## Opens the upgrade menu the first time a west tower is entered within 20 m this life.

const VISIT_RADIUS_M := 20.0

@export var player_rig_path: NodePath
@export var run_upgrade_state_path: NodePath
@export var menu_path: NodePath

var _rig: PlayerRig
var _state: RunUpgradeState
var _menu: UpgradeTowerMenu


func _ready() -> void:
	if player_rig_path != NodePath():
		_rig = get_node_or_null(player_rig_path) as PlayerRig
	if run_upgrade_state_path != NodePath():
		_state = get_node_or_null(run_upgrade_state_path) as RunUpgradeState
	if menu_path != NodePath():
		_menu = get_node_or_null(menu_path) as UpgradeTowerMenu


func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if _menu != null and _menu.is_open():
		return
	if _rig == null or _state == null or _menu == null:
		return
	var glider := _rig.get_glider()
	if glider == null or glider.is_run_ended():
		return
	var tower := find_visit_tower(get_tree(), glider.global_position)
	if tower == null:
		return
	if _state.has_visited_this_life(tower.tower_index):
		return
	_state.mark_visited_this_life(tower.tower_index)
	_menu.open_for(tower, _state, _rig)


static func xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func find_visit_tower(tree: SceneTree, origin: Vector3) -> UpgradeTower:
	if tree == null:
		return null
	var best: UpgradeTower = null
	var best_dist := VISIT_RADIUS_M
	for node in tree.get_nodes_in_group("upgrade_tower"):
		var tower := node as UpgradeTower
		if tower == null or not tower.is_upgrade_stop():
			continue
		var dist := xz_distance(origin, tower.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = tower
	return best
