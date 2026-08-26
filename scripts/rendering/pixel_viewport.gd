extends SubViewportContainer

@export var pixel_scale := 3

@onready var _sub_viewport: SubViewport = $SubViewport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_NEAREST
	stretch = true
	stretch_shrink = maxi(pixel_scale, 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sub_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	_sub_viewport.handle_input_locally = false
	_sub_viewport.gui_disable_input = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.transparent_bg = false
	get_tree().root.size_changed.connect(_on_root_size_changed)
	call_deferred("_ensure_layout")


func _on_root_size_changed() -> void:
	_ensure_layout()


func _ensure_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch_shrink = maxi(pixel_scale, 1)
