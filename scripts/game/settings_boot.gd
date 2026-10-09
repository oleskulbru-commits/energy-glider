extends Node

const GameSettingsScript := preload("res://scripts/game/game_settings.gd")


func _ready() -> void:
	GameSettingsScript.apply()
