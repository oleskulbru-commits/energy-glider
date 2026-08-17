extends SceneTree

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_damage_heal_clamp()
	_verify_hub_edge()
	_verify_knockback_strength()
	print("Player health verification passed.")
	quit(0)


func _verify_damage_heal_clamp() -> void:
	_fail_unless(
		PlayerHealthScript.apply_damage(100, 2) == 98,
		"Contact damage 2 should yield 98 from 100"
	)
	_fail_unless(
		PlayerHealthScript.apply_heal(40, 50) == 90,
		"Tower heal 50 from 40 should yield 90"
	)
	_fail_unless(
		PlayerHealthScript.apply_heal(80, 50) == 100,
		"Heal should clamp at 100"
	)
	_fail_unless(
		PlayerHealthScript.apply_damage(1, 2) == 0,
		"Damage should clamp at 0"
	)
	var health := PlayerHealthScript.new()
	var dealt := {"n": 0}
	health.damaged.connect(func(amount: int) -> void: dealt["n"] = amount)
	# Node needs tree for nothing here — take_damage works without glider.
	health.take_damage(2)
	_fail_unless(dealt["n"] == 2, "damaged signal should emit dealt amount")
	_fail_unless(health.get_current() == 98, "Health should be 98 after take_damage(2)")
	health.free()


func _verify_hub_edge() -> void:
	_fail_unless(
		PlayerHealthScript.should_heal_on_hub_edge(false, true),
		"Entering hub should heal"
	)
	_fail_unless(
		not PlayerHealthScript.should_heal_on_hub_edge(true, true),
		"Staying inside hub should not re-heal"
	)
	_fail_unless(
		not PlayerHealthScript.should_heal_on_hub_edge(true, false),
		"Leaving hub should not heal"
	)
	_fail_unless(
		PlayerHealthScript.should_heal_on_hub_edge(false, true),
		"Re-entering after leave should heal again"
	)


func _verify_knockback_strength() -> void:
	_fail_unless(
		SwarmPillScript.KNOCKBACK_SPEED >= 8.0,
		"Knockback speed should be strong (got %s)" % SwarmPillScript.KNOCKBACK_SPEED
	)
	_fail_unless(
		is_equal_approx(SwarmPillScript.DAMAGE_INTERVAL_SEC, 0.5),
		"Contact damage should tick every 0.5s"
	)
	var vel := SwarmPillScript.knockback_velocity_for(
		Vector3.ZERO, Vector3(1.0, 0.0, 0.0)
	)
	_fail_unless(vel.x > 0.0, "Knockback should push away from pill")
	_fail_unless(vel.length() >= 8.0, "Knockback velocity magnitude too low")
	var impulse := SwarmPillScript.knockback_impulse_for(
		Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 90.0
	)
	_fail_unless(impulse.x > 0.0, "Legacy impulse helper should push away")


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
