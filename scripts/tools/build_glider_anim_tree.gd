extends SceneTree

const OUT_PATH := "res://resources/anims/glider_anim_state_machine.tres"
const XFADE := 0.5
const BOOST_TIME_SCALE := 1.35


func _initialize() -> void:
	var locomotion := _build_locomotion_state_machine()
	var root := _build_root_state_machine(locomotion)

	var err := ResourceSaver.save(root, OUT_PATH)
	if err != OK:
		push_error("Failed to save anim tree: %s" % err)
		quit(1)
		return

	print("Saved ", OUT_PATH)
	quit(0)


func _build_root_state_machine(locomotion: AnimationNodeStateMachine) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("grounded", _make_clip("Eve_Idle"), Vector2(0, 0))
	sm.add_node("locomotion", locomotion, Vector2(280, 0))
	sm.add_node("boost", _make_timescaled_clip("Eve_Forward"), Vector2(560, 0))
	sm.add_node("brake", _make_clip("Eve_Brake"), Vector2(840, 0))
	sm.add_node("landing", _make_clip("Eve_Brake"), Vector2(1120, 0))
	sm.add_node("death", _make_clip("Eve_Idle"), Vector2(1400, 0))

	for from_state in ["grounded", "locomotion", "boost", "brake", "landing", "death"]:
		for to_state in ["grounded", "locomotion", "boost", "brake", "landing", "death"]:
			if from_state == to_state:
				continue
			sm.add_transition(from_state, to_state, _make_transition())

	var start := _make_transition(0.05)
	sm.add_transition("Start", "grounded", start)
	return sm


func _build_locomotion_state_machine() -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("forward", _make_timescaled_clip("Eve_Forward"), Vector2(0, 0))
	sm.add_node("turn_left", _make_clip("Eve_Turn_Left"), Vector2(280, -120))
	sm.add_node("turn_right", _make_clip("Eve_Turn_Right"), Vector2(280, 120))

	sm.add_transition("Start", "forward", _make_transition(0.05))
	sm.add_transition("forward", "turn_left", _make_transition())
	sm.add_transition("turn_left", "forward", _make_transition())
	sm.add_transition("forward", "turn_right", _make_transition())
	sm.add_transition("turn_right", "forward", _make_transition())
	return sm


func _make_timescaled_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("time_scale", time_scale, Vector2(240, 100))
	tree.connect_node("time_scale", 0, "clip")
	tree.connect_node("output", 0, "time_scale")
	return tree


func _make_clip(name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


func _make_transition(xfade: float = XFADE) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade
	return transition
