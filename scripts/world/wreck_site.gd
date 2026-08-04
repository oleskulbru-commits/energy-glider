class_name WreckSite
extends Node3D

enum Tier { TUTORIAL, SALVAGE, MILITARY }

const GROUND_OFFSET := 0.05

const DRONE_SCENE := preload("res://scenes/enemies/scout_drone.tscn")
const RADAR_BEACON_SCENE := preload("res://scenes/world/radar_beacon.tscn")
const RadarBeaconScript := preload("res://scripts/world/radar_beacon.gd")

@export var tier: Tier = Tier.SALVAGE
@export var ripple_index := 0
@export var terrain_manager_path: NodePath

var _drones: Array[ScoutDrone] = []
var _loot_container: LootContainer
var _radar_beacon: RadarBeaconScript


func _ready() -> void:
	add_to_group("wreck_site")
	add_to_group("radar_poi")
	_setup_radar_beacon()
	_setup_loot_container()
	call_deferred("_snap_to_terrain")
	call_deferred("_spawn_drones")


func get_loot_container() -> LootContainer:
	return _loot_container


func is_depleted() -> bool:
	return _loot_container != null and _loot_container.is_breached() and _loot_container.is_empty()


func is_pulse_target_active() -> bool:
	return not is_depleted()


func get_radar_beacon() -> RadarBeaconScript:
	return _radar_beacon


func get_drone_count() -> int:
	match tier:
		Tier.TUTORIAL:
			return 0
		Tier.SALVAGE:
			return 1
		Tier.MILITARY:
			return 2
		_:
			return 0


func can_interact(body: Node3D) -> bool:
	if _loot_container == null or is_depleted():
		return false
	return _loot_container.can_interact(body)


func raise_alarm(target: Node3D) -> void:
	for drone in _drones:
		if drone != null and is_instance_valid(drone):
			drone.raise_alarm(target)


func _setup_radar_beacon() -> void:
	_radar_beacon = get_node_or_null("RadarBeacon") as RadarBeaconScript
	if _radar_beacon == null:
		_radar_beacon = RADAR_BEACON_SCENE.instantiate() as RadarBeaconScript
		_radar_beacon.name = "RadarBeacon"
		add_child(_radar_beacon)


func _setup_loot_container() -> void:
	_loot_container = LootContainer.new()
	_loot_container.name = "LootContainer"
	add_child(_loot_container)

	var table_tier := _to_table_tier(tier)
	_loot_container.container_name = _container_name_for_tier(tier)
	_loot_container.breach_duration = LootTable.breach_duration_for_tier(table_tier)
	_loot_container.set_loot_roll(func() -> Array[LootItem]:
		return LootTable.roll_for_wreck(table_tier)
	)
	_loot_container.contents_changed.connect(_on_loot_contents_changed)


func _to_table_tier(wreck_tier: Tier) -> LootTable.WreckTier:
	match wreck_tier:
		Tier.TUTORIAL:
			return LootTable.WreckTier.TUTORIAL
		Tier.SALVAGE:
			return LootTable.WreckTier.SALVAGE
		Tier.MILITARY:
			return LootTable.WreckTier.MILITARY
		_:
			return LootTable.WreckTier.SALVAGE


func _container_name_for_tier(wreck_tier: Tier) -> String:
	match wreck_tier:
		Tier.TUTORIAL:
			return "ABANDONED WRECK"
		Tier.SALVAGE:
			return "SALVAGE WRECK"
		Tier.MILITARY:
			return "MILITARY WRECK"
		_:
			return "WRECK"


func _spawn_drones() -> void:
	var count := get_drone_count()
	if count <= 0:
		return
	for i in count:
		var drone: ScoutDrone = DRONE_SCENE.instantiate() as ScoutDrone
		get_parent().add_child(drone)
		var angle := (TAU / float(count)) * float(i)
		drone.configure(global_position, angle)
		_drones.append(drone)


func snap_to_ground() -> void:
	_snap_to_terrain()


func _snap_to_terrain() -> void:
	var terrain := _get_terrain_manager()
	if terrain == null:
		return
	terrain.ensure_loaded_at(global_position)
	var ground_y := terrain.sample_height(global_position.x, global_position.z)
	global_position.y = ground_y + GROUND_OFFSET


func _on_loot_contents_changed() -> void:
	if is_depleted():
		_set_depleted_visual()


func _set_depleted_visual() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.scale = Vector3.ONE * 0.92


func _get_terrain_manager() -> TerrainManager:
	if terrain_manager_path != NodePath():
		var terrain := get_node_or_null(terrain_manager_path) as TerrainManager
		if terrain != null:
			return terrain
	var parent := get_parent()
	while parent != null:
		var terrain := parent.get_node_or_null("TerrainManager") as TerrainManager
		if terrain != null:
			return terrain
		parent = parent.get_parent()
	return null
