class_name DebrisBudget
extends Node

## Global cap on active physics debris (RigidBody3D chips and death shards).

enum Priority { NORMAL, CRIT, KILL, DEATH_BURST }

const MAX_ACTIVE := 24
const MAX_SPAWN_PER_FRAME := 4
const MAX_SPAWN_PER_SECOND := 12
const RESERVE_FOR_KILL := 8

const _PHYSICS_DEBRIS_GROUP := &"physics_debris"
const _BUDGET_GROUP := &"debris_budget"

var _entries: Array[Dictionary] = []
var _spawned_this_frame := 0
var _spawned_this_second := 0
var _second_timer := 0.0


func _ready() -> void:
	add_to_group(_BUDGET_GROUP)


func _physics_process(delta: float) -> void:
	_spawned_this_frame = 0
	_second_timer += delta
	if _second_timer >= 1.0:
		_second_timer = 0.0
		_spawned_this_second = 0
	_prune_invalid()


static func find_in_tree(tree: SceneTree) -> DebrisBudget:
	if tree == null:
		return null
	return tree.get_first_node_in_group(_BUDGET_GROUP) as DebrisBudget


func active_count() -> int:
	_prune_invalid()
	return _entries.size()


func reset() -> void:
	_entries.clear()
	_spawned_this_frame = 0
	_spawned_this_second = 0
	_second_timer = 0.0


func request_spawn(count: int, priority: Priority) -> int:
	if count <= 0:
		return 0
	_prune_invalid()

	var allowed := mini(count, _rate_limit_remaining())
	if allowed <= 0:
		return 0

	var room := _room_for_priority(priority)
	if room < allowed:
		_evict_for(priority, allowed - room)
		room = _room_for_priority(priority)

	allowed = mini(allowed, room)
	if allowed > 0:
		_spawned_this_frame += allowed
		_spawned_this_second += allowed
	return allowed


func register(body: RigidBody3D, priority: Priority) -> void:
	if body == null:
		return
	body.add_to_group(_PHYSICS_DEBRIS_GROUP)
	_entries.append({
		"body": body,
		"priority": priority,
		"spawn_time": Time.get_ticks_msec(),
	})
	if not body.tree_exited.is_connected(_on_body_exited):
		body.tree_exited.connect(_on_body_exited.bind(body))


func _on_body_exited(body: Node) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i].get("body") == body:
			_entries.remove_at(i)
			return


func _prune_invalid() -> void:
	for i in range(_entries.size() - 1, -1, -1):
		var body: RigidBody3D = _entries[i].get("body")
		if body == null or not is_instance_valid(body):
			_entries.remove_at(i)


func _rate_limit_remaining() -> int:
	var frame_room := MAX_SPAWN_PER_FRAME - _spawned_this_frame
	var second_room := MAX_SPAWN_PER_SECOND - _spawned_this_second
	return maxi(mini(frame_room, second_room), 0)


func _room_for_priority(priority: Priority) -> int:
	var active := active_count()
	if _is_high_priority(priority):
		return maxi(MAX_ACTIVE - active, RESERVE_FOR_KILL - active)
	return MAX_ACTIVE - active


func _is_high_priority(priority: Priority) -> bool:
	return priority == Priority.KILL or priority == Priority.DEATH_BURST


func _evict_for(priority: Priority, need: int) -> void:
	if need <= 0 or not _is_high_priority(priority):
		return
	var freed := 0
	for evict_priority in [Priority.NORMAL, Priority.CRIT]:
		while freed < need:
			var idx := _oldest_entry_index(evict_priority)
			if idx < 0:
				break
			var body: RigidBody3D = _entries[idx].get("body")
			_entries.remove_at(idx)
			if body != null and is_instance_valid(body):
				body.queue_free()
			freed += 1


func _oldest_entry_index(priority: Priority) -> int:
	var best_idx := -1
	var best_time := INF
	for i in _entries.size():
		if int(_entries[i].get("priority", Priority.NORMAL)) != priority:
			continue
		var spawn_time: float = _entries[i].get("spawn_time", 0.0)
		if spawn_time < best_time:
			best_time = spawn_time
			best_idx = i
	return best_idx
