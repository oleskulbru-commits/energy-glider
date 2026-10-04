extends SceneTree

const GlideMusicScript := preload("res://scripts/game/glide_music.gd")
const BossDirectorScript := preload("res://scripts/game/boss_director.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_tracks()
	_verify_delayed_fade_in()
	_verify_playlist()
	_verify_pause()
	_verify_upgrade_menu_keeps_music()
	_verify_boss_handoff()
	_verify_death()
	if _failed:
		push_error("Glide music verification failed")
		quit(1)
		return
	print("Glide music verification passed")
	quit(0)


func _verify_tracks() -> void:
	_fail_unless(GlideMusicScript.TRACKS.size() == 3, "Glide music should have three tracks")
	var paths: PackedStringArray = []
	for stream in GlideMusicScript.TRACKS:
		_fail_unless(stream != null and not stream.loop, "Each glide track should play through once")
		paths.append(stream.resource_path)
	_fail_unless(
		paths.has("res://assets/audio/music/mars_horizon.mp3"),
		"Mars Horizon should sit in the glide playlist"
	)
	_fail_unless(
		is_equal_approx(GlideMusicScript.ENTRANCE_FADE_SEC, 10.0),
		"Glide music should fade in over 10 seconds"
	)
	_fail_unless(is_equal_approx(GlideMusicScript.FADE_OUT_SEC, 2.0), "Glide music should fade out over 2 seconds")


func _verify_delayed_fade_in() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_fail_unless(player != null, "Glide music should own its player")
	_fail_unless(
		player.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"The pause menu should be able to suspend glide music"
	)
	_fail_unless(not player.playing, "Glide music should stay silent before the E.O.N. is picked up")
	music.call("_tick", 30.0)
	_fail_unless(not player.playing, "Time passing should not start glide music before the first pickup")
	music.call("_on_attempt_started")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC)
	_fail_unless(not player.playing, "Try Again before the first pickup should stay silent")
	music.call("_on_eon_collected")
	_fail_unless(player.playing, "Glide music should start when the E.O.N. is picked up")
	_fail_unless(player.volume_db < -20.0, "Glide music should start quiet and fade in")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC * 0.5)
	_fail_unless(player.volume_db < -3.0, "Glide music should still be fading halfway through the entrance")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC * 0.5)
	_fail_unless(is_equal_approx(player.volume_db, 0.0), "Glide music should reach full volume")
	_fail_unless(int(music.get("_phase")) == GlideMusicScript.Phase.PLAYING, "Fade in should settle into playback")
	music.call("_on_eon_collected")
	_fail_unless(is_equal_approx(player.volume_db, 0.0), "Picking the E.O.N. up again should not restart the fade")
	music.call("_on_player_died", Vector3.ZERO)
	music.call("_tick", GlideMusicScript.FADE_OUT_SEC)
	music.call("_on_attempt_started")
	_fail_unless(player.playing, "Try Again should fade the music back in")
	_fail_unless(player.volume_db < -20.0, "A retry should start the entrance fade from quiet")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC)
	_fail_unless(is_equal_approx(player.volume_db, 0.0), "A retry fade should reach full volume")
	music.free()


func _verify_playlist() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	var first := int(music.get("_index"))
	var count := GlideMusicScript.TRACKS.size()
	for step in count - 1:
		music.call("_on_track_finished")
		_fail_unless(player.playing, "The next glide track should start when one ends")
		_fail_unless(
			int(music.get("_index")) == posmod(first + step + 1, count),
			"Glide tracks should play in order"
		)
		_fail_unless(is_equal_approx(player.volume_db, 0.0), "A handoff should keep full volume")
	music.call("_on_track_finished")
	_fail_unless(int(music.get("_index")) == first, "The glide playlist should wrap")
	_fail_unless(is_equal_approx(player.volume_db, 0.0), "A wrap should keep full volume")
	music.free()


func _verify_pause() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	paused = true
	_fail_unless(player.stream_paused, "The pause menu should suspend glide music")
	paused = false
	_fail_unless(not player.stream_paused, "Closing the pause menu should resume glide music")
	music.free()


func _verify_upgrade_menu_keeps_music() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	music.set_audible_while_paused(true)
	paused = true
	_fail_unless(player.playing, "Glide music should keep playing in the upgrade menu")
	_fail_unless(not player.stream_paused, "The upgrade menu should leave glide music audible")
	paused = false
	music.set_audible_while_paused(false)
	paused = true
	_fail_unless(player.stream_paused, "Glide music should suspend again once the upgrade menu closes")
	paused = false
	music.free()


func _verify_boss_handoff() -> void:
	var boss := BossDirectorScript.new()
	root.add_child(boss)
	var music := _make_music()
	music.call("_bind")
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	var index_before := int(music.get("_index"))
	boss.call("_play_theme")
	music.call("_on_boss_spawned", boss)
	_fail_unless(player.playing, "Glide music should fade out instead of cutting when a boss spawns")
	music.call("_tick", GlideMusicScript.FADE_OUT_SEC * 0.5)
	_fail_unless(player.volume_db < -3.0, "Glide music should be quieter halfway through the boss fade-out")
	music.call("_tick", GlideMusicScript.FADE_OUT_SEC * 0.5)
	_fail_unless(not player.playing, "Glide music should be silent once the boss theme has taken over")
	_fail_unless(
		int(music.get("_phase")) == GlideMusicScript.Phase.SUPPRESSED,
		"Glide music should stay down while the Sun Eater theme plays"
	)
	boss.call("_fade_theme")
	boss.call("_tick_theme_fade", BossDirectorScript.THEME_FADE_SEC)
	_fail_unless(
		int(music.get("_phase")) == GlideMusicScript.Phase.WAITING,
		"Glide music should wait a moment after the Sun Eater theme fades"
	)
	_fail_unless(not player.playing, "Glide music should stay silent during the return delay")
	music.call("_tick", GlideMusicScript.RETURN_DELAY_SEC)
	_fail_unless(player.playing, "Glide music should return after the Sun Eater theme")
	_fail_unless(
		int(music.get("_index")) == index_before,
		"Glide music should resume the track that was playing"
	)
	music.free()
	boss.free()


func _verify_death() -> void:
	var boss := BossDirectorScript.new()
	root.add_child(boss)
	var music := _make_music()
	music.call("_bind")
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	music.call("_on_player_died", Vector3.ZERO)
	music.call("_tick", GlideMusicScript.FADE_OUT_SEC)
	_fail_unless(not player.playing, "Glide music should fade out when the player dies")
	music.call("_tick", 30.0)
	_fail_unless(not player.playing, "A death fade should not start the next glide track")
	boss.call("_play_theme")
	music.call("_on_attempt_started")
	_fail_unless(not player.playing, "A new run should wait while the Sun Eater theme is still fading")
	boss.call("_fade_theme")
	boss.call("_tick_theme_fade", BossDirectorScript.THEME_FADE_SEC)
	_fail_unless(player.playing, "Coming back to life should start the entrance fade")
	_fail_unless(player.volume_db < -20.0, "The entrance fade should start quiet")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC)
	_fail_unless(is_equal_approx(player.volume_db, 0.0), "Glide music should finish fading in on the next run")
	music.free()
	boss.free()


func _reach_full_volume(music: GlideMusic) -> void:
	music.call("_on_eon_collected")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC)


func _make_music() -> GlideMusic:
	var music := GlideMusicScript.new()
	root.add_child(music)
	return music


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
