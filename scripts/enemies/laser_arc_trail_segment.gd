class_name LaserArcTrailSegment
extends Node3D

const SegmentScript := preload("res://scripts/enemies/laser_arc_trail_segment.gd")
const PlayerHealthScript = preload("res://scripts/player/player_health.gd")

const TRAIL_WIDTH_M := 2.4
const TRAIL_LINGER_SEC := 5.0
const LANE_THICKNESS_GROUND_M := 0.08
const LANE_THICKNESS_AIR_M := 0.35
const EMBER_LIFT_GROUND_M := 0.16
const EMBER_EMIT_STOP_BEFORE_END_SEC := 0.35

var _seg_start := Vector3.ZERO
var _seg_end := Vector3.ZERO
var _air_mode := false
var _half_width := TRAIL_WIDTH_M * 0.5
var _triggered := false
var _life_left := TRAIL_LINGER_SEC
var _embers: CPUParticles3D


static func spawn(
	tree: SceneTree,
	start: Vector3,
	end: Vector3,
	air_mode: bool,
	life_sec: float = TRAIL_LINGER_SEC,
	_terrain: TerrainManager = null
) -> Node3D:
	var segment: Node3D = SegmentScript.new()
	var parent := tree.current_scene if tree != null else null
	if parent == null and tree != null:
		parent = tree.root
	if parent == null:
		return segment
	parent.add_child(segment)
	segment.place(start, end, air_mode, life_sec)
	return segment


func place(start: Vector3, end: Vector3, air_mode: bool, life_sec: float) -> void:
	_air_mode = air_mode
	_seg_start = start
	_seg_end = end
	_life_left = maxf(life_sec, 0.1)
	_half_width = TRAIL_WIDTH_M * 0.5
	_place_visual()
	_add_embers()


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= EMBER_EMIT_STOP_BEFORE_END_SEC and _embers != null and _embers.emitting:
		_embers.emitting = false
	if _life_left <= 0.0:
		queue_free()
		return
	_try_trigger_burn()


func _try_trigger_burn() -> void:
	if _triggered:
		return
	if not is_inside_tree():
		return
	var health := get_tree().get_first_node_in_group("player_health")
	if health == null or not health.has_method("movement_chord"):
		return
	var chord: Dictionary = health.movement_chord()
	var from_pos: Vector3 = chord.get("from", Vector3.ZERO)
	var to_pos: Vector3 = chord.get("to", Vector3.ZERO)
	if chord_hits_segment(from_pos, to_pos, _seg_start, _seg_end, _half_width, _air_mode):
		_triggered = true
		if health.has_method("apply_laser_burn"):
			health.apply_laser_burn()


static func chord_hits_segment(
	from_pos: Vector3,
	to_pos: Vector3,
	seg_start: Vector3,
	seg_end: Vector3,
	half_width: float,
	air_mode: bool
) -> bool:
	if air_mode:
		if segment_segment_distance(from_pos, to_pos, seg_start, seg_end) <= half_width:
			return true
		if point_segment_distance(to_pos, seg_start, seg_end) <= half_width:
			return true
		return point_segment_distance(from_pos, seg_start, seg_end) <= half_width
	var from2 := Vector2(from_pos.x, from_pos.z)
	var to2 := Vector2(to_pos.x, to_pos.z)
	var seg_a2 := Vector2(seg_start.x, seg_start.z)
	var seg_b2 := Vector2(seg_end.x, seg_end.z)
	if segment_segment_distance_2d(from2, to2, seg_a2, seg_b2) <= half_width:
		return true
	if point_segment_distance_2d(to2, seg_a2, seg_b2) <= half_width:
		return true
	return point_segment_distance_2d(from2, seg_a2, seg_b2) <= half_width


static func point_segment_distance(point: Vector3, seg_a: Vector3, seg_b: Vector3) -> float:
	return sqrt(point_segment_distance_sq(point, seg_a, seg_b))


static func point_segment_distance_sq(point: Vector3, seg_a: Vector3, seg_b: Vector3) -> float:
	var ab := seg_b - seg_a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return point.distance_squared_to(seg_a)
	var t := clampf((point - seg_a).dot(ab) / len_sq, 0.0, 1.0)
	var closest := seg_a + ab * t
	return point.distance_squared_to(closest)


static func point_segment_distance_2d(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	return sqrt(point_segment_distance_sq_2d(point, seg_a, seg_b))


static func point_segment_distance_sq_2d(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab := seg_b - seg_a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return point.distance_squared_to(seg_a)
	var t := clampf((point - seg_a).dot(ab) / len_sq, 0.0, 1.0)
	var closest := seg_a + ab * t
	return point.distance_squared_to(closest)


static func segment_segment_distance(
	a0: Vector3,
	a1: Vector3,
	b0: Vector3,
	b1: Vector3
) -> float:
	var u := a1 - a0
	var v := b1 - b0
	var w0 := a0 - b0
	var a := u.dot(u)
	var b := u.dot(v)
	var c := v.dot(v)
	var d := u.dot(w0)
	var e := v.dot(w0)
	var denom := a * c - b * b
	var sc := 0.0
	var tc := 0.0
	if denom < 0.0001:
		sc = 0.0
		tc = clampf(e / c, 0.0, 1.0) if c > 0.0001 else 0.0
	else:
		sc = clampf((b * e - c * d) / denom, 0.0, 1.0)
		tc = clampf((a * e - b * d) / denom, 0.0, 1.0)
	var p_a := a0 + u * sc
	var p_b := b0 + v * tc
	return p_a.distance_to(p_b)


static func segment_segment_distance_2d(
	a0: Vector2,
	a1: Vector2,
	b0: Vector2,
	b1: Vector2
) -> float:
	var u := a1 - a0
	var v := b1 - b0
	var w0 := a0 - b0
	var a := u.dot(u)
	var b := u.dot(v)
	var c := v.dot(v)
	var d := u.dot(w0)
	var e := v.dot(w0)
	var denom := a * c - b * b
	var sc := 0.0
	var tc := 0.0
	if denom < 0.0001:
		sc = 0.0
		tc = clampf(e / c, 0.0, 1.0) if c > 0.0001 else 0.0
	else:
		sc = clampf((b * e - c * d) / denom, 0.0, 1.0)
		tc = clampf((a * e - b * d) / denom, 0.0, 1.0)
	var p_a := a0 + u * sc
	var p_b := b0 + v * tc
	return p_a.distance_to(p_b)


func _place_visual() -> void:
	var dir := _seg_end - _seg_start
	if not _air_mode:
		dir.y = 0.0
	var length := dir.length()
	if length < 0.05:
		queue_free()
		return
	var mid := (_seg_start + _seg_end) * 0.5
	if _air_mode:
		global_position = mid
	else:
		global_position = mid + Vector3.UP * 0.14
	if absf(dir.normalized().dot(Vector3.UP)) > 0.98:
		look_at(mid + dir.normalized(), Vector3.FORWARD)
	else:
		look_at(mid + dir.normalized(), Vector3.UP)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	var thickness := LANE_THICKNESS_AIR_M if _air_mode else LANE_THICKNESS_GROUND_M
	box.size = Vector3(TRAIL_WIDTH_M, thickness, length)
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.22, 0.14, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.18, 0.1)
	mat.emission_energy_multiplier = 3.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _add_embers() -> void:
	_embers = CPUParticles3D.new()
	_embers.name = "Embers"
	_embers.emitting = true
	_embers.one_shot = false
	_embers.explosiveness = 0.12
	_embers.amount = 48
	_embers.lifetime = 1.8
	_embers.randomness = 0.9
	_embers.direction = Vector3(0.0, 1.0, 0.0)
	_embers.spread = 95.0
	_embers.gravity = Vector3(0.0, -2.5, 0.0)
	_embers.initial_velocity_min = 0.8
	_embers.initial_velocity_max = 4.5
	_embers.scale_amount_min = 2.5
	_embers.scale_amount_max = 6.5
	_embers.color = Color(1.0, 0.35, 0.12, 0.95)
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_embers.local_coords = false
	_embers.material_override = _ember_material()
	var spark := SphereMesh.new()
	spark.radius = 0.22
	spark.height = 0.44
	_embers.mesh = spark
	var mid := (_seg_start + _seg_end) * 0.5
	if _air_mode:
		_embers.global_position = mid
	else:
		_embers.global_position = mid + Vector3.UP * EMBER_LIFT_GROUND_M
	add_child(_embers)


func _ember_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.42, 0.14, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.28, 0.08, 1.0)
	mat.emission_energy_multiplier = 6.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	return mat
