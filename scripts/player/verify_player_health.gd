extends SceneTree

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_damage_heal_clamp()
	_verify_hub_edge()
	_verify_knockback_strength()
	_verify_hp_regen()
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
	_fail_unless(
		not PlayerHealthScript.should_process_hub_heal(false, false, false),
		"First wait for the E.O.N. should not heal at home"
	)
	_fail_unless(
		PlayerHealthScript.should_process_hub_heal(true, true, false),
		"Active run should heal at towers"
	)
	_fail_unless(
		PlayerHealthScript.should_process_hub_heal(false, true, false),
		"Try Again should still heal at towers before picking up the E.O.N. again"
	)
	_fail_unless(
		not PlayerHealthScript.should_process_hub_heal(false, true, true),
		"Death screen should not heal"
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


func _verify_hp_regen() -> void:
	_fail_unless(
		is_equal_approx(PlayerHealthScript.REGEN_LOCKOUT_SEC, 1.0),
		"Regen lockout should be 1 second"
	)
	_fail_unless(
		is_equal_approx(PlayerHealthScript.lockout_on_hit(0.0), 1.0),
		"A hit should start a 1s regen pause"
	)
	_fail_unless(
		is_equal_approx(PlayerHealthScript.lockout_on_hit(0.4), 1.0),
		"Another hit should reset the pause to 1s, not add"
	)
	_fail_unless(
		is_equal_approx(PlayerHealthScript.lockout_on_hit(1.0), 1.0),
		"Regen pause should never exceed 1s"
	)
	var idle: Dictionary = PlayerHealthScript.tick_regen(0.0, 1.0, 0.0, 0.0)
	_fail_unless(int(idle["heal"]) == 0, "0 hp/s should never heal")
	var blocked: Dictionary = PlayerHealthScript.tick_regen(7.0, 1.0, 0.0, 1.0)
	_fail_unless(int(blocked["heal"]) == 0, "Lockout should disable regen")
	_fail_unless(
		is_equal_approx(float(blocked["lockout"]), 0.0),
		"A 1s pause should expire after 1s"
	)
	var resumed: Dictionary = PlayerHealthScript.tick_regen(1.0, 1.0, 0.0, 0.0)
	_fail_unless(int(resumed["heal"]) == 1, "1 hp/s should heal 1 after 1s")
	var partial: Dictionary = PlayerHealthScript.tick_regen(1.0, 0.99, 0.0, 0.0)
	_fail_unless(int(partial["heal"]) == 0, "1 hp/s should not heal before 1s")
	var mid_pause := PlayerHealthScript.lockout_on_hit(0.4)
	var still_paused: Dictionary = PlayerHealthScript.tick_regen(7.0, 0.7, 0.0, mid_pause)
	_fail_unless(int(still_paused["heal"]) == 0, "Reset pause should still block regen")
	_fail_unless(
		float(still_paused["lockout"]) > 0.2,
		"Reset pause should leave more than the leftover 0.4s"
	)
	_fail_unless(
		PlayerHealthScript.apply_heal(99, 5) == 100,
		"Regen should clamp at full health"
	)
	var health := PlayerHealthScript.new()
	health.take_damage(2)
	_fail_unless(
		is_equal_approx(float(health.get("_regen_lockout")), 1.0),
		"take_damage should reset regen lockout to 1s"
	)
	health.free()


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
