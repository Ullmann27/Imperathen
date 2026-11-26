extends SceneTree

const Registry = preload("res://scripts/visuals/meshy_asset_registry.gd")
const Loadouts = preload("res://scripts/visuals/meshy_loadout_registry.gd")
var checks := 0
var failed := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)


func run() -> void:
	Registry.reset_cache_for_tests()
	var entries := Registry.all_metadata()
	check(entries.size() == 38, "Meshy manifest exposes 29 text-to-3D and nine image-to-3D assets")
	var ids := {}
	var categories := {}
	for entry: Dictionary in entries:
		var stable_id := str(entry.get("stable_id", ""))
		check(not stable_id.is_empty() and not ids.has(stable_id), "stable id is non-empty and unique: " + stable_id)
		ids[stable_id] = true
		var category := str(entry.get("category", ""))
		categories[category] = int(categories.get(category, 0)) + 1
		check(entry.get("runtime_ready", true) == false, stable_id + " is not falsely marked runtime-ready")
		var path := Registry.source_path(stable_id)
		check(path.begins_with("res://assets/meshy/source/") and path.ends_with(".glb"), stable_id + " uses the staged GLB root")
		if Registry.has_source(stable_id):
			var instance := Registry.instantiate(stable_id)
			check(instance != null, stable_id + " imported GLB instantiates as Node3D")
			if instance != null:
				instance.free()
		else:
			check(Registry.instantiate(stable_id) == null, stable_id + " missing optional binary falls back cleanly")
	check(int(categories.get("weapon", 0)) == 8, "eight weapons registered")
	check(int(categories.get("character", 0)) == 13, "seven text-to-3D and six image-to-3D character sources registered")
	check(int(categories.get("equipment", 0)) == 8, "seven equipment props and the muscle cuirass registered")
	check(int(categories.get("building", 0)) == 1, "the imperial temple is registered as a building source")
	check(int(categories.get("resource", 0)) == 6, "six resource sources registered")
	check(int(categories.get("mount", 0)) == 2, "untextured cavalry horse and textured bay horse registered")
	var bay := Registry.metadata("mount_legacy_bay_horse")
	check(str(bay.get("status", "")) == "ready_in_meshy" and str(bay.get("source_api", "")) == "image-to-3d", "bay horse is the textured image-to-3D source")
	check(str(Registry.metadata("armor_roman_muscle_cuirass").get("historical_status", "")) == "imperial_parade_style_era_gated", "muscle cuirass is registered as era-gated")
	var horse := Registry.metadata("mount_ancient_cavalry_horse")
	check(str(horse.get("status", "")) == "geometry_ready_untextured", "cavalry horse remains explicitly untextured")
	check(horse.get("meshy_task_id", null) == null, "cavalry horse cannot claim a textured final task")
	check(str(horse.get("meshy_preview_task_id", "")) == "01a20934-c44a-77ea-95a7-5e2c2c804d5e", "cavalry horse keeps the exact Meshy preview task")
	var galena := Registry.metadata("resource_galena")
	check(str(galena.get("status", "")) == "geometry_ready_untextured", "galena stays explicitly untextured")
	check(galena.get("meshy_task_id", null) == null, "galena cannot claim a final task")
	check(Registry.metadata("not_an_asset").is_empty(), "unknown id returns empty metadata")
	Loadouts.reset_cache_for_tests()
	var loadouts := Loadouts.all_metadata()
	check(loadouts.size() == 7, "seven modular Meshy loadouts registered")
	for loadout: Dictionary in loadouts:
		check(loadout.get("runtime_enabled", true) == false, str(loadout.get("id", "")) + " loadout is not runtime-enabled early")
		for asset_value: Variant in Loadouts.component_ids(str(loadout.get("id", ""))).values():
			var asset_id := str(asset_value)
			check(not Registry.metadata(asset_id).is_empty(), str(loadout.get("id", "")) + " references a canonical Meshy asset")
	var heavy := Loadouts.component_ids("roman_heavy_cavalry")
	check(str(heavy.get("body", "")) == "unit_roman_heavy_cavalry_rider", "heavy cavalry keeps its rider source")
	check(str(heavy.get("mount", "")) == "mount_ancient_cavalry_horse", "heavy cavalry uses the canonical horse")
	check(str(heavy.get("saddle", "")) == "gear_roman_four_horn_saddle", "heavy cavalry uses the separate four-horn saddle")
	check(str(heavy.get("primary", "")) == "gear_roman_cavalry_lance", "heavy cavalry primary weapon is the separate lance")
	check(str(heavy.get("sidearm", "")) == "weap_roman_spatha", "heavy cavalry sidearm is the separate spatha")
	check(str(heavy.get("shield", "")) == "gear_roman_cavalry_oval_shield", "heavy cavalry shield remains modular")
	check(Loadouts.resource_asset("wood") == "resource_firewood", "wood economy key resolves to the firewood visual")
	check(Loadouts.resource_asset("iron_ore") == "resource_iron_ore", "iron economy key resolves to the ore visual")
	print("MESHY_ASSET_REGISTRY ", checks, " checks, ", failed, " failed")
	quit(1 if failed else 0)
