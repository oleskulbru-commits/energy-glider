class_name UpgradeTowerMenu
extends CanvasLayer

signal closed

const SELECTED_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const EMPTY_MODULATE := Color(0.55, 0.52, 0.48, 1.0)
const IDLE_FRAME := Color(1.0, 1.0, 1.0, 1.0)
const EMPTY_FRAME := Color(0.55, 0.52, 0.48, 1.0)
const GLOW_INSET_L := 0.034
const GLOW_INSET_T := 0.063
const GLOW_INSET_R := 0.036
const GLOW_INSET_B := 0.059
const SELECT_GLOW := preload("res://assets/ui/upgrade_menu/card_select_glow.png")
const BORDER_BASE := preload("res://assets/ui/upgrade_menu/upgrade_card.png")
const BORDER_COMMON := preload("res://assets/ui/upgrade_menu/card_border_common.png")
const BORDER_UNCOMMON := preload("res://assets/ui/upgrade_menu/card_border_uncommon.png")
const BORDER_RARE := preload("res://assets/ui/upgrade_menu/card_border_rare.png")
const BORDER_EPIC := preload("res://assets/ui/upgrade_menu/card_border_epic.png")
const BORDER_LEGENDARY := preload("res://assets/ui/upgrade_menu/card_border_legendary.png")
const ICON_FRAME_COMMON := preload("res://assets/ui/upgrade_menu/icon_frame_common.png")
const ICON_FRAME_UNCOMMON := preload("res://assets/ui/upgrade_menu/icon_frame_uncommon.png")
const ICON_FRAME_RARE := preload("res://assets/ui/upgrade_menu/icon_frame_rare.png")
const ICON_FRAME_EPIC := preload("res://assets/ui/upgrade_menu/icon_frame_epic.png")
const ICON_FRAME_LEGENDARY := preload("res://assets/ui/upgrade_menu/icon_frame_legendary.png")
const IconHostScript := preload("res://scripts/ui/upgrade_icon_host.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const HEADER_ORNAMENT := preload("res://assets/ui/upgrade_menu/header_ornament.png")
const HEADER_DIAMOND := preload("res://assets/ui/upgrade_menu/header_diamond.png")
const HEADER_TEX := Vector2(990.0, 195.0)
const HEADER_BAR_X0 := 19.0
const HEADER_BAR_X1 := 970.0
const HEADER_BAR_Y := 173.0
const FRAME_SRC_W := 1024.0
const FRAME_MARGIN_X := 320.0
const FRAME_STROKE_L := 69.0
const FRAME_STROKE_R := 954.0
const FRAME_STROKE_Y := 37.0

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
var _glow: TextureRect
var _header: TextureRect
var _diamond: TextureRect


func _ready() -> void:
	add_to_group("upgrade_tower_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root.visible = false
	_wait_button.pressed.connect(_on_wait_pressed)
	_keep_button.pressed.connect(_on_keep_pressed)
	_cache_cards()
	_glow = TextureRect.new()
	_glow.name = "SelectionGlow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.texture = SELECT_GLOW
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.visible = false
	_glow.z_index = 1
	_root.add_child(_glow)
	_header = _ornament_rect("HeaderOrnament", HEADER_ORNAMENT)
	_diamond = _ornament_rect("HeaderDiamond", HEADER_DIAMOND)
	_root.resized.connect(_place_selection_glow)
	_root.resized.connect(_place_header_ornament)


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
	call_deferred("_place_header_ornament")
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
		button.icon = null
		button.expand_icon = false
		_ensure_icon_host(button)
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
		button.icon = null
		button.text = ""
		button.tooltip_text = _card_tooltip(id)
		button.modulate = SELECTED_MODULATE
		_apply_icon(button, id)
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
		_wait_button.modulate = EMPTY_MODULATE if _wait_button.disabled else Color.WHITE
	_keep_button.disabled = not can_confirm
	_keep_button.modulate = EMPTY_MODULATE if _keep_button.disabled else Color.WHITE
	if _tower != null:
		if bonus_stop:
			_title.text = "BONUS TOWER"
		else:
			_title.text = "TOWER %d" % _tower.tower_index
	call_deferred("_place_selection_glow")


func _apply_empty_card(button: Button, wrapper: Node) -> void:
	button.disabled = true
	button.icon = null
	button.text = "Empty"
	button.tooltip_text = "Empty"
	button.modulate = EMPTY_MODULATE
	_apply_icon(button, UpgradeCatalog.EMPTY_OFFER)
	var slot := _card_buttons.find(button)
	_apply_selection_frame(slot, false, true, BORDER_BASE)
	var rarity_label := wrapper.get_node_or_null("RarityLabel") as Label
	if rarity_label != null:
		rarity_label.text = ""
	var label := wrapper.get_node_or_null("NameLabel") as Label
	if label != null:
		label.text = ""
	_apply_bonus_label(wrapper, UpgradeCatalog.EMPTY_OFFER)


func _icon_frame_for(id: StringName) -> Texture2D:
	match UpgradeCatalog.rarity_of(id):
		UpgradeCatalog.RARITY_UNCOMMON:
			return ICON_FRAME_UNCOMMON
		UpgradeCatalog.RARITY_RARE:
			return ICON_FRAME_RARE
		UpgradeCatalog.RARITY_EPIC:
			return ICON_FRAME_EPIC
		UpgradeCatalog.RARITY_LEGENDARY:
			return ICON_FRAME_LEGENDARY
		_:
			return ICON_FRAME_COMMON


func _ensure_icon_host(button: Button) -> Control:
	var host := button.get_node_or_null("IconHost") as Control
	if host != null:
		return host
	host = Control.new()
	host.name = "IconHost"
	host.set_script(IconHostScript)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.grow_horizontal = Control.GROW_DIRECTION_BOTH
	host.grow_vertical = Control.GROW_DIRECTION_BOTH
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.clip_contents = true
	host.add_child(icon)
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	host.add_child(frame)
	button.add_child(host)
	return host


func _apply_icon(button: Button, id: StringName) -> void:
	var host := _ensure_icon_host(button)
	var icon := host.get_node("Icon") as TextureRect
	var frame := host.get_node("Frame") as TextureRect
	if UpgradeCatalog.is_empty_offer(id):
		icon.texture = null
		frame.texture = null
		host.visible = false
		return
	icon.texture = UpgradeCatalog.icon_for(id)
	frame.texture = _icon_frame_for(id)
	host.visible = true


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


func _apply_selection_frame(slot: int, _selected: bool, empty: bool, border: Texture2D) -> void:
	if slot < 0 or slot >= _card_frames.size():
		return
	var frame := _card_frames[slot]
	if frame == null:
		return
	frame.add_theme_stylebox_override("panel", _style_for(border if border != null else BORDER_BASE))
	if empty:
		frame.self_modulate = EMPTY_FRAME
	else:
		frame.self_modulate = IDLE_FRAME


func _place_selection_glow() -> void:
	if _glow == null:
		return
	if _selected_slot < 0 or _selected_slot >= _card_frames.size():
		_glow.visible = false
		return
	var card := _card_frames[_selected_slot]
	if card == null or not card.visible:
		_glow.visible = false
		return
	var card_rect := card.get_global_rect()
	var to_local := _root.get_global_transform_with_canvas().affine_inverse()
	var origin := to_local * card_rect.position
	var card_size := to_local * card_rect.end - origin
	var inner_w := 1.0 - GLOW_INSET_L - GLOW_INSET_R
	var inner_h := 1.0 - GLOW_INSET_T - GLOW_INSET_B
	var glow_size := Vector2(card_size.x / inner_w, card_size.y / inner_h)
	_glow.position = origin - Vector2(glow_size.x * GLOW_INSET_L, glow_size.y * GLOW_INSET_T)
	_glow.size = glow_size
	_glow.visible = true


func _ornament_rect(node_name: String, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.z_index = 2
	rect.visible = false
	_root.add_child(rect)
	return rect


func _place_header_ornament() -> void:
	var host := _root.get_node_or_null("Center/FrameHost") as Control
	if host == null or _header == null or host.size.x < 2.0:
		return
	var origin := host.global_position - _root.global_position
	var stroke_l := _frame_display_x(FRAME_STROKE_L, host.size.x)
	var stroke_r := _frame_display_x(FRAME_STROKE_R, host.size.x)
	var scale := (stroke_r - stroke_l) / (HEADER_BAR_X1 - HEADER_BAR_X0)
	_header.size = HEADER_TEX * scale
	_header.position = origin + Vector2(
		stroke_l - HEADER_BAR_X0 * scale,
		FRAME_STROKE_Y - HEADER_BAR_Y * scale
	)
	_header.visible = true
	var slot := _root.get_node_or_null("Center/FrameHost/Panel/VBox/DiamondSlot") as Control
	var diamond_size := Vector2(104.0, 28.0)
	_diamond.size = diamond_size
	var diamond_y := origin.y + FRAME_STROKE_Y + 20.0
	if slot != null and slot.size.y > 1.0:
		diamond_y = slot.global_position.y - _root.global_position.y + (slot.size.y - diamond_size.y) * 0.5
	_diamond.position = Vector2(origin.x + (host.size.x - diamond_size.x) * 0.5, diamond_y)
	_diamond.visible = true


func _frame_display_x(source_x: float, host_width: float) -> float:
	var center_src := FRAME_SRC_W - FRAME_MARGIN_X * 2.0
	var center_dst := host_width - FRAME_MARGIN_X * 2.0
	if source_x <= FRAME_MARGIN_X:
		return source_x
	if source_x >= FRAME_SRC_W - FRAME_MARGIN_X:
		return host_width - (FRAME_SRC_W - source_x)
	return FRAME_MARGIN_X + (source_x - FRAME_MARGIN_X) * (center_dst / center_src)


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
	if _glow != null:
		_glow.visible = false
	if _header != null:
		_header.visible = false
	if _diamond != null:
		_diamond.visible = false
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
