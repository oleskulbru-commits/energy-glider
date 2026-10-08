extends SceneTree

const ArenaScene := preload("res://scenes/test/leaper_moveset_arena.tscn")
const DirectorScript := preload("res://scripts/enemies/leaper_moveset_director.gd")
const LeaperPillScript := preload("res://scripts/enemies/leaper_pill.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = ArenaScene.instantiate()
	root.add_child(main)

	var arena := main.get_node_or_null("SubViewport/LeaperMovesetArena") as Node3D
	_fail_unless(arena != null, "Missing SubViewport/LeaperMovesetArena")
	_fail_unless(
		arena.get_node_or_null("CrawlerTestSpawner") == null,
		"Moveset arena should not spawn crawlers"
	)
	_fail_unless(
		arena.get_node_or_null("DroneTestSpawner") == null,
		"Moveset arena should not spawn drones"
	)

	var director := arena.get_node_or_null("LeaperMovesetDirector") as DirectorScript
	_fail_unless(director != null, "Missing LeaperMovesetDirector")
	_fail_unless(director.hops_per_dir == 2, "Moveset should hop twice per heading")

	var player := arena.get_node_or_null("PlayerRig") as PlayerRig
	_fail_unless(player != null, "Moveset arena should keep a spectator player")
	_fail_unless(
		arena.get_node_or_null("WeaponSelectMenu") == null,
		"Moveset arena should not offer a weapon pick"
	)
	var upgrades := arena.get_node_or_null("RunUpgradeState") as RunUpgradeState
	_fail_unless(upgrades != null, "Moveset arena should keep empty upgrade state")
	_fail_unless(upgrades.owned_weapon_count() == 0, "Spectator should own no weapons")

	for _i in 60:
		await process_frame
		if director._leaper != null and director._dummy != null:
			break

	var leaper: LeaperPillScript = director._leaper
	if not _fail_unless(leaper != null, "Director did not spawn a leaper"):
		return
	_fail_unless(leaper.practice_lane, "Leaper should run in practice-lane mode")
	_fail_unless(leaper.practice_in_place, "Moveset leaper should stay in place")
	_fail_unless(
		leaper._target == director._dummy,
		"Leaper should seek the dummy, not the player"
	)
	_fail_unless(
		not (leaper._target is GliderPlayer),
		"Practice dummy must not be the glider"
	)
	_fail_unless(
		is_equal_approx(leaper._jump_range_m, LeaperPillScript.LEAP_RANGE_M),
		"Practice hops should use the 200 m baseline"
	)
	var dummy_delta := director._dummy.global_position - leaper.global_position
	_fail_unless(dummy_delta.x > 0.0, "First dummy should sit east of the leaper for facing")
	_fail_unless(
		dummy_delta.length() < LeaperPillScript.LEAP_RANGE_M * 0.5,
		"In-place moveset dummy should stay near the leaper for inspection"
	)

	print("Leaper moveset arena verification passed.")
	quit(0)


func _fail_unless(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
