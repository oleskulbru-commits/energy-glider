class_name DeathStatsPanel
extends VBoxContainer

const LevelLayoutScript = preload("res://scripts/game/level_layout.gd")
const RunDamageStatsScript = preload("res://scripts/game/run_damage_stats.gd")

@onready var _title: Label = %StoppedTitle
@onready var _west_distance: Label = %WestDistance
@onready var _tower_reached: Label = %TowerReached
@onready var _integrity: Label = %IntegrityValue
@onready var _damage_rows: VBoxContainer = %DamageRows
@onready var _upgrade_rows: VBoxContainer = %UpgradeRows
@onready var _damage_section: VBoxContainer = %DamageSection
@onready var _upgrades_section: VBoxContainer = %UpgradesSection

var _damage_rows_key := "\uffff"
var _upgrade_rows_key := "\uffff"


func set_flavor_text(text: String) -> void:
	if _title != null:
		_title.text = text


func set_sections_visible(show_sections: bool) -> void:
	if _west_distance != null:
		_west_distance.visible = show_sections
	if _tower_reached != null:
		_tower_reached.visible = show_sections
	if _integrity != null:
		_integrity.visible = show_sections
	if _damage_section != null:
		_damage_section.visible = show_sections
	if _upgrades_section != null:
		_upgrades_section.visible = show_sections
	if not show_sections:
		_invalidate_row_cache()


func populate(
	director: EonDirector,
	terrain: TerrainManager,
	upgrade_state: RunUpgradeState,
	damage_stats: RunDamageStatsScript
) -> void:
	set_sections_visible(true)
	_populate_summary(director, terrain)
	_populate_damage_rows(upgrade_state, damage_stats)
	_populate_upgrade_rows(upgrade_state)


func _populate_summary(director: EonDirector, terrain: TerrainManager) -> void:
	var origin_x := 0.0
	if terrain != null:
		origin_x = terrain.run_origin.x
	var death_pos := director.death_position if director != null else Vector3.ZERO
	var west_m := maxf(origin_x - death_pos.x, 0.0)
	if _west_distance != null:
		_west_distance.text = "Distance west: %s" % MathUtil.format_distance_m(west_m)
	var segment := 1
	if director != null:
		segment = LevelLayoutScript.level_at_world_x(death_pos.x, origin_x)
	if _tower_reached != null:
		_tower_reached.text = "Tower %d of %d" % [segment, LevelLayoutScript.segment_count()]
	if _integrity != null:
		var integrity := director.integrity if director != null else 0
		_integrity.text = "E.O.N. Integrity  %d%%" % integrity


func _populate_damage_rows(upgrade_state: RunUpgradeState, damage_stats: RunDamageStatsScript) -> void:
	if _damage_rows == null:
		return
	var key := _damage_content_key(upgrade_state, damage_stats)
	if key == _damage_rows_key:
		if _damage_section != null:
			_damage_section.visible = not key.is_empty()
		return
	_damage_rows_key = key
	_clear_children(_damage_rows)
	if key.is_empty():
		if _damage_section != null:
			_damage_section.visible = false
		return
	if _damage_section != null:
		_damage_section.visible = true
	var ranked: PackedStringArray = damage_stats.ranked_weapons(upgrade_state.owned_weapon_ids())
	var max_damage := 1
	for family in ranked:
		max_damage = maxi(max_damage, damage_stats.damage_for(StringName(family)))
	for family in ranked:
		var id := StringName(family)
		_damage_rows.add_child(_make_damage_row(
			id,
			upgrade_state,
			damage_stats.damage_for(id),
			float(damage_stats.damage_for(id)) / float(max_damage),
			damage_stats.kills_for(id)
		))


func _populate_upgrade_rows(upgrade_state: RunUpgradeState) -> void:
	if _upgrade_rows == null:
		return
	var entries: Array[Dictionary] = []
	if upgrade_state != null:
		entries = upgrade_state.death_upgrade_summary()
	var key := _upgrade_content_key(entries)
	if key == _upgrade_rows_key:
		if _upgrades_section != null:
			_upgrades_section.visible = not key.is_empty()
		return
	_upgrade_rows_key = key
	_clear_children(_upgrade_rows)
	if key.is_empty():
		if _upgrades_section != null:
			_upgrades_section.visible = false
		return
	if _upgrades_section != null:
		_upgrades_section.visible = true
	for entry in entries:
		_upgrade_rows.add_child(_make_upgrade_row(entry))


func _damage_content_key(upgrade_state: RunUpgradeState, damage_stats: RunDamageStatsScript) -> String:
	if upgrade_state == null or damage_stats == null:
		return ""
	var owned := upgrade_state.owned_weapon_ids()
	if owned.is_empty():
		return ""
	var parts: PackedStringArray = []
	for family in damage_stats.ranked_weapons(owned):
		var id := StringName(family)
		parts.append("%s:%d:%d:%d" % [
			family,
			upgrade_state.weapon_level(id),
			damage_stats.damage_for(id),
			damage_stats.kills_for(id)
		])
	return ",".join(parts)


func _upgrade_content_key(entries: Array[Dictionary]) -> String:
	if entries.is_empty():
		return ""
	var parts: PackedStringArray = []
	for entry in entries:
		parts.append(String(entry.get("label", "")))
	return "|".join(parts)


func _invalidate_row_cache() -> void:
	_damage_rows_key = "\uffff"
	_upgrade_rows_key = "\uffff"


func _make_damage_row(
	family: StringName,
	upgrade_state: RunUpgradeState,
	damage: int,
	ratio: float,
	kills: int
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 28

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var level := maxi(upgrade_state.weapon_level(family), 1)
	icon.texture = UpgradeCatalog.icon_for_weapon_level(family, level)
	row.add_child(icon)

	var unlock := UpgradeCatalog.unlock_id_for(family)
	var name_label := Label.new()
	name_label.text = "%s:" % UpgradeCatalog.display_name(unlock)
	name_label.custom_minimum_size.x = 132
	name_label.theme_type_variation = &"HudLabel"
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(180, 14)
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	row.add_child(bar)

	var separator := Label.new()
	separator.text = "|"
	separator.theme_type_variation = &"HudLabel"
	row.add_child(separator)

	var damage_label := Label.new()
	damage_label.text = "%s damage" % MathUtil.format_damage_compact(damage)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	damage_label.custom_minimum_size.x = 96
	damage_label.theme_type_variation = &"HudLabel"
	row.add_child(damage_label)

	var kills_label := Label.new()
	kills_label.name = "KillsLabel"
	kills_label.text = "kills: %d" % kills
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills_label.custom_minimum_size.x = 80
	kills_label.theme_type_variation = &"HudLabel"
	row.add_child(kills_label)
	return row


func _make_upgrade_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 24

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = entry.get("icon") as Texture2D
	row.add_child(icon)

	var label := Label.new()
	label.text = String(entry.get("label", ""))
	label.theme_type_variation = &"HudLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
