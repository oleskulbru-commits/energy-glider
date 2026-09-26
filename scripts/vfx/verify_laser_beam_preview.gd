extends SceneTree

const PreviewScenePath := "res://scenes/test/laser_beam_test.tscn"
const PreviewScript := preload("res://scripts/vfx/laser_beam_preview.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(PreviewScenePath) as PackedScene
	if packed == null:
		push_error("Laser beam preview scene failed to load.")
		quit(1)
		return
	var root := packed.instantiate()
	root.name = "LaserBeamTest"
	get_root().add_child(root)
	await process_frame
	var preview := root.find_child("LaserBeamPreview", true, false) as PreviewScript
	if preview == null:
		push_error("LaserBeamPreview node not found.")
		quit(1)
		return
	if preview._glow_mesh == null or preview._core_mesh == null:
		push_error("Preview ribbons were not created.")
		quit(1)
		return
	if not preview._glow_mesh.visible:
		push_error("Preview glow ribbon should be visible.")
		quit(1)
		return
	var length := preview._beam_start().distance_to(preview._beam_end())
	if length < 40.0:
		push_error("Preview beam should be at least 40 m long (got %.1f)." % length)
		quit(1)
		return
	print("Laser beam preview verification passed.")
	quit(0)
