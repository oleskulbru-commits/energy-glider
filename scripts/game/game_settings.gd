class_name GameSettings
extends RefCounted

## Player options kept after the game closes.
## Pause and music fades change a bus for a moment and must not write this file.

const SAVE_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 1.0
const SILENT_DB := -80.0

static var save_path := SAVE_PATH


static func apply() -> void:
	var cfg := _load()
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		_apply_volume(bus_name, volume_from(cfg, bus_name))
	_apply_mute(bool(cfg.get_value("audio", "mute_all", false)))


static func volume(bus_name: String) -> float:
	return volume_from(_load(), bus_name)


static func set_volume(bus_name: String, value: float) -> void:
	var linear := clampf(value, 0.0, 1.0)
	var cfg := _load()
	cfg.set_value("audio", bus_name, linear)
	cfg.save(save_path)
	_apply_volume(bus_name, linear)


static func is_muted() -> bool:
	return bool(_load().get_value("audio", "mute_all", false))


static func set_muted(muted: bool) -> void:
	var cfg := _load()
	cfg.set_value("audio", "mute_all", muted)
	cfg.save(save_path)
	_apply_mute(muted)


static func restore_audio_defaults() -> void:
	var cfg := _load()
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		cfg.set_value("audio", bus_name, DEFAULT_VOLUME)
		_apply_volume(bus_name, DEFAULT_VOLUME)
	cfg.set_value("audio", "mute_all", false)
	cfg.save(save_path)
	_apply_mute(false)


static func volume_from(cfg: ConfigFile, bus_name: String) -> float:
	return clampf(float(cfg.get_value("audio", bus_name, DEFAULT_VOLUME)), 0.0, 1.0)


static func _apply_volume(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	if linear <= 0.0:
		AudioServer.set_bus_volume_db(bus, SILENT_DB)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(linear))


static func _apply_mute(muted: bool) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, muted)


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	return cfg
