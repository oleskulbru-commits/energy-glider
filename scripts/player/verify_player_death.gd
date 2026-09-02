extends SceneTree

const GliderScene := preload("res://scenes/player/glider.tscn")
const GliderPlayerScript := preload("res://scripts/player/glider_player.gd")
const GliderPhysicsScript := preload("res://scripts/player/glider_physics.gd")
const TerrainManagerScript := preload("res://scripts/terrain/terrain_manager.gd")
const HeroRagdollScript := preload("res://scripts/player/hero_ragdoll.gd")
const SailAnimControllerScript := preload("res://scripts/player/sail_anim_controller.gd")
const EonDirectorScript := preload("res://scripts/game/eon_director.gd")
const PlayerRigScript := preload("res://scripts/player/player_rig.gd")
const GliderInputScript := preload("res://scripts/input/glider_input.gd")
const SandMaterial := preload("res://assets/materials/sand.tres")
const GROUND_PEN_TOLERANCE := 0.05
const GROUND_CONTACT_FRAMES := 120


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_death_overlay_releases_look()
	await _verify_death_tumble()
	await _verify_sail_retract_on_death()
	await _verify_respawn_restore()
	await _verify_hero_ragdoll_spawn()
	await _verify_hero_ragdoll_ground_contact()
	await _verify_hero_ragdoll_pose_stiffness()
	await _verify_hero_ragdoll_momentum()
	await _verify_hero_ragdoll_pose_parity()
	await _verify_death_ragdoll_respawn_cleanup()
	await _verify_death_camera_follow()
	await _verify_death_ragdoll_persistence()
	await _verify_death_overlay_delay()
	print("Player death verification passed.")
	quit(0)


func _verify_death_overlay_releases_look() -> void:
	var rig: PlayerRig = PlayerRigScript.new()
	rig.name = "PlayerRig"
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.name = "Glider"
	rig.add_child(glider)
	root.add_child(rig)

	var director: EonDirector = EonDirectorScript.new()
	director.death_overlay_delay_sec = 0.0
	director.player_rig_path = rig.get_path()
	root.add_child(director)

	await process_frame
	await process_frame
	await process_frame

	rig.capture_look_mouse()
	_fail_unless(rig.is_look_input_enabled(), "Look should be captured before death")
	glider.end_run("death")
	_fail_unless(director.awaiting_death_choice, "Zero delay should show overlay immediately")
	_fail_unless(
		not rig.is_look_input_enabled(),
		"Death overlay should release look mouse so HUD buttons can be clicked"
	)
	rig.capture_look_mouse()
	_fail_unless(
		not rig.is_look_input_enabled(),
		"Death overlay should block recapturing the mouse"
	)

	director.queue_free()
	rig.queue_free()


func _verify_death_tumble() -> void:
	var terrain := _spawn_terrain("death_tumble")
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	glider.global_position = Vector3(0.0, _hover_y(terrain), 0.0)
	glider.linear_velocity = Vector3(8.0, 2.0, 4.0)
	await process_frame
	var pre_speed := glider.linear_velocity.length()
	glider.end_run("death")
	_fail_unless(glider.is_run_ended(), "Death should end the run")
	_fail_unless(glider.is_death_physics_active(), "Death should enable tumble physics")
	_fail_unless(is_equal_approx(glider.gravity_scale, 1.0), "Death should enable gravity")
	_fail_unless(glider.collision_mask == 1, "Death should collide with terrain")
	_fail_unless(not glider.axis_lock_angular_x, "Death should unlock pitch tumble")
	_fail_unless(not glider.axis_lock_angular_z, "Death should unlock roll tumble")
	_fail_unless(
		glider.linear_velocity.length() >= pre_speed * 0.9,
		"Death should preserve momentum (was %.2f, now %.2f)"
		% [pre_speed, glider.linear_velocity.length()]
	)
	var visual: Node3D = glider.get_node("Visual") as Node3D
	_fail_unless(visual.basis.is_equal_approx(Basis.IDENTITY), "Death should reset visual basis for tumble")
	glider.queue_free()
	terrain.queue_free()


func _verify_sail_retract_on_death() -> void:
	var terrain := _spawn_terrain("sail_retract")
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	glider.global_position = Vector3(0.0, _hover_y(terrain), 0.0)
	await process_frame
	var sail: SailAnimController = glider.get_node(
		"Visual/GliderSkin/SailAnimController"
	) as SailAnimController
	sail.force_retract_for_death()
	await process_frame
	var state := sail.get_sail_state()
	_fail_unless(
		state == &"deploy_reverse" or state == &"sail_down",
		"Sail should retract on death (state=%s)" % state
	)
	glider.end_run("death")
	await process_frame
	state = sail.get_sail_state()
	_fail_unless(
		state == &"deploy_reverse" or state == &"sail_down",
		"Death sequence should keep sail retracting (state=%s)" % state
	)
	glider.queue_free()
	terrain.queue_free()


func _verify_respawn_restore() -> void:
	var terrain := _spawn_terrain("respawn_restore")
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	glider.global_position = Vector3(0.0, _hover_y(terrain), 0.0)
	glider.linear_velocity = Vector3(6.0, 0.0, 3.0)
	await process_frame
	glider.end_run("death")
	await process_frame
	glider.reset_for_respawn()
	_fail_unless(not glider.is_run_ended(), "Respawn should clear run ended")
	_fail_unless(not glider.is_death_physics_active(), "Respawn should disable death physics")
	_fail_unless(is_equal_approx(glider.gravity_scale, 0.0), "Respawn should restore zero gravity")
	_fail_unless(glider.collision_mask == 0, "Respawn should restore collision mask")
	_fail_unless(glider.axis_lock_angular_x, "Respawn should restore pitch lock")
	_fail_unless(glider.axis_lock_angular_z, "Respawn should restore roll lock")
	glider.queue_free()
	terrain.queue_free()


func _verify_hero_ragdoll_spawn() -> void:
	var ragdoll: Node = HeroRagdollScript.spawn(
		self,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)),
		Vector3(1.0, 0.0, 2.0),
		Vector3(0.0, 1.0, 0.5)
	)
	await process_frame
	_fail_unless(ragdoll != null, "Hero ragdoll should spawn")
	_fail_unless(ragdoll.get_physical_bone_count() > 0, "Hero ragdoll should create physical bones")
	_verify_ragdoll_self_collision_masks(ragdoll)
	_verify_ragdoll_joint_setup(ragdoll)
	ragdoll.cleanup()
	await process_frame
	_fail_unless(not is_instance_valid(ragdoll), "Hero ragdoll cleanup should free the node")


func _verify_ragdoll_self_collision_masks(ragdoll: Node) -> void:
	var skel: Skeleton3D = ragdoll.get_node_or_null("Hero_Rig/Skeleton3D") as Skeleton3D
	_fail_unless(skel != null, "Ragdoll should expose Hero_Rig/Skeleton3D for collision checks")
	var expected_mask: int = HeroRagdollScript.RAGDOLL_COLLISION_MASK
	for child in skel.get_children():
		if not child is PhysicalBone3D:
			continue
		var pb := child as PhysicalBone3D
		_fail_unless(
			pb.collision_mask == expected_mask,
			"Ragdoll bone %s should mask terrain and ragdoll layers (got %d, expected %d)"
			% [pb.bone_name, pb.collision_mask, expected_mask]
		)


func _verify_ragdoll_joint_setup(ragdoll: Node) -> void:
	var skel: Skeleton3D = ragdoll.get_node_or_null("Hero_Rig/Skeleton3D") as Skeleton3D
	_fail_unless(skel != null, "Ragdoll should expose Hero_Rig/Skeleton3D for joint checks")
	var bone_count := 0
	for child in skel.get_children():
		if not child is PhysicalBone3D:
			continue
		bone_count += 1
		var pb := child as PhysicalBone3D
		var lower: String = pb.bone_name.to_lower()
		_fail_unless(
			not lower.contains("handthumb") and not lower.contains("handindex"),
			"Finger bones should not get physical collision (%s)" % pb.bone_name
		)
		_fail_unless(
			pb.joint_type != PhysicalBone3D.JOINT_TYPE_PIN,
			"Ragdoll bone %s should not use unconstrained pin joints" % pb.bone_name
		)
		if lower.contains("forearm") or (lower.contains("leg") and not lower.contains("upleg")):
			_fail_unless(
				pb.joint_type == PhysicalBone3D.JOINT_TYPE_HINGE,
				"Elbow/knee bone %s should use hinge joints" % pb.bone_name
			)
			_fail_unless(
				bool(pb.get("joint_constraints/angular_limit_enabled")),
				"Hinge bone %s should enable angular limits" % pb.bone_name
			)
		else:
			_fail_unless(
				pb.joint_type == PhysicalBone3D.JOINT_TYPE_CONE,
				"Ragdoll bone %s should use cone joints (got %d)" % [pb.bone_name, pb.joint_type]
			)
		if lower.contains("hips") or lower.contains("spine"):
			_fail_unless(
				not pb.body_offset.is_equal_approx(Transform3D.IDENTITY),
				"Torso bone %s should use bone-aligned body_offset" % pb.bone_name
			)
		if pb.get("continuous_cd") != null:
			_fail_unless(
				bool(pb.get("continuous_cd")),
				"Ragdoll bone %s should enable continuous CCD" % pb.bone_name
			)
		_fail_unless(
			is_equal_approx(pb.collision_priority, HeroRagdollScript.RAGDOLL_COLLISION_PRIORITY),
			"Ragdoll bone %s should use elevated collision priority" % pb.bone_name
		)
	_fail_unless(bone_count >= 18, "Ragdoll should expose major body bones (got %d)" % bone_count)


func _verify_hero_ragdoll_ground_contact() -> void:
	var terrain := _spawn_terrain("ragdoll_ground")
	var ground_y := terrain.sample_height(0.0, 0.0)
	var spawn_y := ground_y + 2.0
	var ragdoll: HeroRagdoll = HeroRagdollScript.spawn(
		self,
		Transform3D(Basis.IDENTITY, Vector3(0.0, spawn_y, 0.0)),
		Vector3(0.0, -6.0, 0.0),
		Vector3.ZERO
	) as HeroRagdoll
	_fail_unless(ragdoll != null, "Hero ragdoll should spawn for ground contact test")
	for _i in GROUND_CONTACT_FRAMES:
		await physics_frame
	var skel: Skeleton3D = ragdoll.get_node("Hero_Rig/Skeleton3D") as Skeleton3D
	var worst_bone := ""
	var worst_depth := 0.0
	for child in skel.get_children():
		if not child is PhysicalBone3D:
			continue
		var pb := child as PhysicalBone3D
		if not pb.is_simulating_physics():
			continue
		var lowest_y := ragdoll.get_bone_lowest_y(pb)
		var terrain_y := terrain.sample_height(pb.global_position.x, pb.global_position.z)
		var depth := terrain_y - lowest_y
		if depth > worst_depth:
			worst_depth = depth
			worst_bone = pb.bone_name
	_fail_unless(
		worst_depth <= GROUND_PEN_TOLERANCE,
		"Ragdoll bone %s penetrated terrain by %.3f m (tolerance %.3f)"
		% [worst_bone, worst_depth, GROUND_PEN_TOLERANCE]
	)
	ragdoll.cleanup()
	await process_frame
	terrain.queue_free()


func _verify_hero_ragdoll_pose_stiffness() -> void:
	var loose: HeroRagdoll = HeroRagdollScript.new() as HeroRagdoll
	loose.pose_stiffness = 0.0
	_fail_unless(loose != null, "Loose ragdoll should instantiate")
	root.add_child(loose)
	loose.global_transform = Transform3D(Basis.IDENTITY, Vector3(-1.5, 3.0, 0.0))
	loose._build_from_skin()
	loose._cache_spawn_pose()
	loose._start_simulation()
	loose._apply_launch(Vector3(0.0, -3.0, 0.0), Vector3.ZERO)
	_set_deterministic_ragdoll_spin(loose)

	var stiff: HeroRagdoll = HeroRagdollScript.new() as HeroRagdoll
	stiff.pose_stiffness = 0.25
	root.add_child(stiff)
	stiff.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.5, 3.0, 0.0))
	stiff._build_from_skin()
	stiff._cache_spawn_pose()
	stiff._start_simulation()
	stiff._apply_launch(Vector3(0.0, -3.0, 0.0), Vector3.ZERO)
	_set_deterministic_ragdoll_spin(stiff)

	_fail_unless(
		not loose._spawn_bone_basis.is_empty(),
		"Loose ragdoll should cache spawn pose basis"
	)
	_fail_unless(
		is_equal_approx(HeroRagdollScript.new().pose_stiffness, 0.25),
		"Default pose stiffness should be 0.25"
	)

	for _i in 45:
		await physics_frame

	var loose_dev := loose.get_pose_deviation_rad()
	var stiff_dev := stiff.get_pose_deviation_rad()
	_fail_unless(
		stiff_dev < loose_dev,
		"Stiff ragdoll should deviate less from spawn pose (loose=%.3f, stiff=%.3f)"
		% [loose_dev, stiff_dev]
	)

	loose.cleanup()
	stiff.cleanup()
	await process_frame


func _verify_hero_ragdoll_momentum() -> void:
	var input_vel := Vector3(12.0, 1.0, 6.0)
	var ragdoll: HeroRagdoll = HeroRagdollScript.spawn(
		self,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 0.0)),
		input_vel,
		Vector3.ZERO
	) as HeroRagdoll
	_fail_unless(ragdoll != null, "Hero ragdoll should spawn for momentum test")
	await physics_frame
	await physics_frame
	var follow_vel := ragdoll.get_follow_velocity()
	var input_h := Vector2(input_vel.x, input_vel.z).length()
	var follow_h := Vector2(follow_vel.x, follow_vel.z).length()
	_fail_unless(
		follow_h >= input_h * 0.85,
		"Ragdoll should keep horizontal momentum (input=%.2f, got=%.2f)"
		% [input_h, follow_h]
	)
	ragdoll.cleanup()
	await process_frame


func _verify_hero_ragdoll_pose_parity() -> void:
	var terrain := _spawn_terrain("ragdoll_pose")
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	_ensure_glider_input(glider)
	glider.global_position = Vector3(0.0, _hover_y(terrain), 0.0)
	glider.linear_velocity = Vector3(0.0, 0.0, 8.0)
	await process_frame

	var skin: Node3D = glider.get_node("Visual/GliderSkin") as Node3D
	var tree: AnimationTree = skin.get_node("AnimationTree") as AnimationTree
	if tree != null and not tree.active:
		tree.active = true

	Input.action_press("move_forward")
	for i in 60:
		await physics_frame

	var live_skel: Skeleton3D = glider.get_node(
		"Visual/GliderSkin/Model/GliderRoot/Hero_Rig/Skeleton3D"
	) as Skeleton3D
	var spine_idx := maxi(0, live_skel.find_bone("spine"))
	var live_spine_rot := live_skel.get_bone_pose_rotation(spine_idx)
	_fail_unless(
		not live_spine_rot.is_equal_approx(Quaternion.IDENTITY),
		"Pose parity test needs non-T-pose live hero"
	)

	var death_seq: Node = glider.get_node("PlayerDeathSequence")
	death_seq.set("detach_delay_sec", 0.0)
	glider.end_run("death")
	await physics_frame

	var ragdoll: Node = _find_hero_ragdoll(root)
	_fail_unless(ragdoll != null, "Ragdoll should spawn for pose parity test")
	var ragdoll_skel: Skeleton3D = ragdoll.get_node("Hero_Rig/Skeleton3D") as Skeleton3D
	var ragdoll_spine_rot := ragdoll_skel.get_bone_pose_rotation(spine_idx)
	_fail_unless(
		not ragdoll_spine_rot.is_equal_approx(Quaternion.IDENTITY),
		"Ragdoll should not spawn in T-pose when live hero was animated"
	)
	_fail_unless(
		absf(live_spine_rot.dot(ragdoll_spine_rot)) > 0.99,
		"Ragdoll spine should match live hero pose (dot=%.3f)"
		% absf(live_spine_rot.dot(ragdoll_spine_rot))
	)

	Input.action_release("move_forward")
	if ragdoll.has_method("cleanup"):
		ragdoll.cleanup()
	glider.queue_free()
	terrain.queue_free()


func _verify_death_ragdoll_respawn_cleanup() -> void:
	var terrain := _spawn_terrain("ragdoll_cleanup")
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	glider.global_position = Vector3(0.0, _hover_y(terrain), 0.0)
	await process_frame
	var hero: Node3D = glider.get_node("Visual/GliderSkin/Model/GliderRoot/Hero_Rig") as Node3D
	_fail_unless(hero.visible, "Hero should start visible")
	var death_seq: Node = glider.get_node("PlayerDeathSequence")
	death_seq.set("detach_delay_sec", 0.0)
	glider.end_run("death")
	for i in 5:
		await physics_frame
	_fail_unless(not hero.visible, "Hero should hide when ragdoll spawns")
	var ragdoll_count := _count_hero_ragdolls(root)
	_fail_unless(ragdoll_count >= 1, "Death should spawn a hero ragdoll")
	glider.reset_for_respawn()
	await process_frame
	_fail_unless(hero.visible, "Hero should be visible again after respawn")
	_fail_unless(_count_hero_ragdolls(root) == 0, "Respawn should cleanup ragdoll nodes")
	glider.queue_free()
	terrain.queue_free()


func _verify_death_camera_follow() -> void:
	var terrain := _spawn_terrain("death_camera")
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	glider.global_position = Vector3(0.0, _hover_y(terrain), 0.0)
	await process_frame
	var hero: Node3D = glider.get_node("Visual/GliderSkin/Model/GliderRoot/Hero_Rig") as Node3D
	glider.end_run("death")
	await physics_frame
	var target := glider.get_camera_follow_target()
	_fail_unless(target == hero, "Death camera should follow Hero_Rig (got %s)" % target)
	_fail_unless(not glider.get_camera_follow_grounded(), "Death camera should not report grounded")
	glider.queue_free()
	terrain.queue_free()

	var terrain2 := _spawn_terrain("death_camera_ragdoll")
	var glider2: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider2.terrain_manager_path = terrain2.get_path()
	root.add_child(glider2)
	glider2.global_position = Vector3(0.0, _hover_y(terrain2), 0.0)
	glider2.linear_velocity = Vector3(8.0, 1.0, 4.0)
	await process_frame
	var death_seq: Node = glider2.get_node("PlayerDeathSequence")
	death_seq.set("detach_delay_sec", 0.0)
	glider2.end_run("death")
	for i in 5:
		await physics_frame
	target = glider2.get_camera_follow_target()
	var ragdoll: Node = null
	for child in root.get_children():
		if child.get_script() == HeroRagdollScript:
			ragdoll = child
			break
	_fail_unless(ragdoll != null, "Ragdoll should exist for camera follow test")
	var anchor: Node3D = ragdoll.get_camera_anchor() as Node3D
	_fail_unless(
		anchor is PhysicalBone3D,
		"Death camera anchor should be a PhysicalBone3D (got %s)" % anchor
	)
	_fail_unless(
		target != null and target != glider2 and target == anchor,
		"Death camera should follow ragdoll anchor after detach (got %s)" % target
	)
	var anchor_pos: Vector3 = anchor.global_position
	for i in 10:
		await physics_frame
	var moved: bool = anchor.global_position.distance_squared_to(anchor_pos) > 0.01
	_fail_unless(
		moved or glider2.linear_velocity.length_squared() > 0.25,
		"Ragdoll camera anchor should move with physics simulation"
	)
	glider2.reset_for_respawn()
	await process_frame
	_fail_unless(glider2.get_camera_follow_target() == glider2, "Respawn should restore glider camera target")
	glider2.queue_free()
	terrain2.queue_free()


	glider2.queue_free()
	terrain2.queue_free()


func _verify_death_ragdoll_persistence() -> void:
	var terrain := _spawn_terrain("ragdoll_persist")
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	root.add_child(glider)
	glider.global_position = Vector3(0.0, _hover_y(terrain), 0.0)
	await process_frame
	var death_seq: Node = glider.get_node("PlayerDeathSequence")
	death_seq.set("detach_delay_sec", 0.0)
	glider.end_run("death")
	for i in 5:
		await physics_frame
	var ragdoll: Node = _find_hero_ragdoll(root)
	_fail_unless(ragdoll != null, "Death should spawn a ragdoll for persistence test")
	await create_timer(HeroRagdollScript.LIFETIME_SEC + 0.5).timeout
	_fail_unless(
		is_instance_valid(ragdoll),
		"Death ragdoll should persist past auto-expire lifetime when owned by death sequence"
	)
	glider.reset_for_respawn()
	await process_frame
	_fail_unless(_find_hero_ragdoll(root) == null, "Respawn should cleanup persisted ragdoll")
	glider.queue_free()
	terrain.queue_free()


func _verify_death_overlay_delay() -> void:
	var terrain := _spawn_terrain("overlay_delay")
	var rig: PlayerRig = PlayerRigScript.new()
	rig.name = "PlayerRig"
	rig.terrain_manager_path = terrain.get_path()
	var glider: GliderPlayer = GliderScene.instantiate() as GliderPlayer
	glider.terrain_manager_path = terrain.get_path()
	rig.add_child(glider)
	root.add_child(rig)

	var director: EonDirector = EonDirectorScript.new()
	director.death_overlay_delay_sec = 0.2
	director.death_fade_lead_sec = 0.1
	director.player_rig_path = rig.get_path()
	director.terrain_manager_path = terrain.get_path()
	root.add_child(director)

	await process_frame
	await process_frame
	await process_frame

	rig.capture_look_mouse()
	_fail_unless(rig.is_look_input_enabled(), "Look should be captured before death")

	glider.end_run("death")
	_fail_unless(glider.is_run_ended(), "Death should end the run")
	_fail_unless(
		not director.death_fade_active,
		"Death fade should not activate immediately"
	)
	_fail_unless(
		not director.awaiting_death_choice,
		"Death overlay choice should not activate immediately"
	)
	_fail_unless(
		rig.is_look_input_enabled(),
		"Death cinematic should keep look captured until the overlay"
	)

	await create_timer(0.05).timeout
	_fail_unless(
		not director.death_fade_active,
		"Death fade should stay inactive before lead delay"
	)
	_fail_unless(
		not director.awaiting_death_choice,
		"Death overlay choice should stay inactive during delay"
	)

	await create_timer(0.08).timeout
	_fail_unless(
		director.death_fade_active,
		"Death fade should activate before overlay choice"
	)
	_fail_unless(
		not director.awaiting_death_choice,
		"Death overlay choice should still wait after fade starts"
	)
	_fail_unless(
		rig.is_look_input_enabled(),
		"Death fade should not release look before the overlay"
	)

	await create_timer(0.1).timeout
	_fail_unless(
		director.awaiting_death_choice,
		"Death overlay choice should activate after delay"
	)
	_fail_unless(
		not rig.is_look_input_enabled(),
		"Death overlay should release look mouse so HUD buttons can be clicked"
	)
	rig.capture_look_mouse()
	_fail_unless(
		not rig.is_look_input_enabled(),
		"Death overlay should block recapturing the mouse"
	)

	director.queue_free()
	rig.queue_free()
	terrain.queue_free()


func _spawn_terrain(name_suffix: String) -> TerrainManager:
	var terrain: TerrainManager = TerrainManagerScript.new()
	terrain.sand_material = SandMaterial
	terrain.name = "VerifyTerrain_%s" % name_suffix
	root.add_child(terrain)
	return terrain


func _hover_y(terrain: TerrainManager) -> float:
	return terrain.sample_height(0.0, 0.0) + GliderPhysicsScript.BASE_HEIGHT + 0.05


func _count_hero_ragdolls(node: Node) -> int:
	var count := 0
	if node.get_script() == HeroRagdollScript:
		count += 1
	for child in node.get_children():
		count += _count_hero_ragdolls(child)
	return count


func _find_hero_ragdoll(node: Node) -> Node:
	if node.get_script() == HeroRagdollScript:
		return node
	for child in node.get_children():
		var found := _find_hero_ragdoll(child)
		if found != null:
			return found
	return null


func _ensure_glider_input(glider: GliderPlayer) -> GliderInputScript:
	var input := glider.get_node_or_null("GliderInput") as GliderInputScript
	if input != null:
		return input
	input = GliderInputScript.new()
	input.name = "GliderInput"
	glider.add_child(input)
	return input


func _set_deterministic_ragdoll_spin(ragdoll: HeroRagdoll) -> void:
	var skel: Skeleton3D = ragdoll.get_node_or_null("Hero_Rig/Skeleton3D") as Skeleton3D
	if skel == null:
		return
	var spin := Vector3(1.8, 0.6, -1.4)
	for child in skel.get_children():
		if child is PhysicalBone3D:
			(child as PhysicalBone3D).angular_velocity = spin


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
