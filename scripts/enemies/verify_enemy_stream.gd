extends SceneTree

const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_cap_curve()
	_verify_spawn_offset()
	_verify_knockback()
	print("Enemy stream verification passed.")
	quit(0)


func _verify_cap_curve() -> void:
	var prev := -1
	for level in range(1, 41):
		var cap := SwarmPillScript.active_cap_for_level(level)
		_fail_unless(cap >= 8 and cap <= 60, "Cap out of range at level %d: %d" % [level, cap])
		_fail_unless(cap >= prev, "Cap should be non-decreasing (%d -> %d at level %d)" % [prev, cap, level])
		prev = cap
	_fail_unless(SwarmPillScript.active_cap_for_level(1) == 8, "Level 1 cap should be 8")
	_fail_unless(SwarmPillScript.active_cap_for_level(40) == 60, "Level 40 cap should be 60")


func _verify_spawn_offset() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var player_x := 100.0
	for _i in 40:
		var offset: Vector2 = SwarmPillScript.spawn_offset_xz(30.0, 90.0, 55.0, rng)
		var world_x := player_x + offset.x
		_fail_unless(offset.x < 0.0, "Spawn ahead offset X must be negative (west), got %s" % offset.x)
		_fail_unless(world_x < player_x, "Spawn world X must be west of player")
		_fail_unless(absf(offset.y) <= 55.0 + 0.001, "Z offset outside spread: %s" % offset.y)
		_fail_unless(offset.x >= -90.0 - 0.001 and offset.x <= -30.0 + 0.001, "Ahead distance out of range: %s" % offset.x)


func _verify_knockback() -> void:
	var pill := Vector3(0.0, 1.0, 0.0)
	var body := Vector3(2.0, 1.0, 0.0)
	var impulse := SwarmPillScript.knockback_impulse_for(pill, body, 10.0)
	_fail_unless(impulse.x > 0.0, "Knockback should push body away from pill on +X")
	_fail_unless(impulse.y > 0.0, "Knockback should include slight upward")
	var toward_pill := SwarmPillScript.knockback_impulse_for(body, pill, 10.0)
	_fail_unless(toward_pill.x < 0.0, "Symmetric case should push other way")


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
