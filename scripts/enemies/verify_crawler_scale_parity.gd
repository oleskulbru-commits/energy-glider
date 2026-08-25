extends SceneTree

const SwarmPillScene := preload("res://scenes/enemies/swarm_pill.tscn")
const FRACTURED_SCENE := preload(
	"res://assets/3dmodels/enemies/crawler/crawler_fractured_v001.glb"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pill: SwarmPill = SwarmPillScene.instantiate() as SwarmPill
	pill.set_physics_process(false)
	root.add_child(pill)
	pill.global_position = Vector3(0.0, 1.0, 0.0)

	var model := pill.get_node_or_null("Visual/Model") as Node3D
	_fail_unless(model != null, "SwarmPill should have Visual/Model")

	var living_scale := CrawlerScaleUtil.animated_model_scale(SwarmPill.CRAWLER_LIVING_SCALE)
	var burst_scale := CrawlerScaleUtil.death_burst_scale()
	_fail_unless(
		is_equal_approx(burst_scale, living_scale),
		"Burst scale should match living animated scale (got %.3f, expected %.3f)"
		% [burst_scale, living_scale]
	)

	var living_aabb := CrawlerScaleUtil.combined_mesh_global_aabb(model)
	var fractured: Node3D = FRACTURED_SCENE.instantiate() as Node3D
	root.add_child(fractured)
	fractured.global_transform = CrawlerScaleUtil.death_burst_transform(model)
	fractured.scale = Vector3.ONE * burst_scale
	var burst_aabb := CrawlerScaleUtil.combined_mesh_global_aabb(fractured)
	fractured.free()

	_fail_unless(
		burst_aabb.size.length() >= living_aabb.size.length() * 0.95,
		"Death burst should not render smaller than the living crawler (living %s, burst %s)"
		% [living_aabb.size, burst_aabb.size]
	)

	print(
		"Crawler scale parity verified (living scale %.3f, burst scale %.3f, living %s, burst %s)."
		% [living_scale, burst_scale, living_aabb.size, burst_aabb.size]
	)
	quit(0)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
