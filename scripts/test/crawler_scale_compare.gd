@tool
extends Node3D

## Side-by-side living vs fractured crawler for scale tuning in the editor.

@export_group("Layout")
@export var spacing: float = 4.0:
	set(value):
		spacing = value
		_request_apply()

@export var align_feet_to_ground: bool = true:
	set(value):
		align_feet_to_ground = value
		_request_apply()

@export_group("Living Crawler")
@export var living_game_scale: float = SwarmPill.CRAWLER_LIVING_SCALE:
	set(value):
		living_game_scale = value
		_request_apply()

@export_group("Fractured Crawler")
@export var use_auto_fractured_scale: bool = true:
	set(value):
		use_auto_fractured_scale = value
		_request_apply()

@export var fractured_burst_mult: float = SwarmPill.CRAWLER_FRACTURED_BURST_MULT:
	set(value):
		fractured_burst_mult = value
		_request_apply()

@export var fractured_scale_manual: float = 1.0:
	set(value):
		fractured_scale_manual = maxf(value, 0.001)
		_request_apply()


func _ready() -> void:
	_request_apply()


func _request_apply() -> void:
	if not is_inside_tree():
		return
	_apply_layout()


func _apply_layout() -> void:
	var living_pivot := get_node_or_null("LivingPivot") as Node3D
	var fractured_pivot := get_node_or_null("FracturedPivot") as Node3D
	var living_model := get_node_or_null("LivingPivot/CrawlerSkin/Model") as Node3D
	var fractured_model := get_node_or_null("FracturedPivot/Fractured") as Node3D
	if living_pivot == null or fractured_pivot == null:
		return
	if living_model == null or fractured_model == null:
		return

	living_pivot.position = Vector3(-spacing * 0.5, 0.0, 0.0)
	fractured_pivot.position = Vector3(spacing * 0.5, 0.0, 0.0)

	var living_scale := CrawlerScaleUtil.animated_model_scale(living_game_scale)
	living_model.scale = Vector3.ONE * living_scale

	var fractured_scale := fractured_scale_manual
	if use_auto_fractured_scale:
		fractured_scale = CrawlerScaleUtil.death_burst_scale(
			living_game_scale,
			fractured_burst_mult
		)
	fractured_model.scale = Vector3.ONE * fractured_scale

	if align_feet_to_ground:
		_align_feet(living_pivot, living_model)
		_align_feet(fractured_pivot, fractured_model)

	_update_labels(living_pivot, fractured_pivot, living_scale, fractured_scale)


func _align_feet(pivot: Node3D, model: Node3D) -> void:
	var aabb := CrawlerScaleUtil.combined_mesh_local_aabb(model)
	pivot.position.y = -aabb.position.y * model.scale.y


func _update_labels(
	living_pivot: Node3D,
	fractured_pivot: Node3D,
	living_scale: float,
	fractured_scale: float
) -> void:
	var living_label: Label3D = living_pivot.get_node_or_null("Label") as Label3D
	if living_label != null:
		living_label.text = "Living\nscale %.3f" % living_scale
	var fractured_label: Label3D = fractured_pivot.get_node_or_null("Label") as Label3D
	if fractured_label != null:
		var mode := "auto" if use_auto_fractured_scale else "manual"
		fractured_label.text = "Fractured (%s)\nscale %.3f" % [mode, fractured_scale]
