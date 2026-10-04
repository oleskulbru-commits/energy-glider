extends SceneTree

const TuneScene := preload("res://scenes/test/laser_reticle_tune.tscn")
const ReticleScript := preload("res://scripts/enemies/laser_ground_reticle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := TuneScene.instantiate()
	get_root().add_child(root)

	var tune := root.get_node_or_null("GliderSkin/LaserGroundReticle")
	if tune == null:
		push_error("Tune scene should have GliderSkin/LaserGroundReticle")
		quit(1)
		return

	var spot_before_ready := tune.get_node_or_null("ReticleProjector") as SpotLight3D
	if spot_before_ready == null:
		push_error("Tune scene should include ReticleProjector in the .tscn")
		quit(1)
		return

	await process_frame

	tune = root.get_node_or_null("GliderSkin/LaserGroundReticle")
	if tune == null:
		push_error("Tune scene should have GliderSkin/LaserGroundReticle")
		quit(1)
		return

	var spot := tune.get_node_or_null("ReticleProjector") as SpotLight3D
	if spot == null:
		push_error("Tune scene should spawn ReticleProjector")
		quit(1)
		return

	if not tune.is_in_group("laser_reticle_tune"):
		push_error("Tune node should join laser_reticle_tune group")
		quit(1)
		return

	tune.spot_local_y = -0.5
	tune.spot_local_z = 0.75
	await process_frame
	if not is_equal_approx(tune.position.y, -0.5):
		push_error("spot_local_y export should drive LaserGroundReticle position.y")
		quit(1)
		return
	if not is_equal_approx(tune.position.z, 0.75):
		push_error("spot_local_z export should drive LaserGroundReticle position.z")
		quit(1)
		return

	var source := FileAccess.get_file_as_string("res://scripts/test/laser_reticle_tune.gd")
	if source.find("spot_local_y") == -1:
		push_error("Tune script should expose spot_local_y")
		quit(1)
		return
	if source.find("spot_local_z") == -1:
		push_error("Tune script should expose spot_local_z")
		quit(1)
		return

	if source.find("fmod(_elapsed") == -1 and source.find("loop_telegraph") == -1:
		push_error("Tune script should loop telegraph time")
		quit(1)
		return

	print("Laser reticle tune verification passed.")
	root.queue_free()
	quit(0)
