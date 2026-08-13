extends SceneTree

const RippleSpawnerScript = preload("res://scripts/world/ripple_spawner.gd")
const RippleSpawnManifest := preload("res://scripts/world/ripple_spawn_manifest.gd")
const TerrainManagerScript = preload("res://scripts/terrain/terrain_manager.gd")
const SandMaterial = preload("res://assets/materials/sand.tres")

const WORLD_SEED := 42
const EXPEDITION_INDEX := 0
const CONE_HALF_DEG := 35.0
const MIN_SEPARATION_M := 150.0


func _init() -> void:
	call_deferred("_run_tests")


func _fail_unless(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)


func _run_tests() -> void:
	var terrain: TerrainManager = TerrainManagerScript.new()
	terrain.world_seed = WORLD_SEED
	terrain.sand_material = SandMaterial
	root.add_child(terrain)

	var origin := Vector3(terrain.run_origin.x, 0.0, terrain.run_origin.y)
	var config := _default_config()
	var rng_a := RippleSpawnerScript.make_rng(WORLD_SEED, EXPEDITION_INDEX)
	var manifest_a: RippleSpawnManifest = RippleSpawnerScript.build_manifest(terrain, origin, config, rng_a)
	_verify_manifest(manifest_a, origin, config)

	var rng_b := RippleSpawnerScript.make_rng(WORLD_SEED, EXPEDITION_INDEX)
	var manifest_b: RippleSpawnManifest = RippleSpawnerScript.build_manifest(terrain, origin, config, rng_b)
	_fail_unless(_manifest_signature(manifest_a) == _manifest_signature(manifest_b), "Same seed should produce identical manifest")

	print("Ripple spawner verification passed.")
	quit(0)


func _default_config() -> Dictionary:
	return {
		"expedition_index": EXPEDITION_INDEX,
		"expedition_bearing_deg": 0.0,
		"ripple_count": 3,
		"pois_per_ripple": 1,
		"first_ripple_center_m": 1200.0,
		"first_ripple_jitter": 0.15,
		"ripple_spacing_m": 1200.0,
		"ripple_spacing_jitter": 0.15,
		"ripple_thickness_ratio": 0.2,
		"cone_half_angle_deg": CONE_HALF_DEG,
		"min_poi_separation_m": MIN_SEPARATION_M,
		"max_slope_deg": 38.0,
		"max_placement_attempts": 30,
	}


func _verify_manifest(manifest: RippleSpawnManifest, origin: Vector3, config: Dictionary) -> void:
	_fail_unless(manifest.size() == 3, "Expedition 1 should spawn 3 wrecks, got %d" % manifest.size())

	var ripple_counts := [0, 0, 0]
	for entry in manifest.entries:
		_fail_unless(entry.ripple_index >= 0 and entry.ripple_index < 3, "Unexpected ripple index %d" % entry.ripple_index)
		ripple_counts[entry.ripple_index] += 1
	_fail_unless(ripple_counts == [1, 1, 1], "Expected one wreck per ripple, got %s" % str(ripple_counts))

	var nearest: RippleSpawnManifest.Entry = null
	var nearest_dist := INF
	for entry in manifest.entries:
		if entry.distance_m < nearest_dist:
			nearest_dist = entry.distance_m
			nearest = entry
	_fail_unless(nearest != null, "Manifest should have a nearest entry")
	_fail_unless(nearest.tier == int(WreckSite.Tier.TUTORIAL), "Nearest ripple should be tutorial tier")

	for entry in manifest.entries:
		if entry.ripple_index == 0:
			_fail_unless(entry.tier != int(WreckSite.Tier.MILITARY), "Ripple 0 must not be military")

	var bands := _expected_distance_bands(config)
	for entry in manifest.entries:
		var band: Vector2 = bands[entry.ripple_index]
		_fail_unless(
			entry.distance_m >= band.x and entry.distance_m <= band.y,
			"Ripple %d distance %.1f outside band [%.1f, %.1f]"
			% [entry.ripple_index, entry.distance_m, band.x, band.y]
		)

	var bearing_rad := deg_to_rad(float(config.get("expedition_bearing_deg", 0.0)))
	var cone_half := deg_to_rad(float(config.get("cone_half_angle_deg", CONE_HALF_DEG)))
	for entry in manifest.entries:
		var dx: float = entry.world_pos.x - origin.x
		var dz: float = entry.world_pos.z - origin.z
		var angle := atan2(dx, dz)
		var delta := absf(wrapf(angle - bearing_rad, -PI, PI))
		_fail_unless(delta <= cone_half + 0.01, "Entry outside forward cone (delta=%.3f)" % delta)

	for i in manifest.size():
		for j in range(i + 1, manifest.size()):
			var a := manifest.get_entry(i)
			var b := manifest.get_entry(j)
			var dist := Vector2(a.world_pos.x, a.world_pos.z).distance_to(Vector2(b.world_pos.x, b.world_pos.z))
			_fail_unless(dist >= MIN_SEPARATION_M - 0.5, "POIs too close: %.1fm" % dist)


func _expected_distance_bands(config: Dictionary) -> Array[Vector2]:
	var first_center := float(config.get("first_ripple_center_m", 600.0))
	var first_jitter := float(config.get("first_ripple_jitter", 0.15))
	var spacing := float(config.get("ripple_spacing_m", 600.0))
	var spacing_jitter := float(config.get("ripple_spacing_jitter", 0.15))
	var thickness_ratio := float(config.get("ripple_thickness_ratio", 0.2))

	var c0_min := first_center * (1.0 - first_jitter)
	var c0_max := first_center * (1.0 + first_jitter)
	var bands: Array[Vector2] = []
	bands.append(_band_for_center((c0_min + c0_max) * 0.5, thickness_ratio))

	var c1_center_min := c0_min + spacing * (1.0 - spacing_jitter)
	var c1_center_max := c0_max + spacing * (1.0 + spacing_jitter)
	bands.append(_band_for_center((c1_center_min + c1_center_max) * 0.5, thickness_ratio))

	var c2_center_min := c1_center_min + spacing * (1.0 - spacing_jitter)
	var c2_center_max := c1_center_max + spacing * (1.0 + spacing_jitter)
	bands.append(_band_for_center((c2_center_min + c2_center_max) * 0.5, thickness_ratio))
	return bands


func _band_for_center(center: float, thickness_ratio: float) -> Vector2:
	var thickness := maxf(100.0, center * thickness_ratio)
	var half := thickness * 0.5
	var slack := center * 0.18
	return Vector2(maxf(10.0, center - half - slack), center + half + slack)


func _manifest_signature(manifest: RippleSpawnManifest) -> String:
	var parts: PackedStringArray = []
	for entry in manifest.entries:
		parts.append(
			"%d:%d:%.2f:%.2f:%.2f"
			% [
				entry.ripple_index,
				entry.tier,
				entry.local_offset.x,
				entry.local_offset.y,
				entry.local_offset.z,
			]
		)
	parts.sort()
	return "|".join(parts)
