class_name PauseMenu
extends CanvasLayer

@onready var _root: Control = %Root
@onready var _resume_button: Button = %ResumeButton

var _rig: PlayerRig


func _ready() -> void:
	add_to_group("pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	visible = false
	_root.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)


func is_open() -> bool:
	return visible


static func find_menu(tree: SceneTree) -> PauseMenu:
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("pause_menu"):
		return node as PauseMenu
	return null


static func can_open_pause(tree: SceneTree, glider: GliderPlayer) -> bool:
	if glider != null and glider.is_run_ended():
		return false
	var weapon := tree.get_first_node_in_group("weapon_select_menu") as WeaponSelectMenu
	if weapon != null and weapon.is_open():
		return false
	var upgrade := tree.get_first_node_in_group("upgrade_tower_menu") as UpgradeTowerMenu
	if upgrade != null and upgrade.is_open():
		return false
	return true


static func should_capture_look_after_unpause(tree: SceneTree) -> bool:
	var pause := find_menu(tree)
	return pause == null or not pause.is_open()


func toggle_for_rig(rig: PlayerRig) -> void:
	if is_open():
		close()
		return
	if rig == null:
		return
	var glider := rig.get_glider()
	if not can_open_pause(get_tree(), glider):
		return
	open(rig)


func open(rig: PlayerRig) -> void:
	_rig = rig
	visible = true
	_root.visible = true
	get_tree().paused = true
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_disable_input = false
	if _rig != null:
		_rig.release_look_mouse()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	_root.visible = false
	get_tree().paused = false
	if _rig != null and should_capture_look_after_unpause(get_tree()):
		_rig.capture_look_mouse()
	_rig = null


func _input(event: InputEvent) -> void:
	if not _is_pause_key(event):
		return
	if is_open():
		close()
		get_viewport().set_input_as_handled()
		return
	var rig := _find_player_rig()
	if rig == null:
		return
	if not can_open_pause(get_tree(), rig.get_glider()):
		return
	open(rig)
	get_viewport().set_input_as_handled()


func _is_pause_key(event: InputEvent) -> bool:
	return event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel")


func _find_player_rig() -> PlayerRig:
	var health := get_tree().get_first_node_in_group("player_health") as PlayerHealth
	if health != null:
		return health.get_parent() as PlayerRig
	return null


func _on_resume_pressed() -> void:
	close()
