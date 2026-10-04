class_name GliderAnimTreeSchema
extends RefCounted

## Explicit body root transitions (from, to). No all-to-all mesh — avoids illegal blends / T-pose.
const ALLOWED_BODY_TRANSITIONS: Array = [
	["grounded", "locomotion"],
	["grounded", "jump"],
	["grounded", "jump_charge"],
	["grounded", "boost"],
	["grounded", "brake"],
	["grounded", "glide"],
	["grounded", "landing"],
	["grounded", "death"],
	["locomotion", "grounded"],
	["locomotion", "jump"],
	["locomotion", "jump_charge"],
	["locomotion", "boost"],
	["locomotion", "brake"],
	["locomotion", "glide"],
	["locomotion", "landing"],
	["locomotion", "death"],
	["jump", "glide"],
	["jump", "boost"],
	["jump", "brake"],
	["jump", "locomotion"],
	["jump", "landing"],
	["jump", "death"],
	["jump_charge", "jump"],
	["jump_charge", "grounded"],
	["jump_charge", "locomotion"],
	["jump_charge", "boost"],
	["jump_charge", "brake"],
	["jump_charge", "death"],
	["glide", "jump"],
	["glide", "boost"],
	["glide", "brake"],
	["glide", "landing"],
	["glide", "locomotion"],
	["glide", "grounded"],
	["glide", "death"],
	["boost", "jump"],
	["boost", "glide"],
	["boost", "locomotion"],
	["boost", "grounded"],
	["boost", "brake"],
	["boost", "landing"],
	["boost", "death"],
	["brake", "jump"],
	["brake", "glide"],
	["brake", "locomotion"],
	["brake", "grounded"],
	["brake", "boost"],
	["brake", "landing"],
	["brake", "death"],
	["landing", "locomotion"],
	["landing", "grounded"],
	["landing", "boost"],
	["landing", "brake"],
	["landing", "death"],
]

const FORBIDDEN_BODY_TRANSITIONS: Array = [
	["landing", "jump"],
	["landing", "jump_charge"],
	["landing", "glide"],
]

## Parameter paths GliderAnimController expects on the live AnimationTree.
const REQUIRED_PARAMETERS: Array[String] = [
	"parameters/body/boost/enter/seek/seek_request",
	"parameters/body/boost/enter/time_scale/scale",
	"parameters/body/boost/exit/seek/seek_request",
	"parameters/body/boost/exit/time_scale/scale",
	"parameters/body/locomotion/enter/seek/seek_request",
	"parameters/body/locomotion/enter/time_scale/scale",
	"parameters/body/locomotion/exit/seek/seek_request",
	"parameters/body/locomotion/exit/time_scale/scale",
	"parameters/body/locomotion/move/blend_space/blend_position",
	"parameters/body/locomotion/move/time_scale/scale",
	"parameters/body/boost/loop/time_scale/scale",
	"parameters/body/brake/loop/time_scale/scale",
]


static func validate(tree: AnimationTree) -> PackedStringArray:
	var errors: PackedStringArray = []
	if tree == null:
		errors.append("AnimationTree is null")
		return errors
	if tree.tree_root == null:
		errors.append("AnimationTree.tree_root is null")
		return errors

	var root_bt := tree.tree_root as AnimationNodeBlendTree
	if root_bt == null:
		errors.append("Root tree_root should be AnimationNodeBlendTree")
		return errors

	var body := root_bt.get_node(&"body") as AnimationNodeStateMachine
	if body == null:
		errors.append("Body state machine missing under tree_root")
		return errors

	var locomotion := body.get_node(&"locomotion") as AnimationNodeStateMachine
	if locomotion == null:
		errors.append("Locomotion nested state machine missing")
	else:
		_assert_seek_nested_sm(locomotion, &"locomotion", errors)
		for state_name in [&"enter", &"move", &"exit"]:
			if not locomotion.has_node(state_name):
				errors.append("Locomotion missing state: %s" % state_name)
		if not locomotion.has_transition(&"move", &"exit"):
			errors.append("Locomotion missing move -> exit transition")
		if not locomotion.has_transition(&"enter", &"move"):
			errors.append("Locomotion missing enter -> move transition")

	var boost := body.get_node(&"boost") as AnimationNodeStateMachine
	if boost == null:
		errors.append("Boost nested state machine missing")
	else:
		_assert_seek_nested_sm(boost, &"boost", errors)
		for state_name in [&"enter", &"loop", &"exit"]:
			if not boost.has_node(state_name):
				errors.append("Boost missing state: %s" % state_name)
		if not boost.has_transition(&"loop", &"exit"):
			errors.append("Boost missing loop -> exit transition")
		if not boost.has_transition(&"enter", &"loop"):
			errors.append("Boost missing enter -> loop transition")

	var param_names := _collect_parameter_names(tree)
	for path in REQUIRED_PARAMETERS:
		if path not in param_names:
			errors.append("AnimationTree missing parameter: %s" % path)

	_assert_body_transition_policy(body, errors)

	return errors


static func _assert_body_transition_policy(body: AnimationNodeStateMachine, errors: PackedStringArray) -> void:
	var allowed := {}
	for pair in ALLOWED_BODY_TRANSITIONS:
		var key := StringName("%s->%s" % [pair[0], pair[1]])
		allowed[key] = true
		if not body.has_transition(StringName(pair[0]), StringName(pair[1])):
			errors.append("Body missing allowed transition: %s -> %s" % [pair[0], pair[1]])
	for pair in FORBIDDEN_BODY_TRANSITIONS:
		if body.has_transition(StringName(pair[0]), StringName(pair[1])):
			errors.append("Body must not have transition: %s -> %s" % [pair[0], pair[1]])


static func _assert_seek_nested_sm(
	sm: AnimationNodeStateMachine,
	label: String,
	errors: PackedStringArray
) -> void:
	for state_name in [&"enter", &"exit"]:
		if not sm.has_node(state_name):
			continue
		var node := sm.get_node(state_name)
		if not node is AnimationNodeBlendTree:
			errors.append(
				"%s state '%s' should be seek/time_scale BlendTree (got %s)"
				% [label, state_name, node.get_class()]
			)
			continue
		var bt := node as AnimationNodeBlendTree
		var node_names: Array[StringName] = bt.get_node_list()
		if node_names.is_empty():
			errors.append("%s state '%s' BlendTree is empty" % [label, state_name])
			continue
		var has_seek := false
		for node_id in node_names:
			var child := bt.get_node(node_id)
			if child is AnimationNodeTimeSeek:
				has_seek = true
				break
		if not has_seek:
			errors.append("%s state '%s' should contain AnimationNodeTimeSeek" % [label, state_name])


static func _collect_parameter_names(tree: AnimationTree) -> Dictionary:
	var names := {}
	for prop in tree.get_property_list():
		var name := str(prop.name)
		if name.begins_with("parameters/"):
			names[name] = true
	return names
