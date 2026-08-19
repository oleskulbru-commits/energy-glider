class_name UpgradeCatalog
extends RefCounted

## Data for tower upgrade cards. Add new ids here without rewriting visit flow.

const SLOTS_PER_TOWER := 5
const FAMILY_PROJECTILE := &"projectile"
const FAMILY_ATTACK_SPEED := &"attack_speed"
const RARITY_COMMON := &"common"
const RARITY_RARE := &"rare"
const RARITY_EPIC := &"epic"
const RARITY_LEGENDARY := &"legendary"

const ID_EXTRA_PROJECTILE := &"projectile_common"

const ICON_DIR := "res://assets/ui/upgrades/"
const ICON_EXTRA_PROJECTILE := preload("res://assets/ui/upgrades/plus_one_projectile.jpg")
const ICON_ATTACK_SPEED := preload("res://assets/ui/upgrades/attack_speed.jpg")

const COLOR_RARITY_COMMON := Color(0.78, 0.78, 0.80, 1.0)
const COLOR_RARITY_RARE := Color(0.38, 0.62, 0.98, 1.0)
const COLOR_RARITY_EPIC := Color(0.72, 0.42, 0.95, 1.0)
const COLOR_RARITY_LEGENDARY := Color(0.98, 0.78, 0.28, 1.0)

const RARITY_WEIGHT_COMMON := 50
const RARITY_WEIGHT_RARE := 25
const RARITY_WEIGHT_EPIC := 15
const RARITY_WEIGHT_LEGENDARY := 10

const ATTACK_SPEED_COMMON := 0.05
const ATTACK_SPEED_RARE := 0.08
const ATTACK_SPEED_EPIC := 0.11
const ATTACK_SPEED_LEGENDARY := 0.15

const PROJECTILE_COMMON := 1
const PROJECTILE_RARE := 2
const PROJECTILE_EPIC := 3
const PROJECTILE_LEGENDARY := 4

const SHOP_SEED_WORLD := 1009
const SHOP_SEED_TOWER := 9176


static func make_id(family: StringName, rarity: StringName) -> StringName:
	return StringName("%s_%s" % [String(family), String(rarity)])


static func family_of(id: StringName) -> StringName:
	var text := String(id)
	if text.begins_with("attack_speed_"):
		return FAMILY_ATTACK_SPEED
	if text.begins_with("projectile_"):
		return FAMILY_PROJECTILE
	if id == &"extra_projectile":
		return FAMILY_PROJECTILE
	return &""


static func rarity_of(id: StringName) -> StringName:
	var family := family_of(id)
	if family == &"":
		return RARITY_COMMON
	var prefix := "%s_" % String(family)
	var text := String(id)
	if not text.begins_with(prefix):
		return RARITY_COMMON
	return StringName(text.substr(prefix.length()))


static func projectile_bonus(rarity: StringName) -> int:
	match rarity:
		RARITY_RARE:
			return PROJECTILE_RARE
		RARITY_EPIC:
			return PROJECTILE_EPIC
		RARITY_LEGENDARY:
			return PROJECTILE_LEGENDARY
		_:
			return PROJECTILE_COMMON


static func attack_speed_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_RARE:
			return ATTACK_SPEED_RARE
		RARITY_EPIC:
			return ATTACK_SPEED_EPIC
		RARITY_LEGENDARY:
			return ATTACK_SPEED_LEGENDARY
		_:
			return ATTACK_SPEED_COMMON


static func display_name(id: StringName) -> String:
	var family := family_of(id)
	if family == FAMILY_PROJECTILE:
		var bonus := projectile_bonus(rarity_of(id))
		if bonus == 1:
			return "+1 projectile"
		return "+%d projectiles" % bonus
	if family == FAMILY_ATTACK_SPEED:
		var pct := int(round(attack_speed_percent(rarity_of(id)) * 100.0))
		return "Attack Speed −%d%%" % pct
	return String(id)


static func rarity_display_name(id: StringName) -> String:
	return String(rarity_of(id)).to_upper()


static func rarity_color(id: StringName) -> Color:
	match rarity_of(id):
		RARITY_RARE:
			return COLOR_RARITY_RARE
		RARITY_EPIC:
			return COLOR_RARITY_EPIC
		RARITY_LEGENDARY:
			return COLOR_RARITY_LEGENDARY
		_:
			return COLOR_RARITY_COMMON


static func icon_path_for(id: StringName) -> String:
	return "%s%s.jpg" % [ICON_DIR, String(id)]


static func icon_for(id: StringName) -> Texture2D:
	var path := icon_path_for(id)
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return _family_fallback_icon(family_of(id))


static func _family_fallback_icon(family: StringName) -> Texture2D:
	if family == FAMILY_ATTACK_SPEED:
		return ICON_ATTACK_SPEED
	if family == FAMILY_PROJECTILE:
		return ICON_EXTRA_PROJECTILE
	return null


static func default_offers() -> PackedStringArray:
	var slots := PackedStringArray()
	for _i in SLOTS_PER_TOWER:
		slots.append(String(ID_EXTRA_PROJECTILE))
	return slots


static func roll_shop(world_seed: int, tower_index: int) -> PackedStringArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * SHOP_SEED_WORLD + tower_index * SHOP_SEED_TOWER
	var slots := PackedStringArray()
	for _i in SLOTS_PER_TOWER:
		var rarity := _roll_rarity(rng)
		var family := _roll_family(rng)
		slots.append(String(make_id(family, rarity)))
	return slots


static func _roll_rarity(rng: RandomNumberGenerator) -> StringName:
	var roll := rng.randi_range(1, 100)
	if roll <= RARITY_WEIGHT_COMMON:
		return RARITY_COMMON
	if roll <= RARITY_WEIGHT_COMMON + RARITY_WEIGHT_RARE:
		return RARITY_RARE
	if roll <= RARITY_WEIGHT_COMMON + RARITY_WEIGHT_RARE + RARITY_WEIGHT_EPIC:
		return RARITY_EPIC
	return RARITY_LEGENDARY


static func _roll_family(rng: RandomNumberGenerator) -> StringName:
	if rng.randi_range(0, 1) == 0:
		return FAMILY_PROJECTILE
	return FAMILY_ATTACK_SPEED
