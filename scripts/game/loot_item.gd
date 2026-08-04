class_name LootItem
extends RefCounted

var item_id: String = ""
var cargo_type: CargoTypes.Type = CargoTypes.Type.NONE
var display_name: String = ""


func _init(
	id: String = "",
	type: CargoTypes.Type = CargoTypes.Type.NONE,
	name: String = ""
) -> void:
	item_id = id
	cargo_type = type
	display_name = name if not name.is_empty() else CargoTypes.label_for(type)


static func antenna_part(id: String = "") -> LootItem:
	return LootItem.new(
		id if not id.is_empty() else _unique_id("antenna"),
		CargoTypes.Type.ANTENNA_PART
	)


static func scrap(id: String = "") -> LootItem:
	return LootItem.new(
		id if not id.is_empty() else _unique_id("scrap"),
		CargoTypes.Type.SCRAP
	)


static func _unique_id(prefix: String) -> String:
	return "%s_%d" % [prefix, randi()]
