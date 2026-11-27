extends RefCounted
## Deterministic local weather from the saved campaign date/time. This is a
## fictional climate model, not a claim about actual weather in 58 BC.
## Shared by presentation and villagers; no random runtime state or save migration.
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const BLOCK_SECONDS := 21600
const TRANSITION_SECONDS := 1800
const KINDS := ["clear","overcast","rain","mist","storm"]
const RAIN := {"clear":0.0,"overcast":0.0,"rain":0.62,"mist":0.0,"storm":1.0}
const WIND := {"clear":0.7,"overcast":1.1,"rain":1.3,"mist":0.35,"storm":2.1}
const WET := {"clear":0.04,"overcast":0.12,"rain":0.78,"mist":0.3,"storm":1.0}
# Clear / cloudy / rain / mist cumulative percentages, by season.
const CHANCES := [[44,68,86,96],[62,78,92,95],[29,54,83,95],[35,61,83,97]]

static func kind_for(jdn: int, block: int, origin: String) -> String:
	var day := jdn + floori(float(block)/4.0)
	var slot := posmod(block,4)
	# The authored first morning is deliberately readable; later weather is
	# independent of mission choices. Preserve the initial opening sunlight.
	if day == Calendar.date_to_jdn(Calendar.CAMPAIGN_START) and slot < 2:
		return "clear"
	var season := clampi(Calendar.season_index(day),0,3)
	var value := posmod(hash("climate-v1:%s:%d:%d" % [origin,day,slot]),100)
	var cuts: Array = CHANCES[season]
	for i in cuts.size():
		if value < int(cuts[i]):
			return KINDS[i]
	return "storm"

static func sample(clock: Variant, origin: String, legacy_season: int = 0) -> Dictionary:
	if not Calendar.validate_clock(clock):
		var legacy := "rain" if posmod(legacy_season,4)==2 else "clear"
		return {"from":legacy,"to":legacy,"mix":1.0,"rain":RAIN[legacy],"wind":WIND[legacy],"wetness":WET[legacy],"kind":legacy}
	var day := int(clock.jdn)
	var second := int(clock.second)
	@warning_ignore("integer_division")
	var block := second / BLOCK_SECONDS
	var current := kind_for(day,block,origin)
	var previous := kind_for(day,block-1,origin)
	var blend := smoothstep(0.0,float(TRANSITION_SECONDS),float(second % BLOCK_SECONDS))
	# The end of each block is exactly the start of the next. Wetting is
	# faster than drying; two previous blocks retain residual dampness.
	var before_wet := settled_wetness(day,block-1,origin)
	var after_wet := settled_wetness(day,block,origin)
	var wet_mix := smoothstep(0.0,float(TRANSITION_SECONDS if after_wet>=before_wet else BLOCK_SECONDS),float(second%BLOCK_SECONDS))
	return {"from":previous,"to":current,"mix":blend,
		"rain":lerpf(float(RAIN[previous]),float(RAIN[current]),blend),
		"wind":lerpf(float(WIND[previous]),float(WIND[current]),blend),
		"wetness":lerpf(before_wet,after_wet,wet_mix),"kind":current if blend>=0.5 else previous}

static func settled_wetness(day: int, block: int, origin: String) -> float:
	return maxf(float(WET[kind_for(day,block,origin)]),maxf(float(WET[kind_for(day,block-1,origin)])*0.18,float(WET[kind_for(day,block-2,origin)])*0.04))

static func for_state(data: Dictionary) -> Dictionary:
	var clock: Variant = data.get("calendar",{}).get("clock")
	if Calendar.validate_clock(clock):
		@warning_ignore("integer_division")
		clock = Calendar.new_clock(int(clock.jdn),int(clock.second)/300*300)
	return sample(clock,str(data.get("origin_id","italia")),int(data.get("strategy",{}).get("turn",0)))
