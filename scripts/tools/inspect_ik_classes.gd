extends SceneTree


func _init() -> void:
	var fabrik := FABRIK3D.new()
	for prop in fabrik.get_property_list():
		print("FABRIK ", prop.name)
	var two := TwoBoneIK3D.new()
	for prop in two.get_property_list():
		print("TwoBone ", prop.name)
	quit(0)
