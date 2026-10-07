extends CanvasLayer

## Run Vestige total. Stays visible while the upgrade menu pauses the game.

@onready var _count: Label = %Count


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_bind_wallet")


func _bind_wallet() -> void:
	var wallet := get_tree().get_first_node_in_group("vestige_wallet")
	if wallet == null:
		_set_count(0)
		return
	if wallet.has_signal("balance_changed") and not wallet.balance_changed.is_connected(_set_count):
		wallet.balance_changed.connect(_set_count)
	if wallet.has_method("get_balance"):
		_set_count(int(wallet.get_balance()))


func _set_count(balance: int) -> void:
	if _count != null:
		_count.text = str(balance)
