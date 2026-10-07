class_name VestigeDrop
extends RefCounted

## Ground-kill Vestige rolls. Quota is spent when the sphere drops, not when it is picked up.

const BAND_SIZE := 8
const CHANCE_PLACE_1 := 0.25
const CHANCE_PLACE_8 := 0.12
const PITY_CHANCE := 0.005

const VestigeWalletScript := preload("res://scripts/game/vestige_wallet.gd")


static func place_in_band(level: int) -> int:
	var safe := maxi(level, 1)
	return ((safe - 1) % BAND_SIZE) + 1


static func earlier_bands(level: int) -> int:
	var safe := maxi(level, 1)
	return (safe - 1) / BAND_SIZE


static func quota_for_level(level: int) -> int:
	return place_in_band(level) + earlier_bands(level)


static func drop_chance(level: int, dropped_count: int) -> float:
	if dropped_count >= quota_for_level(level):
		return PITY_CHANCE
	var span := float(BAND_SIZE - 1)
	var t := clampf(float(place_in_band(level) - 1) / span, 0.0, 1.0)
	return lerpf(CHANCE_PLACE_1, CHANCE_PLACE_8, t)


static func should_drop(level: int, dropped_count: int, roll: float) -> bool:
	return roll < drop_chance(level, dropped_count)


static func current_level(tree: SceneTree) -> int:
	if tree == null:
		return 1
	var progress := tree.get_first_node_in_group("level_progress")
	if progress != null and progress.has_method("get_current_level"):
		return maxi(int(progress.get_current_level()), 1)
	return 1


## Rolls against the tower quota and, on a hit, spends one drop then spawns the sphere.
static func try_from_corpse(
	tree: SceneTree,
	corpse_pos: Vector3,
	hit_pos: Vector3,
	terrain: TerrainManager,
	roll: float = -1.0
) -> bool:
	var wallet = VestigeWalletScript.find(tree)
	if wallet == null or tree == null:
		return false
	var level := current_level(tree)
	var dropped: int = wallet.dropped_count(level)
	var sample := roll if roll >= 0.0 else randf()
	if not should_drop(level, dropped, sample):
		return false
	wallet.note_drop(level)
	# Loaded here so this script, the pickup, and SwarmPill do not preload each other.
	var pickup_script: GDScript = load("res://scripts/game/vestige_pickup.gd")
	pickup_script.spawn(tree, corpse_pos, hit_pos, terrain)
	return true
