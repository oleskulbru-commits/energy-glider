extends SceneTree

const PlayerHealthScript = preload("res://scripts/player/player_health.gd")
const RunUpgradeStateScript = preload("res://scripts/game/run_upgrade_state.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_damage_heal_clamp()
	_verify_knockback_strength()
	_verify_hp_regen()
	await _verify_health_bonus()
	print("Player health verification passed.")
	quit(0)


func _verify_damage_heal_clamp() -> void:
	_fail_unless(
		PlayerHealthScript.BASE_HEALTH == 50,
		"Base player health should be 50"
	)
	_fail_unless(
		PlayerHealthScript.apply_damage(50, 2) == 48,
		"Contact damage 2 should yield 48 from 50"
	)
	_fail_unless(
		PlayerHealthScript.apply_heal(40, 50) == 50,
		"Heal should clamp at base 50"
	)
	_fail_unless(
		PlayerHealthScript.apply_heal(20, 10, 60) == 30,
		"Heal 10 from 20 should yield 30 when max is 60"
	)
	_fail_unless(
		PlayerHealthScript.apply_damage(1, 2) == 0,
		"Damage should clamp at 0"
	)
	var health := PlayerHealthScript.new()
	var dealt := {"n": 0}
	health.damaged.connect(func(amount: int) -> void: dealt["n"] = amount)
	health.take_damage(2)
	_fail_unless(dealt["n"] == 2, "damaged signal should emit dealt amount")
	_fail_unless(health.get_current() == 48, "Health should be 48 after take_damage(2)")
	health.free()


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
		is_equal_approx(PlayerHealthScript.REGEN_LOCKOUT_SEC, 4.0),
		"Regen lockout should be 4 seconds"
	)
	_fail_unless(
		is_equal_approx(PlayerHealthScript.lockout_on_hit(0.0), 4.0),
		"A hit should start a 4s regen pause"
	)
	_fail_unless(
		is_equal_approx(PlayerHealthScript.lockout_on_hit(0.4), 4.0),
		"Another hit should reset the pause to 4s, not add"
	)
	_fail_unless(
		is_equal_approx(PlayerHealthScript.lockout_on_hit(4.0), 4.0),
		"Regen pause should never exceed 4s"
	)
	var idle: Dictionary = PlayerHealthScript.tick_regen(0.0, 1.0, 0.0, 0.0)
	_fail_unless(int(idle["heal"]) == 0, "0 hp/s should never heal")
	var blocked: Dictionary = PlayerHealthScript.tick_regen(7.0, 4.0, 0.0, 4.0)
	_fail_unless(int(blocked["heal"]) == 0, "Lockout should disable regen")
	_fail_unless(
		is_equal_approx(float(blocked["lockout"]), 0.0),
		"A 4s pause should expire after 4s"
	)
	var resumed: Dictionary = PlayerHealthScript.tick_regen(1.0, 1.0, 0.0, 0.0)
	_fail_unless(int(resumed["heal"]) == 1, "1 hp/s should heal 1 after 1s")
	var partial: Dictionary = PlayerHealthScript.tick_regen(1.0, 0.99, 0.0, 0.0)
	_fail_unless(int(partial["heal"]) == 0, "1 hp/s should not heal before 1s")
	var mid_pause := PlayerHealthScript.lockout_on_hit(0.4)
	var still_paused: Dictionary = PlayerHealthScript.tick_regen(7.0, 0.7, 0.0, mid_pause)
	_fail_unless(int(still_paused["heal"]) == 0, "Reset pause should still block regen")
	_fail_unless(
		float(still_paused["lockout"]) > 3.0,
		"Reset pause should leave more than the leftover 0.4s"
	)
	_fail_unless(
		PlayerHealthScript.apply_heal(49, 5) == 50,
		"Regen should clamp at full health"
	)
	var health := PlayerHealthScript.new()
	health.take_damage(2)
	_fail_unless(
		is_equal_approx(float(health.get("_regen_lockout")), 4.0),
		"take_damage should reset regen lockout to 4s"
	)
	health.free()


func _verify_health_bonus() -> void:
	var state: RunUpgradeState = RunUpgradeStateScript.new()
	root.add_child(state)
	var health: PlayerHealth = PlayerHealthScript.new()
	root.add_child(health)
	await process_frame
	_fail_unless(health.get_max() == 50, "Max health should start at 50")
	_fail_unless(health.get_current() == 50, "Current health should start at 50")
	health.take_damage(30)
	_fail_unless(health.get_current() == 20, "30 damage from 50 should leave 20")
	state.max_health_bonus = 10
	health.add_bonus_health(10)
	_fail_unless(health.get_max() == 60, "Common Health should raise max to 60")
	_fail_unless(health.get_current() == 30, "Common Health should add 10 current (20 -> 30)")
	health.reset_full()
	_fail_unless(health.get_current() == 60, "reset_full should restore full max health")
	_fail_unless(health.get_max() == 60, "reset_full should keep upgraded max health")
	state.max_health_bonus = 0
	health.reset_full()
	_fail_unless(health.get_current() == 50, "reset_full without bonus should restore base 50")
	state.max_health_bonus = 10
	health.add_bonus_health(10)
	_fail_unless(health.get_current() == 60, "Full health plus common should become 60/60")
	_fail_unless(health.get_max() == 60, "Full health plus common should raise max to 60")
	state.free()
	health.free()


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
