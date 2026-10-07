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
	_verify_level_gate()
	_verify_boss_keeps_calm_track()
	_verify_finished_calm_track_starts_later()
	_verify_track_break()
	_verify_early_stop_resumes()
	_verify_level_crossing_does_not_cut()
	if _failed:
		push_error("Glide music verification failed")
		quit(1)
		return
	print("Glide music verification passed")
	quit(0)


func _verify_tracks() -> void:
	_fail_unless(GlideMusicScript.EARLY_TRACKS.size() == 3, "Levels 1-4 should have three calm tracks")
	_fail_unless(GlideMusicScript.LATER_TRACKS.size() == 5, "Level 5 and beyond should have five dune tracks")
	_fail_unless(GlideMusicScript.LATER_LEVEL == 5, "Dune tracks should unlock at level 5")
	var early_paths: PackedStringArray = []
	for stream in GlideMusicScript.EARLY_TRACKS:
		_fail_unless(stream != null and not stream.loop, "Each calm track should play through once")
		early_paths.append(stream.resource_path)
	_fail_unless(
		early_paths.has("res://assets/audio/music/gliding_levels_1_3_b.mp3"),
		"The calm gliding track should be in the early playlist"
	)
	_fail_unless(
		early_paths.has("res://assets/audio/music/desert_crossing_chillstep.mp3"),
		"Desert Crossing should be in the levels 1-4 playlist"
	)
	_fail_unless(
		early_paths.has("res://assets/audio/music/desert_crossing_2_chillstep.mp3"),
		"Desert Crossing 2 should be in the levels 1-4 playlist"
	)
	var later_paths: PackedStringArray = []
	for stream in GlideMusicScript.LATER_TRACKS:
		_fail_unless(stream != null and not stream.loop, "Each dune track should play through once")
		later_paths.append(stream.resource_path)
	_fail_unless(
		later_paths.has("res://assets/audio/music/mars_horizon.mp3"),
		"Mars Horizon should sit in the dune playlist"
	)
	_fail_unless(
		later_paths.has("res://assets/audio/music/chillstep_fighting_through_the_desert.mp3"),
		"Fighting Through the Desert should sit in the dune playlist"
	)
	_fail_unless(
		later_paths.has("res://assets/audio/music/chillstep_aggressive.mp3"),
		"Aggressive chillstep should sit in the dune playlist"
	)
	_fail_unless(
		is_equal_approx(GlideMusicScript.OPENING_FADE_SEC, 30.0),
		"The first song should fade in over 30 seconds from game start"
	)
	_fail_unless(
		is_equal_approx(GlideMusicScript.ENTRANCE_FADE_SEC, 10.0),
		"Try Again should fade the first song in over 10 seconds"
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
	_fail_unless(player.playing, "The first song should start at game start")
	_fail_unless(player.volume_db < -20.0, "The opening fade should start quiet")
	music.call("_tick", GlideMusicScript.OPENING_FADE_SEC * 0.5)
	_fail_unless(player.volume_db < -3.0, "The opening fade should still be going after 15 seconds")
	music.call("_on_eon_collected")
	_fail_unless(
		player.volume_db < -3.0,
		"Picking up the E.O.N. should not restart the opening fade"
	)
	music.call("_tick", GlideMusicScript.OPENING_FADE_SEC * 0.5)
	_fail_unless(is_equal_approx(player.volume_db, 0.0), "The opening fade should reach full volume after 30 seconds")
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
	var count := GlideMusicScript.EARLY_TRACKS.size()
	_fail_unless(bool(music.get("_active_early")), "A new run should start on the calm playlist")
	_fail_unless(_is_early(player.stream), "A new run should play a calm track")
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


func _verify_level_gate() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	var calm_stream := player.stream
	var calm_index := int(music.get("_index"))
	music.call("_on_level_changed", 4)
	_fail_unless(not bool(music.get("_later_reached")), "Level 4 should keep the calm playlist")
	music.call("_on_level_changed", GlideMusicScript.LATER_LEVEL)
	_fail_unless(bool(music.get("_later_reached")), "Level 5 should arm the dune playlist")
	_fail_unless(player.stream == calm_stream, "Crossing level 5 should let the calm track finish")
	_fail_unless(int(music.get("_index")) == calm_index, "Crossing level 5 should keep the calm track index")
	_fail_unless(bool(music.get("_active_early")), "The playing list should stay calm until the track ends")
	music.call("_on_track_finished")
	_fail_unless(not bool(music.get("_active_early")), "The next track should come from the dune playlist")
	_fail_unless(_is_later(player.stream), "The track after level 5 should be a dune track")
	_fail_unless(
		player.stream == GlideMusicScript.LATER_TRACKS[int(music.get("_index"))],
		"The dune handoff should play the chosen later track"
	)
	var later_index := int(music.get("_index"))
	music.call("_on_track_finished")
	_fail_unless(
		int(music.get("_index")) == posmod(later_index + 1, GlideMusicScript.LATER_TRACKS.size()),
		"Dune tracks should keep cycling after the handoff"
	)
	_fail_unless(_is_later(player.stream), "Later finishes should stay on the dune playlist")
	music.call("_on_player_died", Vector3.ZERO)
	music.call("_tick", GlideMusicScript.FADE_OUT_SEC)
	music.call("_on_attempt_started")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC)
	_fail_unless(not bool(music.get("_later_reached")), "Try Again should clear the level 5 handoff")
	_fail_unless(bool(music.get("_active_early")), "Try Again should return to the calm playlist")
	_fail_unless(_is_early(player.stream), "Try Again should play a calm track")
	music.free()


func _verify_boss_keeps_calm_track() -> void:
	var boss := BossDirectorScript.new()
	root.add_child(boss)
	var music := _make_music()
	music.call("_bind")
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	var calm_stream := player.stream
	var calm_index := int(music.get("_index"))
	boss.call("_play_theme")
	music.call("_on_boss_spawned", boss)
	music.call("_tick", GlideMusicScript.FADE_OUT_SEC)
	music.call("_on_level_changed", GlideMusicScript.LATER_LEVEL)
	boss.call("_fade_theme")
	boss.call("_tick_theme_fade", BossDirectorScript.THEME_FADE_SEC)
	music.call("_tick", GlideMusicScript.RETURN_DELAY_SEC)
	_fail_unless(player.playing, "The calm track should return after the Sun Eater theme")
	_fail_unless(player.stream == calm_stream, "A boss handoff should resume the calm track")
	_fail_unless(int(music.get("_index")) == calm_index, "A boss handoff should resume the calm index")
	_fail_unless(bool(music.get("_active_early")), "The resumed track should still be the calm one")
	music.call("_on_track_finished")
	_fail_unless(not bool(music.get("_active_early")), "The dune playlist should start once the resumed calm track ends")
	_fail_unless(_is_later(player.stream), "The track after the resumed calm track should be a dune track")
	music.free()
	boss.free()


func _verify_finished_calm_track_starts_later() -> void:
	var boss := BossDirectorScript.new()
	root.add_child(boss)
	var music := _make_music()
	music.call("_bind")
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	boss.call("_play_theme")
	music.call("_on_boss_spawned", boss)
	music.call("_tick", GlideMusicScript.FADE_OUT_SEC)
	music.call("_on_level_changed", GlideMusicScript.LATER_LEVEL)
	music.call("_on_track_finished")
	_fail_unless(bool(music.get("_advance_on_resume")), "A finished calm track should wait until the boss theme ends")
	boss.call("_fade_theme")
	boss.call("_tick_theme_fade", BossDirectorScript.THEME_FADE_SEC)
	music.call("_tick", GlideMusicScript.RETURN_DELAY_SEC)
	_fail_unless(player.playing, "Glide music should return after a calm track that ended during the boss")
	_fail_unless(not bool(music.get("_active_early")), "A calm track that already ended should not restart")
	_fail_unless(_is_later(player.stream), "The return should start the dune playlist")
	music.free()
	boss.free()


func _verify_track_break() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	var first := int(music.get("_index"))
	music.set("_played_sec", player.stream.get_length() - 0.2)
	player.stop()
	music.call("_on_track_finished")
	_fail_unless(not player.playing, "A finished glide song should leave silence")
	_fail_unless(
		int(music.get("_phase")) == GlideMusicScript.Phase.WAITING,
		"The next song should wait out the gap"
	)
	var gap := float(music.get("_wait_t"))
	_fail_unless(
		gap >= GlideMusicScript.BREAK_MIN_SEC and gap <= GlideMusicScript.BREAK_MAX_SEC,
		"The gap between glide songs should last between 10 and 25 seconds"
	)
	music.call("_tick", gap - 0.05)
	_fail_unless(not player.playing, "Silence should hold until the gap ends")
	music.call("_tick", 0.1)
	_fail_unless(player.playing, "The next song should start when the gap ends")
	_fail_unless(player.volume_db < -20.0, "The next song should fade in")
	_fail_unless(
		int(music.get("_index")) == posmod(first + 1, GlideMusicScript.EARLY_TRACKS.size()),
		"The gap should lead into the next calm track"
	)
	music.free()


func _verify_early_stop_resumes() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	var stream := player.stream
	var index := int(music.get("_index"))
	music.set("_played_sec", 20.0)
	player.stop()
	music.call("_on_track_finished")
	_fail_unless(player.stream == stream, "Stopping early should keep the same track")
	_fail_unless(int(music.get("_index")) == index, "Stopping early should not advance the playlist")
	_fail_unless(player.playing, "Stopping early should resume the same track")
	music.set("_played_sec", player.stream.get_length() - 0.2)
	player.stop()
	music.call("_on_track_finished")
	_fail_unless(not player.playing, "A finished track should stay silent through the gap")
	_fail_unless(
		int(music.get("_index")) == posmod(index + 1, GlideMusicScript.EARLY_TRACKS.size()),
		"A track that actually finished should still advance"
	)
	music.call("_tick", float(music.get("_wait_t")))
	_fail_unless(player.volume_db < -20.0, "The next track should fade in after the gap")
	music.free()


func _verify_level_crossing_does_not_cut() -> void:
	var music := _make_music()
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	_reach_full_volume(music)
	var stream := player.stream
	var index := int(music.get("_index"))
	music.call("_on_level_changed", GlideMusicScript.LATER_LEVEL)
	music.set("_played_sec", 40.0)
	player.stop()
	music.call("_on_track_finished")
	_fail_unless(bool(music.get("_later_reached")), "Level 5 should still arm the dune playlist")
	_fail_unless(player.stream == stream, "Passing the dune threshold mid-song should keep that song")
	_fail_unless(int(music.get("_index")) == index, "Passing the dune threshold mid-song should keep the index")
	_fail_unless(bool(music.get("_active_early")), "The dune playlist should wait until the calm song actually ends")
	_fail_unless(player.playing, "An early stop after the threshold should resume the calm song")
	music.set("_played_sec", player.stream.get_length() - 0.2)
	player.stop()
	music.call("_on_track_finished")
	_fail_unless(not player.playing, "The dune handoff should wait through the gap")
	_fail_unless(not bool(music.get("_active_early")), "A calm song that really ended should hand off to the dunes")
	music.call("_tick", float(music.get("_wait_t")))
	_fail_unless(_is_later(player.stream), "The dune handoff should play a dune track")
	_fail_unless(player.volume_db < -20.0, "The dune handoff should fade in")
	music.free()


func _reach_full_volume(music: GlideMusic) -> void:
	music.call("_tick", GlideMusicScript.OPENING_FADE_SEC)


func _make_music() -> GlideMusic:
	var music := GlideMusicScript.new()
	root.add_child(music)
	return music


func _is_early(stream: AudioStream) -> bool:
	return GlideMusicScript.EARLY_TRACKS.has(stream)


func _is_later(stream: AudioStream) -> bool:
	return GlideMusicScript.LATER_TRACKS.has(stream)


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
