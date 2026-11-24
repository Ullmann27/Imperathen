extends RefCounted
## Timed, offline combat authority. The renderer cannot award a hit.
## This keeps the coordinating childhood branch's eleven-field v1 save contract.
## The caller supplies geometry and the existing world's damage transaction.

const PRACTICE_POINT := Vector2(0.0, -7.0)
const STAMINA_LIMIT := 100.0
const STAMINA_RECOVERY := 12.0
const EPSILON := 0.000001
const MIN_CONTACT_DISTANCE := 0.25
const GUARD_SECONDS := 0.85
const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const DODGE_SECONDS := 0.65
const TECHNIQUES := {
	"jab_left":{"label":"Linke Gerade", "short":"Gerade L", "duration":0.62, "windup":0.18, "active":0.14, "reach":1.45, "arc_dot":0.72, "damage":6, "cost":7.0, "practice":0, "family":"fist"},
	"jab_right":{"label":"Rechte Gerade", "short":"Gerade R", "duration":0.68, "windup":0.21, "active":0.14, "reach":1.5, "arc_dot":0.72, "damage":7, "cost":8.0, "practice":0, "family":"fist"},
	"hook_left":{"label":"Linker Haken", "short":"Haken L", "duration":0.82, "windup":0.27, "active":0.16, "reach":1.15, "arc_dot":0.50, "damage":9, "cost":11.0, "practice":3, "family":"fist"},
	"hook_right":{"label":"Rechter Haken", "short":"Haken R", "duration":0.82, "windup":0.27, "active":0.16, "reach":1.15, "arc_dot":0.50, "damage":9, "cost":11.0, "practice":3, "family":"fist"},
	"uppercut_left":{"label":"Linker Uppercut", "short":"Uppercut L", "duration":0.9, "windup":0.30, "active":0.17, "reach":1.05, "arc_dot":0.65, "damage":10, "cost":13.0, "practice":6, "family":"fist"},
	"uppercut_right":{"label":"Rechter Uppercut", "short":"Uppercut R", "duration":0.9, "windup":0.30, "active":0.17, "reach":1.05, "arc_dot":0.65, "damage":10, "cost":13.0, "practice":6, "family":"fist"},
	"headbutt":{"label":"Kopfstoß", "short":"Kopfstoß", "duration":0.76, "windup":0.23, "active":0.14, "reach":0.85, "arc_dot":0.80, "damage":7, "cost":12.0, "practice":8, "family":"head"},
	"front_kick":{"label":"Frontkick", "short":"Frontkick", "duration":1.05, "windup":0.34, "active":0.20, "reach":1.75, "arc_dot":0.78, "damage":11, "cost":15.0, "practice":4, "family":"kick"},
	"side_kick":{"label":"Sidekick", "short":"Sidekick", "duration":1.2, "windup":0.40, "active":0.22, "reach":1.85, "arc_dot":0.72, "damage":12, "cost":18.0, "practice":10, "family":"kick"},
	"high_kick":{"label":"Highkick", "short":"Highkick", "duration":1.3, "windup":0.44, "active":0.24, "reach":1.65, "arc_dot":0.60, "damage":12, "cost":21.0, "practice":14, "family":"kick"},
	"cut_inward":{"label":"Gladius · Innenhieb", "short":"Innenhieb", "duration":0.90, "windup":0.43, "active":0.12, "reach":1.85, "arc_dot":0.55, "damage":16, "cost":14.0, "practice":0, "family":"sword"},
	"cut_outward":{"label":"Gladius · Außenhieb", "short":"Außenhieb", "duration":0.94, "windup":0.45, "active":0.13, "reach":1.85, "arc_dot":0.55, "damage":16, "cost":14.0, "practice":0, "family":"sword"},
	"thrust":{"label":"Gladius · Stoß", "short":"Stoß", "duration":0.82, "windup":0.40, "active":0.11, "reach":2.0, "arc_dot":0.85, "damage":18, "cost":15.0, "practice":0, "family":"sword"},
	"overhead":{"label":"Gladius · Überkopfhieb", "short":"Oben", "duration":1.12, "windup":0.54, "active":0.15, "reach":1.8, "arc_dot":0.75, "damage":22, "cost":21.0, "practice":0, "family":"sword"},
	"turn_cut":{"label":"Gladius · Drehhieb", "short":"Drehhieb", "duration":1.24, "windup":0.60, "active":0.16, "reach":1.8, "arc_dot":0.42, "damage":20, "cost":23.0, "practice":0, "family":"sword"}
}
const COMMAND_FIELDS := {
	"village_unarmed_attack":["technique", "target_id", "facing_x", "facing_z"],
	"village_unarmed_guard":[], "village_unarmed_dodge":[]
}
const STATE_FIELDS := ["version", "stamina", "practice_hits", "resolved_hits", "elapsed", "technique", "target_id", "facing", "resolved", "guard_remaining", "dodge_remaining"]


static func start(data: Dictionary) -> void:
	data.village.unarmed = {"version":1, "stamina":100.0, "practice_hits":0, "resolved_hits":0,
		"elapsed":0.0, "technique":"", "target_id":"", "facing":[0.0,-1.0], "resolved":true,
		"guard_remaining":0.0, "dodge_remaining":0.0}


static func enabled(data: Dictionary) -> bool:
	return typeof(data.get("village")) == TYPE_DICTIONARY and data.village.has("unarmed")


static func is_armed(id: String) -> bool:
	return TECHNIQUES.has(id) and TECHNIQUES[id].family == "sword"


static func service_gear(data: Dictionary) -> bool:
	# The existing adult training transaction explicitly commissions a soldier.
	# Derive issued service equipment from that saved, validated progression;
	# never from age alone, a cosmetic prop or a caller-supplied inventory flag.
	var player: Dictionary = data.get("player", {})
	var progress: Dictionary = data.get("progress", {})
	return enabled(data) and _integer(player.get("age"),18,250018) and player.get("role","") == "soldier" and progress.get("training_complete") == true and progress.get("stage","") in ["trained","skirmish","aftermath","ended","fallen"]


static func available(data: Dictionary, id: String) -> bool:
	if not enabled(data) or typeof(data.village.unarmed) != TYPE_DICTIONARY or not TECHNIQUES.has(id):
		return false
	if is_armed(id):
		return service_gear(data)
	var count: Variant = data.village.unarmed.get("practice_hits")
	return _integer(count, 0, 1000) and int(count) >= int(TECHNIQUES[id].practice)


static func validate_arguments(command: String, args: Dictionary) -> String:
	if not COMMAND_FIELDS.has(command) or not _keys(args, COMMAND_FIELDS[command]):
		return "Der Kampfbefehl enthält fehlende oder unerlaubte Angaben."
	if command != "village_unarmed_attack":
		return ""
	if typeof(args.technique) != TYPE_STRING or not TECHNIQUES.has(args.technique):
		return "Diese Kampftechnik ist unbekannt."
	if typeof(args.target_id) != TYPE_STRING or args.target_id.is_empty() or args.target_id.length() > 64:
		return "Der Angriff benötigt eine gültige Zielkennung."
	if not _number(args.facing_x, -1.1, 1.1) or not _number(args.facing_z, -1.1, 1.1):
		return "Die Blickrichtung für diesen Schlag ist ungültig."
	var facing := Vector2(float(args.facing_x), float(args.facing_z))
	if facing.length() < 0.9 or facing.length() > 1.1:
		return "Die Blickrichtung für diesen Schlag ist ungültig."
	return ""


static func execute(data: Dictionary, command: String, args: Dictionary) -> Dictionary:
	var error := validate_arguments(command, args)
	if not error.is_empty():
		return _result(false, error)
	if not enabled(data):
		return _result(false, "Diese Partie verwendet noch die frühere Kampfsteuerung.")
	error = validate(data)
	if not error.is_empty():
		return _result(false, error)
	if not _alive(data):
		return _result(false, "Die Figur kann gerade keine Kampfbewegung ausführen.")
	var combat: Dictionary = data.village.unarmed
	if busy(data):
		return _result(false, "Lass die aktuelle Bewegung ausklingen.")
	if command != "village_unarmed_attack":
		var dodge := command == "village_unarmed_dodge"
		var cost := 16.0 if dodge else 10.0
		if float(combat.stamina) + EPSILON < cost:
			return _result(false, "Du brauchst einen Augenblick, um wieder Luft zu bekommen.")
		combat.stamina = maxf(0.0, float(combat.stamina) - cost)
		combat.dodge_remaining = DODGE_SECONDS if dodge else 0.0
		# Chapter I lesson „Sieh hin, bevor du Kraft brauchst“ (I-05) lengthens the guard.
		var guard_bonus := guard_bonus_seconds(data)
		combat.guard_remaining = 0.0 if dodge else GUARD_SECONDS + guard_bonus
		_set_defense_windows(data, 0.0 if dodge else 0.75 + guard_bonus, 0.55 if dodge else 0.0)
		return _result(true, "Du weichst aus." if dodge else "Du gehst in Deckung.")
	if not available(data, args.technique):
		return _result(false, "Der Gladius gehört zur abgeschlossenen erwachsenen Soldatenausbildung." if is_armed(args.technique) else "Diese Technik lernst du durch kontrollierte Treffer am Übungspfahl.")
	var spec: Dictionary = TECHNIQUES[args.technique]
	if float(combat.stamina) + EPSILON < float(spec.cost):
		return _result(false, "Für diese Bewegung fehlt Ausdauer. Atme kurz durch.")
	if args.target_id not in ["air", "practice"] and _enemy(data, args.target_id).is_empty():
		return _result(false, "Dieses Ziel gehört nicht zum laufenden Kampf.")
	var facing := Vector2(float(args.facing_x), float(args.facing_z)).normalized()
	combat.stamina = maxf(0.0, float(combat.stamina) - float(spec.cost))
	combat.technique = args.technique
	combat.target_id = args.target_id
	combat.facing = [facing.x, facing.y]
	combat.elapsed = 0.0
	combat.resolved = false
	return _result(true, str(spec.label) + ".")


## The callbacks run against the caller's candidate transaction, never a renderer.
## sight_check(Vector2 from, Vector2 to) -> bool must confirm world geometry.
## apply_hit(Dictionary data, String target_id, int damage) -> bool owns health,
## encounter outcome and progression. Missing callbacks grant no combat hit.
static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable(), apply_hit: Callable = Callable()) -> Dictionary:
	var event := {"hit":false, "practice":false, "interrupted":false, "finished":false, "technique":"", "target_id":""}
	if not enabled(data) or not is_finite(delta) or delta <= 0.0 or delta > 3600.0 or not validate(data).is_empty():
		return event
	var combat: Dictionary = data.village.unarmed
	if not _alive(data):
		event.interrupted = interrupt(data)
		return event
	var busy_seconds := maxf(float(combat.guard_remaining), float(combat.dodge_remaining))
	var old_guard := float(combat.guard_remaining)
	var old_dodge := float(combat.dodge_remaining)
	combat.guard_remaining = maxf(0.0, float(combat.guard_remaining) - delta)
	combat.dodge_remaining = maxf(0.0, float(combat.dodge_remaining) - delta)
	var raid: Variant = data.get("village", {}).get("raid")
	if typeof(raid) == TYPE_DICTIONARY:
		# Life normally consumes/ticks these windows. Its raid clock intentionally
		# pauses during the older military encounter, so expiration must still
		# clear protection instead of leaving a stale future raid block.
		if old_guard > 0.0 and float(combat.guard_remaining) <= EPSILON and raid.has("block_window"):
			raid.block_window = 0.0
		if old_dodge > 0.0 and float(combat.dodge_remaining) <= EPSILON and raid.has("dodge_window"):
			raid.dodge_window = 0.0
	if combat.technique.is_empty():
		combat.stamina = minf(STAMINA_LIMIT, float(combat.stamina) + maxf(0.0, delta - busy_seconds) * STAMINA_RECOVERY)
		return event
	var spec: Dictionary = TECHNIQUES[combat.technique]
	var previous := float(combat.elapsed)
	var elapsed := minf(float(spec.duration), previous + delta)
	var active_end := float(spec.windup) + float(spec.active)
	combat.elapsed = elapsed
	event.technique = combat.technique
	event.target_id = combat.target_id
	# Check interval overlap, including a low-frame-rate tick spanning the window.
	# A missed contact may enter range later in the same active window, but a hit
	# consumes it before the authoritative callback to prevent re-entrant damage.
	if not combat.resolved and previous < active_end and elapsed + EPSILON >= float(spec.windup):
		var target := _target(data, combat.target_id)
		if not target.is_empty() and _contact(data, spec, target, sight_check):
			if combat.target_id == "practice":
				combat.resolved = true
				combat.practice_hits = mini(1000, int(combat.practice_hits) + 1)
				event.practice = true
			elif apply_hit.is_valid():
				combat.resolved = true
				var accepted: Variant = apply_hit.call(data, combat.target_id, int(spec.damage))
				if typeof(accepted) == TYPE_BOOL and accepted:
					combat.resolved_hits = mini(1000000, int(combat.resolved_hits) + 1)
					event.hit = true
	if elapsed + EPSILON >= active_end:
		combat.resolved = true
	if elapsed + EPSILON >= float(spec.duration):
		_clear_motion(combat)
		event.finished = true
	var idle_seconds := maxf(0.0, delta - maxf(0.0, float(spec.duration) - previous))
	combat.stamina = minf(STAMINA_LIMIT, float(combat.stamina) + idle_seconds * STAMINA_RECOVERY)
	return event


static func interrupt(data: Dictionary) -> bool:
	if not enabled(data) or not validate(data).is_empty():
		return false
	var changed := busy(data)
	var combat: Dictionary = data.village.unarmed
	_clear_motion(combat)
	combat.guard_remaining = 0.0
	combat.dodge_remaining = 0.0
	_set_defense_windows(data, 0.0, 0.0)
	return changed


static func busy(data: Dictionary) -> bool:
	if not enabled(data) or typeof(data.village.unarmed) != TYPE_DICTIONARY:
		return false
	var combat: Dictionary = data.village.unarmed
	return not str(combat.get("technique", "")).is_empty() or float(combat.get("guard_remaining", 0.0)) > EPSILON or float(combat.get("dodge_remaining", 0.0)) > EPSILON


static func phase(id: String, elapsed: float) -> String:
	if not TECHNIQUES.has(id) or not is_finite(elapsed) or elapsed < 0.0 or elapsed + EPSILON >= float(TECHNIQUES[id].duration):
		return "idle"
	var spec: Dictionary = TECHNIQUES[id]
	if elapsed + EPSILON < float(spec.windup):
		return "windup"
	if elapsed + EPSILON < float(spec.windup) + float(spec.active):
		return "active"
	return "recovery"


static func view(data: Dictionary) -> Dictionary:
	if not enabled(data) or not validate(data).is_empty():
		return {}
	var result: Dictionary = data.village.unarmed.duplicate(true)
	result["phase"] = phase(result.technique, float(result.elapsed))
	result["progress"] = 0.0 if result.technique.is_empty() else clampf(float(result.elapsed) / float(TECHNIQUES[result.technique].duration), 0.0, 1.0)
	result["techniques"] = []
	result["service_gear"] = service_gear(data)
	for id: String in TECHNIQUES:
		if is_armed(id) and not service_gear(data):
			continue
		var item: Dictionary = TECHNIQUES[id].duplicate(true)
		item["id"] = id
		item["active_start"] = float(item.windup)
		item["active_end"] = float(item.windup) + float(item.active)
		item["recovery"] = float(item.duration) - float(item.active_end)
		item["available"] = available(data, id)
		result.techniques.append(item)
	return result


static func validate(data: Dictionary) -> String:
	if not enabled(data):
		return ""
	var v: Variant = data.village.unarmed
	if not _keys(v, STATE_FIELDS):
		return "Ungültiger Vertrag für unbewaffnete Bewegung."
	if not _integer(v.version, 1, 1) or typeof(v.resolved) != TYPE_BOOL or typeof(v.technique) != TYPE_STRING or typeof(v.target_id) != TYPE_STRING:
		return "Unbekannte Nahkampfversion oder Technik."
	for pair: Array in [["stamina",100.0],["elapsed",1.3],["guard_remaining",GUARD_SECONDS + guard_bonus_seconds(data)],["dodge_remaining",DODGE_SECONDS]]:
		if not _number(v[pair[0]], 0.0, float(pair[1]) + EPSILON):
			return "Ungültige Ausdauer oder Bewegungszeit."
	if not _integer(v.practice_hits, 0, 1000) or not _integer(v.resolved_hits, 0, 1000000):
		return "Ungültiger Trefferzähler."
	if typeof(v.facing) != TYPE_ARRAY or v.facing.size() != 2:
		return "Die Nahkampfrichtung fehlt."
	for value: Variant in v.facing:
		if not _number(value, -1.000001, 1.000001):
			return "Ungültige Nahkampfrichtung."
	if absf(Vector2(float(v.facing[0]), float(v.facing[1])).length() - 1.0) > 0.00001:
		return "Die Nahkampfrichtung muss normiert sein."
	if float(v.guard_remaining) > EPSILON and float(v.dodge_remaining) > EPSILON:
		return "Deckung und Ausweichen können nicht gleichzeitig aktiv sein."
	if v.technique.is_empty():
		if not v.target_id.is_empty() or float(v.elapsed) != 0.0 or not v.resolved:
			return "Beendete Bewegung enthält noch einen Trefferauftrag."
	else:
		if not available(data, v.technique) or v.target_id.is_empty() or v.target_id.length() > 64 or float(v.elapsed) >= float(TECHNIQUES[v.technique].duration):
			return "Unzulässige aktive Nahkampfbewegung."
		if float(v.guard_remaining) > EPSILON or float(v.dodge_remaining) > EPSILON:
			return "Ein Angriff darf keine zweite Abwehrbewegung enthalten."
		if not v.resolved and float(v.elapsed) + EPSILON >= float(TECHNIQUES[v.technique].windup) + float(TECHNIQUES[v.technique].active):
			return "Eine erholende Bewegung darf keinen offenen Treffer enthalten."
	return ""


static func _contact(data: Dictionary, spec: Dictionary, target: Dictionary, sight_check: Callable) -> bool:
	if not sight_check.is_valid():
		return false
	var position: Variant = data.get("player", {}).get("position")
	if typeof(position) != TYPE_ARRAY or position.size() != 3:
		return false
	if not _number(position[0], -1000000.0, 1000000.0) or not _number(position[2], -1000000.0, 1000000.0) or not _number(target.get("x"), -1000000.0, 1000000.0) or not _number(target.get("z"), -1000000.0, 1000000.0):
		return false
	var from := Vector2(float(position[0]), float(position[2]))
	var to := Vector2(float(target.x), float(target.z))
	var offset := to - from
	if offset.length() < MIN_CONTACT_DISTANCE or offset.length() > float(spec.reach):
		return false
	var combat: Dictionary = data.village.unarmed
	var facing := Vector2(float(combat.facing[0]), float(combat.facing[1]))
	if facing.dot(offset.normalized()) + EPSILON < float(spec.arc_dot):
		return false
	var clear: Variant = sight_check.call(from, to)
	return typeof(clear) == TYPE_BOOL and clear


static func _enemy(data: Dictionary, id: String) -> Dictionary:
	for encounter: Dictionary in [data.get("village", {}).get("raid", {}), data.get("encounter", {})]:
		if not encounter.get("active", false):
			continue
		for enemy: Dictionary in encounter.get("enemies", []):
			if str(enemy.get("id", "")) == id and _integer(enemy.get("health"), 1, 1000000):
				return enemy
	return {}


static func _target(data: Dictionary, id: String) -> Dictionary:
	if id == "practice":
		return {"x":PRACTICE_POINT.x, "z":PRACTICE_POINT.y}
	if id == "air":
		return {}
	return _enemy(data, id)


static func _alive(data: Dictionary) -> bool:
	return _integer(data.get("player", {}).get("health"), 1, 1000000) and not data.get("progress", {}).get("career_terminal", false)


static func guard_bonus_seconds(data: Dictionary) -> float:
	return Abilities.effect_value(data, "block_window_bonus_seconds")


static func _set_defense_windows(data: Dictionary, guard: float, dodge: float) -> void:
	var raid: Variant = data.get("village", {}).get("raid")
	if typeof(raid) == TYPE_DICTIONARY and raid.has("block_window") and raid.has("dodge_window"):
		raid.block_window = guard
		raid.dodge_window = dodge


static func _clear_motion(combat: Dictionary) -> void:
	combat.technique = ""
	combat.target_id = ""
	combat.elapsed = 0.0
	combat.resolved = true


static func _keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and floorf(float(value)) == float(value)


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok, "message":message}
