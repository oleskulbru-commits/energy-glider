class_name LevelTerrainCatalog
extends RefCounted

## Authoring registry: difficulty bands, terrain profiles, and prototype level specs.
## Live runs use LevelRunGenerator (seeded segments + hybrids); catalog supplies profile definitions.

const LevelTerrainBandScript = preload("res://scripts/game/level_terrain_band.gd")
const LevelTerrainProfileScript = preload("res://scripts/game/level_terrain_profile.gd")
const LevelTerrainSpecScript = preload("res://scripts/game/level_terrain_spec.gd")

const BAND_TUTORIAL := "TUTORIAL"
const BAND_EASY := "EASY"
const BAND_MEDIUM := "MEDIUM"
const BAND_HARD := "HARD"
const BAND_EXTREME := "EXTREME"

static var _ready := false
static var _bands: Dictionary = {} # String -> LevelTerrainBandScript
static var _profiles: Dictionary = {} # String -> LevelTerrainProfileScript
static var _specs: Dictionary = {} # int -> LevelTerrainSpecScript


static func _ensure() -> void:
	if _ready:
		return
	_ready = true
	_register_bands()
	_register_atomic_profiles()
	_register_hybrid_profiles()
	_register_level_specs()


static func get_band(band_id: String) -> LevelTerrainBandScript:
	_ensure()
	return _bands.get(band_id) as LevelTerrainBandScript


static func get_profile(profile_id: String) -> LevelTerrainProfileScript:
	_ensure()
	return _profiles.get(profile_id) as LevelTerrainProfileScript


static func get_spec_for_level(level_index: int) -> LevelTerrainSpecScript:
	_ensure()
	return _specs.get(level_index) as LevelTerrainSpecScript


static func all_bands() -> Array[LevelTerrainBandScript]:
	_ensure()
	var out: Array[LevelTerrainBandScript] = []
	for key in _bands.keys():
		out.append(_bands[key] as LevelTerrainBandScript)
	out.sort_custom(func(a: LevelTerrainBandScript, b: LevelTerrainBandScript) -> bool:
		return a.intensity < b.intensity
	)
	return out


static func all_profiles() -> Array[LevelTerrainProfileScript]:
	_ensure()
	var out: Array[LevelTerrainProfileScript] = []
	for key in _profiles.keys():
		out.append(_profiles[key] as LevelTerrainProfileScript)
	out.sort_custom(func(a: LevelTerrainProfileScript, b: LevelTerrainProfileScript) -> bool:
		if a.category == b.category:
			return a.id < b.id
		return a.category < b.category
	)
	return out


static func all_specs() -> Array[LevelTerrainSpecScript]:
	_ensure()
	var keys: Array = _specs.keys()
	keys.sort()
	var out: Array[LevelTerrainSpecScript] = []
	for key in keys:
		out.append(_specs[key] as LevelTerrainSpecScript)
	return out


static func list_profiles_in_category(category: String) -> Array[LevelTerrainProfileScript]:
	_ensure()
	var out: Array[LevelTerrainProfileScript] = []
	for profile in all_profiles():
		if profile.category == category:
			out.append(profile)
	return out


static func profile_count() -> int:
	_ensure()
	return _profiles.size()


static func _register_bands() -> void:
	_add_band(LevelTerrainBandScript.new(BAND_TUTORIAL, "Tutorial", 0.0))
	_add_band(LevelTerrainBandScript.new(BAND_EASY, "Easy", 0.25))
	_add_band(LevelTerrainBandScript.new(BAND_MEDIUM, "Medium", 0.5))
	_add_band(LevelTerrainBandScript.new(BAND_HARD, "Hard", 0.75))
	_add_band(LevelTerrainBandScript.new(BAND_EXTREME, "Extreme", 1.0))


static func _add_band(band: LevelTerrainBandScript) -> void:
	_bands[band.id] = band


static func _add_profile(profile: LevelTerrainProfileScript) -> void:
	_profiles[profile.id] = profile


static func _atomic(
	id: String,
	display_name: String,
	category: String,
	description: String
) -> void:
	_add_profile(LevelTerrainProfileScript.new(id, display_name, category, description, []))


static func _hybrid(
	id: String,
	display_name: String,
	description: String,
	composed_of: Array[String]
) -> void:
	_add_profile(
		LevelTerrainProfileScript.new(id, display_name, "hybrid", description, composed_of)
	)


static func _register_atomic_profiles() -> void:
	# Flow / wavelength
	_atomic("rolling_lanes", "Rolling Lanes", "flow", "Long westbound rollers; easy to stay in a fall line")
	_atomic("gentle_swells", "Gentle Swells", "flow", "Soft ocean-like undulation; low commitment")
	_atomic("mid_cadence", "Mid Cadence", "flow", "Classic dune spacing; default real desert")
	_atomic("tight_chop", "Tight Chop", "flow", "Short frequent bumps; constant micro-corrections")
	_atomic("mega_rollers", "Mega Rollers", "flow", "Very long faces; speed builds for ages")
	_atomic("stutter_steps", "Stutter Steps", "flow", "Alternating short/long dunes; broken rhythm")
	_atomic("heartbeat_pulse", "Heartbeat Pulse", "flow", "Regular big-small-big pattern")
	_atomic("syncopated_ridges", "Syncopated Ridges", "flow", "Irregular crest timing; hard to pre-time launches")

	# Crest / edge
	_atomic("soft_shoulders", "Soft Shoulders", "crest", "Rounded tops; skim-friendly")
	_atomic("knife_crests", "Knife Crests", "crest", "Sharp edges; punchy launches, harsher landings")
	_atomic("tabletop_mesas", "Tabletop Mesas", "crest", "Flat crest pads then sudden drop")
	_atomic("lip_ramps", "Lip Ramps", "crest", "Nose-up lips that kick you airborne")
	_atomic("blunt_brows", "Blunt Brows", "crest", "Thick steep brows; hard to crest cleanly")
	_atomic("double_crests", "Double Crests", "crest", "Twin ridges close together; second hit after landing")
	_atomic("false_summits", "False Summits", "crest", "Crest that is not the real high point")
	_atomic("razor_spine", "Razor Spine", "crest", "Narrow ridge line; punishes yaw error")
	_atomic("broken_teeth", "Broken Teeth", "crest", "Jagged uneven crest heights along Z")

	# Bowl / valley
	_atomic("soft_bowls", "Soft Bowls", "bowl", "Gentle 3D bowls; forgiving recovery")
	_atomic("deep_basins", "Deep Basins", "bowl", "Big low points; long climbs out")
	_atomic("shallow_saucers", "Shallow Saucers", "bowl", "Mild depressions; keep speed easily")
	_atomic("funnel_valleys", "Funnel Valleys", "bowl", "Walls steer you into a corridor")
	_atomic("escape_gulches", "Escape Gulches", "bowl", "Narrow exits; must aim the gap")
	_atomic("nested_bowls", "Nested Bowls", "bowl", "Bowl-inside-bowl; multi-stage recovery")
	_atomic("asymmetric_bowls", "Asymmetric Bowls", "bowl", "One wall steep, one wall soft")
	_atomic("floodplain_flats", "Floodplain Flats", "bowl", "Wide soft bottoms between ridges")

	# Climb / grade
	_atomic("easy_grades", "Easy Grades", "climb", "Mild climbs; speed barely bleeds")
	_atomic("climb_trains", "Climb Trains", "climb", "Long stacked uphills")
	_atomic("wall_faces", "Wall Faces", "climb", "Short brutal climbs")
	_atomic("switchback_grades", "Switchback Grades", "climb", "Climb angled off-west; must cut")
	_atomic("false_flat_climbs", "False Flat Climbs", "climb", "Looks flat, still drains speed")
	_atomic("staircase_ascents", "Staircase Ascents", "climb", "Step-step-step climbs")
	_atomic("relief_after_climb", "Relief After Climb", "climb", "Hard climb then generous downhill reward")
	_atomic("punish_climbs", "Punish Climbs", "climb", "Climb with no clean downhill payoff")

	# Lateral / Z
	_atomic("corridor_west", "Corridor West", "lateral", "Almost 2D along -X; little side drift")
	_atomic("mild_weave", "Mild Weave", "lateral", "Soft left/right sway")
	_atomic("slalom_spines", "Slalom Spines", "lateral", "Offset ridges force S-curves")
	_atomic("checker_dunes", "Checker Dunes", "lateral", "Cross-hatched highs and lows")
	_atomic("braided_channels", "Braided Channels", "lateral", "Multiple parallel paths")
	_atomic("dead_end_spurs", "Dead-End Spurs", "lateral", "Tempting side valleys that trap you")
	_atomic("crosswind_ribs", "Crosswind Ribs", "lateral", "Ribs perpendicular to travel")
	_atomic("maze_basins", "Maze Basins", "lateral", "High lateral chaos; easy to lose west line")

	# Warp / readability
	_atomic("honest_terrain", "Honest Terrain", "warp", "Low warp; what you see is what you get")
	_atomic("soft_warp", "Soft Warp", "warp", "Mild distortion")
	_atomic("twisted_warp", "Twisted Warp", "warp", "Fall lines bend unexpectedly")
	_atomic("mirage_ridges", "Mirage Ridges", "warp", "Crests look continuous but break")
	_atomic("skewed_domain", "Skewed Domain", "warp", "Directional stretch; more Z or X chaos")
	_atomic("noisy_micro", "Noisy Micro", "warp", "Fine detail chatter on clean macros")

	# Reset / flats
	_atomic("frequent_flats", "Frequent Flats", "reset", "Many recovery pads")
	_atomic("occasional_shelves", "Occasional Shelves", "reset", "Rare safe shelves")
	_atomic("scarce_flats", "Scarce Flats", "reset", "Almost no reset")
	_atomic("false_flats", "False Flats", "reset", "Flat that still has hidden grade")
	_atomic("ridge_only", "Ridge Only", "reset", "No real valleys; continuous high ground")
	_atomic("valley_only", "Valley Only", "reset", "Low lands with rare tall exits")

	# Speed / flow fantasy
	_atomic("speedway", "Speedway", "speed", "Clean downhills aligned west; build and hold")
	_atomic("pump_track", "Pump Track", "speed", "Short ups/downs you pump through")
	_atomic("glide_garden", "Glide Garden", "speed", "Soft airtime; friendly landings")
	_atomic("commitment_run", "Commitment Run", "speed", "Once you drop in, hard to bail")
	_atomic("stop_and_go", "Stop and Go", "speed", "Features force slow-fast-slow")
	_atomic("momentum_tax", "Momentum Tax", "speed", "Constant small drains; boost matters")
	_atomic("carry_paradise", "Carry Paradise", "speed", "Surplus speed carries far across flats")

	# Hazard-ish terrain
	_atomic("cliffette_drops", "Cliffette Drops", "hazard", "Sudden vertical-ish drops")
	_atomic("blind_backsides", "Blind Backsides", "hazard", "Cannot see landing until crest")
	_atomic("sandtrap_sinks", "Sandtrap Sinks", "hazard", "Soft bottoms that kill speed")
	_atomic("ridge_gauntlet", "Ridge Gauntlet", "hazard", "Many sharp crests in a row")
	_atomic("no_line_chaos", "No-Line Chaos", "hazard", "No obvious best path")
	_atomic("altitude_spikes", "Altitude Spikes", "hazard", "Occasional extreme peaks")

	# Tower-adjacent / setpiece
	_atomic("approach_calm", "Approach Calm", "setpiece", "Softens near next tower; safe arrival")
	_atomic("approach_trial", "Approach Trial", "setpiece", "Hardest chunk just before tower")
	_atomic("departure_boost", "Departure Boost", "setpiece", "Easy exit after leaving a tower")
	_atomic("saddle_gate", "Saddle Gate", "setpiece", "Must pass a saddle/col to continue west")
	_atomic("ridge_gate", "Ridge Gate", "setpiece", "Must crest a wall spanning the path")
	_atomic("bowl_arena", "Bowl Arena", "setpiece", "Mid-level amphitheater set piece")


static func _register_hybrid_profiles() -> void:
	_hybrid(
		"tutorial_flow",
		"Tutorial Flow",
		"Forgiving west flow for learning",
		["rolling_lanes", "soft_shoulders", "frequent_flats"]
	)
	_hybrid(
		"learning_desert",
		"Learning Desert",
		"Readable real dunes without punishment",
		["mid_cadence", "soft_bowls", "honest_terrain"]
	)
	_hybrid(
		"open_speedway",
		"Open Speedway",
		"Long rollers and clean west carry",
		["mega_rollers", "corridor_west", "carry_paradise"]
	)
	_hybrid(
		"crest_school",
		"Crest School",
		"Friendly airtime practice on readable crests",
		["soft_shoulders", "glide_garden", "occasional_shelves"]
	)
	_hybrid(
		"bowl_runner",
		"Bowl Runner",
		"Soft bowls with mild weave",
		["soft_bowls", "mild_weave", "easy_grades"]
	)
	_hybrid(
		"slalom_medium",
		"Slalom Medium",
		"S-curve spines at medium intensity",
		["slalom_spines", "mid_cadence", "soft_warp"]
	)
	_hybrid(
		"knife_medium",
		"Knife Medium",
		"Sharp crests with recovery shelves",
		["knife_crests", "mid_cadence", "occasional_shelves"]
	)
	_hybrid(
		"climb_medium",
		"Climb Medium",
		"Climb trains with downhill relief",
		["climb_trains", "relief_after_climb", "honest_terrain"]
	)
	_hybrid(
		"warp_medium",
		"Warp Medium",
		"Twisted fall lines on soft shoulders",
		["twisted_warp", "soft_shoulders", "mild_weave"]
	)
	_hybrid(
		"gauntlet_hard",
		"Gauntlet Hard",
		"Crest gauntlet with scarce resets",
		["ridge_gauntlet", "scarce_flats", "tight_chop"]
	)
	_hybrid(
		"basin_hard",
		"Basin Hard",
		"Deep basins and brutal exits",
		["deep_basins", "wall_faces", "escape_gulches"]
	)
	_hybrid(
		"chaos_hard",
		"Chaos Hard",
		"Maze basins with warp and broken crests",
		["maze_basins", "twisted_warp", "broken_teeth"]
	)
	_hybrid(
		"endurance_hard",
		"Endurance Hard",
		"Long climbs, scarce flats, momentum tax",
		["climb_trains", "scarce_flats", "momentum_tax"]
	)
	_hybrid(
		"extreme_spine",
		"Extreme Spine",
		"Razor spine with blind landings",
		["razor_spine", "blind_backsides", "no_line_chaos"]
	)
	_hybrid(
		"extreme_walls",
		"Extreme Walls",
		"Wall faces and punish climbs",
		["wall_faces", "punish_climbs", "cliffette_drops"]
	)
	_hybrid(
		"extreme_warp",
		"Extreme Warp",
		"Max warp with syncopated ridges",
		["twisted_warp", "syncopated_ridges", "scarce_flats"]
	)


static func _register_level_specs() -> void:
	_specs[1] = LevelTerrainSpecScript.new(
		1, BAND_TUTORIAL, "tutorial_flow", "Prototype opener; easy surfing"
	)
	_specs[2] = LevelTerrainSpecScript.new(
		2, BAND_EASY, "learning_desert", "First real dunes, still readable"
	)
	_specs[3] = LevelTerrainSpecScript.new(
		3, BAND_MEDIUM, "knife_medium", "Crest commitment without full chaos"
	)
	_specs[4] = LevelTerrainSpecScript.new(
		4, BAND_HARD, "gauntlet_hard", "Dense crests and scarce resets"
	)
	_specs[5] = LevelTerrainSpecScript.new(
		5, BAND_HARD, "endurance_hard", "Long climbs and momentum pressure"
	)
