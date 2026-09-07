class_name AerialExplosionPreset
extends Resource

## Data for one Blender-rendered aerial explosion flipbook set.
## Edit [member material] for look tuning, or leave it unset and use the shader exports below.

@export_group("Flipbook")
@export_dir var texture_dir := "res://assets/vfx/effect_textures/explosions/aerial_explosions/"
@export var color_prefix := "aerial_explode_1_v001_frame_"
@export var color_frame_offset := 1
@export var normal_prefix := "aerial_explode_1_normal_frame_"
@export var normal_frame_offset := 0
@export_range(1, 120, 1) var frame_count := 25
@export_range(1.0, 60.0, 0.5) var fps := 24.0
@export_range(0.1, 40.0, 0.1) var world_scale := 6.0

@export_group("Look")
## When set, this material is duplicated per spawn. Edit shader params here in the inspector.
@export var material: ShaderMaterial
@export_range(0.0, 20.0, 0.05) var emission_strength := 2.5
@export_range(0.0, 2.0, 0.01) var normal_strength := 0.65
@export var light_dir := Vector3(0.3, 0.85, 0.4)
@export var color_tint := Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 3.0, 0.01) var alpha_scale := 1.0
@export_range(0.0, 2.0, 0.01) var lighting_dark := 0.85
@export_range(0.0, 2.0, 0.01) var lighting_bright := 1.15

@export_group("Flash Light")
@export var spawn_light := true
@export var light_color := Color(1.0, 0.82, 0.55, 1.0)
@export_range(0.0, 80.0, 0.5) var light_energy := 18.0
@export_range(0.0, 80.0, 0.5) var light_range_m := 28.0

@export_group("Camera Shake")
@export_range(0.0, 3.0, 0.05) var shake_strength := 0.85
@export_range(0.0, 120.0, 1.0) var shake_radius_m := 38.0
