extends SceneTree
## CPU cost of the level-B agent layer on this machine, headless, for the
## measuring ladder of the handbook (16/64/256/512/1024 soldiers).
##   godot --headless --path prototype --script res://tests/formation_scale_benchmark.gd ++ <report.json>
## Workload observation, not a device claim: Fold7 values need the device.

const Battle := preload("res://scripts/battle/battle_model.gd")
const Agents := preload("res://scripts/formation/formation_agents.gd")
const Levels := preload("res://scripts/formation/formation_levels.gd")


func _initialize() -> void:
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	var rows := []
	for total in [16, 64, 256, 512, 1024]:
		for level in [Levels.LEVEL_B, Levels.LEVEL_C]:
			rows.append(_measure(total, level))
	var text := JSON.stringify({"engine": Engine.get_version_info().string, "processor": OS.get_processor_name(),
		"cores": OS.get_processor_count(), "rows": rows}, "  ")
	if output != "":
		var handle := FileAccess.open(output, FileAccess.WRITE)
		handle.store_string(text + "\n")
		handle.close()
	for row in rows:
		print("FORMATION_SCALE ", JSON.stringify(row))
	quit(0)


func _measure(total: int, level: int) -> Dictionary:
	var model := Battle.new()
	# Two opposing blocks of companies of 32 that close on each other, so the
	# sample includes marching, contact and casualties.
	var companies := maxi(2, total / 32)
	var per := total / companies
	model.squads.clear()
	for i in companies:
		var ally := i % 2 == 0
		var column := i / 2
		var x := -22.0 + float(column % 6) * 8.5
		var z := (10.0 if ally else -12.0) + float(column / 6) * (6.0 if ally else -6.0)
		model._add_squad("bench_%02d" % i, "B%d" % i, "ally" if ally else "enemy", "infantry", "testudo", Vector2(x, clampf(z, -20, 20)), per)
		model.squads["bench_%02d" % i].command = "attack_move"
		model.squads["bench_%02d" % i].goal_z = 0.0
	var agents = Agents.new()
	agents.sync_model(model)
	for a in agents.agents.values():
		a.level = level
	var usec := []
	var ticks := 0
	for frame in 600:
		model.tick(1.0 / 60.0)
		var before := Time.get_ticks_usec()
		var n: int = agents.advance(model)
		if n > 0:
			usec.append(float(Time.get_ticks_usec() - before) / n)
			ticks += n
		for a in agents.agents.values():
			a.level = level
	usec.sort()
	var mean := 0.0
	for value: float in usec:
		mean += value
	mean /= maxf(1.0, usec.size())
	return {"soldiers": agents.counters.created, "level": Levels.LEVEL_NAMES[level], "ticks": ticks,
		"mean_usec_per_tick": mean, "p95_usec_per_tick": usec[int(usec.size() * 0.95)] if not usec.is_empty() else 0.0,
		"ms_per_second_at_30hz": mean * 30.0 / 1000.0, "deaths": agents.counters.deaths,
		"usec_by_phase": agents.timing, "rematches": agents.counters.rematches}
