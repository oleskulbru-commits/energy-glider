class_name GlideMusic
extends Node

## Sand-run bed. The first song fades in over 30 seconds from game start, before
## the E.O.N. is picked up. Try Again fades the first song in over the normal
## entrance. Levels 1-4 cycle the calm tracks. From level 5, the current calm
## track plays out, then the dune tracks take over. Reaching that level never
## cuts the song that is already playing. After a glide song ends, the dunes stay
## quiet for 10-25 seconds before the next one fades in. An early stop resumes
## the same song. Steps aside for the Sun Eater theme, which keeps its own
## playlist. The pause menu suspends it. The upgrade tower menu keeps it playing.

const LATER_LEVEL := 5

const EARLY_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/gliding_levels_1_3_b.mp3"),
	preload("res://assets/audio/music/desert_crossing_chillstep.mp3"),
	preload("res://assets/audio/music/desert_crossing_2_chillstep.mp3"),
]

const LATER_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/gliding_through_the_desert.mp3"),
	preload("res://assets/audio/music/gliding_through_the_dunes.mp3"),
	preload("res://assets/audio/music/mars_horizon.mp3"),
	preload("res://assets/audio/music/chillstep_fighting_through_the_desert.mp3"),
	preload("res://assets/audio/music/chillstep_aggressive.mp3"),
]

const OPENING_FADE_SEC := 30.0
const ENTRANCE_FADE_SEC := 10.0
const RETURN_DELAY_SEC := 2.0
const RETURN_FADE_SEC := 2.0
const FADE_OUT_SEC := 2.0
const HANDOFF_FADE_SEC := 8.0
const BREAK_MIN_SEC := 10.0
const BREAK_MAX_SEC := 25.0

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
var _later_reached := false
var _active_early := true
var _between_tracks := false
var _played_sec := 0.0
var _resumes := 0
var _resume_mark := 0.0


func _ready() -> void:
	add_to_group("glide_music")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_player = AudioStreamPlayer.new()
	_player.name = "GlideTheme"
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	for stream in EARLY_TRACKS + LATER_TRACKS:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
	if not EARLY_TRACKS.is_empty():
		_player.stream = EARLY_TRACKS[0]
	_player.volume_db = 0.0
	_player.finished.connect(_on_track_finished)
	add_child(_player)
	call_deferred("_bind")
	_start_opening()


func _process(delta: float) -> void:
	if (
		_player != null
		and _player.playing
		and not _player.stream_paused
		and (_phase == Phase.PLAYING or _phase == Phase.FADING_IN)
	):
		_played_sec += delta
		if _resumes > 0 and _played_sec > _resume_mark + 0.5:
			_resumes = 0
	_tick(delta)


func _bind() -> void:
	var progress := get_tree().get_first_node_in_group("level_progress")
	if progress != null and progress.has_signal("level_changed"):
		if not progress.level_changed.is_connected(_on_level_changed):
			progress.level_changed.connect(_on_level_changed)
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


func _on_level_changed(level: int) -> void:
	if level >= LATER_LEVEL:
		_later_reached = true


func _on_attempt_started() -> void:
	_between_tracks = false
	_later_reached = false
	_active_early = true
	_run_active = true
	_fresh_start = true
	_resume_position = -1.0
	_advance_on_resume = false
	_stop_player()
	_heard_first_pickup = true
	if _boss != null and _boss.is_theme_playing():
		_phase = Phase.SUPPRESSED
		return
	_start_life()


func _start_opening() -> void:
	_heard_first_pickup = true
	_run_active = true
	_fresh_start = true
	_resume_position = -1.0
	_advance_on_resume = false
	_schedule_start(0.0, OPENING_FADE_SEC)


func _start_life() -> void:
	_run_active = true
	_fresh_start = true
	_resume_position = -1.0
	_advance_on_resume = false
	_schedule_start(0.0, ENTRANCE_FADE_SEC)


func _on_player_died(_position: Vector3 = Vector3.ZERO) -> void:
	_between_tracks = false
	_run_active = false
	if _phase == Phase.FADING_OUT:
		return
	if _phase == Phase.PLAYING or _phase == Phase.FADING_IN:
		_start_fade_out()
		return
	_stop_player()
	_phase = Phase.IDLE


func _on_boss_spawned(_boss_node: Node) -> void:
	_between_tracks = false
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
	if _player == null:
		_phase = Phase.IDLE
		return
	var from_position := 0.0
	if _between_tracks:
		_between_tracks = false
	elif _advance_on_resume:
		_advance_on_resume = false
		if _should_leave_early():
			_active_early = false
			if LATER_TRACKS.is_empty():
				_phase = Phase.IDLE
				return
			_index = randi() % LATER_TRACKS.size()
		else:
			var continuing := _playlist()
			if continuing.is_empty():
				_phase = Phase.IDLE
				return
			_index = posmod(_index + 1, continuing.size())
	elif _resume_position >= 0.0 and _index >= 0 and not _playlist().is_empty():
		from_position = _resume_position
	else:
		if _later_reached:
			_active_early = false
		else:
			_active_early = true
		var fresh := _playlist()
		if fresh.is_empty():
			_phase = Phase.IDLE
			return
		_index = randi() % fresh.size()
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
	if _switching or _player == null:
		return
	if _playback_cut_short():
		_resume_interrupted()
		return
	if _phase == Phase.FADING_OUT or _phase == Phase.SUPPRESSED or not _run_active:
		_advance_on_resume = true
		_resume_position = -1.0
		return
	if _phase != Phase.PLAYING and _phase != Phase.FADING_IN:
		return
	if _playlist().is_empty():
		return
	# Checks call this while the stream is still running, before any time is tracked.
	if _player.playing and _played_sec < 0.5:
		_advance_instant()
		return
	_begin_track_break()


func _advance_instant() -> void:
	var volume := _player.volume_db
	var fade_t := _fade_t
	var phase := _phase
	_select_next_index()
	_start_track(_index, 0.0)
	_player.volume_db = volume
	_fade_t = fade_t
	_phase = phase


func _begin_track_break() -> void:
	if _playlist().is_empty():
		return
	_select_next_index()
	if _playlist().is_empty():
		return
	_stop_player()
	_between_tracks = true
	_schedule_start(randf_range(BREAK_MIN_SEC, BREAK_MAX_SEC), HANDOFF_FADE_SEC)


func _select_next_index() -> void:
	if _should_leave_early():
		if LATER_TRACKS.is_empty():
			return
		_active_early = false
		_index = randi() % LATER_TRACKS.size()
		return
	var tracks := _playlist()
	if tracks.is_empty():
		return
	_index = posmod(_index + 1, tracks.size())


func _playlist() -> Array[AudioStream]:
	return EARLY_TRACKS if _active_early else LATER_TRACKS


func _should_leave_early() -> bool:
	return _active_early and _later_reached


func _playback_cut_short() -> bool:
	if _resumes >= 2 or _player == null or _player.stream == null:
		return false
	var length := _player.stream.get_length()
	if length <= 2.0 or _played_sec < 0.5:
		return false
	return _played_sec < length - 1.5


func _resume_interrupted() -> void:
	_resumes += 1
	_resume_mark = _played_sec
	var position := _played_sec
	var volume := _player.volume_db
	var phase := _phase
	var fade_t := _fade_t
	_play_on(_player, _index, position)
	_player.volume_db = volume
	_fade_t = fade_t
	_phase = phase


func _start_track(index: int, from_position: float) -> void:
	_play_on(_player, index, from_position)


func _play_on(host: AudioStreamPlayer, index: int, from_position: float) -> void:
	var tracks := _playlist()
	if host == null or tracks.is_empty():
		return
	_index = posmod(index, tracks.size())
	var stream := tracks[_index]
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	_switching = true
	if host.stream != stream:
		host.stream = stream
	host.play(maxf(from_position, 0.0))
	if host == _player:
		_played_sec = maxf(from_position, 0.0)
	_switching = false


func _stop_player() -> void:
	if _player != null and _player.playing:
		_player.stop()


func _set_linear_volume(linear: float) -> void:
	if _player == null:
		return
	_player.volume_db = linear_to_db(maxf(linear, 0.0001))
