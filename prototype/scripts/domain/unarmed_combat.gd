extends RefCounted
## A bounded offline combat authority. One accepted motion can resolve one hit.
## Presentation uses the same duration table; animation never grants progress.

const Life = preload("res://scripts/story/village_life.gd")
const PRACTICE_POINT := Vector2(0.0, -7.0)
const TECHNIQUES := {
	"jab_left":{"label":"Linke Gerade", "short":"Gerade L", "duration":0.62, "reach":1.45, "damage":6, "cost":7.0, "practice":0, "family":"fist"},
	"jab_right":{"label":"Rechte Gerade", "short":"Gerade R", "duration":0.68, "reach":1.5, "damage":7, "cost":8.0, "practice":0, "family":"fist"},
	"hook_left":{"label":"Linker Haken", "short":"Haken L", "duration":0.82, "reach":1.15, "damage":9, "cost":11.0, "practice":3, "family":"fist"},
	"hook_right":{"label":"Rechter Haken", "short":"Haken R", "duration":0.82, "reach":1.15, "damage":9, "cost":11.0, "practice":3, "family":"fist"},
	"uppercut_left":{"label":"Linker Uppercut", "short":"Uppercut L", "duration":0.9, "reach":1.05, "damage":10, "cost":13.0, "practice":6, "family":"fist"},
	"uppercut_right":{"label":"Rechter Uppercut", "short":"Uppercut R", "duration":0.9, "reach":1.05, "damage":10, "cost":13.0, "practice":6, "family":"fist"},
	"headbutt":{"label":"Kopfstoß", "short":"Kopfstoß", "duration":0.76, "reach":0.85, "damage":7, "cost":12.0, "practice":8, "family":"head"},
	"front_kick":{"label":"Frontkick", "short":"Frontkick", "duration":1.05, "reach":1.75, "damage":11, "cost":15.0, "practice":4, "family":"kick"},
	"side_kick":{"label":"Sidekick", "short":"Sidekick", "duration":1.2, "reach":1.85, "damage":12, "cost":18.0, "practice":10, "family":"kick"},
	"high_kick":{"label":"Highkick", "short":"Highkick", "duration":1.3, "reach":1.65, "damage":12, "cost":21.0, "practice":14, "family":"kick"}
}
const COMMAND_FIELDS := {"village_unarmed_attack":["technique", "target_id", "facing_x", "facing_z"], "village_unarmed_guard":[], "village_unarmed_dodge":[]}


static func start(data: Dictionary) -> void:
	data.village.unarmed = {"version":1, "stamina":100.0, "practice_hits":0, "resolved_hits":0,
		"elapsed":0.0, "technique":"", "target_id":"", "facing":[0.0,-1.0], "resolved":true,
		"guard_remaining":0.0, "dodge_remaining":0.0}


static func enabled(data: Dictionary) -> bool:
	return data.get("village",{}).has("unarmed")


static func available(data: Dictionary, id: String) -> bool:
	return enabled(data) and TECHNIQUES.has(id) and int(data.village.unarmed.practice_hits)>=int(TECHNIQUES[id].practice)


static func execute(data: Dictionary, command: String, args: Dictionary) -> Dictionary:
	if not enabled(data):
		return _result(false,"Diese Partie verwendet noch die frühere Kampfsteuerung.")
	var combat: Dictionary = data.village.unarmed
	if not combat.technique.is_empty() or combat.guard_remaining>0.0 or combat.dodge_remaining>0.0:
		return _result(false,"Lass die aktuelle Bewegung ausklingen.")
	if command == "village_unarmed_guard" or command == "village_unarmed_dodge":
		var dodge := command == "village_unarmed_dodge"
		var cost := 16.0 if dodge else 10.0
		if combat.stamina<cost:
			return _result(false,"Du brauchst einen Augenblick, um wieder Luft zu bekommen.")
		combat.stamina-=cost
		combat.dodge_remaining=0.65 if dodge else 0.0
		combat.guard_remaining=0.0 if dodge else 0.85
		data.village.raid.dodge_window=0.55 if dodge else 0.0
		data.village.raid.block_window=0.0 if dodge else 0.75
		return _result(true,"Du weichst aus." if dodge else "Du gehst in Deckung.")
	if command != "village_unarmed_attack" or not available(data,str(args.get("technique",""))):
		return _result(false,"Diese Technik lernst du durch kontrollierte Treffer am Übungspfahl.")
	var spec: Dictionary = TECHNIQUES[args.technique]
	if combat.stamina<float(spec.cost):
		return _result(false,"Für diese Bewegung fehlt Ausdauer. Atme kurz durch.")
	var target_id: String = args.target_id
	if target_id not in ["air","practice"] and _enemy(data,target_id).is_empty():
		return _result(false,"Dieses Ziel gehört nicht zum laufenden Kampf.")
	var facing := Vector2(float(args.facing_x),float(args.facing_z))
	if not facing.is_finite() or facing.length()<0.9 or facing.length()>1.1:
		return _result(false,"Die Blickrichtung für diesen Schlag ist ungültig.")
	combat.stamina-=float(spec.cost)
	combat.technique=args.technique
	combat.target_id=target_id
	combat.facing=[facing.normalized().x,facing.normalized().y]
	combat.elapsed=0.0
	combat.resolved=false
	return _result(true,str(spec.label)+".")


static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable()) -> void:
	if not enabled(data) or delta<=0.0:
		return
	var combat: Dictionary = data.village.unarmed
	combat.stamina=minf(100.0,float(combat.stamina)+delta*12.0)
	combat.guard_remaining=maxf(0.0,float(combat.guard_remaining)-delta)
	combat.dodge_remaining=maxf(0.0,float(combat.dodge_remaining)-delta)
	if combat.technique.is_empty():
		return
	var spec: Dictionary = TECHNIQUES[combat.technique]
	combat.elapsed=minf(float(spec.duration),float(combat.elapsed)+delta)
	if not combat.resolved and combat.elapsed+0.000001>=float(spec.duration)*0.4:
		combat.resolved=true
		var target := _target(data,str(combat.target_id))
		if not target.is_empty():
			var from := Vector2(float(data.player.position[0]),float(data.player.position[2]))
			var to := Vector2(float(target.x),float(target.z))
			var offset := to-from
			var facing := Vector2(float(combat.facing[0]),float(combat.facing[1]))
			var clear := not sight_check.is_valid() or bool(sight_check.call(from,to))
			if offset.length()<=float(spec.reach) and offset.length()>0.05 and facing.dot(offset.normalized())>=0.55 and clear:
				if combat.target_id=="practice":
					combat.practice_hits=mini(1000,int(combat.practice_hits)+1)
				elif Life.apply_unarmed_hit(data,combat.target_id,int(spec.damage)):
					combat.resolved_hits=mini(1000000,int(combat.resolved_hits)+1)
	if combat.elapsed+0.000001>=float(spec.duration):
		combat.technique=""
		combat.target_id=""
		combat.elapsed=0.0


static func view(data: Dictionary) -> Dictionary:
	if not enabled(data):
		return {}
	var result: Dictionary = data.village.unarmed.duplicate(true)
	result["techniques"]=[]
	for id: String in TECHNIQUES:
		var item: Dictionary=TECHNIQUES[id].duplicate(true)
		item["id"]=id
		item["available"]=available(data,id)
		result.techniques.append(item)
	return result


static func validate(data: Dictionary) -> String:
	if not enabled(data):
		return ""
	var v: Variant=data.village.unarmed
	if typeof(v)!=TYPE_DICTIONARY or v.size()!=11:
		return "Ungültiger Vertrag für unbewaffnete Bewegung."
	for key in ["version","stamina","practice_hits","resolved_hits","elapsed","technique","target_id","facing","resolved","guard_remaining","dodge_remaining"]:
		if not v.has(key):
			return "Unvollständiger Nahkampfzustand."
	if v.version!=1 or typeof(v.resolved)!=TYPE_BOOL or typeof(v.technique)!=TYPE_STRING or typeof(v.target_id)!=TYPE_STRING:
		return "Unbekannte Nahkampfversion oder Technik."
	for pair in [["stamina",100.0],["elapsed",1.3],["guard_remaining",0.85],["dodge_remaining",0.65]]:
		if typeof(v[pair[0]]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v[pair[0]])) or v[pair[0]]<0 or v[pair[0]]>pair[1]+0.000001:
			return "Ungültige Ausdauer oder Bewegungszeit."
	for pair in [["practice_hits",1000],["resolved_hits",1000000]]:
		var value: Variant=v[pair[0]]
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0 or value>pair[1] or floorf(float(value))!=float(value):
			return "Ungültiger Trefferzähler."
	if typeof(v.facing)!=TYPE_ARRAY or v.facing.size()!=2:
		return "Die Nahkampfrichtung fehlt."
	for value: Variant in v.facing:
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value))>1.000001:
			return "Ungültige Nahkampfrichtung."
	if absf(Vector2(v.facing[0],v.facing[1]).length()-1.0)>0.00001:
		return "Die Nahkampfrichtung muss normiert sein."
	if v.technique.is_empty():
		if not v.target_id.is_empty() or v.elapsed!=0.0 or not v.resolved:
			return "Beendete Bewegung enthält noch einen Trefferauftrag."
	elif not available(data,v.technique) or v.target_id.is_empty() or v.target_id.length()>64 or v.elapsed>TECHNIQUES[v.technique].duration:
		return "Unzulässige aktive Nahkampfbewegung."
	return ""


static func _enemy(data: Dictionary, id: String) -> Dictionary:
	if not data.village.raid.active:
		return {}
	for enemy: Dictionary in data.village.raid.enemies:
		if enemy.id==id and int(enemy.health)>0:
			return enemy
	return {}


static func _target(data: Dictionary, id: String) -> Dictionary:
	if id=="practice":
		return {"x":PRACTICE_POINT.x,"z":PRACTICE_POINT.y}
	return _enemy(data,id)


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
