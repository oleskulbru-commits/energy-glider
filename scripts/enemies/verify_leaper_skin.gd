extends SceneTree

const LeaperPillScene := preload("res://scenes/enemies/leaper_pill.tscn")
const TerrainManagerScript := preload("res://scripts/terrain/terrain_manager.gd")

var _ok := true

const REQUIRED_CLIPS := [
	&"Leaper_ClimbUp",
	&"Leaper_Start_Run",
	&"Leaper_Run",
	&"Leaper_StopRun",
	&"Leaper_Jump",
	&"Leaper_Air",
	&"Leaper_Landing",
	&"Leaper_StandUp",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain: TerrainManager = TerrainManagerScript.new()
	root.add_child(terrain)

	var pill: LeaperPill = LeaperPillScene.instantiate() as LeaperPill
	root.add_child(pill)

	var target := Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(10.0, 0.0, 0.0)
	pill.configure(terrain, target)

	await process_frame
	await process_frame

	_fail_unless(pill.get_node_or_null("Visual") != null, "LeaperPill should keep Visual")
	_fail_unless(pill.get_node_or_null("Pill") == null, "LeaperPill should not spawn a capsule mesh")

	var anim := pill.get_node_or_null("Visual/LeaperAnimController") as LeaperAnimController
	_fail_unless(anim != null, "Missing LeaperAnimController")

	var tree := pill.get_node_or_null("Visual/AnimationTree") as AnimationTree
	_fail_unless(tree != null and tree.active, "Leaper AnimationTree should be active")

	var sm := tree.tree_root as AnimationNodeStateMachine
	_fail_unless(sm != null, "Leaper AnimationTree root should be a state machine")
	for state in [
		&"climb", &"start_run", &"run", &"stop_run", &"jump", &"air", &"land", &"stand_up"
	]:
		_fail_unless(sm.has_node(state), "State machine missing node %s" % state)

	_fail_unless(sm.has_transition(&"run", &"stop_run"), "run should travel to stop_run")
	_fail_unless(sm.has_transition(&"start_run", &"stop_run"), "start_run should travel to stop_run")
	_fail_unless(sm.has_transition(&"stop_run", &"jump"), "stop_run should travel to jump")
	_fail_unless(sm.has_transition(&"jump", &"air"), "jump should auto-advance to air")
	_fail_unless(sm.has_transition(&"air", &"land"), "air should travel to land")
	_fail_unless(sm.has_transition(&"land", &"stand_up"), "land should auto-advance to stand_up")
	_fail_unless(sm.has_transition(&"stand_up", &"run"), "stand_up should auto-advance to run")

	var player := pill.get_node_or_null("Visual/Model/AnimationPlayer") as AnimationPlayer
	_fail_unless(player != null, "Missing leaper AnimationPlayer")
	for clip in REQUIRED_CLIPS:
		_fail_unless(player.has_animation(String(clip)), "Missing clip %s" % clip)

	var mesh := pill.find_child("leaper_moidel", true, false) as MeshInstance3D
	_fail_unless(mesh != null, "Missing leaper skinned mesh")
	_fail_unless(mesh.skin != null, "Leaper mesh should have a Skin")

	var model := pill.get_node_or_null("Visual/Model") as Node3D
	_fail_unless(model != null, "Missing Visual/Model")
	_fail_unless(model.scale.x > 1.0, "Leaper model should undo armature shrink")

	var air_streaks := pill.get_node_or_null("Visual/LeaperAirStreaks") as LeaperAirStreaks
	_fail_unless(air_streaks != null, "Leaper skin should include air streaks")

	var col := pill.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_fail_unless(col != null and col.shape is CapsuleShape3D, "Leaper should keep a capsule hitbox")
	var capsule := col.shape as CapsuleShape3D
	_fail_unless(capsule.height > 0.7, "Leaper capsule should stay taller than the crawler")

	if player.has_animation("Leaper_ClimbUp"):
		_fail_unless(anim.is_spawn_active(), "Spawn gate should stay active while ClimbUp plays")
		var waited := 0.0
		while waited < 5.0 and anim.is_spawn_active():
			await create_timer(0.1).timeout
			waited += 0.1
		_fail_unless(not anim.is_spawn_active(), "Spawn gate should unlock after ClimbUp finishes")
	else:
		_fail_unless(not anim.is_spawn_active(), "Spawn gate should unlock when ClimbUp is absent")

	if not _ok:
		return

	var playback := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_fail_unless(playback != null, "Missing state-machine playback")
	var after_spawn := StringName(playback.get_current_node())
	_fail_unless(
		after_spawn == &"start_run" or after_spawn == &"run",
		"Leaper should start run after climb (got %s)" % after_spawn
	)

	anim.play_stop_run()
	var stop_node := await _wait_for_state(playback, [&"stop_run"], 0.6)
	_fail_unless(
		stop_node == &"stop_run",
		"play_stop_run should travel toward stop_run (got %s)" % stop_node
	)

	anim.play_leap(2.0)
	var leap_node := await _wait_for_state(playback, [&"jump", &"air"], 0.6)
	_fail_unless(
		leap_node == &"jump" or leap_node == &"air",
		"play_leap should travel to jump or air (got %s)" % leap_node
	)

	anim.play_land()
	await process_frame
	_fail_unless(anim.is_recover_active(), "play_land should hold recover until stand-up finishes")
	_fail_unless(
		anim.recover_duration() > LeaperPill.RECOVER_SEC,
		"Recover wait should cover land + stand-up clips"
	)

	if air_streaks != null:
		pill.leap_state = LeaperPill.LeapState.LEAP
		pill._leap_origin = pill.global_position
		pill._leap_impact = pill.global_position + Vector3(20.0, 0.0, 0.0)
		pill._leap_t = 0.35
		anim.play_leap(2.0)
		var streak_fx := air_streaks.get_node_or_null("Streaks") as CPUParticles3D
		_fail_unless(streak_fx != null, "Leaper air streaks should spawn a particle emitter")
		var streak_node := await _wait_for_state(playback, [&"jump", &"air"], 0.8)
		_fail_unless(
			streak_node == &"jump" or streak_node == &"air",
			"Streak test should reach jump or air (got %s)" % streak_node
		)
		await process_frame
		await process_frame
		_fail_unless(streak_fx.emitting, "Air streaks should emit during jump/air")
		pill.leap_state = LeaperPill.LeapState.CHASE
		for _i in 12:
			air_streaks.call("_physics_process", 1.0 / 60.0)
			await process_frame
		_fail_unless(not streak_fx.emitting, "Air streaks should stop outside jump/air")

	if not _ok:
		return
	print("Leaper skin / AnimationTree verification passed.")
	quit(0)


func _wait_for_state(
	playback: AnimationNodeStateMachinePlayback, names: Array, timeout_sec: float
) -> StringName:
	var waited := 0.0
	var current := StringName(playback.get_current_node())
	while waited < timeout_sec:
		for name in names:
			if current == name:
				return current
		await process_frame
		waited += 1.0 / 60.0
		current = StringName(playback.get_current_node())
	return current


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_ok = false
	push_error(message)
	quit(1)
