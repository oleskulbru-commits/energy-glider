class_name UpgradeTowerMenu
extends CanvasLayer

signal closed

const SELECTED_MODULATE := Color(1.0, 0.95, 0.75, 1.0)
const IDLE_MODULATE := Color(0.92, 0.88, 0.8, 1.0)

@onready var _root: Control = %Root
@onready var _title: Label = %TitleLabel
@onready var _cards: HBoxContainer = %Cards
@onready var _wait_button: Button = %WaitButton
@onready var _keep_button: Button = %KeepButton

var _tower: UpgradeTower
var _state: RunUpgradeState
var _rig: PlayerRig
var _selected_slot := -1
var _card_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root.visible = false
	_wait_button.pressed.connect(_on_wait_pressed)
	_keep_button.pressed.connect(_on_keep_pressed)
	_cache_cards()


func is_open() -> bool:
	return visible


func open_for(tower: UpgradeTower, state: RunUpgradeState, rig: PlayerRig) -> void:
	_tower = tower
	_state = state
	_rig = rig
	_selected_slot = -1
	_refresh_cards()
	visible = true
	_root.visible = true
	get_tree().paused = true
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_disable_input = false
	if _rig != null:
		_rig.release_look_mouse()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if not visible:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _cache_cards() -> void:
	_card_buttons.clear()
	for child in _cards.get_children():
		var button := child as Button
		if button == null:
			button = child.get_node_or_null("Button") as Button
		if button == null:
			continue
		var slot := _card_buttons.size()
		button.pressed.connect(_on_card_pressed.bind(slot))
		_card_buttons.append(button)


func _refresh_cards() -> void:
	var offers := PackedStringArray()
	if _state != null and _tower != null:
		offers = _state.get_offers(_tower.tower_index)
	for i in _card_buttons.size():
		var button := _card_buttons[i]
		var wrapper := button.get_parent()
		if wrapper == _cards:
			wrapper = button
		if i >= offers.size():
			button.visible = false
			button.disabled = true
			wrapper.visible = false
			continue
		var id := StringName(offers[i])
		wrapper.visible = true
		button.visible = true
		button.disabled = false
		button.icon = UpgradeCatalog.icon_for(id)
		button.tooltip_text = UpgradeCatalog.display_name(id)
		button.modulate = SELECTED_MODULATE if i == _selected_slot else IDLE_MODULATE
		var label := wrapper.get_node_or_null("NameLabel") as Label
		if label != null:
			label.text = UpgradeCatalog.display_name(id)
	var remaining := offers.size()
	var can_confirm := remaining == 0 or _selected_slot >= 0
	_wait_button.disabled = not can_confirm
	_keep_button.disabled = not can_confirm
	if _tower != null:
		_title.text = "TOWER %d" % _tower.tower_index


func _on_card_pressed(slot: int) -> void:
	var remaining := 0
	if _state != null and _tower != null:
		remaining = _state.remaining_count(_tower.tower_index)
	if slot < 0 or slot >= remaining:
		return
	_selected_slot = slot
	_refresh_cards()


func _on_wait_pressed() -> void:
	_confirm_and_close(true)


func _on_keep_pressed() -> void:
	_confirm_and_close(false)


func _confirm_and_close(wait_until_dawn: bool) -> void:
	if _state != null and _tower != null and _state.remaining_count(_tower.tower_index) > 0:
		if _selected_slot < 0:
			return
		_state.pick_offer(_tower.tower_index, _selected_slot)
	if wait_until_dawn:
		_wait_until_dawn()
	_close()


func _wait_until_dawn() -> void:
	var expedition := get_tree().get_first_node_in_group("expedition_state") as ExpeditionState
	if expedition != null:
		expedition.end_day()
	else:
		var day_night := get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle
		if day_night != null:
			day_night.skip_to_dawn()
	if _rig != null and _tower != null:
		_rig.teleport_in_front_of(_tower.global_position)


func _close() -> void:
	visible = false
	_root.visible = false
	get_tree().paused = false
	if _rig != null:
		_rig.capture_look_mouse()
	_tower = null
	closed.emit()
