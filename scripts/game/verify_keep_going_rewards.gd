extends SceneTree

const KeepGoingRewardsScript = preload("res://scripts/game/keep_going_rewards.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	failed = _check_pay_reveal_and_gold() or failed
	failed = _check_wait_keeps_rolls() or failed
	failed = _check_death_seals_until_next_run() or failed
	failed = _check_bonus_towers() or failed
	failed = _check_vestige_reward() or failed
	failed = _check_icons_only_when_registered() or failed
	if failed:
		push_error("Keep Going reward verification failed")
		quit(1)
		return
	print("Keep Going reward verification passed")
	quit(0)


func _fresh() -> KeepGoingRewards:
	var rewards: KeepGoingRewards = KeepGoingRewardsScript.new()
	rewards.roll_salt = 17
	rewards.set_pool(KeepGoingRewards.TIER_BRONZE, PackedStringArray([&"bronze_a", &"bronze_b"]))
	rewards.set_pool(KeepGoingRewards.TIER_SILVER, PackedStringArray([&"silver_a", &"silver_b"]))
	rewards.set_pool(KeepGoingRewards.TIER_GOLD, PackedStringArray([&"gold_a", &"gold_b"]))
	return rewards


func _check_pay_reveal_and_gold() -> bool:
	var rewards := _fresh()
	if rewards.arrive(1, false) != &"":
		push_error("first arrival paid a reward that was never promised")
		return true
	if rewards.shown_tier(1, false) != KeepGoingRewards.TIER_BRONZE:
		push_error("first tower should show bronze")
		return true
	var bronze := rewards.preview_id(1, false)
	if bronze != rewards.preview_id(1, false):
		push_error("bronze preview changed without a new run")
		return true
	if bronze != &"bronze_a" and bronze != &"bronze_b":
		push_error("bronze preview left the bronze pool")
		return true
	rewards.keep_going(1, false)
	if rewards.promise_tower() != 2:
		push_error("Keep Going should promise the next west tower")
		return true
	if rewards.arrive(5, false) != &"":
		push_error("arriving at the wrong tower paid the promise")
		return true
	if rewards.arrive(2, false) != bronze:
		push_error("arrival should pay the promised bronze reward")
		return true
	if rewards.applied != [&"bronze_a"] and rewards.applied != [&"bronze_b"]:
		push_error("paid bronze was not applied")
		return true
	if rewards.shown_tier(2, false) != KeepGoingRewards.TIER_SILVER:
		push_error("paying bronze should reveal silver")
		return true
	var silver := rewards.preview_id(2, false)
	rewards.keep_going(2, false)
	if rewards.arrive(3, false) != silver:
		push_error("arrival should pay the promised silver reward")
		return true
	if rewards.shown_tier(3, false) != KeepGoingRewards.TIER_GOLD:
		push_error("paying silver should reveal gold")
		return true
	var gold := rewards.preview_id(3, false)
	rewards.keep_going(3, false)
	if rewards.arrive(4, false) != gold:
		push_error("arrival should pay the promised gold reward")
		return true
	if rewards.shown_tier(4, false) != KeepGoingRewards.TIER_BRONZE:
		push_error("paying gold should start a new bronze")
		return true
	if rewards.promise_tower() != -1:
		push_error("a paid promise should be cleared")
		return true
	var next_bronze := rewards.preview_id(4, false)
	if next_bronze != &"bronze_a" and next_bronze != &"bronze_b":
		push_error("the restarted chain should show bronze")
		return true
	rewards.keep_going(40, false)
	if rewards.promise_tower() != -1:
		push_error("tower 40 has no next west tower to promise")
		return true
	if rewards.shown_tier(40, false) != -1:
		push_error("tower 40 should not show another reward")
		return true
	return false


func _check_wait_keeps_rolls() -> bool:
	var rewards := _fresh()
	rewards.keep_going(1, false)
	var bronze := rewards.arrive(2, false)
	var silver := rewards.preview_id(2, false)
	rewards.wait_until_dawn()
	if rewards.promise_tower() != -1:
		push_error("Wait should drop the promise")
		return true
	if rewards.shown_tier(2, false) != KeepGoingRewards.TIER_BRONZE:
		push_error("Wait should return the streak to bronze")
		return true
	if rewards.applied.size() != 1 or rewards.applied[0] != bronze:
		push_error("Wait should leave the reward that was already paid")
		return true
	if rewards.peek_roll(3, KeepGoingRewards.TIER_SILVER) != silver:
		push_error("Wait should keep the silver roll already made")
		return true
	var bronze_again := rewards.preview_id(2, false)
	if bronze_again != rewards.peek_roll(3, KeepGoingRewards.TIER_BRONZE):
		push_error("the bronze roll should stay stable after Wait")
		return true
	rewards.keep_going(6, false)
	rewards.wait_until_dawn()
	if rewards.arrive(7, false) != &"":
		push_error("Wait should stop the next tower from paying")
		return true
	return false


func _check_death_seals_until_next_run() -> bool:
	var rewards := _fresh()
	rewards.keep_going(1, false)
	var before := rewards.preview_id(1, false)
	rewards.note_death()
	if not rewards.is_sealed():
		push_error("death should seal the chain for this trip")
		return true
	if rewards.promise_tower() != -1 or rewards.streak() != KeepGoingRewards.TIER_BRONZE:
		push_error("death should clear the promise and the streak")
		return true
	if rewards.peek_roll(2, KeepGoingRewards.TIER_BRONZE) != &"":
		push_error("death should wipe every roll")
		return true
	if rewards.preview_id(1, false) != &"" or rewards.shown_tier(1, false) != -1:
		push_error("a sealed trip should not roll again")
		return true
	rewards.keep_going(1, false)
	if rewards.promise_tower() != -1 or rewards.arrive(2, false) != &"":
		push_error("a sealed trip should not promise or pay")
		return true
	var next_run: KeepGoingRewards = KeepGoingRewardsScript.new()
	next_run.roll_salt = 17
	next_run.set_pool(KeepGoingRewards.TIER_BRONZE, PackedStringArray([&"bronze_a", &"bronze_b"]))
	var rolled := next_run.preview_id(1, false)
	if rolled == &"" or rolled != before:
		push_error("a new run should roll again")
		return true
	return false


func _check_bonus_towers() -> bool:
	var rewards := _fresh()
	rewards.keep_going(3, false)
	if rewards.arrive(1004, true) != &"":
		push_error("a bonus tower should not pay a west promise")
		return true
	if rewards.promise_tower() != 4:
		push_error("a bonus arrival should leave the west promise in place")
		return true
	rewards.keep_going(1004, true)
	if rewards.promise_tower() != 4:
		push_error("Keep Going at a bonus tower should not replace the west promise")
		return true
	if rewards.shown_tier(1004, true) != -1 or rewards.preview_id(1004, true) != &"":
		push_error("bonus towers should not show a Keep Going reward")
		return true
	if rewards.arrive(4, false) == &"":
		push_error("the west tower should still pay after a bonus stop")
		return true
	return false


func _check_vestige_reward() -> bool:
	var rewards: KeepGoingRewards = KeepGoingRewardsScript.new()
	if rewards.preview_id(1, false) != KeepGoingRewards.VESTIGE:
		push_error("a fresh roller should show the vestige reward")
		return true
	if rewards.icon_for(KeepGoingRewards.VESTIGE) == null:
		push_error("the vestige reward should have its crystal icon")
		return true
	if rewards.amount_for(&"bronze_a", KeepGoingRewards.TIER_BRONZE) != 0:
		push_error("an unknown reward should pay nothing")
		return true
	if not _covers_choices(rewards, KeepGoingRewards.TIER_BRONZE, [1, 2, 3]):
		push_error("bronze vestige should pay 1, 2, or 3 with each amount appearing")
		return true
	if not _covers_choices(rewards, KeepGoingRewards.TIER_SILVER, [4, 5, 6]):
		push_error("silver vestige should pay 4, 5, or 6 with each amount appearing")
		return true
	for _i in 20:
		if rewards.amount_for(KeepGoingRewards.VESTIGE, KeepGoingRewards.TIER_GOLD) != 10:
			push_error("gold vestige should always pay 10")
			return true
	var shown := rewards.preview_amount(8, false)
	if shown < 1 or shown > 3:
		push_error("the bronze square should show 1, 2, or 3 vestiges")
		return true
	if rewards.preview_amount(8, false) != shown:
		push_error("the shown vestige count should stay put")
		return true
	rewards.keep_going(8, false)
	if rewards.arrive(9, false) != KeepGoingRewards.VESTIGE:
		push_error("arrival should pay the promised vestige reward")
		return true
	if rewards.last_payout_amount != shown:
		push_error("arrival should pay the vestige count shown on the square")
		return true
	if rewards.paid_id(9, KeepGoingRewards.TIER_BRONZE, false) != KeepGoingRewards.VESTIGE:
		push_error("the paid bronze square should keep its vestige icon")
		return true
	if rewards.shown_tier(9, false) != KeepGoingRewards.TIER_SILVER:
		push_error("paying bronze vestige should reveal silver")
		return true
	return false


func _covers_choices(rewards: KeepGoingRewards, tier: int, choices: Array) -> bool:
	var seen := {}
	for _i in 90:
		var amount := rewards.amount_for(KeepGoingRewards.VESTIGE, tier)
		if not choices.has(amount):
			return false
		seen[amount] = true
	for choice in choices:
		if not seen.has(choice):
			return false
	return true


func _check_icons_only_when_registered() -> bool:
	var rewards := _fresh()
	var id := rewards.preview_id(1, false)
	if rewards.icon_for(id) != null:
		push_error("a reward should have no icon until one is registered")
		return true
	var texture := PlaceholderTexture2D.new()
	rewards.register_icon(id, texture)
	if rewards.icon_for(id) != texture:
		push_error("a registered reward icon should be returned")
		return true
	if rewards.icon_for(&"missing") != null:
		push_error("an unknown reward should have no icon")
		return true
	return false
