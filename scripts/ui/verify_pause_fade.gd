extends SceneTree

const PauseMenuScene := preload("res://scenes/ui/pause_menu.tscn")
const GlideMusicScript := preload("res://scripts/game/glide_music.gd")

var _failed := false
var _master_bus := -1
var _master_db := 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_master_bus = AudioServer.get_bus_index("Master")
	if _master_bus >= 0:
		_master_db = AudioServer.get_bus_volume_db(_master_bus)
	_verify_pause_waits_for_fade()
	_verify_resume_waits_for_fade()
	_verify_escape_reverses_the_fade()
	_verify_music_fades_through_the_pause()
	if _master_bus >= 0:
		AudioServer.set_bus_volume_db(_master_bus, _master_db)
	if _failed:
		push_error("Pause fade verification failed")
		quit(1)
		return
	print("Pause fade verification passed")
	quit(0)


func _verify_pause_waits_for_fade() -> void:
	var menu := _make_menu()
	var dim := menu.get_node("%Dim") as ColorRect
	menu.open(null)
	_fail_unless(paused, "The game should pause as soon as escape is pressed")
	_fail_unless(menu.is_open(), "The pause controls should appear as soon as the game pauses")
	menu._process(PauseMenu.FADE_SEC * 0.5)
	_fail_unless(paused, "The game should stay paused while the music fades")
	_fail_unless(dim.color.a > 0.2 and dim.color.a < 0.6, "The pause dim should be partway in")
	_fail_unless(_master_db_now() < -6.0, "Sound should be quieter halfway through the pause fade")
	menu._process(PauseMenu.FADE_SEC * 0.5)
	_fail_unless(paused, "The game should still be paused when the fade finishes")
	_fail_unless(menu.is_open(), "The pause controls should stay up after the fade")
	_fail_unless(is_equal_approx(dim.color.a, 0.72), "The pause dim should be fully in")
	menu.free()
	paused = false
	if _master_bus >= 0:
		AudioServer.set_bus_volume_db(_master_bus, _master_db)


func _verify_resume_waits_for_fade() -> void:
	var menu := _make_menu()
	var dim := menu.get_node("%Dim") as ColorRect
	menu.open(null)
	menu._process(PauseMenu.FADE_SEC)
	menu.close()
	_fail_unless(not paused, "The game should resume as soon as resume is pressed")
	_fail_unless(not menu.is_open(), "The pause controls should hide as soon as resume starts")
	menu._process(PauseMenu.FADE_SEC * 0.5)
	_fail_unless(not paused, "The game should stay running while the music fades back in")
	_fail_unless(dim.color.a > 0.2 and dim.color.a < 0.6, "The pause dim should be partway out")
	menu._process(PauseMenu.FADE_SEC * 0.5)
	_fail_unless(not paused, "The game should still be running when the fade finishes")
	_fail_unless(not menu.visible, "The pause menu should hide after resuming")
	_fail_unless(is_equal_approx(_master_db_now(), _master_db), "Sound should be back after resuming")
	menu.free()


func _verify_escape_reverses_the_fade() -> void:
	var menu := _make_menu()
	menu.open(null)
	menu._process(PauseMenu.FADE_SEC * 0.5)
	menu.close()
	_fail_unless(not paused, "Reversing the pause should resume the game immediately")
	menu._process(PauseMenu.FADE_SEC * 0.5)
	_fail_unless(not paused, "Reversing the pause fade should leave the game running")
	_fail_unless(not menu.visible, "Reversing the pause fade should hide the menu")
	menu.free()


func _verify_music_fades_through_the_pause() -> void:
	var music := GlideMusicScript.new()
	root.add_child(music)
	var player := music.get_node("GlideTheme") as AudioStreamPlayer
	music.call("_on_eon_collected")
	music.call("_tick", GlideMusicScript.ENTRANCE_FADE_SEC)
	var menu := _make_menu()
	menu.open(null)
	_fail_unless(paused, "The game should pause before the music fade finishes")
	_fail_unless(player.playing and not player.stream_paused, "Glide music should keep playing while it fades out")
	menu._process(PauseMenu.FADE_SEC * 0.5)
	_fail_unless(_master_db_now() < -6.0, "Glide music should be quieter halfway through the pause fade")
	menu._process(PauseMenu.FADE_SEC * 0.5)
	_fail_unless(player.stream_paused, "Glide music should be suspended once the pause fade finishes")
	menu.close()
	_fail_unless(not paused, "The game should resume before the music fades back in")
	menu._process(PauseMenu.FADE_SEC * 0.25)
	_fail_unless(player.playing and not player.stream_paused, "Glide music should be playing during the resume fade")
	_fail_unless(_master_db_now() < -6.0, "Glide music should still be quiet early in the resume fade")
	menu._process(PauseMenu.FADE_SEC)
	_fail_unless(not player.stream_paused, "Glide music should be playing again after resume")
	menu.free()
	music.free()
	paused = false


func _make_menu() -> PauseMenu:
	var menu := PauseMenuScene.instantiate() as PauseMenu
	root.add_child(menu)
	return menu


func _master_db_now() -> float:
	if _master_bus < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(_master_bus)


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
