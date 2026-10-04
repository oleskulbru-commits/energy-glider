extends SceneTree

const DebrisBudgetScript := preload("res://scripts/game/debris_budget.gd")
const EnemyHitFragmentVfxScript := preload("res://scripts/vfx/enemy_hit_fragment_vfx.gd")
const CRAWLER_KIT := preload("res://assets/vfx/meshes/enemy_fragments/crawler_fragments.glb")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_no_budget_passthrough()
	await _test_active_cap()
	await _test_kill_reserve()
	await _test_kill_eviction()
	await _test_per_frame_rate_limit()
	if _failed:
		return
	print("Debris budget verification passed.")
	quit(0)


func _test_no_budget_passthrough() -> void:
	var wrapper := EnemyHitFragmentVfxScript.spawn(
		self,
		CRAWLER_KIT,
		Vector3.ZERO,
		Vector3.FORWARD,
		2
	)
	_fail_unless(wrapper != null, "Spawn without budget should succeed")
	await create_timer(0.05).timeout
	_fail_unless(
		_count_rigid_bodies(wrapper) == 2,
		"Spawn without budget should create requested bodies (got %d)" % _count_rigid_bodies(wrapper)
	)
	wrapper.queue_free()


func _test_active_cap() -> void:
	var budget := DebrisBudgetScript.new()
	get_root().add_child(budget)
	await process_frame
	for i in DebrisBudgetScript.MAX_ACTIVE:
		var body := _make_body("CapBody%d" % i)
		budget.register(body, DebrisBudgetScript.Priority.NORMAL)
	_fail_unless(
		budget.active_count() == DebrisBudgetScript.MAX_ACTIVE,
		"Budget should track %d active bodies (got %d)"
		% [DebrisBudgetScript.MAX_ACTIVE, budget.active_count()]
	)
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.NORMAL) == 0,
		"Normal spawn should be blocked at active cap"
	)
	budget.reset()
	for body in get_root().get_children():
		if body is RigidBody3D:
			body.queue_free()


func _test_kill_reserve() -> void:
	var budget := DebrisBudgetScript.new()
	get_root().add_child(budget)
	await process_frame
	var soft_cap := DebrisBudgetScript.MAX_ACTIVE - DebrisBudgetScript.RESERVE_FOR_KILL
	var bodies: Array[RigidBody3D] = []
	for i in soft_cap - 1:
		var body := _make_body("ReserveBody%d" % i)
		bodies.append(body)
		budget.register(body, DebrisBudgetScript.Priority.NORMAL)
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.NORMAL) == 1,
		"Normal spawn should fill up to the kill reserve"
	)
	var last_normal := _make_body("ReserveBodyLast")
	bodies.append(last_normal)
	budget.register(last_normal, DebrisBudgetScript.Priority.NORMAL)
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.NORMAL) == 0,
		"Normal spawn should leave the kill reserve empty"
	)
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.CRIT) == 0,
		"Crit spawn should leave the kill reserve empty"
	)
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.KILL) == 1,
		"Kill spawn should use a reserved slot"
	)
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.DEATH_BURST) == 1,
		"Death burst should use a reserved slot"
	)
	for body in bodies:
		_fail_unless(
			not body.is_queued_for_deletion(),
			"Spawns inside the kill reserve should not evict normal debris"
		)
	for body in bodies:
		body.queue_free()


func _test_kill_eviction() -> void:
	var budget := DebrisBudgetScript.new()
	get_root().add_child(budget)
	await process_frame
	for i in DebrisBudgetScript.MAX_ACTIVE:
		var body := _make_body("EvictBody%d" % i)
		budget.register(body, DebrisBudgetScript.Priority.NORMAL)
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.KILL) == 1,
		"Kill spawn should succeed at cap by evicting low-priority debris"
	)
	var kill_body := _make_body("KillBody")
	budget.register(kill_body, DebrisBudgetScript.Priority.KILL)
	_fail_unless(
		budget.active_count() == DebrisBudgetScript.MAX_ACTIVE,
		"Active count should remain capped after kill eviction (got %d)"
		% budget.active_count()
	)
	for body in get_root().get_children():
		if body is RigidBody3D:
			body.queue_free()


func _test_per_frame_rate_limit() -> void:
	var budget := DebrisBudgetScript.new()
	get_root().add_child(budget)
	await process_frame
	var total := 0
	for i in DebrisBudgetScript.MAX_SPAWN_PER_FRAME + 2:
		total += budget.request_spawn(1, DebrisBudgetScript.Priority.NORMAL)
	_fail_unless(
		total == DebrisBudgetScript.MAX_SPAWN_PER_FRAME,
		"Per-frame spawn limit should allow %d bodies (got %d)"
		% [DebrisBudgetScript.MAX_SPAWN_PER_FRAME, total]
	)
	# Counter resets in _physics_process, which runs after physics_frame and before process_frame.
	await physics_frame
	await process_frame
	_fail_unless(
		budget.request_spawn(1, DebrisBudgetScript.Priority.NORMAL) == 1,
		"Spawn limit should reset on the next physics frame"
	)


func _make_body(name: String) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = name
	get_root().add_child(body)
	return body


func _count_rigid_bodies(node: Node) -> int:
	var count := 0
	if node is RigidBody3D:
		count += 1
	for child in node.get_children():
		count += _count_rigid_bodies(child)
	return count


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
	quit(1)
