class_name UpgradeTowerMenu
extends CanvasLayer

signal closed

const SELECTED_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const IDLE_MODULATE := Color(0.92, 0.88, 0.8, 1.0)
const EMPTY_MODULATE := Color(0.55, 0.52, 0.48, 1.0)
const SELECTED_FRAME := Color(1.15, 1.15, 1.15, 1.0)
const IDLE_FRAME := Color(1.0, 1.0, 1.0, 1.0)
const EMPTY_FRAME := Color(0.55, 0.52, 0.48, 1.0)
const BORDER_BASE := preload("res://assets/ui/upgrade_menu/upgrade_card.png")
const BORDER_COMMON := preload("res://assets/ui/upgrade_menu/card_border_common.png")
const BORDER_UNCOMMON := preload("res://assets/ui/upgrade_menu/card_border_uncommon.png")
const BORDER_RARE := preload("res://assets/ui/upgrade_menu/card_border_rare.png")
const BORDER_EPIC := preload("res://assets/ui/upgrade_menu/card_border_epic.png")
const BORDER_LEGENDARY := preload("res://assets/ui/upgrade_menu/card_border_legendary.png")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")

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
var _button_style := StyleBoxEmpty.new()


func _ready() -> void:
	add_to_group("upgrade_tower_menu")
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
	_set_glide_audible_while_paused(true)
	get_tree().paused = true
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_disable_input = false
	if _rig != null:
		_rig.release_look_mouse()
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
		for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(style_name, _button_style)
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
		_apply_selection_frame(i, i == _selected_slot, false, _border_for(id))
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
	var bonus_stop := _tower != null and _tower.is_bonus
	if _wait_button != null:
		_wait_button.visible = not bonus_stop
		_wait_button.disabled = bonus_stop or not can_confirm
	_keep_button.disabled = not can_confirm
	if _tower != null:
		if bonus_stop:
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
	_apply_selection_frame(slot, false, true, BORDER_BASE)
	var rarity_label := wrapper.get_node_or_null("RarityLabel") as Label
	if rarity_label != null:
		rarity_label.text = ""
	var label := wrapper.get_node_or_null("NameLabel") as Label
	if label != null:
		label.text = ""
	_apply_bonus_label(wrapper, UpgradeCatalog.EMPTY_OFFER)


func _border_for(id: StringName) -> Texture2D:
	match UpgradeCatalog.rarity_of(id):
		UpgradeCatalog.RARITY_UNCOMMON:
			return BORDER_UNCOMMON
		UpgradeCatalog.RARITY_RARE:
			return BORDER_RARE
		UpgradeCatalog.RARITY_EPIC:
			return BORDER_EPIC
		UpgradeCatalog.RARITY_LEGENDARY:
			return BORDER_LEGENDARY
		_:
			return BORDER_COMMON


func _style_for(texture: Texture2D) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 20.0
	box.texture_margin_top = 20.0
	box.texture_margin_right = 20.0
	box.texture_margin_bottom = 22.0
	box.content_margin_left = 12.0
	box.content_margin_top = 8.0
	box.content_margin_right = 12.0
	box.content_margin_bottom = 16.0
	box.draw_center = true
	return box


func _apply_selection_frame(slot: int, selected: bool, empty: bool, border: Texture2D) -> void:
	if slot < 0 or slot >= _card_frames.size():
		return
	var frame := _card_frames[slot]
	if frame == null:
		return
	frame.add_theme_stylebox_override("panel", _style_for(border if border != null else BORDER_BASE))
	if empty:
		frame.self_modulate = EMPTY_FRAME
	elif selected:
		frame.self_modulate = SELECTED_FRAME
	else:
		frame.self_modulate = IDLE_FRAME


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
	if _tower != null and _tower.is_bonus:
		return
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
	if wait_until_dawn and _tower != null and not _tower.is_bonus:
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
	_set_glide_audible_while_paused(false)
	if _rig != null and PauseMenuScript.should_capture_look_after_unpause(get_tree()):
		_rig.capture_look_mouse()
	_tower = null
	closed.emit()


func _set_glide_audible_while_paused(audible: bool) -> void:
	var music := get_tree().get_first_node_in_group("glide_music")
	if music != null and music.has_method("set_audible_while_paused"):
		music.set_audible_while_paused(audible)


func _clear_enemies_until_dawn_grace() -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_stream_spawner") as EnemyStreamSpawner
	if spawner != null:
		spawner.reset_after_dawn()
