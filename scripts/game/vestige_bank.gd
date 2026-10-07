class_name VestigeBank
extends RefCounted

## Vestiges kept after a run. The main menu reads this total.

const SAVE_PATH := "user://vestige_bank.cfg"

static var save_path := SAVE_PATH


static func get_total() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return 0
	return maxi(int(cfg.get_value("vestiges", "total", 0)), 0)


static func add(amount: int) -> int:
	var total := get_total() + maxi(amount, 0)
	var cfg := ConfigFile.new()
	cfg.set_value("vestiges", "total", total)
	cfg.save(save_path)
	return total
