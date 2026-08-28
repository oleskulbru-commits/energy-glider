extends SceneTree

const OUT_PATH := "res://resources/anims/glider_anim_state_machine.tres"
const XFADE := 0.5
const XFADE_START := 0.05
const SAIL_XFADE := 0.2
const AIR_XFADE := 0.2
const JUMP_ENTER_XFADE := 0.05


func _initialize() -> void:
	var ease := _make_ease_in_out_curve()
	var locomotion := _build_locomotion_state_machine(ease)
	var boost := _build_boost_state_machine(ease)
	var brake := _build_brake_state_machine(ease)
	var body := _build_body_state_machine(locomotion, boost, brake, ease)
	var sail := _build_sail_state_machine(ease)
	var root := _build_root_blend_tree(body, sail)

	var err := ResourceSaver.save(root, OUT_PATH)
	if err != OK:
		push_error("Failed to save anim tree: %s" % err)
		quit(1)
		return

	print("Saved ", OUT_PATH)
	quit(0)


func _build_root_blend_tree(
	body: AnimationNodeStateMachine,
	sail: AnimationNodeStateMachine
) -> AnimationNodeBlendTree:
	# Mast blend filters are applied at runtime on the Blend2 node via GliderAnimLayerFilters.
	var tree := AnimationNodeBlendTree.new()
	var blend := AnimationNodeBlend2.new()
	tree.add_node("body", body, Vector2(0, 0))
	tree.add_node("sail", sail, Vector2(0, 200))
	tree.add_node("blend", blend, Vector2(320, 100))
	tree.connect_node(&"blend", 0, &"body")
	tree.connect_node(&"blend", 1, &"sail")
	tree.connect_node(&"output", 0, &"blend")
	return tree


func _build_body_state_machine(
	locomotion: AnimationNodeStateMachine,
	boost: AnimationNodeStateMachine,
	brake: AnimationNodeStateMachine,
	ease: Curve
) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("grounded", _make_clip("Eve_Idle"), Vector2(0, 0))
	sm.add_node("locomotion", locomotion, Vector2(280, 0))
	sm.add_node("jump", _make_timescaled_one_shot_clip("Eve_Jump"), Vector2(560, -160))
	sm.add_node("glide", _make_loop_clip("Eve_Glide"), Vector2(840, -160))
	sm.add_node("boost", boost, Vector2(560, 0))
	sm.add_node("brake", brake, Vector2(560, 120))
	sm.add_node("landing", _make_clip("Eve_Land"), Vector2(1120, -160))
	sm.add_node("death", _make_clip("Eve_Idle"), Vector2(1400, 0))

	var body_states := [
		"grounded", "locomotion", "jump", "glide", "boost", "brake", "landing", "death",
	]
	for from_state in body_states:
		for to_state in body_states:
			if from_state == to_state:
				continue
			var xfade := _body_transition_xfade(from_state, to_state)
			sm.add_transition(from_state, to_state, _make_transition(xfade, ease))

	var start := _make_transition(XFADE_START, ease)
	sm.add_transition("Start", "grounded", start)
	return sm


func _uses_air_xfade(from_state: String, to_state: String) -> bool:
	var air_states := ["jump", "glide", "landing"]
	return from_state in air_states or to_state in air_states


func _body_transition_xfade(from_state: String, to_state: String) -> float:
	if from_state == "landing":
		return XFADE
	if to_state == "jump" and from_state in ["grounded", "locomotion", "boost", "brake"]:
		return JUMP_ENTER_XFADE
	if to_state == "locomotion" and from_state == "grounded":
		return JUMP_ENTER_XFADE
	if _uses_air_xfade(from_state, to_state):
		return AIR_XFADE
	return XFADE


func _build_sail_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	# Stowed pose is Sail_Deploy t=0 (time_scale=0); avoids Sail_Down vs Sail_Deploy mismatch pops.
	sm.add_node("sail_down", _make_seek_timescaled_clip("Sail_Deploy"), Vector2(0, 0))
	sm.add_node("deploy_forward", _make_seek_timescaled_clip("Sail_Deploy"), Vector2(280, 0))
	sm.add_node("sail_up", _make_loop_clip("Sail_Up"), Vector2(560, 0))
	sm.add_node("deploy_reverse", _make_seek_timescaled_clip("Sail_Deploy"), Vector2(840, 0))

	sm.add_transition("Start", "sail_down", _make_transition(XFADE_START, ease))

	# deploy_forward→sail_up and deploy_reverse→sail_down are driven via start() in SailAnimController.

	for from_state in ["sail_down", "deploy_forward", "sail_up", "deploy_reverse"]:
		for to_state in ["sail_down", "deploy_forward", "sail_up", "deploy_reverse"]:
			if from_state == to_state:
				continue
			sm.add_transition(from_state, to_state, _make_transition(SAIL_XFADE, ease))

	return sm


func _build_locomotion_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("enter", _make_clip("Eve_Idle_To_Forward"), Vector2(-280, 0))
	sm.add_node("forward", _make_timescaled_clip("Eve_Forward"), Vector2(0, 0))
	sm.add_node("turn_left", _make_clip("Eve_Turn_Left"), Vector2(280, -120))
	sm.add_node("turn_right", _make_clip("Eve_Turn_Right"), Vector2(280, 120))
	sm.add_node("strafe_left", _make_timescaled_clip("Eve_Forward"), Vector2(560, -120))
	sm.add_node("strafe_right", _make_timescaled_clip("Eve_Forward"), Vector2(560, 120))

	sm.add_transition("Start", "enter", _make_transition(XFADE_START, ease))
	sm.add_transition("enter", "forward", _make_auto_end_transition(AIR_XFADE, ease))
	sm.add_transition("forward", "turn_left", _make_transition(XFADE, ease))
	sm.add_transition("turn_left", "forward", _make_transition(XFADE, ease))
	sm.add_transition("forward", "turn_right", _make_transition(XFADE, ease))
	sm.add_transition("turn_right", "forward", _make_transition(XFADE, ease))
	sm.add_transition("turn_left", "turn_right", _make_transition(XFADE, ease))
	sm.add_transition("turn_right", "turn_left", _make_transition(XFADE, ease))
	sm.add_transition("forward", "strafe_left", _make_transition(XFADE, ease))
	sm.add_transition("strafe_left", "forward", _make_transition(XFADE, ease))
	sm.add_transition("forward", "strafe_right", _make_transition(XFADE, ease))
	sm.add_transition("strafe_right", "forward", _make_transition(XFADE, ease))
	sm.add_transition("strafe_left", "strafe_right", _make_transition(XFADE, ease))
	sm.add_transition("strafe_right", "strafe_left", _make_transition(XFADE, ease))
	return sm


func _build_brake_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	# Swap enter clip to Eve_Forward_To_Brake when that art lands in the GLB.
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("enter", _make_clip("Eve_Forward"), Vector2(0, 0))
	sm.add_node("loop", _make_timescaled_loop_clip("Eve_Boost"), Vector2(280, 0))

	sm.add_transition("Start", "enter", _make_transition(XFADE_START, ease))
	sm.add_transition("enter", "loop", _make_auto_end_transition(AIR_XFADE, ease))

	for from_state in ["enter", "loop"]:
		for to_state in ["enter", "loop"]:
			if from_state == to_state:
				continue
			if from_state == "enter" and to_state == "loop":
				continue
			sm.add_transition(from_state, to_state, _make_transition(AIR_XFADE, ease))

	return sm


func _build_boost_state_machine(ease: Curve) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("enter", _make_clip("Eve_Forward_To_Boost"), Vector2(0, 0))
	sm.add_node("loop", _make_timescaled_loop_clip("Eve_Boost"), Vector2(280, 0))

	sm.add_transition("Start", "enter", _make_transition(XFADE_START, ease))
	sm.add_transition("enter", "loop", _make_auto_end_transition(AIR_XFADE, ease))

	for from_state in ["enter", "loop"]:
		for to_state in ["enter", "loop"]:
			if from_state == to_state:
				continue
			if from_state == "enter" and to_state == "loop":
				continue
			sm.add_transition(from_state, to_state, _make_transition(AIR_XFADE, ease))

	return sm


func _make_timescaled_loop_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_loop_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("time_scale", time_scale, Vector2(240, 100))
	tree.connect_node(&"time_scale", 0, &"clip")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_one_shot_clip(name: String) -> AnimationNodeAnimation:
	var node := _make_clip(name)
	node.loop_mode = Animation.LOOP_NONE
	return node


func _make_timescaled_one_shot_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_one_shot_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("time_scale", time_scale, Vector2(240, 100))
	tree.connect_node(&"time_scale", 0, &"clip")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_timescaled_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_clip(clip_name)
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("time_scale", time_scale, Vector2(240, 100))
	tree.connect_node(&"time_scale", 0, &"clip")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_seek_timescaled_clip(clip_name: String) -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	var clip := _make_clip(clip_name)
	var seek := AnimationNodeTimeSeek.new()
	var time_scale := AnimationNodeTimeScale.new()
	tree.add_node("clip", clip, Vector2(0, 100))
	tree.add_node("seek", seek, Vector2(240, 100))
	tree.add_node("time_scale", time_scale, Vector2(480, 100))
	tree.connect_node(&"seek", 0, &"clip")
	tree.connect_node(&"time_scale", 0, &"seek")
	tree.connect_node(&"output", 0, &"time_scale")
	return tree


func _make_loop_clip(name: String) -> AnimationNodeAnimation:
	var node := _make_clip(name)
	node.loop_mode = Animation.LOOP_LINEAR
	return node


func _make_clip(name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


func _make_ease_in_out_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0), 0.0, 0.0)
	curve.add_point(Vector2(0.5, 0.5), 1.0, 1.0)
	curve.add_point(Vector2(1.0, 1.0), 0.0, 0.0)
	return curve


func _make_transition(xfade: float, curve: Curve = null) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade
	if curve != null:
		transition.xfade_curve = curve
	return transition


func _make_auto_end_transition(xfade: float, curve: Curve = null) -> AnimationNodeStateMachineTransition:
	var transition := _make_transition(xfade, curve)
	transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	return transition
