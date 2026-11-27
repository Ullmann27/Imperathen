extends RefCounted
## Only fitted derivatives may replace a live actor; source GLBs never do.
## Four imported tiers are required together so distance cannot swap identity.

const PATH := "res://assets/meshy/characters/%s_%d.glb"
const SUPPORTED := ["unit_roman_signifer", "unit_germanic_axe_fighter", "unit_legacy_blacksmith"]
## A recovered story face belongs to that person, not to a random crowd slot.
const OWNER_STORY := {"sextus": "unit_legacy_blacksmith"}

static func story_asset(id: String, origin: String, years: int, appearance: String) -> String:
	if origin != "italia" or years < 18 or appearance != "civilian_man":
		return ""
	var asset := str(OWNER_STORY.get(id, ""))
	return asset if has_complete_set(asset) else ""


static func owner_asset_allowed(asset: String, named_id: String) -> bool:
	return asset not in OWNER_STORY.values() or OWNER_STORY.get(named_id, "") == asset


static func is_owner_civilian(asset: String) -> bool:
	return asset in OWNER_STORY.values()


static func has_complete_set(stable_id: String) -> bool:
	if stable_id not in SUPPORTED:
		return false
	for level in 4:
		if not ResourceLoader.exists(PATH % [stable_id, level], "PackedScene"):
			return false
	return true


static func path_for(stable_id: String, age: int, level: int) -> String:
	if age < 18 or not has_complete_set(stable_id):
		return ""
	return PATH % [stable_id, clampi(level, 0, 3)]


static func family_prefix(stable_id: String) -> String:
	return "res://assets/meshy/characters/" + stable_id + "_"
