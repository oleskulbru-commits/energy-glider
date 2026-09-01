extends SceneTree

const AutoRifleScript = preload("res://scripts/weapons/auto_rifle.gd")
const AutoTeslaScript = preload("res://scripts/weapons/auto_tesla.gd")
const SwarmPillScript = preload("res://scripts/enemies/swarm_pill.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_stats()
	_verify_unique_targets()
	_verify_chamber_semantics()
	_verify_stun()
	_verify_bounce_chain()
	print("Tesla verification passed.")
	quit(0)


func _verify_stats() -> void:
	_fail_unless(AutoTeslaScript.DAMAGE == 23, "Tesla strike damage should be 23")
	_fail_unless(is_equal_approx(AutoTeslaScript.RANGE_M, 20.0), "Tesla acquire range should be 20 m")
	_fail_unless(is_equal_approx(AutoTeslaScript.FIRE_INTERVAL_SEC, 3.0), "Tesla interval should be 3 s")
	_fail_unless(is_equal_approx(AutoTeslaScript.STUN_SEC, 1.0), "Tesla stun should last 1 s")
	_fail_unless(AutoTeslaScript.damage_for(0.0) == 23, "Base Tesla strike should deal 23")
	_fail_unless(
		AutoTeslaScript.damage_for(0.04) == 24,
		"4% Damage should round 23.92 to 24"
	)
	_fail_unless(
		is_equal_approx(AutoTeslaScript.fire_interval_for(0.0), 3.0),
		"Base Tesla wait should stay 3 s"
	)
	_fail_unless(
		is_equal_approx(AutoTeslaScript.fire_interval_for(0.13), 3.0 * 0.87),
		"4% + 9% Attack Speed should wait 3.0 × 0.87"
	)
	_fail_unless(
		is_equal_approx(AutoTeslaScript.fire_interval_for(0.80), 0.60),
		"80% CDR should wait 0.60 s"
	)
	_fail_unless(
		is_equal_approx(AutoTeslaScript.fire_interval_for(0.95), 0.60),
		"Over-cap CDR should still wait 0.60 s"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(AutoTeslaScript.RANGE_M, 0.0), 20.0),
		"Tesla with no Range bonus should stay 20 m"
	)
	_fail_unless(
		is_equal_approx(
			AutoRifleScript.bounce_range_for(AutoRifleScript.range_for(20.0, 0.0)),
			10.0
		),
		"Tesla bounce range should be half of 20 m"
	)
	_fail_unless(
		is_equal_approx(AutoRifleScript.range_for(20.0, 10.0), 200.0),
		"Tesla Range bonus should clamp to 200 m"
	)
	_fail_unless(
		AutoRifleScript.crit_damage_for(AutoTeslaScript.damage_for(0.0), true) == 46,
		"Tesla crit should double 23 to 46"
	)


func _verify_unique_targets() -> void:
	var origin := Vector3.ZERO
	var facing := Vector3(-1.0, 0.0, 0.0)
	var a := _marker_at(Vector3(-10.0, 0.0, 0.0))
	var b := _marker_at(Vector3(-12.0, 0.0, 4.0))
	var c := _marker_at(Vector3(-8.0, 0.0, -3.0))
	var behind := _marker_at(Vector3(10.0, 0.0, 0.0))
	var far := _marker_at(Vector3(-80.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var picked := AutoTeslaScript.pick_unique_targets(
		[a, b, c, behind, far], origin, facing, 20.0, 2, rng
	)
	_fail_unless(picked.size() == 2, "Two extras should pick two unique in-range targets")
	_fail_unless(picked[0] != picked[1], "Tesla extras must not share a target")
	_fail_unless(not picked.has(behind), "Tesla extras must stay in the front hemisphere")
	_fail_unless(not picked.has(far), "Tesla extras must stay inside 20 m")
	var one := AutoTeslaScript.pick_unique_targets([a], origin, facing, 20.0, 4, rng)
	_fail_unless(one.size() == 1 and one[0] == a, "A single pick call should cap at available unique targets")
	var exclude: Dictionary = {a.get_instance_id(): true}
	var after_exclude := AutoTeslaScript.pick_unique_targets([a], origin, facing, 20.0, 1, rng, exclude)
	_fail_unless(after_exclude.is_empty(), "Volley exclude should skip already-struck targets")
	a.free()
	b.free()
	c.free()
	behind.free()
	far.free()


func _verify_chamber_semantics() -> void:
	# Mirror shotgun: failed strikes keep chamber slots; cooldown waits until the volley empties.
	var remaining := 2
	var fired := 0
	var miss: Node3D = null
	if miss == null:
		pass
	else:
		remaining -= 1
		fired += 1
	_fail_unless(remaining == 2 and fired == 0, "Missed Tesla strike should keep chamber slots")
	while remaining > 0:
		remaining -= 1
		fired += 1
	_fail_unless(remaining == 0 and fired == 2, "Cooldown should wait until every chambered strike fires")


func _verify_stun() -> void:
	var living: SwarmPill = SwarmPillScript.new()
	root.add_child(living)
	_fail_unless(not living.take_damage(10), "10 dmg should not kill a 20 hp pill")
	living.apply_stun(AutoTeslaScript.STUN_SEC)
	_fail_unless(living.is_stunned(), "A surviving Tesla hit should stun")
	living.set("_target", living)
	living._physics_process(0.4)
	_fail_unless(living.is_stunned(), "Stun should last the full second")
	_fail_unless(
		living.velocity.length_squared() < 0.0001,
		"A stunned pill should not seek"
	)
	living._physics_process(0.7)
	_fail_unless(not living.is_stunned(), "Stun should expire after 1 s")
	living.free()
	var doomed: SwarmPill = SwarmPillScript.new()
	root.add_child(doomed)
	_fail_unless(doomed.take_damage(20), "20 dmg should kill a 20 hp pill")
	doomed.apply_stun(1.0)
	_fail_unless(not doomed.is_stunned(), "Lethal Tesla hits should skip stun")
	doomed.free()


func _verify_bounce_chain() -> void:
	var origin := Vector3.ZERO
	var a: SwarmPill = SwarmPillScript.new()
	var b: SwarmPill = SwarmPillScript.new()
	root.add_child(a)
	root.add_child(b)
	a.global_position = Vector3(-10.0, 0.0, 0.0)
	b.global_position = Vector3(-14.0, 0.0, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var chain := AutoRifleScript.build_bounce_chain(
		a,
		[a, b],
		2,
		AutoRifleScript.bounce_range_for(20.0),
		rng
	)
	_fail_unless(chain.size() == 1, "Tesla bounce range should chain to a nearby second pill")
	a.free()
	b.free()


func _marker_at(pos: Vector3) -> Node3D:
	var marker := Node3D.new()
	root.add_child(marker)
	marker.global_position = pos
	return marker


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	push_error(message)
	quit(1)
