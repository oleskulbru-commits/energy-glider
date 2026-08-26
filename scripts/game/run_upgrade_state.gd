class_name RunUpgradeState
extends Node

## Stacks and weapons reset on Try Again. Taken weapon-bundle slots refill after
## grant_starter if that life owns a matching gun; normal Empty slots stay Empty.

signal extra_projectiles_changed(count: int)
signal weapons_changed

var extra_projectiles := 0
var attack_speed_reduction := 0.0
var damage_bonus := 0.0
var projectile_speed_bonus := 0.0
var glider_speed_bonus := 0.0
var glide_bonus := 0.0
var steering_bonus := 0.0
var health_regen_per_sec := 0.0
var max_health_bonus := 0
var luck_bonus := 0
var momentum_retention := 0.0
var crit_chance := 0.0
var duration_bonus := 0.0
var pushback_bonus := 0.0
var bounce_count := 0
var range_bonus := 0.0
var has_rifle := false
var has_laser := false
var has_tesla := false
var has_rocket := false
var has_shotgun := false
var unlock_pity_steps := 0
var _offers: Dictionary = {}
var _visited_this_life: Dictionary = {}
var _weapon_holes: Dictionary = {}
var _life_index := 0
var _owned_order: PackedStringArray = PackedStringArray()
var _rifle_level := 0
var _laser_level := 0
var _tesla_level := 0
var _rocket_level := 0
var _shotgun_level := 0
var _rifle_bundle := WeaponBundle.new()
var _laser_bundle := WeaponBundle.new()
var _tesla_bundle := WeaponBundle.new()
var _rocket_bundle := WeaponBundle.new()
var _shotgun_bundle := WeaponBundle.new()


class WeaponBundle:
	var extra_projectiles := 0
	var attack_speed := 0.0
	var damage := 0.0
	var projectile_speed := 0.0
	var crit := 0.0
	var duration := 0.0
	var pushback := 0.0
	var bounce := 0
	var range := 0.0

	func clear() -> void:
		extra_projectiles = 0
		attack_speed = 0.0
		damage = 0.0
		projectile_speed = 0.0
		crit = 0.0
		duration = 0.0
		pushback = 0.0
		bounce = 0
		range = 0.0


func _ready() -> void:
	add_to_group("run_upgrade_state")
	call_deferred("_connect_director")


func _connect_director() -> void:
	var director := get_tree().get_first_node_in_group("eon_director") as EonDirector
	if director == null:
		return
	if not director.player_died.is_connected(_on_player_died):
		director.player_died.connect(_on_player_died)
	if director.has_signal("attempt_started") and not director.attempt_started.is_connected(_on_attempt_started):
		director.attempt_started.connect(_on_attempt_started)


func _on_player_died(_position: Vector3) -> void:
	clear_visited_this_life()


func _on_attempt_started() -> void:
	reset_run()


func reset_run() -> void:
	extra_projectiles = 0
	attack_speed_reduction = 0.0
	damage_bonus = 0.0
	projectile_speed_bonus = 0.0
	glider_speed_bonus = 0.0
	glide_bonus = 0.0
	steering_bonus = 0.0
	health_regen_per_sec = 0.0
	max_health_bonus = 0
	luck_bonus = 0
	momentum_retention = 0.0
	crit_chance = 0.0
	duration_bonus = 0.0
	pushback_bonus = 0.0
	bounce_count = 0
	range_bonus = 0.0
	_rifle_bundle.clear()
	_laser_bundle.clear()
	_tesla_bundle.clear()
	_rocket_bundle.clear()
	_shotgun_bundle.clear()
	has_rifle = false
	has_laser = false
	has_tesla = false
	has_rocket = false
	has_shotgun = false
	unlock_pity_steps = 0
	_owned_order = PackedStringArray()
	_rifle_level = 0
	_laser_level = 0
	_tesla_level = 0
	_rocket_level = 0
	_shotgun_level = 0
	_life_index += 1
	clear_visited_this_life()
	extra_projectiles_changed.emit(extra_projectiles)
	weapons_changed.emit()


func grant_starter(family: StringName) -> void:
	has_rifle = false
	has_laser = false
	has_tesla = false
	has_rocket = false
	has_shotgun = false
	_owned_order = PackedStringArray()
	_rifle_level = 0
	_laser_level = 0
	_tesla_level = 0
	_rocket_level = 0
	_shotgun_level = 0
	grant_weapon(family)
	_refill_weapon_holes()


func grant_weapon(family: StringName) -> void:
	if family == UpgradeCatalog.FAMILY_RIFLE:
		if has_rifle:
			return
		has_rifle = true
		_owned_order.append("rifle")
		_rifle_level = 1
	elif family == UpgradeCatalog.FAMILY_LASER:
		if has_laser:
			return
		has_laser = true
		_owned_order.append("laser")
		_laser_level = 1
	elif family == UpgradeCatalog.FAMILY_TESLA:
		if has_tesla:
			return
		has_tesla = true
		_owned_order.append("tesla")
		_tesla_level = 1
	elif family == UpgradeCatalog.FAMILY_ROCKET:
		if has_rocket:
			return
		has_rocket = true
		_owned_order.append("rocket")
		_rocket_level = 1
	elif family == UpgradeCatalog.FAMILY_SHOTGUN:
		if has_shotgun:
			return
		has_shotgun = true
		_owned_order.append("shotgun")
		_shotgun_level = 1
	else:
		return
	unlock_pity_steps = 0
	weapons_changed.emit()


func owned_weapon_ids() -> PackedStringArray:
	return _owned_order


func weapon_level(family: StringName) -> int:
	if family == UpgradeCatalog.FAMILY_SHOTGUN:
		return _shotgun_level
	if family == UpgradeCatalog.FAMILY_ROCKET:
		return _rocket_level
	if family == UpgradeCatalog.FAMILY_TESLA:
		return _tesla_level
	if family == UpgradeCatalog.FAMILY_LASER:
		return _laser_level
	if family == UpgradeCatalog.FAMILY_RIFLE:
		return _rifle_level
	return 0


func owns_weapon(family: StringName) -> bool:
	if family == UpgradeCatalog.FAMILY_RIFLE:
		return has_rifle
	if family == UpgradeCatalog.FAMILY_LASER:
		return has_laser
	if family == UpgradeCatalog.FAMILY_TESLA:
		return has_tesla
	if family == UpgradeCatalog.FAMILY_ROCKET:
		return has_rocket
	if family == UpgradeCatalog.FAMILY_SHOTGUN:
		return has_shotgun
	return false


func extra_projectiles_for(weapon: StringName) -> int:
	return extra_projectiles + _bundle(weapon).extra_projectiles


func attack_speed_reduction_for(weapon: StringName) -> float:
	return attack_speed_reduction + _bundle(weapon).attack_speed


func damage_bonus_for(weapon: StringName) -> float:
	return damage_bonus + _bundle(weapon).damage


func projectile_speed_bonus_for(weapon: StringName) -> float:
	return projectile_speed_bonus + _bundle(weapon).projectile_speed


func crit_chance_for(weapon: StringName) -> float:
	return crit_chance + _bundle(weapon).crit


func duration_bonus_for(weapon: StringName) -> float:
	return duration_bonus + _bundle(weapon).duration


func pushback_bonus_for(weapon: StringName) -> float:
	return pushback_bonus + _bundle(weapon).pushback


func bounce_count_for(weapon: StringName) -> int:
	return bounce_count + _bundle(weapon).bounce


func range_bonus_for(weapon: StringName) -> float:
	return range_bonus + _bundle(weapon).range


func ensure_tower(tower_index: int) -> void:
	if tower_index < 1:
		return
	if _offers.has(tower_index):
		return
	var world_seed := LevelRun.world_seed()
	if world_seed < 0:
		world_seed = 42
	_offers[tower_index] = UpgradeCatalog.roll_shop(
		world_seed, tower_index, luck_bonus, has_rifle, has_laser, has_tesla, has_rocket, has_shotgun, unlock_pity_steps
	)


func get_offers(tower_index: int) -> PackedStringArray:
	ensure_tower(tower_index)
	var raw: Variant = _offers.get(tower_index, PackedStringArray())
	return raw as PackedStringArray


func remaining_count(tower_index: int) -> int:
	var n := 0
	for id in get_offers(tower_index):
		if not UpgradeCatalog.is_empty_offer(StringName(id)):
			n += 1
	return n


func note_tower_without_unlock() -> void:
	unlock_pity_steps += 1


## Call once when leaving a tower. Empty shops and non-unlock picks bump pity;
## taking an unlock leaves pity cleared by grant_weapon.
func note_visit_outcome(took_unlock: bool) -> void:
	if took_unlock:
		return
	note_tower_without_unlock()


func pick_offer(tower_index: int, slot: int) -> StringName:
	var offers := get_offers(tower_index)
	if slot < 0 or slot >= offers.size():
		return &""
	var id := StringName(offers[slot])
	if UpgradeCatalog.is_empty_offer(id):
		return &""
	if UpgradeCatalog.is_weapon_offer(id):
		_remember_weapon_hole(tower_index, slot)
	offers[slot] = String(UpgradeCatalog.EMPTY_OFFER)
	_offers[tower_index] = offers
	_apply_upgrade(id)
	return id


func _apply_upgrade(id: StringName, weapon_family: StringName = &"") -> void:
	if UpgradeCatalog.is_weapon_unlock(id):
		grant_weapon(UpgradeCatalog.unlock_weapon_family(id))
		return
	if UpgradeCatalog.is_weapon_offer(id):
		var family := UpgradeCatalog.family_of(id)
		for part in UpgradeCatalog.weapon_parts(id):
			_apply_upgrade(StringName(part), family)
		_raise_weapon_level(family)
		return
	var family := UpgradeCatalog.family_of(id)
	if family == UpgradeCatalog.FAMILY_PROJECTILE:
		var amount := UpgradeCatalog.projectile_bonus(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).extra_projectiles += maxi(amount, 0)
		else:
			add_extra_projectile(amount)
	elif family == UpgradeCatalog.FAMILY_ATTACK_SPEED:
		var amount := UpgradeCatalog.attack_speed_percent(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).attack_speed += amount
		else:
			attack_speed_reduction += amount
	elif family == UpgradeCatalog.FAMILY_DAMAGE:
		var amount := UpgradeCatalog.damage_percent(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).damage += amount
		else:
			damage_bonus += amount
	elif family == UpgradeCatalog.FAMILY_PROJECTILE_SPEED:
		var amount := UpgradeCatalog.projectile_speed_percent(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).projectile_speed += amount
		else:
			projectile_speed_bonus += amount
	elif family == UpgradeCatalog.FAMILY_GLIDER_SPEED:
		glider_speed_bonus += UpgradeCatalog.glider_speed_percent(UpgradeCatalog.rarity_of(id))
	elif family == UpgradeCatalog.FAMILY_GLIDE:
		glide_bonus += UpgradeCatalog.glide_percent(UpgradeCatalog.rarity_of(id))
	elif family == UpgradeCatalog.FAMILY_STEERING:
		steering_bonus += UpgradeCatalog.steering_percent(UpgradeCatalog.rarity_of(id))
	elif family == UpgradeCatalog.FAMILY_HP_REGEN:
		health_regen_per_sec += UpgradeCatalog.hp_regen_per_sec(UpgradeCatalog.rarity_of(id))
	elif family == UpgradeCatalog.FAMILY_HEALTH:
		var amount := UpgradeCatalog.health_bonus(UpgradeCatalog.rarity_of(id))
		max_health_bonus += amount
		var health := get_tree().get_first_node_in_group("player_health") as PlayerHealth
		if health != null:
			health.add_bonus_health(amount)
	elif family == UpgradeCatalog.FAMILY_LUCK:
		luck_bonus += UpgradeCatalog.luck_points(UpgradeCatalog.rarity_of(id))
	elif family == UpgradeCatalog.FAMILY_MOMENTUM_RETENTION:
		momentum_retention += UpgradeCatalog.momentum_retention_percent(
			UpgradeCatalog.rarity_of(id)
		)
	elif family == UpgradeCatalog.FAMILY_CRIT:
		var amount := UpgradeCatalog.crit_chance(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).crit += amount
		else:
			crit_chance += amount
	elif family == UpgradeCatalog.FAMILY_DURATION:
		var amount := UpgradeCatalog.duration_percent(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).duration += amount
		else:
			duration_bonus += amount
	elif family == UpgradeCatalog.FAMILY_PUSHBACK:
		var amount := UpgradeCatalog.pushback_percent(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).pushback += amount
		else:
			pushback_bonus += amount
	elif family == UpgradeCatalog.FAMILY_BOUNCE:
		var amount := UpgradeCatalog.bounce_count(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).bounce += maxi(amount, 0)
		else:
			bounce_count += maxi(amount, 0)
	elif family == UpgradeCatalog.FAMILY_RANGE:
		var amount := UpgradeCatalog.range_percent(UpgradeCatalog.rarity_of(id))
		if weapon_family != &"":
			_bundle(weapon_family).range += amount
		else:
			range_bonus += amount


func hud_extra_projectiles() -> int:
	return extra_projectiles


func hud_attack_speed_reduction() -> float:
	return attack_speed_reduction


func hud_damage_bonus() -> float:
	return damage_bonus


func hud_projectile_speed_bonus() -> float:
	return projectile_speed_bonus


func hud_crit_chance() -> float:
	return crit_chance


func hud_duration_bonus() -> float:
	return duration_bonus


func hud_pushback_bonus() -> float:
	return pushback_bonus


func hud_range_bonus() -> float:
	return range_bonus


func add_extra_projectile(amount: int = 1) -> void:
	extra_projectiles += maxi(amount, 0)
	extra_projectiles_changed.emit(extra_projectiles)


func has_visited_this_life(tower_index: int) -> bool:
	return bool(_visited_this_life.get(tower_index, false))


func mark_visited_this_life(tower_index: int) -> void:
	if tower_index < 1:
		return
	_visited_this_life[tower_index] = true


func clear_visited_this_life() -> void:
	_visited_this_life.clear()


func _raise_weapon_level(family: StringName) -> void:
	if family == UpgradeCatalog.FAMILY_RIFLE and has_rifle:
		_rifle_level += 1
		weapons_changed.emit()
	elif family == UpgradeCatalog.FAMILY_LASER and has_laser:
		_laser_level += 1
		weapons_changed.emit()
	elif family == UpgradeCatalog.FAMILY_TESLA and has_tesla:
		_tesla_level += 1
		weapons_changed.emit()
	elif family == UpgradeCatalog.FAMILY_ROCKET and has_rocket:
		_rocket_level += 1
		weapons_changed.emit()
	elif family == UpgradeCatalog.FAMILY_SHOTGUN and has_shotgun:
		_shotgun_level += 1
		weapons_changed.emit()


func _bundle(weapon: StringName) -> WeaponBundle:
	if weapon == UpgradeCatalog.FAMILY_SHOTGUN:
		return _shotgun_bundle
	if weapon == UpgradeCatalog.FAMILY_ROCKET:
		return _rocket_bundle
	if weapon == UpgradeCatalog.FAMILY_TESLA:
		return _tesla_bundle
	if weapon == UpgradeCatalog.FAMILY_LASER:
		return _laser_bundle
	return _rifle_bundle


func _remember_weapon_hole(tower_index: int, slot: int) -> void:
	var holes := PackedInt32Array()
	if _weapon_holes.has(tower_index):
		holes = PackedInt32Array(_weapon_holes[tower_index])
	for existing in holes:
		if existing == slot:
			return
	holes.append(slot)
	_weapon_holes[tower_index] = holes


func _refill_weapon_holes() -> void:
	if _weapon_holes.is_empty():
		return
	if not has_rifle and not has_laser and not has_tesla and not has_rocket and not has_shotgun:
		return
	var world_seed := LevelRun.world_seed()
	if world_seed < 0:
		world_seed = 42
	var remaining: Dictionary = {}
	for tower_index in _weapon_holes.keys():
		if not _offers.has(tower_index):
			remaining[tower_index] = PackedInt32Array(_weapon_holes[tower_index])
			continue
		var holes := PackedInt32Array(_weapon_holes[tower_index])
		var offers: PackedStringArray = _offers[tower_index] as PackedStringArray
		var used: Dictionary = {}
		for id in offers:
			var named := StringName(id)
			if UpgradeCatalog.is_empty_offer(named):
				continue
			used[String(UpgradeCatalog.weapon_base_id(named))] = true
		var leftover_holes := PackedInt32Array()
		for slot in holes:
			if slot < 0 or slot >= offers.size():
				continue
			if not UpgradeCatalog.is_empty_offer(StringName(offers[slot])):
				continue
			var fresh := UpgradeCatalog.roll_weapon_refill(
				world_seed,
				int(tower_index),
				_life_index,
				int(slot),
				used,
				luck_bonus,
				has_rifle,
				has_laser,
				has_tesla,
				has_rocket,
				has_shotgun
			)
			if fresh.is_empty():
				leftover_holes.append(slot)
				continue
			offers[slot] = fresh
			used[String(UpgradeCatalog.weapon_base_id(StringName(fresh)))] = true
		_offers[tower_index] = offers
		if not leftover_holes.is_empty():
			remaining[tower_index] = leftover_holes
	_weapon_holes = remaining
