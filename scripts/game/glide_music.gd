class_name GlideMusic
extends Node

## Sand-run bed. Fades in after the first E.O.N. pickup, and again after each
## Try Again. Cycles the dune tracks, and steps aside for the Sun Eater theme.
## The pause menu suspends it. The upgrade tower menu keeps it playing.

const TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/gliding_through_the_desert.mp3"),
	preload("res://assets/audio/music/gliding_through_the_dunes.mp3"),
	preload("res://assets/audio/music/mars_horizon.mp3"),
]

const ENTRANCE_FADE_SEC := 10.0
const RETURN_DELAY_SEC := 2.0
const RETURN_FADE_SEC := 2.0
const FADE_OUT_SEC := 2.0

enum Phase { IDLE, WAITING, FADING_IN, PLAYING, FADING_OUT, SUPPRESSED }

var _player: AudioStreamPlayer
var _boss: BossDirector
var _phase := Phase.IDLE
var _wait_t := 0.0
var _fade_t := 0.0
var _fade_from_linear := 1.0
var _index := -1
var _resume_position := -1.0
var _advance_on_resume := false
var _fresh_start := true
var _run_active := true
var _heard_first_pickup := false
var _fade_in_sec := ENTRANCE_FADE_SEC
var _switching := false


func _ready() -> void:
	add_to_group("glide_music")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_player = AudioStreamPlayer.new()
	_player.name = "GlideTheme"
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	for stream in TRACKS:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
	if not TRACKS.is_empty():
		_player.stream = TRACKS[0]
	_player.volume_db = 0.0
	_player.finished.connect(_on_track_finished)
	add_child(_player)
	call_deferred("_bind")


func _process(delta: float) -> void:
	_tick(delta)


func _bind() -> void:
	var eon := get_tree().get_first_node_in_group("eon_director")
	if eon != null:
		if eon.has_signal("eon_collected") and not eon.eon_collected.is_connected(_on_eon_collected):
			eon.eon_collected.connect(_on_eon_collected)
		if eon.has_signal("attempt_started") and not eon.attempt_started.is_connected(_on_attempt_started):
			eon.attempt_started.connect(_on_attempt_started)
		if eon.has_signal("player_died") and not eon.player_died.is_connected(_on_player_died):
			eon.player_died.connect(_on_player_died)
	_boss = get_tree().get_first_node_in_group("boss_director") as BossDirector
	if _boss == null:
		return
	if not _boss.boss_spawned.is_connected(_on_boss_spawned):
		_boss.boss_spawned.connect(_on_boss_spawned)
	if not _boss.theme_fade_finished.is_connected(_on_boss_theme_faded):
		_boss.theme_fade_finished.connect(_on_boss_theme_faded)


func _on_eon_collected() -> void:
	if _heard_first_pickup:
		return
	_heard_first_pickup = true
	_start_life()


func _on_attempt_started() -> void:
	_run_active = true
	_fresh_start = true
	_resume_position = -1.0
	_advance_on_resume = false
	_stop_player()
	if not _heard_first_pickup:
		_phase = Phase.IDLE
		return
	if _boss != null and _boss.is_theme_playing():
		_phase = Phase.SUPPRESSED
		return
	_start_life()


func _start_life() -> void:
	_run_active = true
	_fresh_start = true
	_resume_position = -1.0
	_advance_on_resume = false
	_schedule_start(0.0, ENTRANCE_FADE_SEC)


func _on_player_died(_position: Vector3 = Vector3.ZERO) -> void:
	_run_active = false
	if _phase == Phase.FADING_OUT:
		return
	if _phase == Phase.PLAYING or _phase == Phase.FADING_IN:
		_start_fade_out()
		return
	_stop_player()
	_phase = Phase.IDLE


func _on_boss_spawned(_boss_node: Node) -> void:
	_fresh_start = false
	if _phase == Phase.FADING_OUT or _phase == Phase.SUPPRESSED:
		_phase = Phase.FADING_OUT if _player != null and _player.playing else Phase.SUPPRESSED
		return
	if _phase == Phase.PLAYING or _phase == Phase.FADING_IN:
		_start_fade_out()
		return
	_stop_player()
	_phase = Phase.SUPPRESSED


func _on_boss_theme_faded() -> void:
	if not _run_active:
		return
	if _fresh_start:
		if not _heard_first_pickup:
			_phase = Phase.IDLE
			return
		_resume_position = -1.0
		_advance_on_resume = false
		_schedule_start(0.0, ENTRANCE_FADE_SEC)
		return
	_schedule_start(RETURN_DELAY_SEC, RETURN_FADE_SEC)


func set_audible_while_paused(audible: bool) -> void:
	var mode := Node.PROCESS_MODE_ALWAYS if audible else Node.PROCESS_MODE_PAUSABLE
	process_mode = mode
	if _player != null:
		_player.process_mode = mode


func _schedule_start(delay: float, fade_sec: float) -> void:
	_fade_in_sec = fade_sec
	if delay <= 0.0:
		_begin_playback()
		return
	_phase = Phase.WAITING
	_wait_t = delay


func _tick(delta: float) -> void:
	if _phase == Phase.WAITING:
		_wait_t = maxf(_wait_t - delta, 0.0)
		if _wait_t <= 0.0:
			_begin_playback()
		return
	if _phase == Phase.FADING_IN:
		_fade_t = maxf(_fade_t - delta, 0.0)
		var linear := 1.0
		if _fade_in_sec > 0.0:
			linear = 1.0 - _fade_t / _fade_in_sec
		_set_linear_volume(linear)
		if _fade_t <= 0.0:
			_phase = Phase.PLAYING
			_set_linear_volume(1.0)
		return
	if _phase != Phase.FADING_OUT:
		return
	_fade_t = maxf(_fade_t - delta, 0.0)
	var out_linear := 0.0
	if FADE_OUT_SEC > 0.0:
		out_linear = _fade_from_linear * (_fade_t / FADE_OUT_SEC)
	_set_linear_volume(out_linear)
	if _fade_t > 0.0:
		return
	_finish_fade_out()


func _begin_playback() -> void:
	if TRACKS.is_empty() or _player == null:
		_phase = Phase.IDLE
		return
	var from_position := 0.0
	if _advance_on_resume:
		_index = posmod(_index + 1, TRACKS.size())
		_advance_on_resume = false
	elif _resume_position >= 0.0 and _index >= 0:
		from_position = _resume_position
	else:
		_index = randi() % TRACKS.size()
	_resume_position = -1.0
	_phase = Phase.FADING_IN
	_fade_t = _fade_in_sec
	_set_linear_volume(0.0)
	_start_track(_index, from_position)


func _start_fade_out() -> void:
	if _player == null:
		_phase = Phase.IDLE
		return
	_fade_from_linear = db_to_linear(_player.volume_db)
	_fade_t = FADE_OUT_SEC
	_phase = Phase.FADING_OUT


func _finish_fade_out() -> void:
	if _player != null and _player.playing and not _advance_on_resume:
		_resume_position = _player.get_playback_position()
	_stop_player()
	_set_linear_volume(1.0)
	if not _run_active:
		_phase = Phase.IDLE
		return
	if not _fresh_start and _boss_has_theme():
		_phase = Phase.SUPPRESSED
		return
	_phase = Phase.IDLE


func _boss_has_theme() -> bool:
	return _boss != null and _boss.is_theme_playing()


func _on_track_finished() -> void:
	if _switching or _player == null or TRACKS.is_empty():
		return
	if _phase == Phase.FADING_OUT or _phase == Phase.SUPPRESSED or not _run_active:
		_advance_on_resume = true
		_resume_position = -1.0
		return
	if _phase != Phase.PLAYING and _phase != Phase.FADING_IN:
		return
	var volume := _player.volume_db
	var fade_t := _fade_t
	var phase := _phase
	_start_track(_index + 1, 0.0)
	_player.volume_db = volume
	_fade_t = fade_t
	_phase = phase


func _start_track(index: int, from_position: float) -> void:
	if _player == null or TRACKS.is_empty():
		return
	_index = posmod(index, TRACKS.size())
	var stream := TRACKS[_index]
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	_switching = true
	_player.stream = stream
	_player.play(maxf(from_position, 0.0))
	_switching = false


func _stop_player() -> void:
	if _player != null and _player.playing:
		_player.stop()


func _set_linear_volume(linear: float) -> void:
	if _player == null:
		return
	_player.volume_db = linear_to_db(maxf(linear, 0.0001))
