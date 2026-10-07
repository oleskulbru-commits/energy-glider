extends SceneTree

const VestigeDropScript := preload("res://scripts/game/vestige_drop.gd")
const VestigeWalletScript := preload("res://scripts/game/vestige_wallet.gd")
const VestigePickupScript := preload("res://scripts/game/vestige_pickup.gd")
const VestigeBankScript := preload("res://scripts/game/vestige_bank.gd")
const SwarmPillScript := preload("res://scripts/enemies/swarm_pill.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_quota()
	_verify_chance()
	_verify_wallet_spends_on_drop()
	_verify_pull_and_despawn()
	_verify_bank()
	if _failed:
		push_error("Vestige verification failed")
		quit(1)
		return
	print("Vestige verification passed")
	quit(0)


func _verify_quota() -> void:
	_fail_unless(VestigeDropScript.quota_for_level(1) == 1, "Tower 1 should owe 1 vestige")
	_fail_unless(VestigeDropScript.quota_for_level(8) == 8, "Tower 8 should owe 8 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(9) == 2, "Tower 9 should owe 2 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(16) == 9, "Tower 16 should owe 9 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(17) == 3, "Tower 17 should owe 3 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(24) == 10, "Tower 24 should owe 10 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(25) == 4, "Tower 25 should owe 4 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(32) == 11, "Tower 32 should owe 11 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(33) == 5, "Tower 33 should owe 5 vestiges")
	_fail_unless(VestigeDropScript.quota_for_level(40) == 12, "Tower 40 should owe 12 vestiges")


func _verify_chance() -> void:
	_fail_unless(
		is_equal_approx(VestigeDropScript.drop_chance(1, 0), 0.125),
		"The first tower in a band should drop at 12.5%"
	)
	_fail_unless(
		is_equal_approx(VestigeDropScript.drop_chance(8, 0), 0.06),
		"The eighth tower in a band should drop at 6%"
	)
	_fail_unless(
		is_equal_approx(VestigeDropScript.drop_chance(9, 0), 0.125),
		"Tower 9 should use the high chance again"
	)
	_fail_unless(
		is_equal_approx(VestigeDropScript.drop_chance(16, 0), 0.06),
		"Tower 16 should use the low on-budget chance"
	)
	_fail_unless(
		is_equal_approx(VestigeDropScript.drop_chance(1, 1), VestigeDropScript.PITY_CHANCE),
		"After the quota, tower 1 should fall to the pity chance"
	)
	_fail_unless(
		is_equal_approx(VestigeDropScript.drop_chance(9, 2), VestigeDropScript.PITY_CHANCE),
		"After two drops, tower 9 should fall to the pity chance"
	)
	_fail_unless(VestigeDropScript.should_drop(1, 0, 0.124), "A roll under 12.5% should drop")
	_fail_unless(not VestigeDropScript.should_drop(1, 0, 0.125), "A roll at 12.5% should miss")
	_fail_unless(VestigeDropScript.should_drop(1, 1, 0.004), "Pity should still allow a rare drop")
	_fail_unless(not VestigeDropScript.should_drop(1, 1, 0.005), "A roll at the pity chance should miss")


func _verify_wallet_spends_on_drop() -> void:
	var wallet := VestigeWalletScript.new()
	root.add_child(wallet)
	wallet.note_drop(1)
	_fail_unless(wallet.dropped_count(1) == 1, "A drop should spend the tower quota")
	_fail_unless(wallet.get_balance() == 0, "A drop should not enter the wallet before pickup")
	wallet.collect_one()
	_fail_unless(wallet.get_balance() == 1, "Pickup should add one vestige")
	_fail_unless(wallet.dropped_count(1) == 1, "Pickup should not refund the quota")
	wallet.call("_on_dawn")
	_fail_unless(wallet.dropped_count(1) == 0, "Dawn should clear the tower quotas")
	_fail_unless(wallet.get_balance() == 1, "Dawn should keep collected vestiges")
	var sphere := VestigePickupScript.new()
	root.add_child(sphere)
	wallet.call("_on_player_died", Vector3.ZERO)
	_fail_unless(sphere.is_queued_for_deletion(), "Death should clear uncollected spheres")
	_fail_unless(wallet.get_balance() == 1, "Death should keep the collected balance")
	wallet.free()


func _verify_pull_and_despawn() -> void:
	_fail_unless(
		VestigePickupScript.should_commit_pull(10.0, false),
		"A sphere at 10 m should start pulling"
	)
	_fail_unless(
		not VestigePickupScript.should_commit_pull(10.01, false),
		"A sphere past 10 m should stay on the sand"
	)
	_fail_unless(
		VestigePickupScript.should_commit_pull(80.0, true),
		"A pull that has started should stay committed"
	)
	_fail_unless(VestigePickupScript.has_arrived(1.2), "Arrival should collect the sphere")
	_fail_unless(not VestigePickupScript.has_arrived(1.21), "A sphere short of the board should keep flying")
	var facing := Vector3(-1.0, 0.0, 0.0)
	_fail_unless(
		SwarmPillScript.is_behind_facing(Vector3.ZERO, facing, Vector3(400.01, 0.0, 0.0), 400.0),
		"A sphere 400 m behind should despawn"
	)
	_fail_unless(
		not SwarmPillScript.is_behind_facing(Vector3.ZERO, facing, Vector3(400.0, 0.0, 0.0), 400.0),
		"A sphere exactly 400 m behind should still remain"
	)
	_fail_unless(
		not SwarmPillScript.is_behind_facing(Vector3.ZERO, facing, Vector3(-80.0, 0.0, 0.0), 400.0),
		"A sphere ahead of the player should stay"
	)
	_fail_unless(
		not SwarmPillScript.is_behind_facing(Vector3.ZERO, facing, Vector3(0.0, 0.0, 120.0), 400.0),
		"A sphere beside the player should stay"
	)


func _verify_bank() -> void:
	var saved_path: String = VestigeBankScript.save_path
	VestigeBankScript.save_path = "user://vestige_bank_verify.cfg"
	_remove_bank_file("vestige_bank_verify.cfg")
	var first := VestigeWalletScript.new()
	root.add_child(first)
	first.collect_one()
	first.collect_one()
	first.collect_one()
	first.deposit_run()
	_fail_unless(VestigeBankScript.get_total() == 3, "A finished run should add its vestiges to the bank")
	first.deposit_run()
	_fail_unless(VestigeBankScript.get_total() == 3, "Ending the run twice should not bank the same vestiges again")
	var second := VestigeWalletScript.new()
	root.add_child(second)
	second.collect_one()
	second.collect_one()
	second.deposit_run()
	_fail_unless(
		VestigeBankScript.get_total() == 5,
		"The main menu total should include every finished run"
	)
	first.free()
	second.free()
	_remove_bank_file("vestige_bank_verify.cfg")
	VestigeBankScript.save_path = saved_path


func _remove_bank_file(file_name: String) -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(file_name):
		dir.remove(file_name)


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
