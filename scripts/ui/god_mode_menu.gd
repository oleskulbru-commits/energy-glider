class_name GodModeMenu
extends Control

signal back_requested
signal started

const MAX_WEAPONS := UpgradeCatalog.MAX_OWNED_WEAPONS

@onready var _weapon_rows: VBoxContainer = %WeaponRows
@onready var _upgrade_rows: VBoxContainer = %UpgradeRows
@onready var _start_button: Button = %StartButton

var _state: RunUpgradeState
var _weapon_checks: Dictionary = {}
var _upgrade_rows_by_family: Dictionary = {}


func _ready() -> void:
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_STOP
	%BackButton.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	call_deferred("_ensure_rows_built")


func _ensure_rows_built() -> void:
	if _weapon_checks.is_empty():
		_build_weapon_rows()
	if _upgrade_rows_by_family.is_empty():
		_build_upgrade_rows()


func bind_state(state: RunUpgradeState) -> void:
	_state = state


func open() -> void:
	_ensure_rows_built()
	_reset_defaults()
	visible = true
	_refresh_weapon_limits()
	_refresh_start_button()


func close() -> void:
	visible = false


func _reset_defaults() -> void:
	for family in _weapon_checks.keys():
		var check: Button = _weapon_checks[family]
		check.button_pressed = false
		check.disabled = false
		_update_toggle_visual(check, false)
	for family in _upgrade_rows_by_family.keys():
		var row: Dictionary = _upgrade_rows_by_family[family]
		var check: Button = row.get("check")
		var spin: SpinBox = row.get("spin")
		if check != null:
			check.button_pressed = false
			_update_toggle_visual(check, false)
		if spin != null:
			spin.value = 0
			spin.editable = false


func _build_weapon_rows() -> void:
	if _weapon_rows == null:
		return
	for family in UpgradeCatalog.god_mode_weapon_families():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 32
		var check := _make_toggle_button()
		check.toggled.connect(_on_weapon_toggled.bind(family))
		check.toggled.connect(_update_toggle_visual.bind(check))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = UpgradeCatalog.icon_for(UpgradeCatalog.unlock_id_for(family))
		var label := Label.new()
		label.text = UpgradeCatalog.display_name(UpgradeCatalog.unlock_id_for(family))
		label.theme_type_variation = &"HudLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(check)
		row.add_child(icon)
		row.add_child(label)
		_weapon_rows.add_child(row)
		_weapon_checks[family] = check


func _make_toggle_button() -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(28, 28)
	btn.text = ""
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	normal.border_color = Color(0.85, 0.72, 0.55, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(1.0, 0.95, 0.75, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.38, 0.45, 0.95)
	pressed.border_color = Color(0.55, 0.92, 0.98, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", normal.duplicate())
	btn.add_theme_color_override("font_color", Color(0.55, 0.92, 0.98))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 18)
	return btn


func _update_toggle_visual(btn: Button, pressed: bool) -> void:
	btn.text = "✓" if pressed else ""


func _build_upgrade_rows() -> void:
	if _upgrade_rows == null:
		return
	for def in UpgradeCatalog.god_mode_stat_defs():
		var family: StringName = def.get("family")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 32
		var check := _make_toggle_button()
		check.toggled.connect(_on_upgrade_toggled.bind(family))
		check.toggled.connect(_update_toggle_visual.bind(check))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = def.get("icon") as Texture2D
		var label := Label.new()
		label.text = String(def.get("label", ""))
		label.theme_type_variation = &"HudLabel"
		label.custom_minimum_size.x = 160
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.editable = false
		spin.custom_minimum_size.x = 88
		if def.get("kind") == UpgradeCatalog.GOD_MODE_KIND_PERCENT:
			spin.suffix = "%"
			var cap_percent := int(def.get("cap_percent", -1))
			spin.max_value = cap_percent if cap_percent >= 0 else UpgradeCatalog.GOD_MODE_PERCENT_MAX_UNCAPPED
		else:
			spin.max_value = 9999
		spin.value_changed.connect(_on_upgrade_value_changed.bind(family, def))
		var cap_label := Label.new()
		cap_label.theme_type_variation = &"HudMuted"
		var cap_percent := int(def.get("cap_percent", -1))
		if cap_percent >= 0:
			cap_label.text = "Cap at %d%%" % cap_percent
		else:
			cap_label.text = ""
		cap_label.custom_minimum_size.x = 88
		cap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(check)
		row.add_child(icon)
		row.add_child(label)
		row.add_child(spin)
		row.add_child(cap_label)
		_upgrade_rows.add_child(row)
		_upgrade_rows_by_family[family] = {
			"check": check,
			"spin": spin,
			"def": def,
		}


func _selected_weapon_count() -> int:
	var count := 0
	for family in _weapon_checks.keys():
		var check: Button = _weapon_checks[family]
		if check.button_pressed:
			count += 1
	return count


func _refresh_weapon_limits() -> void:
	var count := _selected_weapon_count()
	var at_cap := count >= MAX_WEAPONS
	for family in _weapon_checks.keys():
		var check: Button = _weapon_checks[family]
		if not check.button_pressed:
			check.disabled = at_cap


func _refresh_start_button() -> void:
	_start_button.disabled = _selected_weapon_count() <= 0


func _on_weapon_toggled(_pressed: bool, _family: StringName) -> void:
	_refresh_weapon_limits()
	_refresh_start_button()


func _on_upgrade_toggled(pressed: bool, family: StringName) -> void:
	var row: Dictionary = _upgrade_rows_by_family.get(family, {})
	var spin: SpinBox = row.get("spin")
	if spin != null:
		spin.editable = pressed


func _on_upgrade_value_changed(_value: float, family: StringName, def: Dictionary) -> void:
	var row: Dictionary = _upgrade_rows_by_family.get(family, {})
	var spin: SpinBox = row.get("spin")
	if spin == null:
		return
	var clamped := int(spin.value)
	if def.get("kind") == UpgradeCatalog.GOD_MODE_KIND_PERCENT:
		clamped = UpgradeCatalog.clamp_god_mode_percent(family, clamped)
	else:
		clamped = UpgradeCatalog.clamp_god_mode_int(family, clamped)
	if int(spin.value) != clamped:
		spin.value = clamped


func _collect_weapons() -> PackedStringArray:
	var weapons := PackedStringArray()
	for family in UpgradeCatalog.god_mode_weapon_families():
		var check: Button = _weapon_checks[family]
		if check.button_pressed:
			weapons.append(String(family))
	return weapons


func _collect_enabled_stats() -> Dictionary:
	var stats := {}
	for family in _upgrade_rows_by_family.keys():
		var row: Dictionary = _upgrade_rows_by_family[family]
		var check: Button = row.get("check")
		var spin: SpinBox = row.get("spin")
		var def: Dictionary = row.get("def", {})
		if check == null or spin == null or not check.button_pressed:
			continue
		var value := int(spin.value)
		if def.get("kind") == UpgradeCatalog.GOD_MODE_KIND_PERCENT:
			value = UpgradeCatalog.clamp_god_mode_percent(family, value)
		else:
			value = UpgradeCatalog.clamp_god_mode_int(family, value)
		stats[family] = value
	return stats


func _on_back_pressed() -> void:
	close()
	back_requested.emit()


func _on_start_pressed() -> void:
	if _selected_weapon_count() <= 0:
		return
	if _state != null:
		_state.apply_god_mode_loadout(_collect_weapons(), _collect_enabled_stats())
	close()
	started.emit()
