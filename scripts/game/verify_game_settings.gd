extends SceneTree

const GameSettingsScript := preload("res://scripts/game/game_settings.gd")
const VERIFY_FILE := "user://settings_verify.cfg"

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var saved_path: String = GameSettingsScript.save_path
	GameSettingsScript.save_path = VERIFY_FILE
	_remove_verify_file()
	_verify_defaults_when_missing()
	_verify_volumes_survive_a_restart()
	_verify_mute_survives_a_restart()
	_verify_slider_writes_the_save()
	_verify_pause_duck_is_not_saved()
	_verify_restore_defaults()
	_remove_verify_file()
	GameSettingsScript.save_path = saved_path
	GameSettingsScript.apply()
	if _failed:
		push_error("Game settings verification failed")
		quit(1)
		return
	print("Game settings verification passed")
	quit(0)


func _verify_defaults_when_missing() -> void:
	_clear_buses()
	GameSettingsScript.apply()
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Music"), 1.0), "A missing save should keep music at full volume")
	_fail_unless(not GameSettingsScript.is_muted(), "A missing save should leave mute off")
	_fail_unless(_bus_linear("Music") > 0.99, "Applying a missing save should leave the music bus at full volume")
	_fail_unless(not _master_muted(), "Applying a missing save should leave Master unmuted")


func _verify_volumes_survive_a_restart() -> void:
	GameSettingsScript.set_volume("Master", 0.5)
	GameSettingsScript.set_volume("Music", 0.25)
	GameSettingsScript.set_volume("SFX", 0.0)
	GameSettingsScript.set_volume("UI", 1.5)
	_clear_buses()
	GameSettingsScript.apply()
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Master"), 0.5), "Master volume should be saved")
	_fail_unless(is_equal_approx(_bus_linear("Master"), 0.5), "A new launch should restore the Master bus")
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Music"), 0.25), "Music volume should be saved")
	_fail_unless(is_equal_approx(_bus_linear("Music"), 0.25), "A new launch should restore the Music bus")
	_fail_unless(is_equal_approx(GameSettingsScript.volume("SFX"), 0.0), "Silence should be saved as zero")
	_fail_unless(
		is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), GameSettingsScript.SILENT_DB),
		"A new launch should silence the SFX bus when the saved volume is zero"
	)
	_fail_unless(is_equal_approx(GameSettingsScript.volume("UI"), 1.0), "A volume above full should clamp to full")
	_fail_unless(is_equal_approx(_bus_linear("UI"), 1.0), "A new launch should apply the clamped UI volume")
	GameSettingsScript.set_volume("Music", -3.0)
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Music"), 0.0), "A negative volume should clamp to silence")
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Master"), 0.5), "Changing one bus should keep the others")


func _verify_mute_survives_a_restart() -> void:
	GameSettingsScript.set_muted(true)
	_clear_buses()
	GameSettingsScript.apply()
	_fail_unless(GameSettingsScript.is_muted(), "Mute should be saved")
	_fail_unless(_master_muted(), "A new launch should mute Master again")
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Master"), 0.5), "Mute should keep the saved Master volume")


func _verify_slider_writes_the_save() -> void:
	var slider := (load("res://scenes/ui/volume_slider.tscn") as PackedScene).instantiate() as VolumeSlider
	slider.bus_name = "Music"
	root.add_child(slider)
	slider.set_volume(0.35)
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Music"), 0.35), "Dragging a slider should save that volume")
	_fail_unless(is_equal_approx(_bus_linear("Music"), 0.35), "Dragging a slider should set that bus")
	slider.free()


func _verify_pause_duck_is_not_saved() -> void:
	GameSettingsScript.set_volume("Master", 0.5)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(0.05))
	_fail_unless(is_equal_approx(GameSettingsScript.volume("Master"), 0.5), "A pause fade should not replace the saved Master volume")
	_clear_buses()
	GameSettingsScript.apply()
	_fail_unless(is_equal_approx(_bus_linear("Master"), 0.5), "The next launch should restore the volume from before the pause fade")


func _verify_restore_defaults() -> void:
	GameSettingsScript.set_muted(true)
	GameSettingsScript.restore_audio_defaults()
	_clear_buses()
	GameSettingsScript.apply()
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		_fail_unless(
			is_equal_approx(GameSettingsScript.volume(bus_name), 1.0),
			"Restore defaults should save full %s volume" % bus_name
		)
		_fail_unless(
			_bus_linear(bus_name) > 0.99,
			"A new launch after restore should put %s back to full volume" % bus_name
		)
	_fail_unless(not GameSettingsScript.is_muted(), "Restore defaults should clear mute")
	_fail_unless(not _master_muted(), "A new launch after restore should leave Master unmuted")


func _clear_buses() -> void:
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		var bus := AudioServer.get_bus_index(bus_name)
		_fail_unless(bus >= 0, "%s bus should exist" % bus_name)
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, 0.0)
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, false)


func _bus_linear(bus_name: String) -> float:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return -1.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus))


func _master_muted() -> bool:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return false
	return AudioServer.is_bus_mute(bus)


func _remove_verify_file() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("settings_verify.cfg"):
		dir.remove("settings_verify.cfg")


func _fail_unless(ok: bool, message: String) -> void:
	if ok:
		return
	_failed = true
	push_error(message)
