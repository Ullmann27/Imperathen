extends RefCounted
## Pure projection of the saved economy/behavior into visible intentions.
## No money, inventory, path or relationship changes happen in presentation.
const PROPS := {
	"water":"res://assets/legio/water_pitcher.glb",
	"basket":"res://assets/legio/neighbour_basket.glb",
	"amphora":"res://assets/legio/transport_amphora.glb",
	"cup":"res://assets/legio/cup_julia.glb",
}
const WORK := ["vend","work","haul","water"]
const TALK_MAX := 180

static func village_prop(activity: String) -> String:
	return "basket" if activity == "errand" else "cup" if activity == "meal" else ""

static func city_prop(resident: Dictionary, now: int) -> String:
	var act := str(resident.get("act",""))
	var arrived := now >= int(resident.get("arr",now))
	var bag: Dictionary = resident.get("bag",{})
	if act == "flee":
		return ""
	if act == "haul" and not bag.is_empty():
		return "amphora" if bag.has("wine") or bag.has("oil") else "basket"
	if act == "water":
		return "water"
	if act == "shop" or not bag.is_empty() and act == "home":
		return "basket"
	if act == "tavern" and arrived:
		return "cup"
	return ""

static func standing_work(resident: Dictionary, now: int) -> bool:
	if now < int(resident.get("arr",now)) or now >= int(resident.get("until",now+1)):
		return false
	var act := str(resident.get("act",""))
	return act in WORK and city_prop(resident,now).is_empty()

static func partner_id(resident: Dictionary, now: int) -> int:
	if now < int(resident.get("arr",now)) or now >= int(resident.get("until",now+1)):
		return -1
	var partner := int(resident.get("with",-1))
	if partner < 0:
		return -1
	if resident.get("act","") == "shop" and int(resident.get("step",0)) == 2:
		return partner
	# The domain's with field can outlive the conversation event. Never
	# loop a talk pose for the entire afternoon at a leisure anchor.
	if now - int(resident.get("talked",-1000000)) <= TALK_MAX and now >= int(resident.get("talked",now)):
		return partner
	return -1

## Match only saved conversation intentions. Mutual social conversations
## take priority; a buyer may request a vendor without a reciprocal intent.
## Stable IDs break ties so streaming order cannot change the selected pairs.
static func conversation_pairs(requests: Dictionary, buyers: Dictionary) -> Dictionary:
	var pairs: Dictionary = {}
	var ids: Array = requests.keys()
	ids.sort()
	for person: int in ids:
		var peer := int(requests[person])
		if peer == person or peer < 0 or pairs.has(person) or pairs.has(peer):
			continue
		if int(requests.get(peer, -1)) == person:
			pairs[person] = peer
			pairs[peer] = person
	for person: int in ids:
		if not bool(buyers.get(person, false)) or pairs.has(person):
			continue
		var peer := int(requests[person])
		if peer == person or peer < 0 or pairs.has(peer):
			continue
		pairs[person] = peer
		pairs[peer] = person
	return pairs


static func speaker(first: int, second: int, now: int) -> int:
	# Stable alternating turns instead of both people speaking continuously.
	var lower := mini(first,second)
	var upper := maxi(first,second)
	return lower if posmod(now/5+lower+upper,2) == 0 else upper
