class_name LaserImpactShockwave
extends MeshInstance3D

const DURATION_SEC := 0.35
const START_RING := 0.08
const END_RING := 0.95


func play() -> void:
	scale = Vector3.ONE
	var mat := _ensure_material()
	if mat == null:
		queue_free()
		return
	mat.set_shader_parameter("ring_progress", START_RING)
	mat.set_shader_parameter("fade", 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("ring_progress", v),
		START_RING,
		END_RING,
		DURATION_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("fade", v),
		1.0,
		0.0,
		DURATION_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _ensure_material() -> ShaderMaterial:
	var mat := material_override as ShaderMaterial
	if mat == null and mesh is QuadMesh:
		var quad := mesh as QuadMesh
		if quad.material is ShaderMaterial:
			mat = quad.material as ShaderMaterial
	if mat == null:
		return null
	mat = mat.duplicate() as ShaderMaterial
	material_override = mat
	return mat
