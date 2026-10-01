class_name GameplayMusic
extends AudioStreamPlayer

const DEFAULT_STREAM := "res://assets/sound/music/Mars Horizon.mp3"

@export var music_stream: AudioStream
@export_range(-80.0, 24.0, 0.5) var music_volume_db := -18.0


func _ready() -> void:
	add_to_group("gameplay_music")
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = &"Master"
	volume_db = music_volume_db
	if music_stream == null:
		music_stream = load(DEFAULT_STREAM) as AudioStream
	_apply_stream(music_stream)


func _apply_stream(stream_res: AudioStream) -> void:
	if stream_res == null:
		return
	stream = stream_res
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func start_run_music() -> void:
	_apply_stream(music_stream)
	if stream == null:
		return
	if is_playing():
		return
	play()


func stop_run_music() -> void:
	stop()
