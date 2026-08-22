class_name RunUpgradeState
extends Node

## Stacks reset on Try Again. Taken weapon slots refill; other Empty slots stay empty.

signal extra_projectiles_changed(count: int)

var extra_projectiles := 0
var attack_speed_reduction := 0.0
var damage_bonus := 0.0
var projectile_speed_bonus := 0.0
var glider_speed_bonus := 0.0
var health_regen_per_sec := 0.0
var max_health_bonus := 0
var luck_bonus := 0
var momentum_retention := 0.0
var crit_chance := 0.0
var duration_bonus := 0.0
var pushback_bonus := 0.0
var _offers: Dictionary = {}
var _visited_this_life: Dictionary = {}
var _weapon_holes: Dictionary = {}
var _life_index := 0
var _weapon_extra_projectiles := 0
var _weapon_attack_speed := 0.0
var _weapon_damage := 0.0
var _weapon_projectile_speed := 0.0
var _weapon_crit := 0.0
var _weapon_duration := 0.0
var _weapon_pushback := 0.0


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
	health_regen_per_sec = 0.0
	max_health_bonus = 0
	luck_bonus = 0
	momentum_retention = 0.0
	crit_chance = 0.0
	duration_bonus = 0.0
	pushback_bonus = 0.0
	_weapon_extra_projectiles = 0
	_weapon_attack_speed = 0.0
	_weapon_damage = 0.0
	_weapon_projectile_speed = 0.0
	_weapon_crit = 0.0
	_weapon_duration = 0.0
	_weapon_pushback = 0.0
	_life_index += 1
	_refill_weapon_holes()
	clear_visited_this_life()
	extra_projectiles_changed.emit(extra_projectiles)


func ensure_tower(tower_index: int) -> void:
	if tower_index < 1:
		return
	if _offers.has(tower_index):
		return
	var seed := LevelRun.world_seed()
	if seed < 0:
		seed = 42
	_offers[tower_index] = UpgradeCatalog.roll_shop(seed, tower_index, luck_bonus)


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


func _apply_upgrade(id: StringName, from_weapon: bool = false) -> void:
	if UpgradeCatalog.is_weapon_offer(id):
		for part in UpgradeCatalog.weapon_parts(id):
			_apply_upgrade(StringName(part), true)
		return
	var family := UpgradeCatalog.family_of(id)
	if family == UpgradeCatalog.FAMILY_PROJECTILE:
		var amount := UpgradeCatalog.projectile_bonus(UpgradeCatalog.rarity_of(id))
		add_extra_projectile(amount)
		if from_weapon:
			_weapon_extra_projectiles += maxi(amount, 0)
	elif family == UpgradeCatalog.FAMILY_ATTACK_SPEED:
		var amount := UpgradeCatalog.attack_speed_percent(UpgradeCatalog.rarity_of(id))
		attack_speed_reduction += amount
		if from_weapon:
			_weapon_attack_speed += amount
	elif family == UpgradeCatalog.FAMILY_DAMAGE:
		var amount := UpgradeCatalog.damage_percent(UpgradeCatalog.rarity_of(id))
		damage_bonus += amount
		if from_weapon:
			_weapon_damage += amount
	elif family == UpgradeCatalog.FAMILY_PROJECTILE_SPEED:
		var amount := UpgradeCatalog.projectile_speed_percent(UpgradeCatalog.rarity_of(id))
		projectile_speed_bonus += amount
		if from_weapon:
			_weapon_projectile_speed += amount
	elif family == UpgradeCatalog.FAMILY_GLIDER_SPEED:
		glider_speed_bonus += UpgradeCatalog.glider_speed_percent(UpgradeCatalog.rarity_of(id))
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
		crit_chance += amount
		if from_weapon:
			_weapon_crit += amount
	elif family == UpgradeCatalog.FAMILY_DURATION:
		var amount := UpgradeCatalog.duration_percent(UpgradeCatalog.rarity_of(id))
		duration_bonus += amount
		if from_weapon:
			_weapon_duration += amount
	elif family == UpgradeCatalog.FAMILY_PUSHBACK:
		var amount := UpgradeCatalog.pushback_percent(UpgradeCatalog.rarity_of(id))
		pushback_bonus += amount
		if from_weapon:
			_weapon_pushback += amount


func hud_extra_projectiles() -> int:
	return extra_projectiles - _weapon_extra_projectiles


func hud_attack_speed_reduction() -> float:
	return attack_speed_reduction - _weapon_attack_speed


func hud_damage_bonus() -> float:
	return damage_bonus - _weapon_damage


func hud_projectile_speed_bonus() -> float:
	return projectile_speed_bonus - _weapon_projectile_speed


func hud_crit_chance() -> float:
	return crit_chance - _weapon_crit


func hud_duration_bonus() -> float:
	return duration_bonus - _weapon_duration


func hud_pushback_bonus() -> float:
	return pushback_bonus - _weapon_pushback


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
	var seed := LevelRun.world_seed()
	if seed < 0:
		seed = 42
	for tower_index in _weapon_holes.keys():
		if not _offers.has(tower_index):
			continue
		var holes := PackedInt32Array(_weapon_holes[tower_index])
		var offers: PackedStringArray = _offers[tower_index] as PackedStringArray
		var used: Dictionary = {}
		for id in offers:
			var named := StringName(id)
			if UpgradeCatalog.is_empty_offer(named):
				continue
			used[String(UpgradeCatalog.weapon_base_id(named))] = true
		for slot in holes:
			if slot < 0 or slot >= offers.size():
				continue
			if not UpgradeCatalog.is_empty_offer(StringName(offers[slot])):
				continue
			var fresh := UpgradeCatalog.roll_weapon_refill(
				seed, int(tower_index), _life_index, int(slot), used, luck_bonus
			)
			if fresh.is_empty():
				continue
			offers[slot] = fresh
			used[String(UpgradeCatalog.weapon_base_id(StringName(fresh)))] = true
		_offers[tower_index] = offers
	_weapon_holes.clear()
