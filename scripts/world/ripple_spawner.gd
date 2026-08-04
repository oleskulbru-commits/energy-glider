@tool
class_name RippleSpawner
extends Node3D

const WRECK_SCENE := preload("res://scenes/world/wreck_site.tscn")
const RippleSpawnManifest := preload("res://scripts/world/ripple_spawn_manifest.gd")

const NARROW_ARC_HALF_DEG := 12.0
const FALLBACK_ARC_WIDEN_DEG := 5.0
const MIN_RIPPLE_THICKNESS_M := 100.0

@export var terrain_manager_path: NodePath
@export var expedition_index := 0
@export var expedition_bearing_deg := 0.0
@export var ripple_count := 3
@export var pois_per_ripple := 1
@export var first_ripple_center_m := 1200.0
@export var first_ripple_jitter := 0.15
@export var ripple_spacing_m := 1200.0
@export var ripple_spacing_jitter := 0.15
@export var ripple_thickness_ratio := 0.2
@export var cone_half_angle_deg := 35.0
@export var min_poi_separation_m := 150.0
@export var max_slope_deg := 38.0
@export var max_placement_attempts := 30
@export var debug_draw_editor := false
@export var debug_draw_runtime := false

var _manifest: RippleSpawnManifest
var _debug_root: Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()
		return
	call_deferred("_spawn_ripples")


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED and debug_draw_editor:
		_refresh_editor_preview()


func _spawn_ripples() -> void:
	var terrain := _get_terrain_manager()
	var origin := _get_spawn_origin(terrain)
	var rng := _make_rng(terrain)
	_manifest = build_manifest(terrain, origin, _build_config(), rng)
	_clear_debug_nodes()
	for entry in _manifest.entries:
		_spawn_wreck(entry, origin)
	if debug_draw_runtime:
		_log_manifest(_manifest, origin)


static func build_manifest(
	terrain: TerrainManager,
	origin: Vector3,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> RippleSpawnManifest:
	var manifest := RippleSpawnManifest.new()
	var accepted: Array[Vector3] = []
	var bearing_rad := deg_to_rad(float(config.get("expedition_bearing_deg", 0.0)))
	var ripple_total: int = maxi(int(config.get("ripple_count", 3)), 1)
	var slots_per_ripple: int = maxi(int(config.get("pois_per_ripple", 1)), 1)
	var max_slope := deg_to_rad(float(config.get("max_slope_deg", 38.0)))
	var min_sep := float(config.get("min_poi_separation_m", 150.0))
	var max_attempts := int(config.get("max_placement_attempts", 30))
	var cone_half := deg_to_rad(float(config.get("cone_half_angle_deg", 35.0)))

	var ripple_centers: Array[float] = []
	var cumulative := 0.0
	for i in ripple_total:
		if i == 0:
			cumulative = _jittered_value(
				rng,
				float(config.get("first_ripple_center_m", 600.0)),
				float(config.get("first_ripple_jitter", 0.15))
			)
		else:
			cumulative += _jittered_value(
				rng,
				float(config.get("ripple_spacing_m", 600.0)),
				float(config.get("ripple_spacing_jitter", 0.15))
			)
		ripple_centers.append(cumulative)

	for ripple_index in ripple_total:
		var center_dist: float = ripple_centers[ripple_index]
		var thickness := maxf(
			MIN_RIPPLE_THICKNESS_M,
			center_dist * float(config.get("ripple_thickness_ratio", 0.2))
		)
		var inner_r := maxf(center_dist - thickness * 0.5, 10.0)
		var outer_r := center_dist + thickness * 0.5
		var arc_t := 0.0 if ripple_total <= 1 else float(ripple_index) / float(ripple_total - 1)
		var arc_half := lerpf(
			deg_to_rad(NARROW_ARC_HALF_DEG),
			cone_half,
			arc_t
		)

		for _slot in slots_per_ripple:
			var tier := _roll_tier_for_ripple(rng, ripple_index, int(config.get("expedition_index", 0)))
			var placed := _try_place_entry(
				manifest,
				accepted,
				terrain,
				origin,
				ripple_index,
				tier,
				bearing_rad,
				inner_r,
				outer_r,
				arc_half,
				max_slope,
				min_sep,
				max_attempts,
				rng,
				false
			)
			if placed:
				continue
			placed = _try_place_entry(
				manifest,
				accepted,
				terrain,
				origin,
				ripple_index,
				tier,
				bearing_rad,
				inner_r,
				outer_r,
				arc_half + deg_to_rad(FALLBACK_ARC_WIDEN_DEG),
				max_slope,
				min_sep,
				max_attempts,
				rng,
				true
			)
			if placed:
				continue
			_place_fallback_entry(
				manifest,
				accepted,
				terrain,
				origin,
				ripple_index,
				tier,
				bearing_rad,
				center_dist,
				arc_half,
				max_slope
			)

	_enforce_quotas(manifest, int(config.get("expedition_index", 0)))
	return manifest


static func make_rng(world_seed: int, expedition_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_seed) * 1009 + int(expedition_index) * 9176 + 13
	return rng


func _build_config() -> Dictionary:
	return {
		"expedition_index": expedition_index,
		"expedition_bearing_deg": expedition_bearing_deg,
		"ripple_count": ripple_count,
		"pois_per_ripple": pois_per_ripple,
		"first_ripple_center_m": first_ripple_center_m,
		"first_ripple_jitter": first_ripple_jitter,
		"ripple_spacing_m": ripple_spacing_m,
		"ripple_spacing_jitter": ripple_spacing_jitter,
		"ripple_thickness_ratio": ripple_thickness_ratio,
		"cone_half_angle_deg": cone_half_angle_deg,
		"min_poi_separation_m": min_poi_separation_m,
		"max_slope_deg": max_slope_deg,
		"max_placement_attempts": max_placement_attempts,
	}


func _make_rng(terrain: TerrainManager) -> RandomNumberGenerator:
	var world_seed := 42
	if terrain != null:
		world_seed = terrain.world_seed
	return make_rng(world_seed, expedition_index)


func _spawn_wreck(entry: RippleSpawnManifest.Entry, origin: Vector3) -> void:
	var terrain := _get_terrain_manager()
	var wreck: WreckSite = WRECK_SCENE.instantiate() as WreckSite
	wreck.tier = entry.tier as WreckSite.Tier
	wreck.ripple_index = entry.ripple_index
	wreck.position = entry.local_offset
	add_child(wreck)
	if terrain != null:
		wreck.terrain_manager_path = wreck.get_path_to(terrain)
		terrain.ensure_loaded_at(wreck.global_position)
	wreck.snap_to_ground()


func _get_spawn_origin(terrain: TerrainManager) -> Vector3:
	if terrain != null:
		return Vector3(terrain.run_origin.x, 0.0, terrain.run_origin.y)
	return Vector3.ZERO


func _get_terrain_manager() -> TerrainManager:
	if terrain_manager_path != NodePath():
		return get_node_or_null(terrain_manager_path) as TerrainManager
	return get_parent().get_node_or_null("TerrainManager") as TerrainManager


func _refresh_editor_preview() -> void:
	if not debug_draw_editor:
		_clear_debug_nodes()
		return
	var terrain := _get_terrain_manager()
	var origin := _get_spawn_origin(terrain)
	var rng := _make_rng(terrain)
	_manifest = build_manifest(terrain, origin, _build_config(), rng)
	_draw_debug_manifest(_manifest, origin)


func _clear_debug_nodes() -> void:
	if _debug_root != null and is_instance_valid(_debug_root):
		_debug_root.queue_free()
		_debug_root = null


func _draw_debug_manifest(manifest: RippleSpawnManifest, origin: Vector3) -> void:
	_clear_debug_nodes()
	_debug_root = Node3D.new()
	_debug_root.name = "DebugRipples"
	add_child(_debug_root)
	if Engine.is_editor_hint():
		_debug_root.owner = null
	for entry in manifest.entries:
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 4.0
		sphere.height = 8.0
		marker.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = _tier_color(entry.tier as WreckSite.Tier)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.65
		marker.material_override = material
		marker.position = entry.local_offset + Vector3(0.0, 6.0, 0.0)
		_debug_root.add_child(marker)
		if Engine.is_editor_hint():
			marker.owner = null


static func _tier_color(tier: WreckSite.Tier) -> Color:
	match tier:
		WreckSite.Tier.TUTORIAL:
			return Color(0.35, 0.88, 0.95)
		WreckSite.Tier.SALVAGE:
			return Color(0.98, 0.78, 0.18)
		WreckSite.Tier.MILITARY:
			return Color(0.95, 0.32, 0.28)
		_:
			return Color.WHITE


static func _jittered_value(rng: RandomNumberGenerator, base: float, jitter_fraction: float) -> float:
	var jitter := base * jitter_fraction
	return base + rng.randf_range(-jitter, jitter)


static func _roll_tier_for_ripple(
	rng: RandomNumberGenerator,
	ripple_index: int,
	expedition_index: int
) -> WreckSite.Tier:
	if expedition_index <= 0:
		if ripple_index == 0:
			return WreckSite.Tier.TUTORIAL
		if ripple_index == 1:
			return WreckSite.Tier.SALVAGE
		if rng.randf() < 0.3:
			return WreckSite.Tier.MILITARY
		return WreckSite.Tier.SALVAGE
	if ripple_index == 0:
		return WreckSite.Tier.TUTORIAL
	return WreckSite.Tier.SALVAGE


static func _try_place_entry(
	manifest: RippleSpawnManifest,
	accepted: Array[Vector3],
	terrain: TerrainManager,
	origin: Vector3,
	ripple_index: int,
	tier: WreckSite.Tier,
	bearing_rad: float,
	inner_r: float,
	outer_r: float,
	arc_half: float,
	max_slope: float,
	min_sep: float,
	max_attempts: int,
	rng: RandomNumberGenerator,
	widen_thickness: bool
) -> bool:
	var inner := inner_r
	var outer := outer_r
	if widen_thickness:
		var extra := (outer_r - inner_r) * 0.25
		inner = maxf(inner - extra, 10.0)
		outer += extra

	for _attempt in max_attempts:
		var radius := rng.randf_range(inner, outer)
		var angle_offset := rng.randf_range(-arc_half, arc_half)
		if ripple_index == 0:
			angle_offset *= 0.35
		var theta := bearing_rad + angle_offset
		var offset := Vector3(sin(theta) * radius, 0.0, cos(theta) * radius)
		var world_pos := origin + offset
		if terrain != null:
			# Height/normal sampling does not need meshes; avoid sync chunk loads (editor freeze).
			world_pos.y = terrain.sample_height(world_pos.x, world_pos.z)
		if not _is_valid_candidate(
			terrain,
			world_pos,
			origin,
			accepted,
			bearing_rad,
			arc_half,
			max_slope,
			min_sep
		):
			continue
		_add_manifest_entry(manifest, accepted, origin, ripple_index, tier, world_pos, theta, radius)
		return true
	return false


static func _place_fallback_entry(
	manifest: RippleSpawnManifest,
	accepted: Array[Vector3],
	terrain: TerrainManager,
	origin: Vector3,
	ripple_index: int,
	tier: WreckSite.Tier,
	bearing_rad: float,
	center_dist: float,
	arc_half: float,
	max_slope: float
) -> void:
	var theta := bearing_rad
	var offset := Vector3(sin(theta) * center_dist, 0.0, cos(theta) * center_dist)
	var world_pos := origin + offset
	if terrain != null:
		world_pos.y = terrain.sample_height(world_pos.x, world_pos.z)
	if not _is_valid_candidate(
		terrain,
		world_pos,
		origin,
		accepted,
		bearing_rad,
		arc_half,
		max_slope,
		0.0
	):
		world_pos.y = _sample_height(terrain, world_pos.x, world_pos.z)
	_add_manifest_entry(manifest, accepted, origin, ripple_index, tier, world_pos, theta, center_dist)


static func _add_manifest_entry(
	manifest: RippleSpawnManifest,
	accepted: Array[Vector3],
	origin: Vector3,
	ripple_index: int,
	tier: WreckSite.Tier,
	world_pos: Vector3,
	theta: float,
	radius: float
) -> void:
	var entry := RippleSpawnManifest.Entry.new()
	entry.ripple_index = ripple_index
	entry.world_pos = world_pos
	entry.local_offset = world_pos - origin
	entry.tier = int(tier)
	entry.distance_m = radius
	entry.bearing_rad = theta
	manifest.add(entry)
	accepted.append(world_pos)


static func _is_valid_candidate(
	terrain: TerrainManager,
	world_pos: Vector3,
	origin: Vector3,
	accepted: Array[Vector3],
	bearing_rad: float,
	arc_half: float,
	max_slope: float,
	min_sep: float
) -> bool:
	var dx := world_pos.x - origin.x
	var dz := world_pos.z - origin.z
	var candidate_angle := atan2(dx, dz)
	var angle_delta := absf(wrapf(candidate_angle - bearing_rad, -PI, PI))
	if angle_delta > arc_half + 0.001:
		return false
	for prior in accepted:
		var flat_a := Vector2(world_pos.x, world_pos.z)
		var flat_b := Vector2(prior.x, prior.z)
		if flat_a.distance_to(flat_b) < min_sep:
			return false
	if terrain == null:
		return true
	var slope := terrain.sample_normal(world_pos.x, world_pos.z).angle_to(Vector3.UP)
	return slope <= max_slope


static func _sample_height(terrain: TerrainManager, world_x: float, world_z: float) -> float:
	if terrain != null:
		return terrain.sample_height(world_x, world_z)
	return 0.0


static func _enforce_quotas(manifest: RippleSpawnManifest, expedition_index: int) -> void:
	if manifest.size() == 0:
		return
	if expedition_index > 0:
		return
	var nearest: RippleSpawnManifest.Entry = null
	var nearest_dist := INF
	for entry in manifest.entries:
		if entry.distance_m < nearest_dist:
			nearest_dist = entry.distance_m
			nearest = entry
	if nearest != null:
		nearest.tier = int(WreckSite.Tier.TUTORIAL)
	for entry in manifest.entries:
		if entry.ripple_index == 0:
			if entry.tier == int(WreckSite.Tier.MILITARY):
				entry.tier = int(WreckSite.Tier.SALVAGE)


func _log_manifest(manifest: RippleSpawnManifest, origin: Vector3) -> void:
	print("RippleSpawner manifest (%d entries) origin=%s" % [manifest.size(), origin])
	for entry in manifest.entries:
		print(
			"  ripple=%d tier=%d dist=%.1fm pos=%s"
			% [entry.ripple_index, entry.tier, entry.distance_m, entry.local_offset]
		)
