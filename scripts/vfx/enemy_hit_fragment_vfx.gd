class_name EnemyHitFragmentVfx
extends Node3D

## Short-lived physics chips spawned on non-lethal enemy hits.

const SceneUtilScript := preload("res://scripts/util/scene_util.gd")
const CrawlerDebrisSandScript := preload("res://scripts/enemies/crawler_debris_sand.gd")
const DroneDebrisSparkVfxScript := preload("res://scripts/enemies/drone_debris_spark_vfx.gd")
const SandParticleVfxScript := preload("res://scripts/vfx/sand_particle_vfx.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")

const LIFETIME_SEC := 1.2
const KILL_LIFETIME_SEC := 3.0
const IMPULSE_MIN := 2.0
const IMPULSE_MAX := 5.0
const KILL_IMPULSE_MIN := 3.0
const KILL_IMPULSE_MAX := 7.0
const UP_IMPULSE := 1.5
const KILL_UP_IMPULSE := 2.5
const TORQUE_MAX := 4.0
const KILL_TORQUE_MAX := 6.0
const MIN_MESH_VOLUME := 0.00008
const SPAWN_JITTER_M := 0.05

const DEBRIS_COLLISION_LAYER := 1
const DEBRIS_COLLISION_MASK := 1

static var _kit_cache: Dictionary = {}

var _terrain: TerrainManager
var _impulse_min := IMPULSE_MIN
var _impulse_max := IMPULSE_MAX
var _up_impulse := UP_IMPULSE
var _torque_max := TORQUE_MAX
var _lifetime_sec := LIFETIME_SEC
var _spawn_landing_sand := false
var _death_sand_on_land := false
var _spark_color := Color(0.0, 0.0, 0.0, 0.0)


static func get_kit_mesh_count(kit: PackedScene) -> int:
	return _ensure_kit_cache(kit).size()


static func spawn(
	tree: SceneTree,
	kit: PackedScene,
	hit_pos: Vector3,
	hit_dir: Vector3,
	count: int,
	scale_mult: float = 1.0,
	terrain: TerrainManager = null,
	is_lethal: bool = false,
	weapon_family: StringName = &"",
	spark_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	death_sand_on_land: bool = false
) -> Node3D:
	if tree == null or kit == null or count <= 0:
		return null
	var entries := _ensure_kit_cache(kit)
	if entries.is_empty():
		push_warning("EnemyHitFragmentVfx: no mesh entries in kit %s" % kit.resource_path)
		return null
	var parent := SceneUtilScript.world_parent(tree)
	if parent == null:
		return null

	var wrapper = load("res://scripts/vfx/enemy_hit_fragment_vfx.gd").new()
	parent.add_child(wrapper)
	wrapper._terrain = terrain
	wrapper._spawn_landing_sand = UpgradeCatalogScript.weapon_causes_debris_sand(weapon_family)
	wrapper._death_sand_on_land = death_sand_on_land
	wrapper._spark_color = spark_color
	if is_lethal:
		wrapper._impulse_min = KILL_IMPULSE_MIN
		wrapper._impulse_max = KILL_IMPULSE_MAX
		wrapper._up_impulse = KILL_UP_IMPULSE
		wrapper._torque_max = KILL_TORQUE_MAX
		wrapper._lifetime_sec = KILL_LIFETIME_SEC
	wrapper._spawn_pieces(entries, hit_pos, hit_dir, count, scale_mult)
	wrapper._schedule_cleanup()
	return wrapper


static func _ensure_kit_cache(kit: PackedScene) -> Array:
	var key := kit.resource_path
	if _kit_cache.has(key):
		return _kit_cache[key]

	var entries: Array = []
	var temp := kit.instantiate()
	_collect_mesh_entries(temp, entries)
	temp.free()
	_kit_cache[key] = entries
	return entries


static func _collect_mesh_entries(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var entry := _mesh_entry_from(mesh_inst)
		if not entry.is_empty():
			out.append(entry)
	for child in node.get_children():
		_collect_mesh_entries(child, out)


static func _mesh_entry_from(mesh_inst: MeshInstance3D) -> Dictionary:
	var mesh: Mesh = mesh_inst.mesh
	if mesh == null:
		return {}
	if mesh.get_aabb().size.length_squared() < MIN_MESH_VOLUME:
		return {}

	var surf_mats: Array = []
	var surf_count := mesh_inst.get_surface_override_material_count()
	if surf_count <= 0:
		surf_count = mesh.get_surface_count()
	for idx in surf_count:
		var mat := mesh_inst.get_surface_override_material(idx)
		if mat == null:
			mat = mesh.surface_get_material(idx)
		surf_mats.append(mat)

	return {
		"mesh": mesh,
		"surface_materials": surf_mats,
		"material_override": mesh_inst.material_override,
	}


func _spawn_pieces(
	entries: Array,
	hit_pos: Vector3,
	hit_dir: Vector3,
	count: int,
	scale_mult: float
) -> void:
	for i in count:
		var entry_idx := randi() % entries.size()
		_spawn_piece(entries[entry_idx], hit_pos, hit_dir, scale_mult)


func _spawn_piece(entry: Dictionary, hit_pos: Vector3, hit_dir: Vector3, scale_mult: float) -> void:
	var mesh: Mesh = entry.get("mesh")
	if mesh == null:
		return

	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_COLLISION_LAYER
	body.collision_mask = DEBRIS_COLLISION_MASK
	body.gravity_scale = 1.0
	body.continuous_cd = true
	var needs_contact := (
		_spawn_landing_sand or _death_sand_on_land or _spark_color.a > 0.0
	)
	if needs_contact:
		body.contact_monitor = true
		body.max_contacts_reported = 1

	var mesh_copy := _mesh_instance_from_entry(entry, scale_mult)
	body.add_child(mesh_copy)
	var collision := _collision_for_mesh(mesh)
	collision.scale = Vector3.ONE * scale_mult
	body.add_child(collision)

	add_child(body)
	body.global_position = hit_pos + Vector3(
		randf_range(-SPAWN_JITTER_M, SPAWN_JITTER_M),
		randf_range(0.0, SPAWN_JITTER_M * 2.0),
		randf_range(-SPAWN_JITTER_M, SPAWN_JITTER_M)
	)
	body.rotation = Vector3(
		randf_range(-0.4, 0.4),
		randf_range(0.0, TAU),
		randf_range(-0.4, 0.4)
	)

	_apply_burst_impulse(body, hit_pos, hit_dir)
	if _death_sand_on_land:
		CrawlerDebrisSandScript.attach(body, _terrain, SandParticleVfxScript.BurstPreset.DEATH)
	elif _spawn_landing_sand:
		CrawlerDebrisSandScript.attach(body, _terrain, SandParticleVfxScript.BurstPreset.LIGHT)
	if _spark_color.a > 0.0:
		DroneDebrisSparkVfxScript.attach(body, _spark_color, scale_mult)


func _mesh_instance_from_entry(entry: Dictionary, scale_mult: float) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.mesh = entry.get("mesh")
	copy.scale = Vector3.ONE * scale_mult
	var surf_mats: Array = entry.get("surface_materials", [])
	for idx in surf_mats.size():
		var mat: Material = surf_mats[idx]
		if mat != null:
			copy.set_surface_override_material(idx, mat)
	var override_mat: Material = entry.get("material_override")
	if override_mat != null:
		copy.material_override = override_mat
	return copy


func _collision_for_mesh(mesh: Mesh) -> CollisionShape3D:
	var shape_node := CollisionShape3D.new()
	var shape: Shape3D = mesh.create_convex_shape(true, false)
	if shape == null:
		shape = mesh.create_trimesh_shape()
	shape_node.shape = shape
	return shape_node


func _apply_burst_impulse(body: RigidBody3D, hit_pos: Vector3, hit_dir: Vector3) -> void:
	var origin := hit_pos
	if origin == Vector3.ZERO:
		origin = body.global_position

	var dir := body.global_position - origin
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		if hit_dir.length_squared() > 0.0001:
			dir = hit_dir
			dir.y = 0.0
		else:
			dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	dir = dir.normalized()

	var strength := randf_range(_impulse_min, _impulse_max)
	var impulse := dir * strength + Vector3.UP * _up_impulse
	body.apply_central_impulse(impulse)
	body.apply_torque_impulse(
		Vector3(
			randf_range(-_torque_max, _torque_max),
			randf_range(-_torque_max, _torque_max),
			randf_range(-_torque_max, _torque_max)
		)
	)


func _schedule_cleanup() -> void:
	var timer := get_tree().create_timer(_lifetime_sec)
	timer.timeout.connect(queue_free)
