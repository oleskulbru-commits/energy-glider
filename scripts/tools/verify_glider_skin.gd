extends SceneTree

const PLAYER_RIG := "res://scenes/player/player_rig.tscn"
const GliderPlayerScript = preload("res://scripts/player/glider_player.gd")
const GliderAnimClipsScript = preload("res://scripts/player/glider_anim_clips.gd")
const GliderFootIkScript = preload("res://scripts/player/glider_foot_ik.gd")
const GliderAnimTreeSchemaScript = preload("res://scripts/tools/glider_anim_tree_schema.gd")
const SAIL_LAYER_PREFIX := "GliderRoot/SailPivot/"
const PIVOT_PATH := "GliderRoot/SailPivot"
const DEPLOY_WAIT_FRAMES := 120
const RETRACT_WAIT_FRAMES := 48
const JUMP_AIR_WAIT_FRAMES := 30
const BOOST_WAIT_FRAMES := 24
const BRAKE_BLEND_WAIT_FRAMES := 36
const TURN_SWAP_WAIT_FRAMES := 240
const TURN_LEAN_WAIT_FRAMES := 60
const STRAFE_LEAN_WAIT_FRAMES := 90
const AIR_STEER_LEAN_WAIT_FRAMES := 96
const EXPECTED_AIR_STEER_LEAN := 0.35
const AIR_LEAN_TOLERANCE := 0.22
const PARAM_SAIL_DOWN_SEEK := "parameters/sail/sail_down/seek/seek_request"
const PARAM_SAIL_DOWN_SCALE := "parameters/sail/sail_down/time_scale/scale"
const PARAM_BLEND_POSITION := "parameters/body/locomotion/move/blend_space/blend_position"
const PARAM_GLIDE_BLEND := "parameters/body/glide/blend_space/blend_position"
const LEG_IK_LEFT_PATH := "Model/GliderRoot/Hero_Rig/Skeleton3D/Left_LegIK"
const LEG_IK_RIGHT_PATH := "Model/GliderRoot/Hero_Rig/Skeleton3D/Right_LegIK"


func _blend_position(tree: AnimationTree) -> Vector2:
	return tree.get(PARAM_BLEND_POSITION) as Vector2


func _glide_blend_position(tree: AnimationTree) -> float:
	return tree.get(PARAM_GLIDE_BLEND) as float


func _assert_blendspace_locomotion(locomotion_sm: AnimationNodeStateMachine) -> void:
	var move_tree := locomotion_sm.get_node(&"move") as AnimationNodeBlendTree
	if move_tree == null:
		push_error("Locomotion move state should be a BlendTree")
		quit(1)
		return
	var blend_space := move_tree.get_node(&"blend_space") as AnimationNodeBlendSpace2D
	if blend_space == null:
		push_error("Locomotion move should contain a BlendSpace2D node")
		quit(1)
		return
	if blend_space.get_blend_point_count() < 5:
		push_error("Locomotion BlendSpace2D should define at least five points")
		quit(1)
		return
	if move_tree.has_node(&"foot_lock"):
		push_error("Locomotion move should not contain legacy foot_lock node")
		quit(1)
		return


func _initialize() -> void:
	var scene: PackedScene = load(PLAYER_RIG)
	var rig: Node = scene.instantiate()
	root.add_child(rig)
	await process_frame
	await process_frame

	var glider: Node = rig.get_node("Glider")
	var skin: Node = glider.get_node("Visual/GliderSkin")
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	if tree == null:
		push_error("AnimationTree missing")
		quit(1)
		return
	if not tree.active:
		push_error("AnimationTree not active")
		quit(1)
		return

	var player := tree.get_node(tree.anim_player) as AnimationPlayer
	if player == null:
		push_error("AnimationPlayer path invalid: %s" % tree.anim_player)
		quit(1)
		return

	for clip_name in GliderAnimClipsScript.ALL_WIRED:
		if not player.has_animation(clip_name):
			push_error("Missing wired clip: %s" % clip_name)
			quit(1)
			return

	var root_playback := tree.get("parameters/body/playback") as AnimationNodeStateMachinePlayback
	if root_playback == null:
		push_error("Body playback missing")
		quit(1)
		return

	var locomotion_playback := tree.get("parameters/body/locomotion/playback") as AnimationNodeStateMachinePlayback
	if locomotion_playback == null:
		push_error("Locomotion playback missing")
		quit(1)
		return

	var boost_playback := tree.get("parameters/body/boost/playback") as AnimationNodeStateMachinePlayback
	if boost_playback == null:
		push_error("Boost playback missing")
		quit(1)
		return

	var schema_errors := GliderAnimTreeSchemaScript.validate(tree)
	for schema_msg in schema_errors:
		push_error(schema_msg)
	if not schema_errors.is_empty():
		quit(1)
		return

	var brake_playback := tree.get("parameters/body/brake/playback") as AnimationNodeStateMachinePlayback
	if brake_playback == null:
		push_error("Brake playback missing")
		quit(1)
		return

	var sail_playback := tree.get("parameters/sail/playback") as AnimationNodeStateMachinePlayback
	if sail_playback == null:
		push_error("Sail playback missing")
		quit(1)
		return

	var blend_amount: Variant = tree.get("parameters/blend/blend_amount")
	if typeof(blend_amount) != TYPE_FLOAT and typeof(blend_amount) != TYPE_NIL:
		push_error("Unexpected blend_amount type")
		quit(1)
		return

	for prop in tree.get_property_list():
		if str(prop.name).contains("surf"):
			push_error("Stale surf parameter still present: %s" % prop.name)
			quit(1)
			return

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	_enter_stowed_sail(tree, sail_playback)
	var foot_ik := skin.get_node_or_null("GliderFootIk") as GliderFootIkScript
	if foot_ik == null:
		push_error("GliderFootIk missing on skin")
		quit(1)
		return
	var left_leg_ik := skin.get_node_or_null(LEG_IK_LEFT_PATH) as TwoBoneIK3D
	var right_leg_ik := skin.get_node_or_null(LEG_IK_RIGHT_PATH) as TwoBoneIK3D
	if left_leg_ik == null or right_leg_ik == null:
		push_error("Hero skeleton missing Left_LegIK / Right_LegIK")
		quit(1)
		return
	for _i in 12:
		await process_frame
	if not foot_ik.is_configured():
		push_error("GliderFootIk failed to configure leg IK gate")
		quit(1)
		return
	if foot_ik.is_active_for_locomotion_move():
		push_error("Leg IK should start inactive before locomotion move gate")
		quit(1)
		return
	if left_leg_ik.active or right_leg_ik.active:
		push_error("TwoBoneIK modifiers should start inactive")
		quit(1)
		return
	foot_ik.set_active_for_locomotion_move(true)
	if not foot_ik.is_active_for_locomotion_move() or not left_leg_ik.active or not right_leg_ik.active:
		push_error("Leg IK should be active during locomotion move")
		quit(1)
		return
	var root_bt := tree.tree_root as AnimationNodeBlendTree
	if root_bt == null:
		push_error("Expected BlendTree root")
		quit(1)
		return

	var blend_node: AnimationNode = root_bt.get_node(&"blend")
	var body_node: AnimationNode = root_bt.get_node(&"body")
	var sail_node: AnimationNode = root_bt.get_node(&"sail")
	if not blend_node.filter_enabled:
		push_error("Blend2 sail filter not applied")
		quit(1)
		return
	if body_node.filter_enabled or sail_node.filter_enabled:
		push_error("Filters must be on Blend2, not body/sail state machines")
		quit(1)
		return

	var deploy_skel: Skeleton3D = skin.get_node("Model/GliderRoot/SailPivot/MastBase/SailDeployRig/Skeleton3D")
	const SOLAR_BONE := "Bone.011"
	var solar_bone_idx := deploy_skel.find_bone(SOLAR_BONE)
	if solar_bone_idx < 0:
		push_error("Solar panel bone %s missing on deploy rig" % SOLAR_BONE)
		quit(1)
		return

	var solar_bone_track := _sample_solar_bone_track_path(player)
	if solar_bone_track == "":
		push_error("Could not find solar bone track in sail clips")
		quit(1)
		return
	if not blend_node.is_path_filtered(NodePath(solar_bone_track)):
		push_error("Blend2 filter missing solar bone track: %s" % solar_bone_track)
		quit(1)
		return

	var sample_sail_path := _sample_sail_track_path(player)
	if sample_sail_path != "" and not blend_node.is_path_filtered(NodePath(sample_sail_path)):
		push_error("Blend2 filter missing sail track path: %s" % sample_sail_path)
		quit(1)
		return

	var mast_joint: Node3D = skin.get_node("Model/GliderRoot/SailPivot/MastBase/MastJoint1")
	var stowed_mast_rot := mast_joint.rotation
	var stowed_solar_rot := deploy_skel.get_bone_pose_rotation(solar_bone_idx)

	var hero_skel: Skeleton3D = skin.get_node("Model/GliderRoot/Hero_Rig/Skeleton3D")
	var spine_idx := maxi(0, hero_skel.find_bone("spine"))
	var spine_rot := hero_skel.get_bone_pose_rotation(spine_idx)
	if spine_rot.is_equal_approx(Quaternion.IDENTITY):
		push_error("Hero skeleton still in bind/T-pose — body layer not reaching Blend2 output")
		quit(1)
		return

	Input.action_press("move_forward")
	var pre_deploy_solar_rot := deploy_skel.get_bone_pose_rotation(solar_bone_idx)
	for i in 8:
		await process_frame
		var cur_sail_state := sail_playback.get_current_node()
		var deploy_pos := sail_playback.get_current_play_position()
		if cur_sail_state != &"deploy_forward" or deploy_pos <= 0.05:
			var stowed_q := Quaternion.from_euler(stowed_mast_rot)
			var current_q := Quaternion.from_euler(mast_joint.rotation)
			if absf(stowed_q.dot(current_q)) < 0.995:
				push_error(
					"Mast should stay stowed until deploy starts (frame %d state=%s pos=%.3f dot=%.3f)" % [
						i, cur_sail_state, deploy_pos, absf(stowed_q.dot(current_q))
					]
				)
				quit(1)
				return
			var solar_q := deploy_skel.get_bone_pose_rotation(solar_bone_idx)
			if absf(stowed_solar_rot.dot(solar_q)) < 0.995:
				push_error(
					"Solar bone should stay stowed until deploy starts (frame %d state=%s dot=%.3f)" % [
						i, cur_sail_state, absf(stowed_solar_rot.dot(solar_q))
					]
				)
				quit(1)
				return
	var deploy_state := sail_playback.get_current_node()
	if deploy_state != &"deploy_forward" and deploy_state != &"sail_up":
		push_error("Sail did not enter deploy on W press (state=%s)" % deploy_state)
		quit(1)
		return

	var reached_sail_up := false
	var prev_solar_rot := pre_deploy_solar_rot
	for _i in DEPLOY_WAIT_FRAMES:
		await process_frame
		var solar_now := deploy_skel.get_bone_pose_rotation(solar_bone_idx)
		if sail_playback.get_current_node() == &"sail_up":
			if absf(prev_solar_rot.dot(solar_now)) < 0.995:
				push_error(
					"Solar bone popped entering sail_up (dot=%.3f)" % absf(prev_solar_rot.dot(solar_now))
				)
				quit(1)
				return
			reached_sail_up = true
			break
		prev_solar_rot = solar_now
	if not reached_sail_up:
		push_error("Sail did not reach sail_up during deploy (state=%s)" % sail_playback.get_current_node())
		quit(1)
		return

	if not player.has_animation("Sail_Up"):
		push_error("Sail_Up clip missing for loop verification")
		quit(1)
		return
	if player.get_animation("Sail_Up").loop_mode != Animation.LOOP_LINEAR:
		push_error("Sail_Up clip should loop linearly during sail_up state")
		quit(1)
		return

	for _i in 12:
		await process_frame

	var deployed_solar_rot := deploy_skel.get_bone_pose_rotation(solar_bone_idx)
	if absf(stowed_solar_rot.dot(deployed_solar_rot)) > 0.999:
		push_error("Solar panel bone did not deploy during sail_up")
		quit(1)
		return

	Input.action_release("move_forward")
	await process_frame
	if sail_playback.get_current_node() == &"sail_down":
		push_error("Sail retract should not snap straight to sail_down from sail_up")
		quit(1)
		return

	var saw_deploy_reverse := false
	var retract_state := &""
	for _i in 240:
		await process_frame
		var node := sail_playback.get_current_node()
		if node == &"deploy_reverse":
			saw_deploy_reverse = true
		retract_state = node
		if node == &"sail_down":
			var retracted_solar_rot := deploy_skel.get_bone_pose_rotation(solar_bone_idx)
			if absf(retracted_solar_rot.dot(stowed_solar_rot)) >= 0.999:
				break

	if not saw_deploy_reverse:
		push_error(
			"Sail retract from sail_up should play deploy_reverse (state=%s)" % retract_state
		)
		quit(1)
		return
	if retract_state != &"sail_down":
		push_error("Sail did not return to sail_down on W release (state=%s)" % retract_state)
		quit(1)
		return

	var retracted_mast_rot := mast_joint.rotation
	if (retracted_mast_rot - stowed_mast_rot).length_squared() > 0.000001:
		push_error("Mast joint did not return to stowed rotation after retract")
		quit(1)
		return

	var retracted_solar_rot := deploy_skel.get_bone_pose_rotation(solar_bone_idx)
	if absf(retracted_solar_rot.dot(stowed_solar_rot)) < 0.999:
		push_error("Solar panel bone did not return to stowed pose after retract")
		quit(1)
		return
	if absf(retracted_solar_rot.dot(deployed_solar_rot)) > 0.999:
		push_error("Solar panel bone still deployed after retract")
		quit(1)
		return

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	Input.action_press("move_forward")
	for _i in 12:
		await process_frame

	Input.action_press("steer_left")
	for _i in TURN_LEAN_WAIT_FRAMES:
		await process_frame

	if locomotion_playback.get_current_node() != &"move":
		push_error("Locomotion should stay on move during turn (state=%s)" % locomotion_playback.get_current_node())
		quit(1)
		return
	if _blend_position(tree).x > -0.25:
		push_error("Locomotion blend should lean left on A press (blend=%s)" % _blend_position(tree))
		quit(1)
		return

	var left_foot_idx := hero_skel.find_bone("mixamorig_LeftFoot")
	var right_foot_idx := hero_skel.find_bone("mixamorig_RightFoot")
	if left_foot_idx < 0 or right_foot_idx < 0:
		push_error("Hero skeleton missing foot bones for foot IK verify")
		quit(1)
		return
	Input.action_release("steer_left")
	await process_frame
	Input.action_press("steer_left")
	for _i in TURN_SWAP_WAIT_FRAMES:
		await process_frame
	Input.action_release("steer_left")
	await process_frame
	Input.action_press("steer_right")
	for _i in TURN_SWAP_WAIT_FRAMES:
		await process_frame

	if locomotion_playback.get_current_node() != &"move":
		push_error("Locomotion should stay on move during turn swap (state=%s)" % locomotion_playback.get_current_node())
		quit(1)
		return
	if _blend_position(tree).x < 0.22:
		push_error("Locomotion blend should lean right after swap (blend=%s)" % _blend_position(tree))
		quit(1)
		return

	var body_sm := body_node as AnimationNodeStateMachine
	var locomotion_sm := body_sm.get_node(&"locomotion") as AnimationNodeStateMachine
	if not locomotion_sm.has_transition(&"enter", &"move"):
		push_error("Locomotion state machine missing enter to move transition")
		quit(1)
		return

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("move_forward")
	for _i in 24:
		await process_frame

	_assert_blendspace_locomotion(locomotion_sm)

	Input.action_release("steer_left")
	Input.action_release("steer_right")
	for _i in TURN_LEAN_WAIT_FRAMES:
		await process_frame

	Input.action_press("strafe_left")
	for _i in STRAFE_LEAN_WAIT_FRAMES:
		await process_frame

	if locomotion_playback.get_current_node() != &"move":
		push_error(
			"Locomotion should stay on move during strafe (state=%s)"
			% locomotion_playback.get_current_node()
		)
		quit(1)
		return
	var strafe_left_blend := _blend_position(tree)
	if strafe_left_blend.x > -0.15 or strafe_left_blend.y < 0.45:
		push_error("Locomotion should strafe left on Q press (blend=%s)" % strafe_left_blend)
		quit(1)
		return

	Input.action_release("strafe_left")
	await process_frame
	Input.action_press("strafe_right")
	for _i in TURN_SWAP_WAIT_FRAMES:
		await process_frame

	if locomotion_playback.get_current_node() != &"move":
		push_error(
			"Locomotion should stay on move during strafe swap (state=%s)"
			% locomotion_playback.get_current_node()
		)
		quit(1)
		return
	var strafe_right_blend := _blend_position(tree)
	if strafe_right_blend.x < 0.22 or strafe_right_blend.y < 0.45:
		push_error("Locomotion should strafe right after swap (blend=%s)" % strafe_right_blend)
		quit(1)
		return

	Input.action_release("strafe_right")
	Input.action_release("move_forward")
	Input.action_release("steer_right")
	for _i in 12:
		await process_frame

	var glider_player := glider as GliderPlayerScript
	if glider_player == null:
		push_error("Glider node is not GliderPlayer")
		quit(1)
		return

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	for _i in 12:
		await process_frame

	Input.action_press("jump")
	await process_frame
	if root_playback.get_current_node() == &"jump":
		push_error(
			"Jump from locomotion should crossfade, not snap on first frame (state=%s)"
			% root_playback.get_current_node()
		)
		quit(1)
		return
	Input.action_release("jump")
	for _i in JUMP_AIR_WAIT_FRAMES:
		await process_frame

	if not glider_player.is_gliding():
		push_error("Jump input did not enter gliding state")
		quit(1)
		return

	var air_body_state := root_playback.get_current_node()
	if air_body_state != &"jump" and air_body_state != &"glide":
		push_error("Body stuck in %s while gliding after jump" % air_body_state)
		quit(1)
		return
	if not foot_ik.is_leg_ik_active() or not left_leg_ik.active or not right_leg_ik.active:
		push_error("Leg IK should stay active during jump / glide (body=%s)" % air_body_state)
		quit(1)
		return

	var glide_node := body_sm.get_node(&"glide")
	if not (glide_node is AnimationNodeBlendTree and (glide_node as AnimationNodeBlendTree).has_node(&"blend_space")):
		push_error("Glide root should use a 1D blend space for air steering")
		quit(1)
		return

	Input.action_press("steer_left")
	for _i in AIR_STEER_LEAN_WAIT_FRAMES:
		await process_frame
	var air_lean := _glide_blend_position(tree)
	if air_lean > -0.12:
		push_error(
			"Glide blend should show subtle left lean while airborne (blend=%s)"
			% air_lean
		)
		quit(1)
		return
	if air_lean < -0.55:
		push_error(
			"Glide blend should not full-turn while airborne (blend=%s)"
			% air_lean
		)
		quit(1)
		return
	if absf(air_lean + EXPECTED_AIR_STEER_LEAN) > AIR_LEAN_TOLERANCE:
		push_error(
			"Glide lean should stay near capped amount (blend=%s expected ~%.2f)"
			% [air_lean, -EXPECTED_AIR_STEER_LEAN]
		)
		quit(1)
		return
	Input.action_release("steer_left")

	Input.action_press("move_forward")
	for _i in 12:
		await process_frame
	if glider_player.is_gliding() and sail_playback.get_current_node() in [&"deploy_forward", &"sail_up"]:
		push_error(
			"Mast should stay stowed while airborne even with W held (state=%s)"
			% sail_playback.get_current_node()
		)
		quit(1)
		return
	Input.action_release("move_forward")

	for state_name in ["jump_charge", "jump", "glide", "landing", "boost", "brake"]:
		if not body_sm.has_node(StringName(state_name)):
			push_error("Body state machine missing node: %s" % state_name)
			quit(1)
			return

	Input.action_press("boost")
	await process_frame
	var air_boost_root := root_playback.get_current_node()
	if air_boost_root == &"boost":
		push_error("Air boost should crossfade from glide, not snap on first frame (state=%s)" % air_boost_root)
		quit(1)
		return

	var saw_air_boost := false
	for _i in BOOST_WAIT_FRAMES:
		await process_frame
		if root_playback.get_current_node() == &"boost":
			saw_air_boost = true
			break

	if not saw_air_boost:
		push_error("Air boost should reach boost root while gliding (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	var saw_air_boost_loop := false
	for _i in BOOST_WAIT_FRAMES:
		await process_frame
		if boost_playback.get_current_node() == &"loop":
			saw_air_boost_loop = true
			break

	if not saw_air_boost_loop:
		push_error("Air boost should snap to loop (state=%s)" % boost_playback.get_current_node())
		quit(1)
		return

	if foot_ik.is_leg_ik_active() or left_leg_ik.active or right_leg_ik.active:
		push_error("Leg IK should be inactive during air boost")
		quit(1)
		return

	for _i in BOOST_WAIT_FRAMES:
		await process_frame

	Input.action_release("boost")
	var saw_glide_after_boost := false
	for _i in BOOST_WAIT_FRAMES:
		await process_frame
		var after_air_boost := root_playback.get_current_node()
		if after_air_boost == &"glide" or after_air_boost == &"jump":
			saw_glide_after_boost = true
			break

	if not saw_glide_after_boost:
		push_error("Body should return to glide/jump after air boost release (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	Input.action_press("brake")
	await process_frame
	var air_brake_root := root_playback.get_current_node()
	if air_brake_root == &"brake":
		push_error("Air brake should crossfade from glide, not snap on first frame (state=%s)" % air_brake_root)
		quit(1)
		return

	var saw_air_brake := false
	for _i in BRAKE_BLEND_WAIT_FRAMES:
		await process_frame
		if root_playback.get_current_node() == &"brake":
			saw_air_brake = true
			break

	if not saw_air_brake:
		push_error("Air brake should reach brake root while gliding (state=%s)" % root_playback.get_current_node())
		quit(1)
		return
	if not foot_ik.is_leg_ik_active() or not left_leg_ik.active or not right_leg_ik.active:
		push_error("Leg IK should stay active during air brake while gliding")
		quit(1)
		return

	Input.action_release("brake")
	Input.action_release("jump")
	for _i in 12:
		await process_frame

	glider_player.reset_for_respawn()
	root_playback.start("locomotion")
	locomotion_playback.start("move")
	for _i in 12:
		await process_frame

	Input.action_press("boost")
	var saw_ground_boost := false
	for _i in BRAKE_BLEND_WAIT_FRAMES:
		await process_frame
		if root_playback.get_current_node() == &"boost":
			saw_ground_boost = true
			break

	if not saw_ground_boost:
		push_error("Body did not enter boost on Shift press (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	var boost_sub := boost_playback.get_current_node()
	if boost_sub != &"enter" and boost_sub != &"loop":
		push_error("Boost nested state unexpected after press (state=%s)" % boost_sub)
		quit(1)
		return
	if not foot_ik.is_leg_ik_active() or not left_leg_ik.active or not right_leg_ik.active:
		push_error("Leg IK should stay active during ground boost")
		quit(1)
		return

	Input.action_release("boost")
	for _i in 90:
		await process_frame
		if root_playback.get_current_node() != &"boost":
			break

	glider_player.reset_for_respawn()
	var anim_controller := skin.get_node("GliderAnimController")
	if anim_controller != null and anim_controller.has_method("reset_animation_state"):
		anim_controller.reset_animation_state()
	for _i in 12:
		await process_frame

	Input.action_press("move_forward")
	Input.action_press("boost")
	for _i in 6:
		await process_frame
	Input.action_release("jump")
	await process_frame
	Input.action_press("jump")
	await process_frame
	if root_playback.get_current_node() == &"jump":
		push_error(
			"Jump from boost should crossfade, not snap on first frame (state=%s)"
			% root_playback.get_current_node()
		)
		quit(1)
		return
	Input.action_release("jump")
	var saw_boost_for_jump := false
	var saw_jump_from_boost := false
	for _i in JUMP_AIR_WAIT_FRAMES:
		await process_frame
		var body_state := root_playback.get_current_node()
		if body_state == &"boost":
			saw_boost_for_jump = true
		if body_state == &"jump":
			saw_jump_from_boost = true
			break
		if (
			glider_player.is_gliding()
			and anim_controller.get_body_root_state() == &"jump"
		):
			saw_jump_from_boost = true
			break
	if not saw_boost_for_jump and not saw_jump_from_boost:
		push_error("Boost-to-jump test needs boost or jump (state=%s)" % root_playback.get_current_node())
		quit(1)
		return
	if not glider_player.is_gliding():
		push_error("Boost-to-jump test needs gliding after jump")
		quit(1)
		return
	if not saw_jump_from_boost:
		push_error(
			"Jump from boost should reach jump with Shift held (state=%s)"
			% root_playback.get_current_node()
		)
		quit(1)
		return

	for _i in 12:
		await process_frame
		var body_state := root_playback.get_current_node()
		if body_state != &"jump" and anim_controller.get_body_root_state() != &"jump":
			push_error(
				"Shift held during jump should not interrupt jump playback (state=%s root=%s)"
				% [body_state, anim_controller.get_body_root_state()]
			)
			quit(1)
			return

	Input.action_release("jump")
	Input.action_release("boost")
	Input.action_release("move_forward")
	glider_player.reset_for_respawn()
	for _i in 12:
		await process_frame

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	glider_player.velocity = Vector3(0.0, 0.0, 8.0)
	for _i in 12:
		await process_frame

	Input.action_press("brake")
	var saw_brake := false
	for _i in BRAKE_BLEND_WAIT_FRAMES:
		await process_frame
		if root_playback.get_current_node() == &"brake":
			saw_brake = true
			break

	if not saw_brake:
		push_error(
			"Body did not enter brake on brake press while moving (state=%s)"
			% root_playback.get_current_node()
		)
		quit(1)
		return

	var brake_sub := brake_playback.get_current_node()
	for _i in BOOST_WAIT_FRAMES:
		await process_frame
		brake_sub = brake_playback.get_current_node()
		if brake_sub == &"loop":
			break
	if brake_sub != &"loop":
		push_error("Brake should reach loop, not enter (state=%s)" % brake_sub)
		quit(1)
		return
	if not foot_ik.is_leg_ik_active() or not left_leg_ik.active or not right_leg_ik.active:
		push_error("Leg IK should stay active during grounded brake loop")
		quit(1)
		return

	for _i in 120:
		await process_frame
		if Vector2(glider_player.velocity.x, glider_player.velocity.z).length() < 0.35:
			break

	# Skin verify has no terrain; simulate coming to rest while brake stays held.
	glider_player.velocity = Vector3.ZERO
	for _i in BRAKE_BLEND_WAIT_FRAMES:
		await process_frame

	if root_playback.get_current_node() == &"brake":
		push_error("Body should leave brake once stopped even if brake is held (state=%s)" % root_playback.get_current_node())
		quit(1)
		return
	if root_playback.get_current_node() != &"grounded":
		push_error("Body should idle once stopped with brake held (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	Input.action_release("brake")

	glider_player.reset_for_respawn()
	var anim_controller_charge := skin.get_node("GliderAnimController")
	if anim_controller_charge != null and anim_controller_charge.has_method("reset_animation_state"):
		anim_controller_charge.reset_animation_state()
	for _i in 12:
		await process_frame

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	for _i in 12:
		await process_frame

	glider_player.use_jump_hold_release = true
	Input.action_press("jump")
	for _i in 18:
		await process_frame
	if root_playback.get_current_node() != &"jump_charge":
		push_error(
			"Held jump should enter jump_charge before release (state=%s)"
			% root_playback.get_current_node()
		)
		quit(1)
		return
	Input.action_release("jump")
	await process_frame
	for _i in JUMP_AIR_WAIT_FRAMES:
		await process_frame
	if not glider_player.is_gliding():
		push_error("Jump charge release did not enter gliding state")
		quit(1)
		return
	if root_playback.get_current_node() != &"jump" and root_playback.get_current_node() != &"glide":
		push_error(
			"Jump charge release should reach jump or glide (state=%s)"
			% root_playback.get_current_node()
		)
		quit(1)
		return

	Input.action_release("jump")
	glider_player.use_jump_hold_release = false
	glider_player.reset_for_respawn()
	var anim_controller_br := skin.get_node("GliderAnimController")
	if anim_controller_br != null and anim_controller_br.has_method("reset_animation_state"):
		anim_controller_br.reset_animation_state()
	for _i in 12:
		await process_frame

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	glider_player.velocity = Vector3(0.0, 0.0, 8.0)
	for _i in 12:
		await process_frame

	Input.action_press("move_forward")
	Input.action_press("brake")
	for _i in BRAKE_BLEND_WAIT_FRAMES:
		await process_frame
		if root_playback.get_current_node() == &"brake" and brake_playback.get_current_node() == &"loop":
			break

	if root_playback.get_current_node() != &"brake":
		push_error("Brake release test needs brake root while moving (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	Input.action_release("brake")
	var saw_warmed_locomotion := false
	for _i in 12:
		await process_frame
		var loco_node := locomotion_playback.get_current_node()
		if loco_node != &"Start" and loco_node != StringName():
			saw_warmed_locomotion = true
			break

	if not saw_warmed_locomotion:
		push_error(
			"Brake release at speed should warm locomotion during root crossfade (loco=%s root=%s)"
			% [locomotion_playback.get_current_node(), root_playback.get_current_node()]
		)
		quit(1)
		return

	Input.action_release("move_forward")

	glider_player.reset_for_respawn()
	var anim_controller_ws := skin.get_node("GliderAnimController")
	if anim_controller_ws != null and anim_controller_ws.has_method("reset_animation_state"):
		anim_controller_ws.reset_animation_state()
	for _i in 12:
		await process_frame

	root_playback.start("locomotion")
	locomotion_playback.start("move")
	glider_player.velocity = Vector3(0.0, 0.0, 6.0)
	for _i in 12:
		await process_frame

	Input.action_press("move_forward")
	Input.action_press("brake")
	var locomotion_while_braking := false
	for _i in 150:
		await process_frame
		if root_playback.get_current_node() == &"locomotion":
			var brake_speed := Vector2(glider_player.velocity.x, glider_player.velocity.z).length()
			if brake_speed >= grounded_speed_enter_for_test():
				locomotion_while_braking = true
		glider_player.velocity = glider_player.velocity.lerp(Vector3.ZERO, 0.1)
		if Vector2(glider_player.velocity.x, glider_player.velocity.z).length() < 0.05:
			break

	if locomotion_while_braking:
		push_error("W+S brake should not return to locomotion before stop (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	glider_player.velocity = Vector3.ZERO
	var reached_ws_idle := false
	for _i in 90:
		await process_frame
		if root_playback.get_current_node() == &"grounded":
			reached_ws_idle = true
			break

	if not reached_ws_idle:
		push_error("W+S brake should idle once stopped with both held (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	Input.action_release("move_forward")
	Input.action_release("brake")

	glider_player.reset_for_respawn()
	var anim_controller_idle := skin.get_node("GliderAnimController")
	if anim_controller_idle != null and anim_controller_idle.has_method("reset_animation_state"):
		anim_controller_idle.reset_animation_state()
	for _i in 12:
		await process_frame

	if root_playback.get_current_node() != &"grounded":
		push_error("Idle enter test should start grounded (state=%s)" % root_playback.get_current_node())
		quit(1)
		return

	Input.action_press("move_forward")
	var saw_idle_enter := false
	for _i in 36:
		await process_frame
		if locomotion_playback.get_current_node() == &"enter":
			saw_idle_enter = true
			break

	if not saw_idle_enter:
		push_error(
			"Idle to forward should play enter clip before forward (loco=%s root=%s)"
			% [locomotion_playback.get_current_node(), root_playback.get_current_node()]
		)
		quit(1)
		return

	Input.action_release("move_forward")

	print(
		"AnimationTree OK, body+sail layering, retract, sail_up loop, blendspace turn/strafe, leg IK (loco + ground boost + brake + jump/glide/landing), jump crossfade, jump charge, jump/glide subtle air lean, airborne mast stow, air boost, boost, brake, brake release, air brake blend, W+S brake, and idle enter verified, clips: ",
		player.get_animation_list()
	)
	quit(0)


func grounded_speed_enter_for_test() -> float:
	return 0.3


func _enter_stowed_sail(tree: AnimationTree, sail_playback: AnimationNodeStateMachinePlayback) -> void:
	tree.set(PARAM_SAIL_DOWN_SEEK, 0.0)
	tree.set(PARAM_SAIL_DOWN_SCALE, 0.0)
	sail_playback.start("sail_down")
	tree.advance(0.0)


func _sample_sail_track_path(player: AnimationPlayer) -> String:
	if not player.has_animation("Sail_Deploy"):
		return ""
	var anim: Animation = player.get_animation("Sail_Deploy")
	for i in anim.get_track_count():
		var track_path := str(anim.track_get_path(i))
		var node_path := track_path.split(":")[0]
		if node_path.begins_with(SAIL_LAYER_PREFIX) and node_path != PIVOT_PATH:
			return track_path
	return ""


func _sample_solar_bone_track_path(player: AnimationPlayer) -> String:
	if not player.has_animation("Sail_Deploy"):
		return ""
	var anim: Animation = player.get_animation("Sail_Deploy")
	for i in anim.get_track_count():
		var track_path := str(anim.track_get_path(i))
		if track_path.ends_with(":Bone.011"):
			return track_path
	return ""
