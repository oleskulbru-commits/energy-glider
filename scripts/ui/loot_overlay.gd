class_name LootOverlay
extends CanvasLayer

signal opened
signal closed

@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _item_list: VBoxContainer = %ItemList
@onready var _take_all_button: Button = %TakeAllButton
@onready var _close_button: Button = %CloseButton
@onready var _status_label: Label = %StatusLabel

var _container: LootContainer
var _cargo: PlayerCargo
var _open := false


func _ready() -> void:
	layer = 20
	visible = false
	_take_all_button.pressed.connect(_on_take_all_pressed)
	_close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _open


func open(container: LootContainer, cargo: PlayerCargo) -> void:
	if container == null or cargo == null:
		return
	_container = container
	_cargo = cargo
	_open = true
	visible = true
	_status_label.text = ""
	_refresh_list()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_container = null
	_clear_item_rows()
	closed.emit()


func _refresh_list() -> void:
	_clear_item_rows()
	if _container == null:
		return

	_title_label.text = _container.get_display_name()
	var contents := _container.get_contents()
	for i in contents.size():
		var item: LootItem = contents[i]
		if item == null:
			continue
		_add_item_row(i, item)

	_take_all_button.disabled = contents.is_empty()
	if contents.is_empty():
		close()


func _add_item_row(index: int, item: LootItem) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1))
	row.add_child(name_label)

	var take_button := Button.new()
	take_button.text = "TAKE"
	take_button.pressed.connect(_on_take_item_pressed.bind(index))
	row.add_child(take_button)

	_item_list.add_child(row)


func _clear_item_rows() -> void:
	for child in _item_list.get_children():
		child.queue_free()


func _on_take_item_pressed(index: int) -> void:
	if _container == null or _cargo == null:
		return
	if _container.take_at(index, _cargo):
		_status_label.text = ""
		_refresh_list()
	else:
		_status_label.text = "Inventory full"


func _on_take_all_pressed() -> void:
	if _container == null or _cargo == null:
		return
	var before := _cargo.get_used_slots()
	var taken := _container.take_all(_cargo)
	if taken <= 0 and not _cargo.is_full():
		_status_label.text = "Nothing to take"
	elif taken <= 0:
		_status_label.text = "Inventory full"
	else:
		_status_label.text = "Took %d item(s)" % taken
		if _cargo.get_used_slots() == before and taken == 0:
			_status_label.text = "Inventory full"
	_refresh_list()
