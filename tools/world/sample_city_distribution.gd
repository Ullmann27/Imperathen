extends SceneTree
## Offline-Stichproben für tools/world/capture_city_distribution.py.
const Life := preload("res://scripts/domain/city_life.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const SEED := 20261126

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var city := Life.new()
	var jdn := Calendar.campaign_start_jdn()
	if not city.found(SEED, jdn, 4 * 3600):
		printerr(city.error)
		quit(1)
		return
	var records := []
	for hour in [6, 12, 20]:
		var now: int = hour * 3600
		if not city.advance_to(now, 0).done:
			quit(1)
			return
		var outside := []
		for person in city.state.residents.size():
			if not city.is_indoors(person, now):
				var pos := city.position_of(person, now)
				outside.append([person, snappedf(pos.x, 0.01), snappedf(pos.z, 0.01)])
		var summary := city.summary()
		assert(outside.size() == int(summary.outdoors))
		records.append({"hour":hour, "summary":summary, "outdoors":outside})
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify({"source_commit":args[1], "seed":SEED, "jdn":jdn, "engine":Engine.get_version_info().string, "samples":records}))
	output.close()
	print("Drei Stadtzustände gespeichert: ", args[0])
	quit(0)
