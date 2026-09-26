extends SceneTree

const LaserDroneScene := preload("res://scenes/enemies/rebel_drones/laser_drone.tscn")
const DroneStreakVfxScript := preload("res://scripts/enemies/drone_streak_vfx.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var drone: CharacterBody3D = LaserDroneScene.instantiate() as CharacterBody3D
	var target := Node3D.new()
	root.add_child(target)
	root.add_child(drone)
	drone.configure(null, target)
	await process_frame

	var vfx := drone.get_node_or_null("Visual/Body") as DroneStreakVfxScript
	_fail_unless(vfx != null, "Laser drone should have DroneStreakVfx on Visual/Body")

	var thruster_root := drone.get_node_or_null(
		"Visual/Body/Body/Rebel_Drone/ThrusterStreaks"
	) as Node3D
	var hover_root := drone.get_node_or_null(
		"Visual/Body/Body/Rebel_Drone/HoverStreaks"
	) as Node3D
	_fail_unless(thruster_root != null, "Missing ThrusterStreaks")
	_fail_unless(hover_root != null, "Missing HoverStreaks")

	var thruster_mesh := thruster_root.get_node("Streak") as MeshInstance3D
	var hover_mesh := hover_root.get_node("Streak") as MeshInstance3D
	var thruster_glow := _read_glow(thruster_mesh.material_override)
	var hover_glow := _read_glow(hover_mesh.material_override)
	_fail_unless(
		is_equal_approx(hover_glow, thruster_glow * DroneStreakVfxScript.HOVER_BRIGHTNESS_MULT),
		"Hover GlowStrength should be half thruster (got %.3f, expected %.3f)"
		% [hover_glow, thruster_glow * DroneStreakVfxScript.HOVER_BRIGHTNESS_MULT]
	)
	var thruster_opacity := _read_opacity(thruster_mesh.material_override)
	var hover_opacity := _read_opacity(hover_mesh.material_override)
	_fail_unless(
		is_equal_approx(
			hover_opacity,
			thruster_opacity * DroneStreakVfxScript.HOVER_BRIGHTNESS_MULT
		),
		"Hover opacity should be half thruster (got %.3f, expected %.3f)"
		% [hover_opacity, thruster_opacity * DroneStreakVfxScript.HOVER_BRIGHTNESS_MULT]
	)

	drone.velocity = Vector3.ZERO
	vfx._physics_process(0.016)
	_fail_unless(not thruster_root.visible, "Thruster streaks should be hidden at rest")
	_fail_unless(hover_root.visible, "Hover streaks should stay visible at rest")

	drone.velocity = Vector3(10.0, 0.0, 0.0)
	vfx._physics_process(0.016)
	_fail_unless(thruster_root.visible, "Thruster streaks should show when moving")
	_fail_unless(hover_root.visible, "Hover streaks should stay visible while moving")

	drone.velocity = Vector3(0.2, 0.0, 0.0)
	vfx._physics_process(0.016)
	_fail_unless(
		not thruster_root.visible,
		"Thruster streaks should hide below speed threshold (%.1f m/s)"
		% DroneStreakVfxScript.MOVE_SPEED_THRESHOLD_MPS
	)

	var rebel := vfx.get_rebel_drone()
	_fail_unless(rebel != null, "Rebel_Drone mesh should exist for death emissive test")
	var live_emissive := vfx.get_emissive_energy_multiplier()
	_fail_unless(live_emissive > 0.0, "Live emissive energy should be readable")

	drone.velocity = Vector3(10.0, 0.0, 0.0)
	vfx._physics_process(0.016)
	_fail_unless(thruster_root.visible, "Thrusters should be on before death prep while moving")
	vfx.prepare_for_death()
	_fail_unless(not hover_root.visible, "Hover streaks should hide immediately on death prep")
	_fail_unless(thruster_root.visible, "Thruster streaks should stay visible for debris handoff")
	var death_emissive := vfx.get_emissive_energy_multiplier()
	_fail_unless(
		is_equal_approx(
			death_emissive,
			live_emissive * DroneStreakVfxScript.DEATH_EMISSIVE_ENERGY_MULT
		),
		"Death emissive energy should be ~15%% of live (got %.3f, expected %.3f)"
		% [death_emissive, live_emissive * DroneStreakVfxScript.DEATH_EMISSIVE_ENERGY_MULT]
	)

	if _failed:
		return
	print("Drone streak VFX verification passed.")
	quit(0)


func _read_glow(material: Material) -> float:
	if material is ShaderMaterial:
		return float((material as ShaderMaterial).get_shader_parameter("GlowStrength"))
	return -1.0


func _read_opacity(material: Material) -> float:
	if material is ShaderMaterial:
		var color: Variant = (material as ShaderMaterial).get_shader_parameter("ColorParameter")
		if color is Color:
			return (color as Color).a
	return -1.0


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
	quit(1)
