class_name LaserSweepLine
extends Node3D

const SweepLineScript := preload("res://scripts/enemies/laser_sweep_line.gd")

## Flat red lane on the sand for fixed-sweep telegraph.

const LIFE_SEC := 0.85
const LANE_WIDTH_M := 2.4
const LANE_THICKNESS_M := 0.08


static func spawn(
	tree: SceneTree,
	start: Vector3,
	end: Vector3,
	life_sec: float = LIFE_SEC
) -> Node3D:
	var line: Node3D = SweepLineScript.new()
	var parent := tree.current_scene if tree != null else null
	if parent == null:
		return line
	parent.add_child(line)
	line.place(start, end, life_sec)
	return line


func place(start: Vector3, end: Vector3, life_sec: float = LIFE_SEC) -> void:
	var dir := end - start
	dir.y = 0.0
	var length := dir.length()
	if length < 0.1:
		queue_free()
		return
	var mid := (start + end) * 0.5
	global_position = mid + Vector3.UP * 0.14
	look_at(mid + dir.normalized(), Vector3.UP)
	_ensure_visual(length)
	set_meta("_life", maxf(life_sec, 0.1))


func _ready() -> void:
	set_meta("_life", LIFE_SEC)


func _physics_process(delta: float) -> void:
	var life: float = float(get_meta("_life", LIFE_SEC))
	life -= delta
	set_meta("_life", life)
	if life <= 0.0:
		queue_free()


func _ensure_visual(length: float) -> void:
	if get_child_count() > 0:
		return
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(LANE_WIDTH_M, LANE_THICKNESS_M, length)
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.22, 0.14, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.18, 0.1)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	add_child(mesh_inst)
