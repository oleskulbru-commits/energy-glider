class_name UpgradeTowerMenu
extends CanvasLayer

signal closed

const SELECTED_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const IDLE_MODULATE := Color(0.92, 0.88, 0.8, 1.0)
const EMPTY_MODULATE := Color(0.55, 0.52, 0.48, 1.0)
const SELECTED_BORDER := Color(1.0, 0.9, 0.38, 1.0)
const IDLE_BORDER := Color(0.85, 0.72, 0.55, 0.28)
const EMPTY_BORDER := Color(0.45, 0.42, 0.38, 0.32)

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
var _card_frames: Array[Control] = []
var _selected_frame_style: StyleBoxFlat
var _idle_frame_style: StyleBoxFlat
var _empty_frame_style: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root.visible = false
	_selected_frame_style = _make_frame_style(SELECTED_BORDER, 5, Color(0.16, 0.12, 0.05, 0.72), true)
	_idle_frame_style = _make_frame_style(IDLE_BORDER, 2, Color(0.05, 0.05, 0.06, 0.28), false)
	_empty_frame_style = _make_frame_style(EMPTY_BORDER, 1, Color(0.03, 0.03, 0.04, 0.22), false)
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
	_card_frames.clear()
	for child in _cards.get_children():
		var button := child.find_child("Button", true, false) as Button
		if button == null:
			continue
		var slot := _card_buttons.size()
		button.pressed.connect(_on_card_pressed.bind(slot))
		_card_buttons.append(button)
		_card_frames.append(child as Control)


func _refresh_cards() -> void:
	var offers := PackedStringArray()
	if _state != null and _tower != null:
		offers = _state.get_offers(_tower.tower_index)
	for i in _card_buttons.size():
		var button := _card_buttons[i]
		var wrapper := button.get_parent()
		if wrapper == _cards:
			wrapper = button
		var frame := _card_frames[i] if i < _card_frames.size() else null
		if i >= offers.size():
			if frame != null:
				frame.visible = false
			wrapper.visible = false
			continue
		if frame != null:
			frame.visible = true
		wrapper.visible = true
		button.visible = true
		var id := StringName(offers[i])
		var empty := UpgradeCatalog.is_empty_offer(id)
		if empty:
			_apply_empty_card(button, wrapper)
			continue
		button.disabled = false
		button.icon = UpgradeCatalog.icon_for(id)
		button.text = ""
		button.tooltip_text = _card_tooltip(id)
		button.modulate = SELECTED_MODULATE if i == _selected_slot else IDLE_MODULATE
		_apply_selection_frame(i, i == _selected_slot, false)
		var rarity_label := wrapper.get_node_or_null("RarityLabel") as Label
		if rarity_label != null:
			rarity_label.text = UpgradeCatalog.rarity_display_name(id)
			rarity_label.add_theme_color_override("font_color", UpgradeCatalog.rarity_color(id))
		var label := wrapper.get_node_or_null("NameLabel") as Label
		if label != null:
			label.text = UpgradeCatalog.display_name(id)
		_apply_bonus_label(wrapper, id)
	var remaining := 0
	if _state != null and _tower != null:
		remaining = _state.remaining_count(_tower.tower_index)
	var can_confirm := remaining == 0 or _selected_slot >= 0
	_wait_button.disabled = not can_confirm
	_keep_button.disabled = not can_confirm
	if _tower != null:
		if _tower.is_bonus:
			_title.text = "BONUS TOWER"
		else:
			_title.text = "TOWER %d" % _tower.tower_index


func _apply_empty_card(button: Button, wrapper: Node) -> void:
	button.disabled = true
	button.icon = null
	button.text = "Empty"
	button.tooltip_text = "Empty"
	button.modulate = EMPTY_MODULATE
	var slot := _card_buttons.find(button)
	_apply_selection_frame(slot, false, true)
	var rarity_label := wrapper.get_node_or_null("RarityLabel") as Label
	if rarity_label != null:
		rarity_label.text = ""
	var label := wrapper.get_node_or_null("NameLabel") as Label
	if label != null:
		label.text = ""
	_apply_bonus_label(wrapper, UpgradeCatalog.EMPTY_OFFER)


func _apply_selection_frame(slot: int, selected: bool, empty: bool) -> void:
	if slot < 0 or slot >= _card_frames.size():
		return
	var frame := _card_frames[slot]
	if frame == null:
		return
	var style := _empty_frame_style
	if not empty:
		style = _selected_frame_style if selected else _idle_frame_style
	frame.add_theme_stylebox_override("panel", style)


func _make_frame_style(border: Color, width: int, bg: Color, glow: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(width)
	box.border_color = border
	box.set_corner_radius_all(8)
	box.set_content_margin_all(8)
	if glow:
		box.shadow_color = Color(1.0, 0.82, 0.28, 0.62)
		box.shadow_size = 12
		box.shadow_offset = Vector2.ZERO
	return box


func _apply_bonus_label(wrapper: Node, id: StringName) -> void:
	var bonus := wrapper.get_node_or_null("BonusLabel") as Label
	if bonus == null:
		return
	var lines := UpgradeCatalog.weapon_bonus_lines(id)
	if lines.is_empty():
		bonus.text = ""
		bonus.visible = false
		return
	bonus.visible = true
	bonus.text = "\n".join(lines)


func _card_tooltip(id: StringName) -> String:
	var tip := UpgradeCatalog.display_name(id)
	for line in UpgradeCatalog.weapon_bonus_lines(id):
		tip += "\n%s" % line
	return tip


func _on_card_pressed(slot: int) -> void:
	var offers := PackedStringArray()
	if _state != null and _tower != null:
		offers = _state.get_offers(_tower.tower_index)
	if slot < 0 or slot >= offers.size():
		return
	if UpgradeCatalog.is_empty_offer(StringName(offers[slot])):
		return
	_selected_slot = slot
	_refresh_cards()


func _on_wait_pressed() -> void:
	_confirm_and_close(true)


func _on_keep_pressed() -> void:
	_confirm_and_close(false)


func _confirm_and_close(wait_until_dawn: bool) -> void:
	var took_unlock := false
	if _state != null and _tower != null:
		if _state.remaining_count(_tower.tower_index) > 0:
			if _selected_slot < 0:
				return
			var picked := _state.pick_offer(_tower.tower_index, _selected_slot)
			took_unlock = UpgradeCatalog.is_weapon_unlock(picked)
		_state.note_visit_outcome(took_unlock)
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
	_clear_enemies_until_dawn_grace()


func _close() -> void:
	visible = false
	_root.visible = false
	get_tree().paused = false
	if _rig != null:
		_rig.capture_look_mouse()
	_tower = null
	closed.emit()


func _clear_enemies_until_dawn_grace() -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_stream_spawner") as EnemyStreamSpawner
	if spawner != null:
		spawner.reset_after_dawn()
