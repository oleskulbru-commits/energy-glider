class_name PauseMenu
extends CanvasLayer

const FADE_SEC := 0.5

@onready var _root: Control = %Root
@onready var _dim: ColorRect = %Dim
@onready var _center: Control = %Center
@onready var _resume_button: Button = %ResumeButton
@onready var _main_menu_button: Button = %MainMenuButton

var _rig: PlayerRig
var _fade_dir := 0
var _amount := 0.0
var _dim_color := Color(0.02, 0.02, 0.03, 0.72)
var _master_bus := -1
var _master_db := 0.0
var _holding_music := false


func _ready() -> void:
	add_to_group("pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	visible = false
	_root.visible = false
	_center.visible = false
	_dim_color = _dim.color
	_dim.color = Color(_dim_color.r, _dim_color.g, _dim_color.b, 0.0)
	_master_bus = AudioServer.get_bus_index("Master")
	if _master_bus >= 0:
		_master_db = AudioServer.get_bus_volume_db(_master_bus)
	_resume_button.pressed.connect(_on_resume_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


func _process(delta: float) -> void:
	if _fade_dir == 0:
		return
	_amount = clampf(_amount + _fade_dir * delta / FADE_SEC, 0.0, 1.0)
	_apply_amount(_amount)
	if _fade_dir > 0 and _amount >= 1.0:
		_complete_pause()
	elif _fade_dir < 0 and _amount <= 0.0:
		_complete_resume()


func is_open() -> bool:
	return _center.visible


func is_fading() -> bool:
	return _fade_dir != 0


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
	if is_open() or _fade_dir > 0:
		close()
		return
	if _fade_dir < 0:
		open(rig if rig != null else _rig)
		return
	if rig == null:
		return
	var glider := rig.get_glider()
	if not can_open_pause(get_tree(), glider):
		return
	open(rig)


func open(rig: PlayerRig) -> void:
	if rig != null:
		_rig = rig
	_fade_dir = 1
	visible = true
	_root.visible = true
	_center.visible = true
	# Keep the theme audible while the tree is paused so the master fade can finish.
	_hold_music(true)
	get_tree().paused = true
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_disable_input = false
	if _rig != null:
		_rig.release_look_mouse()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if _fade_dir < 0:
		return
	if not is_open() and _fade_dir == 0 and _amount <= 0.0:
		return
	_center.visible = false
	_fade_dir = -1
	# Unpause before releasing the music hold, so the stream does not click off.
	get_tree().paused = false
	_hold_music(false)
	if _rig != null and should_capture_look_after_unpause(get_tree()):
		_rig.capture_look_mouse()


func _complete_pause() -> void:
	_fade_dir = 0
	_apply_amount(1.0)
	_hold_music(false)


func _complete_resume() -> void:
	_fade_dir = 0
	_apply_amount(0.0)
	_hold_music(false)
	visible = false
	_root.visible = false
	_center.visible = false
	_rig = null


func _apply_amount(amount: float) -> void:
	_dim.color = Color(_dim_color.r, _dim_color.g, _dim_color.b, _dim_color.a * amount)
	if _master_bus < 0:
		return
	if amount <= 0.0:
		AudioServer.set_bus_volume_db(_master_bus, _master_db)
		return
	var full := db_to_linear(_master_db)
	var linear := lerpf(0.0, full, 1.0 - amount)
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(maxf(linear, 0.0001)))


func _hold_music(hold: bool) -> void:
	if _holding_music == hold:
		return
	_holding_music = hold
	var tree := get_tree()
	if tree == null:
		return
	var glide := tree.get_first_node_in_group("glide_music")
	if glide != null and glide.has_method("set_audible_while_paused"):
		glide.set_audible_while_paused(hold)
	var boss := tree.get_first_node_in_group("boss_director")
	if boss != null and boss.has_method("set_audible_while_paused"):
		boss.set_audible_while_paused(hold)


func _input(event: InputEvent) -> void:
	if not _is_pause_key(event):
		return
	if is_open() or _fade_dir > 0:
		close()
		get_viewport().set_input_as_handled()
		return
	if _fade_dir < 0:
		open(_rig if _rig != null else _find_player_rig())
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


func _on_main_menu_pressed() -> void:
	_fade_dir = 0
	_apply_amount(0.0)
	_hold_music(false)
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	var director := tree.get_first_node_in_group("eon_director")
	if director != null and director.has_method("request_main_menu"):
		director.request_main_menu()
