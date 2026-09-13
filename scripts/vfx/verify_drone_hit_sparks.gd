extends SceneTree

const LaserDroneScene := preload("res://scenes/enemies/rebel_drones/laser_drone.tscn")
const DroneDamageSparkVfxScript := preload("res://scripts/vfx/drone_damage_spark_vfx.gd")
const DroneDebrisSparkVfxScript := preload("res://scripts/enemies/drone_debris_spark_vfx.gd")
const DroneHitSparkVfxScript := preload("res://scripts/vfx/drone_hit_spark_vfx.gd")
const DroneStreakVfxScript := preload("res://scripts/enemies/drone_streak_vfx.gd")
const EnemyHitFragmentVfxScript := preload("res://scripts/vfx/enemy_hit_fragment_vfx.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")
const DRONE_FRAGMENT_KIT := preload("res://assets/vfx/meshes/enemy_fragments/drone_fragments.glb")
const SparksTexturePath := "res://assets/vfx/effect_textures/sparks_texture.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_fail_unless(
		not UpgradeCatalogScript.weapon_causes_debris_sand(UpgradeCatalogScript.FAMILY_RIFLE),
		"Drone hit sparks should not use debris landing sand"
	)

	var drone: CharacterBody3D = LaserDroneScene.instantiate() as CharacterBody3D
	var target := Node3D.new()
	root.add_child(target)
	root.add_child(drone)
	drone.configure(null, target)
	await process_frame

	var streak_vfx := drone.get_node_or_null("Visual/Body") as DroneStreakVfxScript
	_fail_unless(streak_vfx != null, "Laser drone should expose DroneStreakVfx on Visual/Body")
	var spark_color := streak_vfx.get_spark_color()
	var streak_mesh := drone.get_node_or_null(
		"Visual/Body/Body/Rebel_Drone/ThrusterStreaks/Streak"
	) as MeshInstance3D
	_fail_unless(streak_mesh != null, "Laser drone should expose thruster streak mesh")
	var streak_mat := streak_mesh.material_override as ShaderMaterial
	_fail_unless(streak_mat != null, "Thruster streak should use ShaderMaterial")
	var expected: Variant = streak_mat.get_shader_parameter("ColorParameter")
	_fail_unless(expected is Color, "Thruster streak should expose ColorParameter")
	_fail_unless(
		spark_color.is_equal_approx(expected),
		"Spark color should match thruster streak (got %s, expected %s)" % [spark_color, expected]
	)

	var wrapper := DroneHitSparkVfxScript.spawn(
		self,
		drone.global_position + Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		spark_color,
		8,
		DroneHitSparkVfxScript.DEFAULT_GLOW_STRENGTH
	)
	_fail_unless(wrapper != null, "DroneHitSparkVfx.spawn should return a wrapper")
	await process_frame
	var burst := wrapper.get_node_or_null("SparkBurst") as GPUParticles3D
	_fail_unless(burst != null, "Spark wrapper should contain GPUParticles3D SparkBurst")
	_fail_unless(burst.amount == 8, "Spark burst amount should match spawn count (got %d)" % burst.amount)
	_fail_unless(
		burst.draw_pass_1 is QuadMesh,
		"Spark burst should render with QuadMesh draw pass"
	)
	_verify_spark_quad(burst.draw_pass_1 as QuadMesh, burst.process_material as ParticleProcessMaterial, "Hit spark burst")

	var combat_source := FileAccess.get_file_as_string("res://scripts/enemies/combat_drone.gd")
	_fail_unless(
		combat_source.find("_try_spawn_hit_sparks") != -1,
		"CombatDrone should override hit spark spawning"
	)
	_fail_unless(
		combat_source.find("_try_spawn_hit_fragments") != -1,
		"CombatDrone should override hit fragment spawning"
	)
	_fail_unless(
		combat_source.find("_ensure_damage_sparks") != -1,
		"CombatDrone should attach damage sparks when wounded"
	)
	_fail_unless(
		combat_source.find("drone_fragments.glb") != -1,
		"CombatDrone should expose drone_fragments hit kit"
	)
	_fail_unless(
		combat_source.find("DroneDeathBurstScript.spawn") == -1,
		"CombatDrone death should not spawn body/weapon DroneDeathBurst debris"
	)
	_fail_unless(
		combat_source.find("CameraImpactShakeScript.request") != -1,
		"CombatDrone death should request camera shake"
	)
	_fail_unless(
		EnemyHitFragmentVfxScript.get_kit_mesh_count(DRONE_FRAGMENT_KIT) == 6,
		"Drone fragment kit should cache 6 meshes (got %d)"
		% EnemyHitFragmentVfxScript.get_kit_mesh_count(DRONE_FRAGMENT_KIT)
	)

	var fragment_bodies_before := _count_rigid_bodies(root)
	_fail_unless(not drone.take_damage(5, Vector3(1.0, 0.0, 0.0)), "First laser drone hit should not kill")
	await process_frame
	_fail_unless(
		_count_rigid_bodies(root) > fragment_bodies_before,
		"Non-lethal drone hit should spawn hit fragment rigid bodies"
	)
	var damage_sparks := drone.get_node_or_null("Visual/DamageSparks") as GPUParticles3D
	_fail_unless(damage_sparks != null, "Wounded drone should spawn Visual/DamageSparks")
	_fail_unless(damage_sparks.emitting, "Damage sparks should be emitting")
	_fail_unless(not damage_sparks.one_shot, "Damage sparks should loop until death")
	_fail_unless(
		damage_sparks.amount == DroneDamageSparkVfxScript.PARTICLE_AMOUNT,
		"Damage sparks amount should match looping preset (got %d, expected %d)"
		% [damage_sparks.amount, DroneDamageSparkVfxScript.PARTICLE_AMOUNT]
	)
	_fail_unless(
		is_equal_approx(damage_sparks.scale.x, 0.25),
		"Damage sparks should compensate Visual 4x scale (got %s)" % damage_sparks.scale
	)
	_verify_spark_quad(
		damage_sparks.draw_pass_1 as QuadMesh,
		damage_sparks.process_material as ParticleProcessMaterial,
		"Damage sparks"
	)

	_fail_unless(drone.take_damage(999, Vector3(1.0, 0.0, 0.0)), "Lethal hit should kill wounded drone")
	await process_frame
	_fail_unless(
		not is_instance_valid(damage_sparks),
		"Damage sparks should be freed on drone death"
	)

	var spark_bodies := _find_sparking_fragment_bodies(root)
	_fail_unless(
		spark_bodies.size() >= 1,
		"Lethal kill should spawn fragment chunks with spark emitters (got %d)" % spark_bodies.size()
	)
	for body in spark_bodies:
		var debris_sparks := body.get_node_or_null("DebrisSparks") as GPUParticles3D
		_fail_unless(debris_sparks != null, "Kill fragment should carry looping DebrisSparks")
		_fail_unless(debris_sparks.emitting, "Kill fragment sparks should emit until ground contact")
		_fail_unless(
			debris_sparks.lifetime >= DroneDamageSparkVfxScript.DEBRIS_PARTICLE_LIFETIME,
			"Kill fragment spark lifetime should use debris tuning (got %s)"
			% debris_sparks.lifetime
		)
		var quad := debris_sparks.draw_pass_1 as QuadMesh
		_fail_unless(quad != null, "Kill fragment sparks should use a QuadMesh draw pass")
		_fail_unless(
			quad.size.y >= DroneDamageSparkVfxScript.debris_spark_length_for_chunk(7.0) * 0.9,
			"Kill fragment spark quads should scale with chunk size (got %s)"
			% quad.size
		)
		_fail_unless(
			_count_nodes_with_script(body, DroneDebrisSparkVfxScript) >= 1,
			"Kill fragment should attach DroneDebrisSparkVfx controller"
		)

	print("Drone hit spark verification passed.")
	quit(0)


func _verify_spark_quad(quad: QuadMesh, proc: ParticleProcessMaterial, label: String) -> void:
	_fail_unless(quad != null, "%s should use QuadMesh draw pass" % label)
	var mat := quad.material as ShaderMaterial
	_fail_unless(mat != null, "%s should use ShaderMaterial" % label)
	var base_tex: Variant = mat.get_shader_parameter("Base_Texture")
	_fail_unless(base_tex is Texture2D, "%s should expose Base_Texture" % label)
	_fail_unless(
		(base_tex as Texture2D).resource_path == SparksTexturePath,
		"%s should use sparks_texture.png (got %s)" % [label, (base_tex as Texture2D).resource_path]
	)
	_fail_unless(
		is_equal_approx(quad.size.y / quad.size.x, DroneHitSparkVfxScript.SPARK_TEX_ASPECT),
		"%s quad should keep 32x16 aspect on mesh height (got %s)" % [label, quad.size]
	)
	_fail_unless(proc != null, "%s should use ParticleProcessMaterial" % label)
	_fail_unless(proc.particle_flag_align_y, "%s should align streaks to velocity" % label)
	_fail_unless(
		is_equal_approx(proc.angle_min, 0.0) and is_equal_approx(proc.angle_max, 0.0),
		"%s should not apply random in-plane spin" % label
	)


func _find_sparking_fragment_bodies(node: Node) -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	if node is RigidBody3D and node.get_node_or_null("DebrisSparks") != null:
		out.append(node as RigidBody3D)
	for child in node.get_children():
		out.append_array(_find_sparking_fragment_bodies(child))
	return out


func _count_rigid_bodies(node: Node) -> int:
	var count := 0
	if node is RigidBody3D:
		count += 1
	for child in node.get_children():
		count += _count_rigid_bodies(child)
	return count


func _count_nodes_with_script(node: Node, script: Script) -> int:
	var count := 0
	if node.get_script() == script:
		count += 1
	for child in node.get_children():
		count += _count_nodes_with_script(child, script)
	return count


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
