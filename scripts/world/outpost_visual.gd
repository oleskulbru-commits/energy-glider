extends Node3D

## Tall desert lighthouse outpost — readable from kilometers out.

const TOWER_HEIGHT := 100.0
const BASE_WIDTH := 14.0
const SHAFT_WIDTH := 3.2
const DECK_Y := 58.0
const MID_DISH_Y := 32.0
const UPPER_DISH_Y := 72.0

var _metal: StandardMaterial3D
var _metal_dark: StandardMaterial3D
var _concrete: StandardMaterial3D
var _glass_warm: StandardMaterial3D
var _nav_red: StandardMaterial3D
var _beacon: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_tower()


func _build_materials() -> void:
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.28, 0.29, 0.32)
	_metal.metallic = 0.55
	_metal.roughness = 0.62

	_metal_dark = StandardMaterial3D.new()
	_metal_dark.albedo_color = Color(0.16, 0.17, 0.19)
	_metal_dark.metallic = 0.45
	_metal_dark.roughness = 0.78

	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.40, 0.36, 0.30)
	_concrete.roughness = 0.94

	_glass_warm = StandardMaterial3D.new()
	_glass_warm.albedo_color = Color(0.95, 0.72, 0.28)
	_glass_warm.emission_enabled = true
	_glass_warm.emission = Color(1.0, 0.62, 0.18)
	_glass_warm.emission_energy_multiplier = 4.5
	_glass_warm.roughness = 0.25
	_glass_warm.metallic = 0.05

	_nav_red = StandardMaterial3D.new()
	_nav_red.albedo_color = Color(0.85, 0.08, 0.06)
	_nav_red.emission_enabled = true
	_nav_red.emission = Color(1.0, 0.12, 0.08)
	_nav_red.emission_energy_multiplier = 8.0
	_nav_red.roughness = 0.35

	_beacon = StandardMaterial3D.new()
	_beacon.albedo_color = Color(0.95, 0.95, 1.0)
	_beacon.emission_enabled = true
	_beacon.emission = Color(0.85, 0.92, 1.0)
	_beacon.emission_energy_multiplier = 12.0
	_beacon.roughness = 0.2


func _build_tower() -> void:
	_clear_built()
	_add_pad()
	_add_flared_base()
	_add_lattice_shaft(10.0, DECK_Y - 4.0, SHAFT_WIDTH)
	_add_mid_dish(MID_DISH_Y)
	_add_observation_deck(DECK_Y)
	_add_lattice_shaft(DECK_Y + 4.0, TOWER_HEIGHT - 12.0, SHAFT_WIDTH * 0.72)
	_add_upper_dish(UPPER_DISH_Y)
	_add_antenna_crown(TOWER_HEIGHT - 12.0)
	_add_nav_lights()
	_add_far_silhouette()


func _clear_built() -> void:
	for child in get_children():
		child.queue_free()


func _add_pad() -> void:
	var pad := _box(Vector3(BASE_WIDTH, 0.6, BASE_WIDTH), _concrete)
	pad.position = Vector3(0.0, 0.3, 0.0)
	add_child(pad)

	var ring := _cylinder(BASE_WIDTH * 0.52, BASE_WIDTH * 0.58, 1.2, _metal_dark)
	ring.position = Vector3(0.0, 1.0, 0.0)
	add_child(ring)

	# Entrance block (human scale cue).
	var entry := _box(Vector3(3.2, 3.4, 4.0), _metal_dark)
	entry.position = Vector3(0.0, 2.3, BASE_WIDTH * 0.28)
	add_child(entry)
	var door_glow := _box(Vector3(1.4, 2.2, 0.15), _glass_warm)
	door_glow.position = Vector3(0.0, 2.1, BASE_WIDTH * 0.28 + 2.05)
	add_child(door_glow)

	# Stair wedge cue.
	var stair := _box(Vector3(2.4, 0.35, 5.0), _concrete)
	stair.position = Vector3(4.2, 0.4, 5.5)
	stair.rotation_degrees = Vector3(8.0, -18.0, 0.0)
	add_child(stair)


func _add_flared_base() -> void:
	var flare := _cylinder(SHAFT_WIDTH * 0.7, BASE_WIDTH * 0.38, 8.0, _metal)
	flare.position = Vector3(0.0, 5.5, 0.0)
	add_child(flare)

	for i in 6:
		var angle := float(i) / 6.0 * TAU
		var leg := _box(Vector3(0.55, 9.0, 0.55), _metal_dark)
		var r := BASE_WIDTH * 0.34
		leg.position = Vector3(cos(angle) * r, 5.0, sin(angle) * r)
		leg.rotation_degrees = Vector3(12.0 * cos(angle + PI * 0.5), 0.0, -12.0 * sin(angle + PI * 0.5))
		add_child(leg)


func _add_lattice_shaft(y0: float, y1: float, width: float) -> void:
	var height := y1 - y0
	if height <= 0.5:
		return
	var half := width * 0.5
	var corners := [
		Vector3(-half, 0.0, -half),
		Vector3(half, 0.0, -half),
		Vector3(half, 0.0, half),
		Vector3(-half, 0.0, half),
	]
	for corner in corners:
		var post := _box(Vector3(0.28, height, 0.28), _metal)
		post.position = Vector3(corner.x, y0 + height * 0.5, corner.z)
		add_child(post)

	var ring_count := maxi(int(height / 7.0), 2)
	for i in ring_count + 1:
		var t := float(i) / float(ring_count)
		var y := lerpf(y0, y1, t)
		_add_ring(y, width, 0.18)

	# Cross braces on each face.
	var face_dirs := [
		[Vector3(-half, 0.0, -half), Vector3(half, 0.0, -half)],
		[Vector3(half, 0.0, -half), Vector3(half, 0.0, half)],
		[Vector3(half, 0.0, half), Vector3(-half, 0.0, half)],
		[Vector3(-half, 0.0, half), Vector3(-half, 0.0, -half)],
	]
	for face in face_dirs:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		for i in range(0, ring_count, 2):
			var y_a := lerpf(y0, y1, float(i) / float(ring_count))
			var y_b := lerpf(y0, y1, float(mini(i + 1, ring_count)) / float(ring_count))
			_add_brace(Vector3(a.x, y_a, a.z), Vector3(b.x, y_b, b.z))
			_add_brace(Vector3(b.x, y_a, b.z), Vector3(a.x, y_b, a.z))

	# Cable runs.
	for i in 3:
		var angle := float(i) / 3.0 * TAU + 0.4
		var r := half + 0.35
		var cable := _box(Vector3(0.12, height * 0.92, 0.12), _metal_dark)
		cable.position = Vector3(cos(angle) * r, y0 + height * 0.5, sin(angle) * r)
		add_child(cable)


func _add_ring(y: float, width: float, thickness: float) -> void:
	var half := width * 0.5
	var segments := [
		[Vector3(-half, y, -half), Vector3(half, y, -half)],
		[Vector3(half, y, -half), Vector3(half, y, half)],
		[Vector3(half, y, half), Vector3(-half, y, half)],
		[Vector3(-half, y, half), Vector3(-half, y, -half)],
	]
	for seg in segments:
		_add_brace(seg[0], seg[1], thickness)


func _add_brace(a: Vector3, b: Vector3, thickness: float = 0.14) -> void:
	var mid := (a + b) * 0.5
	var delta := b - a
	var length := delta.length()
	if length < 0.05:
		return
	var brace := _box(Vector3(thickness, thickness, length), _metal_dark)
	brace.position = mid
	add_child(brace)
	if absf(delta.normalized().dot(Vector3.UP)) > 0.98:
		brace.look_at(mid + Vector3.FORWARD, Vector3.UP)
	else:
		brace.look_at(b, Vector3.UP)


func _add_mid_dish(y: float) -> void:
	var arm := _box(Vector3(0.35, 0.35, 5.5), _metal)
	arm.position = Vector3(0.0, y, 3.4)
	add_child(arm)
	var dish := _cylinder(3.8, 4.2, 0.35, _metal)
	dish.position = Vector3(0.0, y, 6.2)
	dish.rotation_degrees = Vector3(72.0, 0.0, 0.0)
	add_child(dish)
	var hub := _cylinder(0.35, 0.35, 1.2, _metal_dark)
	hub.position = Vector3(0.0, y, 5.4)
	hub.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(hub)


func _add_upper_dish(y: float) -> void:
	var arm := _box(Vector3(0.28, 0.28, 3.8), _metal)
	arm.position = Vector3(-2.4, y, 0.0)
	arm.rotation_degrees = Vector3(0.0, 90.0, 12.0)
	add_child(arm)
	var dish := _cylinder(2.2, 2.5, 0.28, _metal)
	dish.position = Vector3(-4.6, y + 0.4, 0.0)
	dish.rotation_degrees = Vector3(18.0, 0.0, 70.0)
	add_child(dish)


func _add_observation_deck(y: float) -> void:
	var collar := _cylinder(4.2, 4.6, 2.2, _metal_dark)
	collar.position = Vector3(0.0, y - 1.6, 0.0)
	add_child(collar)

	var floor_deck := _cylinder(5.4, 5.4, 0.45, _metal)
	floor_deck.position = Vector3(0.0, y, 0.0)
	add_child(floor_deck)

	# Warm lit glass band — far-readable outpost “alive” cue.
	var glass := _cylinder(5.1, 5.1, 3.2, _glass_warm)
	glass.position = Vector3(0.0, y + 2.0, 0.0)
	add_child(glass)

	var roof := _cylinder(5.5, 4.8, 0.7, _metal)
	roof.position = Vector3(0.0, y + 3.9, 0.0)
	add_child(roof)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.35)
	light.light_energy = 2.8
	light.omni_range = 28.0
	light.position = Vector3(0.0, y + 2.0, 0.0)
	add_child(light)


func _add_antenna_crown(y0: float) -> void:
	var tip_h := TOWER_HEIGHT - y0
	var mast := _box(Vector3(0.55, tip_h, 0.55), _metal)
	mast.position = Vector3(0.0, y0 + tip_h * 0.5, 0.0)
	add_child(mast)

	for i in 4:
		var angle := float(i) / 4.0 * TAU
		var rod := _box(Vector3(0.12, 7.0 + float(i) * 1.4, 0.12), _metal_dark)
		rod.position = Vector3(cos(angle) * 1.1, y0 + 5.0 + float(i), sin(angle) * 1.1)
		rod.rotation_degrees = Vector3(18.0 * cos(angle), 0.0, -18.0 * sin(angle))
		add_child(rod)

	var spike := _cylinder(0.08, 0.02, 9.0, _metal)
	spike.position = Vector3(0.0, TOWER_HEIGHT + 2.0, 0.0)
	add_child(spike)

	var beacon_orb := _sphere(0.55, _beacon)
	beacon_orb.position = Vector3(0.0, TOWER_HEIGHT + 6.2, 0.0)
	add_child(beacon_orb)

	var beacon_light := OmniLight3D.new()
	beacon_light.light_color = Color(0.85, 0.92, 1.0)
	beacon_light.light_energy = 5.0
	beacon_light.omni_range = 80.0
	beacon_light.position = Vector3(0.0, TOWER_HEIGHT + 6.2, 0.0)
	add_child(beacon_light)


func _add_nav_lights() -> void:
	var heights := [18.0, 36.0, DECK_Y + 4.5, 82.0, TOWER_HEIGHT - 2.0]
	for y in heights:
		for side in [-1.0, 1.0]:
			var lamp := _sphere(0.28, _nav_red)
			lamp.position = Vector3(side * (SHAFT_WIDTH * 0.55 + 0.4), y, 0.0)
			add_child(lamp)


func _add_far_silhouette() -> void:
	# Unshaded emissive needle — stays readable when mesh detail collapses with distance.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.22, 0.23, 0.26, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.28, 0.18)
	mat.emission_energy_multiplier = 1.6
	mat.no_depth_test = false

	var needle := _box(Vector3(2.2, TOWER_HEIGHT + 8.0, 2.2), mat)
	needle.position = Vector3(0.0, (TOWER_HEIGHT + 8.0) * 0.5, 0.0)
	needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Only contribute when far; fade in with distance via visibility ranges.
	needle.visibility_range_begin = 450.0
	needle.visibility_range_begin_margin = 120.0
	needle.visibility_range_end = 0.0
	add_child(needle)

	var crown := _sphere(3.2, _glass_warm)
	crown.position = Vector3(0.0, DECK_Y + 2.0, 0.0)
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crown.visibility_range_begin = 450.0
	crown.visibility_range_begin_margin = 120.0
	add_child(crown)


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	return mi


func _cylinder(top_r: float, bottom_r: float, height: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = material
	return mi


func _sphere(radius: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = material
	return mi
