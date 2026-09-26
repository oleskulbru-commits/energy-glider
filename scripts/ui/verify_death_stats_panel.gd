extends SceneTree

const HUDScene := preload("res://scenes/ui/glider_hud.tscn")
const DeathStatsScene := preload("res://scenes/ui/death_stats_panel.tscn")
const DeathStatsPanelScript := preload("res://scripts/ui/death_stats_panel.gd")
const RunUpgradeStateScript := preload("res://scripts/game/run_upgrade_state.gd")
const RunDamageStatsScript := preload("res://scripts/game/run_damage_stats.gd")
const UpgradeCatalogScript := preload("res://scripts/game/upgrade_catalog.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_populate_keeps_rows_and_scroll()
	await _verify_hud_death_overlay_populates_once()
	if _failed:
		quit(1)
		return
	print("Death stats panel verification passed.")
	quit(0)


func _verify_populate_keeps_rows_and_scroll() -> void:
	var panel: DeathStatsPanelScript = DeathStatsScene.instantiate() as DeathStatsPanelScript
	_fail_unless(panel != null, "DeathStatsPanel scene should instantiate")
	if _failed:
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 80)
	root.add_child(scroll)
	scroll.add_child(panel)
	await process_frame

	var upgrade_state := RunUpgradeStateScript.new()
	var damage_stats := RunDamageStatsScript.new()
	root.add_child(upgrade_state)
	root.add_child(damage_stats)
	upgrade_state.grant_weapon(UpgradeCatalogScript.FAMILY_RIFLE)
	upgrade_state.grant_weapon(UpgradeCatalogScript.FAMILY_LASER)
	damage_stats.record(UpgradeCatalogScript.FAMILY_RIFLE, 40)
	damage_stats.record(UpgradeCatalogScript.FAMILY_LASER, 10)
	upgrade_state._apply_upgrade(
		UpgradeCatalogScript.make_id(
			UpgradeCatalogScript.FAMILY_PROJECTILE,
			UpgradeCatalogScript.RARITY_UNCOMMON
		)
	)

	panel.populate(null, null, upgrade_state, damage_stats)
	await process_frame
	var damage_rows: VBoxContainer = panel.get_node("%DamageRows")
	var upgrade_rows: VBoxContainer = panel.get_node("%UpgradeRows")
	_fail_unless(damage_rows.get_child_count() == 2, "Damage rows should list owned weapons")
	_fail_unless(
		_row_text(damage_rows.get_child(0)).contains("kills: 0"),
		"Damage rows should list kills beside damage"
	)
	_fail_unless(upgrade_rows.get_child_count() >= 1, "Upgrade rows should list bundled upgrades")
	if _failed:
		_free_nodes([scroll, upgrade_state, damage_stats])
		return

	var first_damage_id := damage_rows.get_child(0).get_instance_id()
	var first_upgrade_id := upgrade_rows.get_child(0).get_instance_id()
	var scroll_bar := scroll.get_v_scroll_bar()
	var can_scroll := scroll_bar != null and scroll_bar.max_value > scroll_bar.page
	if can_scroll:
		scroll.scroll_vertical = 24

	panel.populate(null, null, upgrade_state, damage_stats)
	await process_frame
	_fail_unless(
		damage_rows.get_child(0).get_instance_id() == first_damage_id,
		"Repeated populate should keep existing damage rows"
	)
	_fail_unless(
		upgrade_rows.get_child(0).get_instance_id() == first_upgrade_id,
		"Repeated populate should keep existing upgrade rows"
	)
	if can_scroll:
		_fail_unless(
			scroll.scroll_vertical == 24,
			"Repeated populate should keep the death board scroll offset"
		)

	damage_stats.record(UpgradeCatalogScript.FAMILY_RIFLE, 15)
	damage_stats.record_kill(UpgradeCatalogScript.FAMILY_RIFLE)
	panel.populate(null, null, upgrade_state, damage_stats)
	await process_frame
	_fail_unless(
		damage_rows.get_child(0).get_instance_id() != first_damage_id,
		"Changed damage totals should rebuild damage rows"
	)
	_fail_unless(
		_row_text(damage_rows.get_child(0)).contains("kills: 1"),
		"Updated kill counts should show on the rebuilt damage row"
	)

	_free_nodes([scroll, upgrade_state, damage_stats])


func _verify_hud_death_overlay_populates_once() -> void:
	var upgrade_state := RunUpgradeStateScript.new()
	var damage_stats := RunDamageStatsScript.new()
	root.add_child(upgrade_state)
	root.add_child(damage_stats)
	upgrade_state.grant_weapon(UpgradeCatalogScript.FAMILY_RIFLE)
	damage_stats.record(UpgradeCatalogScript.FAMILY_RIFLE, 25)

	var hud: GliderHUD = HUDScene.instantiate() as GliderHUD
	_fail_unless(hud != null, "Glider HUD scene should instantiate")
	if _failed:
		_free_nodes([upgrade_state, damage_stats])
		return
	root.add_child(hud)
	await process_frame

	hud.call("_update_death_overlay")
	await process_frame
	var panel: DeathStatsPanelScript = hud.get_node("%DeathStatsPanel") as DeathStatsPanelScript
	var damage_rows: VBoxContainer = panel.get_node("%DamageRows")
	_fail_unless(damage_rows.get_child_count() == 1, "Death overlay should populate damage rows once")
	if _failed:
		_free_nodes([hud, upgrade_state, damage_stats])
		return

	var row_id := damage_rows.get_child(0).get_instance_id()
	hud.call("_update_death_overlay")
	await process_frame
	_fail_unless(
		bool(hud.get("_death_board_populated")),
		"Death overlay should remember it already populated the board"
	)
	_fail_unless(
		damage_rows.get_child(0).get_instance_id() == row_id,
		"Death overlay process should not recreate damage rows"
	)

	_free_nodes([hud, upgrade_state, damage_stats])


func _free_nodes(nodes: Array) -> void:
	for node in nodes:
		if node != null:
			(node as Node).queue_free()


func _row_text(row: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for child in row.get_children():
		var label := child as Label
		if label != null:
			parts.append(label.text)
	return " ".join(parts)


func _fail_unless(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
