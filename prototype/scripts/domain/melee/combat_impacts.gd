extends RefCounted
## One API for impact and weapon sounds/effects (D-050). The level-A
## authority (melee_core.gd) publishes a normalized record for every audible
## combat moment at its exact frame; an audio system attaches with
##   CombatImpacts.hub().impact.connect(play_impact)
## and never needs to touch combat logic. Publishing is observation only:
## listeners must not change the combat state.
##
## Record (schema 1):
##   kind         impact | swing | draw | release | break
##   event        source event type (hit, block, parry, guard_broken,
##                projectile_hit, projectile_block, projectile_miss, swing,
##                draw, release, shield_broken)
##   outcome      hit | block | parry | guard_broken | lodged | deflected |
##                miss | "" (for swing/draw/release)
##   frame        simulation frame (60 Hz) of the contact/release
##   clip_frame   measured clip frame of the contact (-1 for projectiles)
##   time_s       frame / 60
##   material_a   striking material (iron, bronze, flesh, leather, lead,
##                wood, sinew, hemp)
##   material_b   struck material (iron, bronze, wood, leather, cloth,
##                flesh, soil, world, air)
##   energy_j     kinetic energy at contact (release: at launch)
##   speed_m_s    speed of the striking point / projectile
##   position     Vector3 world position of the contact or release
##   direction    Vector3 unit travel direction (ZERO when unknown)
##   weapon_id    weapon_catalog.gd id (fist, gladius, axe, bow, pilum, ...)
##   weapon_class unarmed | melee | thrown | bow | crossbow | sling
##   mechanism    weapon_catalog.gd mechanism
##   strike_kind  cut | thrust | blunt
##   source       attacker / shooter id
##   target       defender id or ""
##   zone         hit zone or ""
##   braced       defender guarding (blocks)
##   sound_hint   id of the synthesized placeholder (melee_feedback.gd)
##   gain_db      suggested level from energy (log scale)

const Weapons = preload("res://scripts/domain/melee/weapon_catalog.gd")
const Feedback = preload("res://scripts/domain/melee/melee_feedback.gd")
const HubScript = preload("res://scripts/domain/melee/combat_impact_hub.gd")
const SCHEMA := 1
const FPS := 60.0
const IMPACT_EVENTS := ["hit", "block", "parry", "guard_broken", "projectile_hit", "projectile_block", "projectile_miss"]
const KIND_OF := {"swing":"swing", "draw":"draw", "release":"release", "shield_broken":"break"}
const FEEDBACK_AS := {"projectile_hit":"hit", "projectile_block":"block"}
const FIELDS := ["schema", "kind", "event", "outcome", "frame", "clip_frame", "time_s", "material_a", "material_b",
	"energy_j", "speed_m_s", "position", "direction", "weapon_id", "weapon_class", "mechanism", "strike_kind",
	"source", "target", "zone", "braced", "sound_hint", "gain_db"]
static var _hub: HubScript = null


static func hub() -> HubScript:
	if _hub == null:
		_hub = HubScript.new()
	return _hub


static func connect_listener(listener: Callable) -> void:
	if not hub().impact.is_connected(listener):
		hub().impact.connect(listener)


static func disconnect_listener(listener: Callable) -> void:
	if hub().impact.is_connected(listener):
		hub().impact.disconnect(listener)


static func has_listeners() -> bool:
	return not hub().get_signal_connection_list("impact").is_empty()


## Normalized record for one core event, or {} when the event makes no sound.
static func record(event: Dictionary) -> Dictionary:
	var type := str(event.get("type", ""))
	var kind := "impact" if type in IMPACT_EVENTS else str(KIND_OF.get(type, ""))
	if kind.is_empty():
		return {}
	var weapon_id := str(event.get("weapon", event.get("family", "")))
	var w := Weapons.weapon(weapon_id)
	var outcome := ""
	match type:
		"hit", "projectile_hit":
			outcome = "hit"
		"block", "parry", "guard_broken":
			outcome = type
		"projectile_block":
			outcome = "lodged" if bool(event.get("lodged", false)) else "deflected"
		"projectile_miss":
			outcome = "miss"
	var material_a := str(event.get("weapon_material", Weapons.impact_material(weapon_id)))
	if material_a.is_empty():
		material_a = Weapons.impact_material(weapon_id)
	var material_b := str(event.get("surface_material", "air"))
	match type:
		"draw":
			material_a = str(w.get("material", material_a))
			material_b = str(w.get("string_material", "air"))
		"release":
			material_a = str(w.get("string_material", w.get("material", material_a)))
			material_b = "air"
		"shield_broken":
			material_a = "wood"
			material_b = "wood"
		"swing":
			material_b = "air"
	var direction: Variant = event.get("direction_vector", Vector3.ZERO)
	var position: Variant = event.get("point", Vector3.ZERO)
	var frame := int(event.get("frame", 0))
	var energy := float(event.get("energy_j", 0.0))
	# Missile impacts sound like the same materials meeting in a melee.
	var feedback := Feedback.for_event(event.merged({"type":str(FEEDBACK_AS.get(type, type))}, true))
	return {"schema":SCHEMA, "kind":kind, "event":type, "outcome":outcome,
		"frame":frame, "clip_frame":int(event.get("clip_frame", -1)), "time_s":float(frame) / FPS,
		"material_a":material_a, "material_b":material_b,
		"energy_j":energy, "speed_m_s":float(event.get("speed_m_s", 0.0)),
		"position":position if typeof(position) == TYPE_VECTOR3 else Vector3.ZERO,
		"direction":direction if typeof(direction) == TYPE_VECTOR3 else Vector3.ZERO,
		"weapon_id":weapon_id, "weapon_class":str(w.get("class", "")), "mechanism":str(w.get("mechanism", "")),
		"strike_kind":str(event.get("strike_kind", w.get("strike_kind", ""))),
		"source":str(event.get("attacker", event.get("fighter", ""))), "target":str(event.get("defender", "")),
		"zone":str(event.get("zone", "")), "braced":bool(event.get("braced", false)),
		"sound_hint":str(feedback.get("sound", {}).get("id", "")),
		"gain_db":float(feedback.get("sound", {}).get("gain_db", -18.0))}


## Emit one record per audible event, in event order. Returns the number
## of records emitted (0 without listeners: no work is done then).
static func publish(events: Array) -> int:
	if not has_listeners():
		return 0
	var count := 0
	for event: Variant in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var r := record(event)
		if r.is_empty():
			continue
		hub().impact.emit(r)
		count += 1
	return count
