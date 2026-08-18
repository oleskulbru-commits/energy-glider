class_name UpgradeCatalog
extends RefCounted

## Data for tower upgrade cards. Add new ids here without rewriting visit flow.

const ID_EXTRA_PROJECTILE := &"extra_projectile"
const SLOTS_PER_TOWER := 5
const ICON_EXTRA_PROJECTILE := preload("res://assets/ui/upgrades/plus_one_projectile.jpg")


static func display_name(id: StringName) -> String:
	if id == ID_EXTRA_PROJECTILE:
		return "+1 projectile"
	return String(id)


static func icon_for(id: StringName) -> Texture2D:
	if id == ID_EXTRA_PROJECTILE:
		return ICON_EXTRA_PROJECTILE
	return null


static func default_offers() -> PackedStringArray:
	var slots := PackedStringArray()
	for _i in SLOTS_PER_TOWER:
		slots.append(String(ID_EXTRA_PROJECTILE))
	return slots
