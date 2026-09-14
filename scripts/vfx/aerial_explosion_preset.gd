class_name AerialExplosionPreset
extends Resource

## Data for one Blender-rendered aerial explosion flipbook set.
## Edit [member material] (ShaderMaterial) for look tuning.

enum GroundSandBurst {
	LIGHT,
	HEAVY,
	MG,
	DEATH,
	EXPLOSION,
}

@export_group("Flipbook")
@export_dir var texture_dir := "res://assets/vfx/effect_textures/explosions/aerial_explosions/"
@export var color_prefix := "aerial_explode_3_v001_frame_"
@export var color_frame_offset := 1
@export_range(1, 120, 1) var frame_count := 75
@export_range(1.0, 60.0, 0.5) var fps := 24.0
@export_range(0.1, 40.0, 0.1) var world_scale := 6.0

@export_group("Look")
## Duplicated per in-game spawn. Edit shader params here or on the material resource.
@export var material: ShaderMaterial
## Used only when [member material] is unset.
@export_range(0.0, 20.0, 0.05) var emission_strength := 2.5
@export var color_tint := Color(1.0, 1.0, 1.0, 1.0)
@export var smoke_tint := Color(0.22, 0.20, 0.18, 1.0)
@export_range(0.0, 1.0, 0.01) var smoke_mix := 0.28
@export_range(0.0, 3.0, 0.01) var alpha_scale := 1.0
@export var proximity_fade_enabled := true
@export_range(0.0, 8.0, 0.05) var proximity_fade_distance := 1.0

@export_group("Impact Sparks")
@export var spawn_sparks := true
@export var spark_color := Color(2.0, 1.05, 0.32, 1.0)
@export_range(0, 80, 1) var spark_count := 32
@export_range(0.0, 20.0, 0.5) var spark_glow_strength := 7.0

@export_group("Flash Light")
@export var spawn_light := true
@export var light_color := Color(1.0, 0.82, 0.55, 1.0)
@export_range(0.0, 80.0, 0.5) var light_energy := 18.0
@export_range(0.0, 80.0, 0.5) var light_range_m := 28.0

@export_group("Camera Shake")
@export_range(0.0, 3.0, 0.05) var shake_strength := 0.85
@export_range(0.0, 120.0, 1.0) var shake_radius_m := 38.0

@export_group("Ground Sand")
## Spawns a sand burst when the explosion is within [member ground_sand_max_clearance_m] of terrain.
@export var spawn_ground_sand := true
@export_range(0.0, 12.0, 0.1) var ground_sand_max_clearance_m := 3.5
@export var ground_sand_burst: GroundSandBurst = GroundSandBurst.EXPLOSION
@export_range(0.1, 4.0, 0.05) var ground_sand_scale_mult := 1.0

@export_group("Ground Burn Decal")
## Spawns a scorch decal when the explosion is within [member ground_burn_max_clearance_m] of terrain.
@export var spawn_ground_burn_decal := true
@export_range(0.0, 12.0, 0.1) var ground_burn_max_clearance_m := 3.5
@export var ground_burn_albedo: Texture2D
@export var ground_burn_normal: Texture2D
@export var ground_burn_tint := Color(1.15, 0.78, 0.58, 1.0)
@export_range(0.1, 2.0, 0.05) var ground_burn_size_mult := 0.23333333
@export_range(0.0, 2.0, 0.01) var ground_burn_opacity := 1.0
@export_range(1.0, 180.0, 1.0) var ground_burn_lifetime_sec := 45.0
@export_range(0.5, 30.0, 0.5) var ground_burn_fade_sec := 10.0
