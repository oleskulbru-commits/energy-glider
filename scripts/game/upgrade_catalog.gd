class_name UpgradeCatalog
extends RefCounted

## Data for tower upgrade cards. Add new ids here without rewriting visit flow.

const SLOTS_PER_TOWER := 5
const FAMILY_PROJECTILE := &"projectile"
const FAMILY_ATTACK_SPEED := &"attack_speed"
const FAMILY_DAMAGE := &"damage"
const FAMILY_PROJECTILE_SPEED := &"projectile_speed"
const FAMILY_GLIDER_SPEED := &"glider_speed"
const FAMILY_GLIDE := &"glide"
const FAMILY_STEERING := &"steering"
const FAMILY_HP_REGEN := &"hp_regen"
const FAMILY_HEALTH := &"health"
const FAMILY_LUCK := &"luck"
const FAMILY_MOMENTUM_RETENTION := &"momentum_retention"
const FAMILY_CRIT := &"crit"
const FAMILY_DURATION := &"duration"
const FAMILY_PUSHBACK := &"pushback"
const FAMILY_BOUNCE := &"bounce"
const FAMILY_RIFLE := &"rifle"
const FAMILY_LASER := &"laser"
const RARITY_COMMON := &"common"
const RARITY_UNCOMMON := &"uncommon"
const RARITY_RARE := &"rare"
const RARITY_EPIC := &"epic"
const RARITY_LEGENDARY := &"legendary"

const ID_EXTRA_PROJECTILE := &"projectile_common"
const EMPTY_OFFER := &""

const ICON_DIR := "res://assets/ui/upgrades/"
const ICON_EXTRA_PROJECTILE := preload("res://assets/ui/upgrades/plus_one_projectile.jpg")
const ICON_ATTACK_SPEED := preload("res://assets/ui/upgrades/attack_speed.jpg")

const COLOR_RARITY_COMMON := Color(0.78, 0.78, 0.80, 1.0)
const COLOR_RARITY_UNCOMMON := Color(0.32, 0.78, 0.42, 1.0)
const COLOR_RARITY_RARE := Color(0.38, 0.62, 0.98, 1.0)
const COLOR_RARITY_EPIC := Color(0.72, 0.42, 0.95, 1.0)
const COLOR_RARITY_LEGENDARY := Color(0.98, 0.78, 0.28, 1.0)

const RARITY_WEIGHT_COMMON := 50
const RARITY_WEIGHT_UNCOMMON := 20
const RARITY_WEIGHT_RARE := 15
const RARITY_WEIGHT_EPIC := 10
const RARITY_WEIGHT_LEGENDARY := 5

const ATTACK_SPEED_COMMON := 0.04
const ATTACK_SPEED_UNCOMMON := 0.06
const ATTACK_SPEED_RARE := 0.09
const ATTACK_SPEED_EPIC := 0.12
const ATTACK_SPEED_LEGENDARY := 0.15

const PROJECTILE_COMMON := 1
const PROJECTILE_UNCOMMON := 2
const PROJECTILE_RARE := 3
const PROJECTILE_EPIC := 4
const PROJECTILE_LEGENDARY := 5

const DAMAGE_COMMON := 0.04
const DAMAGE_UNCOMMON := 0.06
const DAMAGE_RARE := 0.09
const DAMAGE_EPIC := 0.12
const DAMAGE_LEGENDARY := 0.15

const PROJECTILE_SPEED_COMMON := 0.04
const PROJECTILE_SPEED_UNCOMMON := 0.06
const PROJECTILE_SPEED_RARE := 0.09
const PROJECTILE_SPEED_EPIC := 0.12
const PROJECTILE_SPEED_LEGENDARY := 0.15

const GLIDER_SPEED_COMMON := 0.08
const GLIDER_SPEED_UNCOMMON := 0.10
const GLIDER_SPEED_RARE := 0.12
const GLIDER_SPEED_EPIC := 0.16
const GLIDER_SPEED_LEGENDARY := 0.22

const GLIDE_COMMON := 0.08
const GLIDE_UNCOMMON := 0.11
const GLIDE_RARE := 0.15
const GLIDE_EPIC := 0.20
const GLIDE_LEGENDARY := 0.25
const GLIDE_CAP := 0.50

const STEERING_COMMON := 0.06
const STEERING_UNCOMMON := 0.08
const STEERING_RARE := 0.12
const STEERING_EPIC := 0.16
const STEERING_LEGENDARY := 0.20
const STEERING_CAP := 0.40

const HP_REGEN_PERIOD_SEC := 3.0
const HP_REGEN_COMMON := 0.5
const HP_REGEN_UNCOMMON := 1.0
const HP_REGEN_RARE := 1.5
const HP_REGEN_EPIC := 2.0
const HP_REGEN_LEGENDARY := 3.0

const HEALTH_COMMON := 10
const HEALTH_UNCOMMON := 15
const HEALTH_RARE := 25
const HEALTH_EPIC := 35
const HEALTH_LEGENDARY := 45

const LUCK_COMMON := 1
const LUCK_UNCOMMON := 2
const LUCK_RARE := 3
const LUCK_EPIC := 4
const LUCK_LEGENDARY := 5

const MOMENTUM_RETENTION_COMMON := 0.08
const MOMENTUM_RETENTION_UNCOMMON := 0.11
const MOMENTUM_RETENTION_RARE := 0.15
const MOMENTUM_RETENTION_EPIC := 0.20
const MOMENTUM_RETENTION_LEGENDARY := 0.25
const MOMENTUM_RETENTION_CAP := 1.0

const CRIT_COMMON := 0.04
const CRIT_UNCOMMON := 0.06
const CRIT_RARE := 0.10
const CRIT_EPIC := 0.13
const CRIT_LEGENDARY := 0.17
const CRIT_CAP := 1.0

const DURATION_COMMON := 0.10
const DURATION_UNCOMMON := 0.15
const DURATION_RARE := 0.25
const DURATION_EPIC := 0.35
const DURATION_LEGENDARY := 0.50

const PUSHBACK_COMMON := 0.10
const PUSHBACK_UNCOMMON := 0.15
const PUSHBACK_RARE := 0.25
const PUSHBACK_EPIC := 0.35
const PUSHBACK_LEGENDARY := 0.50

const BOUNCE_COMMON := 1
const BOUNCE_UNCOMMON := 2
const BOUNCE_RARE := 3
const BOUNCE_EPIC := 4
const BOUNCE_LEGENDARY := 5

const SHOP_SEED_WORLD := 1009
const SHOP_SEED_TOWER := 9176
const SHOP_SEED_LIFE := 4283
const SHOP_SEED_SLOT := 7919
const WEAPON_OFFER_SEP := "|"
const ID_UNLOCK_RIFLE := &"unlock_rifle"
const ID_UNLOCK_LASER := &"unlock_laser"
const UNLOCK_PITY := 0.05


static func make_id(family: StringName, rarity: StringName) -> StringName:
	return StringName("%s_%s" % [String(family), String(rarity)])


static func weapon_base_id(id: StringName) -> StringName:
	var text := String(id)
	var pipe := text.find(WEAPON_OFFER_SEP)
	if pipe < 0:
		return id
	return StringName(text.substr(0, pipe))


static func is_weapon_family(family: StringName) -> bool:
	return family == FAMILY_RIFLE or family == FAMILY_LASER


static func is_weapon_unlock(id: StringName) -> bool:
	return id == ID_UNLOCK_RIFLE or id == ID_UNLOCK_LASER


static func unlock_id_for(family: StringName) -> StringName:
	if family == FAMILY_RIFLE:
		return ID_UNLOCK_RIFLE
	if family == FAMILY_LASER:
		return ID_UNLOCK_LASER
	return &""


static func unlock_weapon_family(id: StringName) -> StringName:
	if id == ID_UNLOCK_RIFLE:
		return FAMILY_RIFLE
	if id == ID_UNLOCK_LASER:
		return FAMILY_LASER
	return &""


static func missing_unlock_id(has_rifle: bool, has_laser: bool) -> StringName:
	if has_rifle and not has_laser:
		return ID_UNLOCK_LASER
	if has_laser and not has_rifle:
		return ID_UNLOCK_RIFLE
	return &""


static func is_weapon_offer(id: StringName) -> bool:
	return weapon_parts(id).size() >= 2


static func eligible_families(weapon_family: StringName) -> Array[StringName]:
	if weapon_family == FAMILY_LASER:
		return [
			FAMILY_PROJECTILE,
			FAMILY_ATTACK_SPEED,
			FAMILY_DAMAGE,
			FAMILY_CRIT,
			FAMILY_DURATION,
			FAMILY_BOUNCE
		]
	return [
		FAMILY_PROJECTILE,
		FAMILY_ATTACK_SPEED,
		FAMILY_DAMAGE,
		FAMILY_PROJECTILE_SPEED,
		FAMILY_CRIT,
		FAMILY_PUSHBACK,
		FAMILY_BOUNCE
	]


static func encode_weapon_offer(base_id: StringName, part_a: StringName, part_b: StringName) -> String:
	return "%s%s%s%s%s" % [String(base_id), WEAPON_OFFER_SEP, String(part_a), WEAPON_OFFER_SEP, String(part_b)]


static func weapon_parts(id: StringName) -> PackedStringArray:
	var text := String(id)
	var bits := text.split(WEAPON_OFFER_SEP, false)
	if bits.size() < 3:
		return PackedStringArray()
	return PackedStringArray([bits[1], bits[2]])


static func weapon_bonus_lines(id: StringName) -> PackedStringArray:
	var lines := PackedStringArray()
	for part in weapon_parts(id):
		lines.append(display_name(StringName(part)))
	return lines


static func roll_weapon_parts(
	weapon_family: StringName, rarity: StringName, rng: RandomNumberGenerator
) -> PackedStringArray:
	var families := eligible_families(weapon_family)
	if families.size() < 2:
		return PackedStringArray()
	var first := rng.randi_range(0, families.size() - 1)
	var second := rng.randi_range(0, families.size() - 2)
	if second >= first:
		second += 1
	return PackedStringArray([
		String(make_id(families[first], rarity)),
		String(make_id(families[second], rarity))
	])


static func roll_weapon_offer(
	rng: RandomNumberGenerator,
	used: Dictionary,
	luck: int = 0,
	has_rifle: bool = true,
	has_laser: bool = true
) -> String:
	var pool: Array[StringName] = []
	if has_rifle:
		pool.append(FAMILY_RIFLE)
	if has_laser:
		pool.append(FAMILY_LASER)
	if pool.is_empty():
		return ""
	for _try in 40:
		var family: StringName = pool[rng.randi_range(0, pool.size() - 1)]
		var rarity := _roll_rarity(rng, rarity_luck_for(family, luck))
		var base := String(make_id(family, rarity))
		if used.has(base):
			continue
		var parts := roll_weapon_parts(family, rarity, rng)
		if parts.size() < 2:
			continue
		return encode_weapon_offer(StringName(base), StringName(parts[0]), StringName(parts[1]))
	for family in pool:
		for rarity in [
			RARITY_COMMON,
			RARITY_UNCOMMON,
			RARITY_RARE,
			RARITY_EPIC,
			RARITY_LEGENDARY
		]:
			var base := String(make_id(family, rarity))
			if used.has(base):
				continue
			var parts := roll_weapon_parts(family, rarity, rng)
			if parts.size() < 2:
				continue
			return encode_weapon_offer(StringName(base), StringName(parts[0]), StringName(parts[1]))
	return ""


static func roll_weapon_refill(
	world_seed: int,
	tower_index: int,
	life_index: int,
	slot: int,
	used: Dictionary,
	luck: int = 0,
	has_rifle: bool = true,
	has_laser: bool = true
) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = (
		world_seed * SHOP_SEED_WORLD
		+ tower_index * SHOP_SEED_TOWER
		+ life_index * SHOP_SEED_LIFE
		+ slot * SHOP_SEED_SLOT
	)
	return roll_weapon_offer(rng, used, luck, has_rifle, has_laser)


static func family_of(id: StringName) -> StringName:
	var text := String(weapon_base_id(id))
	if text.begins_with("attack_speed_"):
		return FAMILY_ATTACK_SPEED
	if text.begins_with("crit_"):
		return FAMILY_CRIT
	if text.begins_with("duration_"):
		return FAMILY_DURATION
	if text.begins_with("pushback_"):
		return FAMILY_PUSHBACK
	if text.begins_with("bounce_"):
		return FAMILY_BOUNCE
	if text.begins_with("damage_"):
		return FAMILY_DAMAGE
	if text.begins_with("projectile_speed_"):
		return FAMILY_PROJECTILE_SPEED
	if text.begins_with("glider_speed_"):
		return FAMILY_GLIDER_SPEED
	if text.begins_with("glide_"):
		return FAMILY_GLIDE
	if text.begins_with("steering_"):
		return FAMILY_STEERING
	if text.begins_with("momentum_retention_"):
		return FAMILY_MOMENTUM_RETENTION
	if text.begins_with("hp_regen_"):
		return FAMILY_HP_REGEN
	if text.begins_with("health_"):
		return FAMILY_HEALTH
	if text.begins_with("luck_"):
		return FAMILY_LUCK
	if text.begins_with("rifle_"):
		return FAMILY_RIFLE
	if text.begins_with("laser_"):
		return FAMILY_LASER
	if text.begins_with("projectile_"):
		return FAMILY_PROJECTILE
	if id == &"extra_projectile":
		return FAMILY_PROJECTILE
	return &""


static func rarity_of(id: StringName) -> StringName:
	var base := weapon_base_id(id)
	var family := family_of(base)
	if family == &"":
		return RARITY_COMMON
	var prefix := "%s_" % String(family)
	var text := String(base)
	if not text.begins_with(prefix):
		return RARITY_COMMON
	return StringName(text.substr(prefix.length()))


static func projectile_bonus(rarity: StringName) -> int:
	match rarity:
		RARITY_UNCOMMON:
			return PROJECTILE_UNCOMMON
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
		RARITY_UNCOMMON:
			return ATTACK_SPEED_UNCOMMON
		RARITY_RARE:
			return ATTACK_SPEED_RARE
		RARITY_EPIC:
			return ATTACK_SPEED_EPIC
		RARITY_LEGENDARY:
			return ATTACK_SPEED_LEGENDARY
		_:
			return ATTACK_SPEED_COMMON


static func damage_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return DAMAGE_UNCOMMON
		RARITY_RARE:
			return DAMAGE_RARE
		RARITY_EPIC:
			return DAMAGE_EPIC
		RARITY_LEGENDARY:
			return DAMAGE_LEGENDARY
		_:
			return DAMAGE_COMMON


static func projectile_speed_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return PROJECTILE_SPEED_UNCOMMON
		RARITY_RARE:
			return PROJECTILE_SPEED_RARE
		RARITY_EPIC:
			return PROJECTILE_SPEED_EPIC
		RARITY_LEGENDARY:
			return PROJECTILE_SPEED_LEGENDARY
		_:
			return PROJECTILE_SPEED_COMMON


static func glider_speed_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return GLIDER_SPEED_UNCOMMON
		RARITY_RARE:
			return GLIDER_SPEED_RARE
		RARITY_EPIC:
			return GLIDER_SPEED_EPIC
		RARITY_LEGENDARY:
			return GLIDER_SPEED_LEGENDARY
		_:
			return GLIDER_SPEED_COMMON


static func glide_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return GLIDE_UNCOMMON
		RARITY_RARE:
			return GLIDE_RARE
		RARITY_EPIC:
			return GLIDE_EPIC
		RARITY_LEGENDARY:
			return GLIDE_LEGENDARY
		_:
			return GLIDE_COMMON


static func steering_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return STEERING_UNCOMMON
		RARITY_RARE:
			return STEERING_RARE
		RARITY_EPIC:
			return STEERING_EPIC
		RARITY_LEGENDARY:
			return STEERING_LEGENDARY
		_:
			return STEERING_COMMON


static func hp_regen_per_period(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return HP_REGEN_UNCOMMON
		RARITY_RARE:
			return HP_REGEN_RARE
		RARITY_EPIC:
			return HP_REGEN_EPIC
		RARITY_LEGENDARY:
			return HP_REGEN_LEGENDARY
		_:
			return HP_REGEN_COMMON


static func hp_regen_per_sec(rarity: StringName) -> float:
	return hp_regen_per_period(rarity) / HP_REGEN_PERIOD_SEC


static func hp_regen_period_text(amount_per_period: float) -> String:
	var amount := snappedf(amount_per_period, 0.1)
	var period := int(round(HP_REGEN_PERIOD_SEC))
	if is_equal_approx(amount, roundf(amount)):
		return "%d/%ds" % [int(roundf(amount)), period]
	return "%.1f/%ds" % [amount, period]


static func health_bonus(rarity: StringName) -> int:
	match rarity:
		RARITY_UNCOMMON:
			return HEALTH_UNCOMMON
		RARITY_RARE:
			return HEALTH_RARE
		RARITY_EPIC:
			return HEALTH_EPIC
		RARITY_LEGENDARY:
			return HEALTH_LEGENDARY
		_:
			return HEALTH_COMMON


static func luck_points(rarity: StringName) -> int:
	match rarity:
		RARITY_UNCOMMON:
			return LUCK_UNCOMMON
		RARITY_RARE:
			return LUCK_RARE
		RARITY_EPIC:
			return LUCK_EPIC
		RARITY_LEGENDARY:
			return LUCK_LEGENDARY
		_:
			return LUCK_COMMON


static func momentum_retention_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return MOMENTUM_RETENTION_UNCOMMON
		RARITY_RARE:
			return MOMENTUM_RETENTION_RARE
		RARITY_EPIC:
			return MOMENTUM_RETENTION_EPIC
		RARITY_LEGENDARY:
			return MOMENTUM_RETENTION_LEGENDARY
		_:
			return MOMENTUM_RETENTION_COMMON


static func crit_chance(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return CRIT_UNCOMMON
		RARITY_RARE:
			return CRIT_RARE
		RARITY_EPIC:
			return CRIT_EPIC
		RARITY_LEGENDARY:
			return CRIT_LEGENDARY
		_:
			return CRIT_COMMON


static func duration_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return DURATION_UNCOMMON
		RARITY_RARE:
			return DURATION_RARE
		RARITY_EPIC:
			return DURATION_EPIC
		RARITY_LEGENDARY:
			return DURATION_LEGENDARY
		_:
			return DURATION_COMMON


static func pushback_percent(rarity: StringName) -> float:
	match rarity:
		RARITY_UNCOMMON:
			return PUSHBACK_UNCOMMON
		RARITY_RARE:
			return PUSHBACK_RARE
		RARITY_EPIC:
			return PUSHBACK_EPIC
		RARITY_LEGENDARY:
			return PUSHBACK_LEGENDARY
		_:
			return PUSHBACK_COMMON


static func bounce_count(rarity: StringName) -> int:
	match rarity:
		RARITY_UNCOMMON:
			return BOUNCE_UNCOMMON
		RARITY_RARE:
			return BOUNCE_RARE
		RARITY_EPIC:
			return BOUNCE_EPIC
		RARITY_LEGENDARY:
			return BOUNCE_LEGENDARY
		_:
			return BOUNCE_COMMON


## Luck cards always use the base rarity table.
static func rarity_luck_for(family: StringName, luck: int) -> int:
	if family == FAMILY_LUCK:
		return 0
	return maxi(luck, 0)


## Common / Uncommon / Rare / Epic / Legendary weights after `luck` points.
static func rarity_weights_for_luck(luck: int) -> PackedInt32Array:
	var weights := PackedInt32Array([
		RARITY_WEIGHT_COMMON,
		RARITY_WEIGHT_UNCOMMON,
		RARITY_WEIGHT_RARE,
		RARITY_WEIGHT_EPIC,
		RARITY_WEIGHT_LEGENDARY
	])
	for _i in maxi(luck, 0):
		weights = _apply_luck_point(weights)
	return weights


static func is_empty_offer(id: StringName) -> bool:
	return String(id).is_empty()


static func display_name(id: StringName) -> String:
	if is_empty_offer(id):
		return "Empty"
	if is_weapon_unlock(id):
		if id == ID_UNLOCK_RIFLE:
			return "Rifle"
		return "Laser"
	var family := family_of(id)
	if family == FAMILY_PROJECTILE:
		var bonus := projectile_bonus(rarity_of(id))
		if bonus == 1:
			return "+1 projectile"
		return "+%d projectiles" % bonus
	if family == FAMILY_ATTACK_SPEED:
		var pct := int(round(attack_speed_percent(rarity_of(id)) * 100.0))
		return "Attack Speed −%d%%" % pct
	if family == FAMILY_DAMAGE:
		var pct := int(round(damage_percent(rarity_of(id)) * 100.0))
		return "Damage +%d%%" % pct
	if family == FAMILY_PROJECTILE_SPEED:
		var pct := int(round(projectile_speed_percent(rarity_of(id)) * 100.0))
		return "Projectile Speed +%d%%" % pct
	if family == FAMILY_GLIDER_SPEED:
		var pct := int(round(glider_speed_percent(rarity_of(id)) * 100.0))
		return "Glider Speed +%d%%" % pct
	if family == FAMILY_GLIDE:
		var pct := int(round(glide_percent(rarity_of(id)) * 100.0))
		return "Glide +%d%%" % pct
	if family == FAMILY_STEERING:
		var pct := int(round(steering_percent(rarity_of(id)) * 100.0))
		return "Steering +%d%%" % pct
	if family == FAMILY_HP_REGEN:
		return "HP Regen +%s" % hp_regen_period_text(hp_regen_per_period(rarity_of(id)))
	if family == FAMILY_HEALTH:
		return "Health +%d" % health_bonus(rarity_of(id))
	if family == FAMILY_LUCK:
		return "Luck +%d" % luck_points(rarity_of(id))
	if family == FAMILY_MOMENTUM_RETENTION:
		var pct := int(round(momentum_retention_percent(rarity_of(id)) * 100.0))
		return "Momentum Retention +%d%%" % pct
	if family == FAMILY_CRIT:
		var pct := int(round(crit_chance(rarity_of(id)) * 100.0))
		return "Crit +%d%%" % pct
	if family == FAMILY_DURATION:
		var pct := int(round(duration_percent(rarity_of(id)) * 100.0))
		return "Duration +%d%%" % pct
	if family == FAMILY_PUSHBACK:
		var pct := int(round(pushback_percent(rarity_of(id)) * 100.0))
		return "Pushback +%d%%" % pct
	if family == FAMILY_BOUNCE:
		return "Bounce +%d" % bounce_count(rarity_of(id))
	if family == FAMILY_RIFLE:
		return "Rifle"
	if family == FAMILY_LASER:
		return "Laser"
	return String(weapon_base_id(id))


static func rarity_display_name(id: StringName) -> String:
	if is_empty_offer(id) or is_weapon_unlock(id):
		return ""
	return String(rarity_of(id)).to_upper()


static func rarity_color(id: StringName) -> Color:
	match rarity_of(id):
		RARITY_UNCOMMON:
			return COLOR_RARITY_UNCOMMON
		RARITY_RARE:
			return COLOR_RARITY_RARE
		RARITY_EPIC:
			return COLOR_RARITY_EPIC
		RARITY_LEGENDARY:
			return COLOR_RARITY_LEGENDARY
		_:
			return COLOR_RARITY_COMMON


static func icon_path_for(id: StringName) -> String:
	if is_weapon_unlock(id):
		return "%s%s.jpg" % [ICON_DIR, String(make_id(unlock_weapon_family(id), RARITY_COMMON))]
	var stem := String(weapon_base_id(id))
	var jpg := "%s%s.jpg" % [ICON_DIR, stem]
	if ResourceLoader.exists(jpg):
		return jpg
	var png := "%s%s.png" % [ICON_DIR, stem]
	if ResourceLoader.exists(png):
		return png
	return jpg


static func icon_for(id: StringName) -> Texture2D:
	if is_empty_offer(id):
		return null
	var path := icon_path_for(id)
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return _family_fallback_icon(family_of(id))


static func rarity_for_weapon_level(level: int) -> StringName:
	var rungs: Array[StringName] = [
		RARITY_COMMON,
		RARITY_UNCOMMON,
		RARITY_RARE,
		RARITY_EPIC,
		RARITY_LEGENDARY
	]
	var index := clampi(level, 1, rungs.size()) - 1
	return rungs[index]


static func icon_for_weapon_level(family: StringName, level: int) -> Texture2D:
	return icon_for(make_id(family, rarity_for_weapon_level(level)))


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


static func eligible_shop_families(has_rifle: bool, has_laser: bool) -> Array[StringName]:
	var families: Array[StringName] = [
		FAMILY_PROJECTILE,
		FAMILY_ATTACK_SPEED,
		FAMILY_DAMAGE,
		FAMILY_GLIDER_SPEED,
		FAMILY_GLIDE,
		FAMILY_STEERING,
		FAMILY_HP_REGEN,
		FAMILY_HEALTH,
		FAMILY_LUCK,
		FAMILY_MOMENTUM_RETENTION,
		FAMILY_CRIT
	]
	if has_rifle:
		families.append(FAMILY_PROJECTILE_SPEED)
		families.append(FAMILY_PUSHBACK)
		families.append(FAMILY_RIFLE)
	if has_laser:
		families.append(FAMILY_DURATION)
		families.append(FAMILY_LASER)
	if has_rifle or has_laser:
		families.append(FAMILY_BOUNCE)
	return families


static func unlock_chance(tower_index: int, family_count: int) -> float:
	if family_count <= 0:
		return 0.0
	return minf(1.0, 1.0 / float(family_count) + UNLOCK_PITY * float(maxi(tower_index - 1, 0)))


static func roll_shop(
	world_seed: int,
	tower_index: int,
	luck: int = 0,
	has_rifle: bool = false,
	has_laser: bool = false
) -> PackedStringArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * SHOP_SEED_WORLD + tower_index * SHOP_SEED_TOWER
	var families := eligible_shop_families(has_rifle, has_laser)
	var slots := PackedStringArray()
	var used: Dictionary = {}
	for _i in SLOTS_PER_TOWER:
		var id := _roll_unique_id(rng, used, luck, families)
		used[String(weapon_base_id(StringName(id)))] = true
		slots.append(id)
	var unlock := missing_unlock_id(has_rifle, has_laser)
	if unlock != &"" and rng.randf() < unlock_chance(tower_index, families.size()):
		var slot := rng.randi_range(0, SLOTS_PER_TOWER - 1)
		slots[slot] = String(unlock)
	return slots


static func _roll_unique_id(
	rng: RandomNumberGenerator,
	used: Dictionary,
	luck: int,
	families: Array[StringName]
) -> String:
	if families.is_empty():
		return String(ID_EXTRA_PROJECTILE)
	for _try in 80:
		var family: StringName = families[rng.randi_range(0, families.size() - 1)]
		var rarity := _roll_rarity(rng, rarity_luck_for(family, luck))
		var base := String(make_id(family, rarity))
		if used.has(base):
			continue
		if is_weapon_family(family):
			var parts := roll_weapon_parts(family, rarity, rng)
			if parts.size() < 2:
				continue
			return encode_weapon_offer(StringName(base), StringName(parts[0]), StringName(parts[1]))
		return base
	for family in families:
		for rarity in [
			RARITY_COMMON,
			RARITY_UNCOMMON,
			RARITY_RARE,
			RARITY_EPIC,
			RARITY_LEGENDARY
		]:
			var id := String(make_id(family, rarity))
			if used.has(id):
				continue
			if is_weapon_family(family):
				var parts := roll_weapon_parts(family, rarity, rng)
				if parts.size() < 2:
					continue
				return encode_weapon_offer(StringName(id), StringName(parts[0]), StringName(parts[1]))
			return id
	return String(ID_EXTRA_PROJECTILE)


static func _roll_rarity(rng: RandomNumberGenerator, luck: int = 0) -> StringName:
	var weights := rarity_weights_for_luck(luck)
	var total := 0
	for weight in weights:
		total += int(weight)
	if total <= 0:
		return RARITY_LEGENDARY
	var roll := rng.randi_range(1, total)
	var rarities: Array[StringName] = [
		RARITY_COMMON,
		RARITY_UNCOMMON,
		RARITY_RARE,
		RARITY_EPIC,
		RARITY_LEGENDARY
	]
	var cap := 0
	for i in rarities.size():
		cap += int(weights[i])
		if roll <= cap:
			return rarities[i]
	return RARITY_LEGENDARY


static func _apply_luck_point(weights: PackedInt32Array) -> PackedInt32Array:
	var dests := PackedInt32Array([1, 2, 3, 4])
	var leftover := dests.size()
	for dest in dests:
		if weights[0] <= 0:
			break
		weights[0] -= 1
		weights[dest] += 1
		leftover -= 1
	if leftover <= 0:
		return weights
	for src in range(1, 4):
		if weights[src] > 0:
			weights[src] -= 1
			weights[src + 1] += 1
			break
	return weights


static func _roll_family(rng: RandomNumberGenerator) -> StringName:
	var families := eligible_shop_families(true, true)
	return families[rng.randi_range(0, families.size() - 1)]
