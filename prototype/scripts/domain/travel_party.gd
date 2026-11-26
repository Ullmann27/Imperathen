extends RefCounted
## Personal company in WorldState. Person records, story facts, the clock and
## bought items keep their original owners. Keys are canonical PersonRegistry IDs.
const Clock = preload("res://scripts/domain/world_clock.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")

const NpcBehavior = preload("res://scripts/domain/npc_behavior.gd")
const FRIEND := "pc:companion"
const FATHER := "vil:silvanus"
## Authored local biographies. Ages for Silvanus and the two specialists are
## creative year-precision estimates; no invented historical birth day.
const PROFILES := {
	"vil:silvanus":{"age":38,"personality":"Umsichtig, achtet auf seine Familie","interest":"Handwerk","goal":"Die Familie versorgen","family":"Vater der Spielfigur"},
	"vil:aurelia":{"age":34,"personality":"Geduldig, lehnt vermeidbare Risiken ab","interest":"Heilkunde","goal":"Verletzte versorgen","family":""},
	"vil:varro":{"age":32,"personality":"Aufmerksam, erkundet gern unbekannte Wege","interest":"Navigation","goal":"Sichere Wege zwischen den Höfen finden","family":""}
}
const SPECIALISTS := ["vil:aurelia","vil:varro"]
const DAILY_WAGE := 2
const POST := Vector2(0, -7)
const REACH := 3.2
const LESSON_SECONDS := 6.0
const SKILLS := ["melee","sword","spear","shield","archery","riding","endurance","agility","perception","tactics","discipline","leadership","healing","trade","craft","navigation","negotiation"]
const REQUESTS := ["follow","wait","assist","home"]
const ROLES := ["guide","carry","watch","aid"]
const KIT := {"walking_staff":"tool", "wool_cloak":"body", "linen_tunic":"body", "leather_belt":"belt", "bronze_brooch":"belt"}
const COMMAND_FIELDS := {
	"party_invite":["actor_uid"], "party_hire":["actor_uid"], "party_dismiss":["actor_uid"],
	"party_order":["actor_uid","order"], "party_assign":["actor_uid","assignment"],
	"party_supply":["actor_uid","quantity"], "party_equip":["actor_uid","item_id"],
	"party_train":["actor_uid","skill"], "party_delegate":["actor_uid","leader_uid"]
}

static func initial() -> Dictionary:
	return {"members":{}, "staff_stock":0, "staff_made":0}

static func new_member() -> Dictionary:
	return {"status":"active","order":"follow","assignment":"","bond":0,"morale":65,
		"rations":0,"meals":0,"contract":"voluntary","paid":0,"prepaid":0,"skills":{},"equipment":{},"memories":[],
		"lesson":"","practice":0.0,"shortage":0}

static func remember(member: Dictionary, note: String) -> void:
	member.memories.append(note)
	if member.memories.size() > 32:
		member.memories.pop_front()

static func local_id(world: Dictionary, uid: String) -> String:
	return str(world.companion.id) if uid == FRIEND else uid.trim_prefix("vil:")

static func resident(world: Dictionary, uid: String) -> Dictionary:
	for person: Dictionary in world.village.economy.people:
		if str(person.id) == local_id(world, uid):
			return person
	return {}

static func healthy(world: Dictionary, uid: String) -> bool:
	var person := resident(world, uid)
	if person.is_empty():
		return uid == FRIEND
	return person.alive and int(person.health) > 30 and person.assignment == "idle" and not world.village.militia.has(person.id)

static func protected(world: Dictionary) -> bool:
	return world.encounter.active or world.village.raid.status in ["warning","active"] or world.village.get("childhood",{}).get("screenplay",{}).get("i10","") == "pending"

static func position(world: Dictionary, uid: String) -> Vector2:
	var id := local_id(world, uid)
	var observation: Dictionary = world.village.get("behavior",{}).get("people",{}).get(id,{})
	if observation.get("observed",false):
		return Vector2(observation.position[0], observation.position[2])
	var saved: Array = world.world_state.party.members.get(uid,{}).get("travel_position", [])
	if not saved.is_empty():
		return Vector2(saved[0], saved[2])
	if uid == FRIEND:
		return Childhood.POINTS.marcus if Childhood.enabled(world) else Vector2(-3, 4)
	return Life.actor_position(world,id)

static func player_position(world: Dictionary) -> Vector2:
	return Vector2(world.player.position[0], world.player.position[2])

static func base_trust(world: Dictionary, uid: String) -> int:
	if uid == FRIEND:
		return int(world.companion.trust)
	return int(Life.relationship(world, local_id(world,uid)).get("trust",0))

static func validate_arguments(command: String, args: Dictionary) -> String:
	for key in args:
		if key == "quantity":
			if not _integer(args.quantity,1,99):
				return "Übergib zwischen einer und 99 ganzen Rationen."
		elif typeof(args[key]) != TYPE_STRING or args[key].is_empty() or args[key].length() > 64:
			return "Für diese Bitte fehlt eine gültige Kennung."
	var uid: String = args.actor_uid
	var group := command == "party_order" and (uid == "all" or uid.begins_with("group:"))
	if not group and uid != FRIEND and not uid.begins_with("vil:"):
		return "Diese Person kann hier keine Begleitung zusagen."
	if command == "party_order" and args.order not in REQUESTS:
		return "Eine zivile Reisegruppe kann nur freiwillige Begleitaufgaben übernehmen."
	if command == "party_assign" and args.assignment not in ROLES:
		return "Unbekannte Begleitaufgabe."
	if command == "party_equip" and not KIT.has(args.item_id):
		return "Dieser Gegenstand eignet sich nicht für die Reisegruppe."
	if command == "party_train" and args.skill not in ["perception","endurance"]:
		return "Für diese Ausbildung fehlt ein geeigneter Lehrer."
	return ""

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}

static func _invite(world: Dictionary, uid: String, hired: bool) -> Dictionary:
	var members: Dictionary = world.world_state.party.members
	if members.has(uid) and members[uid].status == "active":
		return _result(false,"Diese Person gehört bereits zum Gefolge.")
	if uid != FRIEND and (not world.village.enabled or not Life.has_npc(world,local_id(world,uid))):
		return _result(false,"Diese Person kann aktuell keine Begleitung vereinbaren.")
	if not healthy(world,uid) or position(world,uid).distance_to(player_position(world)) > REACH:
		return _result(false,"Sprich mit der verfügbaren Person vor Ort.")
	if uid == FATHER and not Childhood.enabled(world):
		return _result(false,"Dieser Lebensweg kennt Silvanus nicht als Vater.")
	if uid == FRIEND and (not world.companion.met or world.companion.choice != "help"):
		return _result(false,"Dein Gegenüber ist noch nicht bereit, mit dir zu reisen.")
	if uid != FRIEND and uid != FATHER and uid not in SPECIALISTS and not willing_resident(world,uid):
		return _result(false,"Diese Person möchte sich erst besser kennenlernen oder hat noch Verpflichtungen.")
	if hired and uid not in SPECIALISTS:
		return _result(false,"Diese Person bietet hier keinen bezahlten Dienst an.")
	if uid in SPECIALISTS:
		var relation := Life.relationship(world,local_id(world,uid))
		if not world.village.enabled or not relation.get("met",false):
			return _result(false,"Stelle dich zuerst persönlich vor.")
		if not hired and not relation.get("ally",false):
			return _result(false,"Diese Fachkraft bittet um einen vereinbarten Lohn.")
		if hired and int(world.resources.denarii) < DAILY_WAGE:
			return _result(false,"Für den ersten Reisetag fehlen zwei Denare.")
		if hired and int(world.player.age) < 18 and (not travelling(world,FATHER) or not healthy(world,FATHER) or position(world,FATHER).distance_to(player_position(world)) > REACH):
			return _result(false,"Silvanus muss den Vertrag vor Ort mit dir vereinbaren.")
	if not members.has(uid):
		members[uid] = new_member()
		if uid == "vil:aurelia":
			members[uid].skills.healing = 12
		elif uid == "vil:varro":
			members[uid].skills.navigation = 12
	var member: Dictionary = members[uid]
	member.contract = "paid" if hired else "voluntary"
	if hired:
		world.resources.denarii -= DAILY_WAGE
		member.paid += DAILY_WAGE
		member.prepaid = 1
	member.status = "active"
	member.order = "follow"
	member.shortage = 0
	remember(member,"Die persönliche Einladung angenommen.")
	return _result(true,"»Ich komme mit.«")

static func willing_resident(world: Dictionary, uid: String) -> bool:
	var relation := Life.relationship(world,local_id(world,uid))
	return relation.get("met",false) and (relation.get("ally",false) or int(relation.get("trust",0)) >= 8) and healthy(world,uid)

static func apply(world: Dictionary, command: String, args: Dictionary) -> Dictionary:
	var uid: String = args.actor_uid
	var members: Dictionary = world.world_state.party.members
	if protected(world) or int(world.player.health) <= 0:
		return _result(false,"Die laufende Gefahr hat Vorrang.")
	if command in ["party_invite","party_hire"]:
		return _invite(world,uid,command == "party_hire")
	if command == "party_order":
		var targets: Array = members.keys() if uid == "all" else [uid]
		if uid.begins_with("group:"):
			var leader := uid.trim_prefix("group:")
			if members.get(leader,{}).get("status","") != "active":
				return _result(false,"Diese Reisegruppe hat keine verfügbare Leitung.")
			targets = [leader]
			for other: String in members:
				if members[other].get("deputy","") == leader:
					targets.append(other)
		var willing := []
		for target: String in targets:
			var person: Dictionary = members.get(target,{})
			if person.get("status","") == "active" and healthy(world,target):
				willing.append(person)
		if willing.is_empty():
			return _result(false,"Niemand ist für diese Bitte verfügbar.")
		for person: Dictionary in willing:
			_order(person,args.order)
		return _result(true,"%d Personen haben deine Bitte angenommen." % willing.size())
	var member: Dictionary = members.get(uid,{})
	if member.get("status","") != "active":
		return _result(false,"Diese Person reist nicht mit dir.")
	if command == "party_dismiss":
		member.status = "dismissed"
		member.assignment = ""
		member.prepaid = 0
		_order(member,"home")
		remember(member,"Ihr habt euch verabschiedet.")
		return _result(true,"Ihr verabschiedet euch. Persönlicher Besitz bleibt bei seinem Eigentümer.")
	if not healthy(world,uid):
		return _result(false,"Diese Person muss sich erholen oder hat andere Verpflichtungen.")
	if command == "party_delegate":
		var leader: String = args.leader_uid
		if leader == "player":
			member.erase("deputy")
			return _result(true,"Die Person reist wieder unmittelbar mit dir.")
		var chief: Dictionary = members.get(leader,{})
		if leader == uid or chief.get("status","") != "active" or chief.has("deputy") or not healthy(world,leader) or chief.order == "home":
			return _result(false,"Die gewählte Person kann diese Reisegruppe nicht übernehmen.")
		for other: Dictionary in members.values():
			if other.get("deputy","") == uid:
				return _result(false,"Übergib zuerst die bereits betreuten Mitreisenden.")
		member.deputy = leader
		return _result(true,"Die beiden stimmen der gemeinsamen Reisegruppe zu.")
	if command == "party_assign":
		if args.assignment == "aid" and uid == FRIEND and int(member.skills.get("healing",0)) == 0:
			return _result(false,"»Verletzte versorgen kann ich noch nicht. Lass mich nach dem Weg sehen.«")
		member.assignment = args.assignment
		_order(member,"assist")
		return _result(true,"Dein Gefährte übernimmt die Aufgabe.")
	if member.order == "home" or position(world,uid).distance_to(player_position(world)) > REACH:
		return _result(false,"Gehe für die Übergabe oder Übung zu deinem Gefährten.")
	if command == "party_supply":
		var count := int(args.quantity)
		if int(world.resources.grain) < count or int(member.rations) + count > capacity(member):
			return _result(false,"Der Vorrat oder der freie Trageplatz reicht nicht.")
		world.resources.grain -= count
		member.rations += count
		return _result(true,"%d Rationen übergeben." % count)
	if command == "party_equip":
		return _equip(world, member, args.item_id)
	if command == "party_train":
		if member.order == "train" or not _lesson_ready(world, uid):
			return _result(false,"Versammelt euch mit Silvanus am Übungsplatz.")
		if int(member.skills.get(args.skill,0)) >= 10:
			return _result(false,"Für die nächste Stufe ist Fachunterricht nötig.")
		member.lesson = args.skill
		member.practice = 0.0
		member.order = "train"
		return _result(true,"Die beaufsichtigte Übung beginnt. Bleibt sechs Sekunden zusammen am Übungsplatz.")
	return _result(false,"Unbekannte Bitte.")

static func _order(member: Dictionary, order: String) -> void:
	member.order = order
	member.lesson = ""
	member.practice = 0.0

static func capacity(member: Dictionary) -> int:
	return 8 + (4 if member.equipment.has("tool") else 0) + int(member.skills.get("endurance",0))

static func _equip(world: Dictionary, member: Dictionary, id: String) -> Dictionary:
	var slot: String = KIT[id]
	var old: String = member.equipment.get(slot,"")
	var party: Dictionary = world.world_state.party
	var trade: Dictionary = world.village.get("city_trade",{})
	if old == id and slot == "tool" and int(member.rations) > capacity(member)-4:
		return _result(false,"Verbrauche zuerst einen Teil der getragenen Rationen.")
	if old != id:
		if id == "walking_staff":
			if int(party.staff_stock) > 0:
				party.staff_stock -= 1
			elif int(world.resources.wood) > 0:
				world.resources.wood -= 1
				party.staff_made += 1
			else:
				return _result(false,"Für einen Wanderstab wird ein Holz benötigt.")
		else:
			var reserved := 1 if trade.get("equipment",{}).values().has(id) else 0
			if int(trade.get("inventory",{}).get(id,0)) <= reserved:
				return _result(false,"Kein freies Exemplar in deinem Gepäck.")
			trade.inventory[id] -= 1
	if old == "walking_staff":
		party.staff_stock += 1
	elif old != "":
		trade.inventory[old] += 1
	member.equipment.erase(slot)
	if old != id:
		member.equipment[slot] = id
	return _result(true,"Die Ausrüstung wurde persönlich übergeben.")

static func _lesson_ready(world: Dictionary, uid: String) -> bool:
	var father: Dictionary = world.world_state.party.members.get(FATHER,{})
	return father.get("status","") == "active" and father.order != "home" and healthy(world,FATHER) and healthy(world,uid) and player_position(world).distance_to(POST) <= REACH and position(world,FATHER).distance_to(POST) <= REACH and position(world,uid).distance_to(POST) <= REACH

static func advance_lessons(world: Dictionary, delta: float) -> void:
	for uid: String in world.world_state.party.members:
		var member: Dictionary = world.world_state.party.members[uid]
		if member.order != "train" or protected(world) or not _lesson_ready(world,uid):
			continue
		member.practice += delta
		if member.practice >= LESSON_SECONDS:
			var skill: String = member.lesson
			member.skills[skill] = int(member.skills.get(skill,0)) + 1
			member.bond = mini(100,int(member.bond) + 1)
			remember(member,"Gemeinsame Übung am Platz abgeschlossen.")
			_order(member,"follow")

## Days actually spent travelling. At home the village economy serves residents.
## After two unfed days a volunteer goes home; a long jump never loops over years.
static func settle_days(world: Dictionary, days: int) -> void:
	if days <= 0:
		return
	for uid: String in world.world_state.party.members:
		var member: Dictionary = world.world_state.party.members[uid]
		if member.status != "active" or member.order == "home":
			continue
		var served_days := mini(days,int(member.rations) + 2 - int(member.shortage))
		var unpaid := false
		if member.contract == "paid":
			var credit := mini(served_days,int(member.prepaid))
			var funded := mini(served_days-credit,int(world.resources.denarii) / DAILY_WAGE)
			var payment := funded * DAILY_WAGE
			world.resources.denarii -= payment
			member.paid += payment
			member.prepaid -= credit
			unpaid = credit + funded < served_days
			served_days = credit + funded
		var fed := mini(int(member.rations),served_days)
		member.rations -= fed
		member.meals += fed
		if fed > 0:
			member.shortage = 0
		var missed := mini(2 - int(member.shortage),served_days-fed)
		member.shortage += missed
		member.morale = clampi(int(member.morale)+fed-8*missed,0,100)
		if missed > 0:
			member.bond = maxi(-100,int(member.bond)-missed)
		if unpaid:
			member.status = "dismissed"
			member.prepaid = 0
			member.assignment = ""
			_order(member,"home")
			remember(member,"Der bezahlte Begleitvertrag endete, als der vereinbarte Lohn ausblieb.")
		elif member.shortage >= 2:
			_order(member,"home")
			remember(member,"Wegen fehlender Rationen nach Hause zurückgekehrt.")

	clear_vacant_roles(world)

static func wages_paid(party: Dictionary) -> int:
	var total := 0
	for member: Dictionary in party.members.values():
		total += int(member.paid)
	return total

static func clear_vacant_roles(world: Dictionary) -> void:
	var members: Dictionary = world.world_state.party.members
	for member: Dictionary in members.values():
		if member.has("deputy") and (member.status != "active" or members[member.deputy].status != "active"):
			member.erase("deputy")

static func grain_issued(party: Dictionary) -> int:
	var total := 0
	for member: Dictionary in party.members.values():
		total += int(member.rations) + int(member.meals)
	return total

static func view(world: Dictionary) -> Dictionary:
	var rows := []
	for uid: String in world.world_state.party.members:
		var member: Dictionary = world.world_state.party.members[uid]
		var row := member.duplicate(true)
		var person := resident(world,uid)
		var id := local_id(world,uid)
		row.actor_uid = uid
		row.name = person.get("name",id.capitalize())
		row.health = person.get("health",100)
		var profile: Dictionary = PROFILES.get(uid,{"age":12 if uid == FRIEND else 30,"personality":"Neugierig, kennt die Wege" if uid == FRIEND else str(person.get("profession","Dorfbewohner")),"interest":"Lernen" if uid == FRIEND else str(person.get("profession","Dorfleben")),"goal":"Eigenständig Aufträge erledigen","family":""})
		row.birth_year = int(world.calendar.births.companion.year) if uid == FRIEND else Calendar.add_years(int(world.calendar.origin_year),-int(profile.age))
		row.age = Calendar.age_in_year(row.birth_year,Clock.year(world))
		row.personality = profile.personality
		row.interest = profile.interest
		row.goal = profile.goal
		row.family = profile.family
		row.trust = clampi(base_trust(world,uid)+int(member.bond),-100,100)
		row.location = "Unterkunft" if member.order == "home" else "Valdora"
		row.wage = DAILY_WAGE if member.contract == "paid" else 0
		row.capacity = capacity(member)
		row.items = []
		var inventory: Dictionary = world.village.get("city_trade",{}).get("inventory",{})
		for item_id: String in KIT:
			if item_id == "walking_staff" or int(inventory.get(item_id,0)) > 0 or member.equipment.values().has(item_id):
				row.items.append(item_id)
		rows.append(row)
	return {"party_uid":"party:player","members":rows}

static func validate(world: Dictionary) -> String:
	var party: Variant = world.world_state.get("party")
	if not _keys(party,["members","staff_stock","staff_made"]) or typeof(party.members) != TYPE_DICTIONARY or not _integer(party.staff_stock,0,1000000) or not _integer(party.staff_made,0,1000000):
		return "Ungültiges Gefolgebuch."
	var staffs := int(party.staff_stock)
	for uid: Variant in party.members:
		if typeof(uid) != TYPE_STRING or (uid != FRIEND and (not uid.begins_with("vil:") or not world.village.enabled or not Life.has_npc(world,local_id(world,uid)) or resident(world,uid).is_empty())) or (uid == FATHER and not Childhood.enabled(world)) or (uid == FRIEND and not world.companion.met):
			return "Unbekannte oder noch nicht getroffene Person im Gefolge."
		var member: Variant = party.members[uid]
		var fields := new_member().keys()
		if member is Dictionary and member.has("travel_position"):
			if NpcBehavior.enabled(world) or not NpcBehavior._position(member.travel_position):
				return "Ungültiger beobachteter Reiseort."
			fields.append("travel_position")
		if not _keys(member,fields) or member.status not in ["active","dismissed"] or member.order not in REQUESTS + ["train"] or member.assignment not in ROLES + [""]:
			return "Ungültige Gefolgschaft oder Aufgabe."
		if uid in SPECIALISTS and not Life.relationship(world,local_id(world,uid)).get("met",false):
			return "Fachkraft ohne persönliche Bekanntschaft."
		if member.contract not in ["paid","voluntary"] or (member.contract == "paid" and uid not in SPECIALISTS) or not _integer(member.paid,0,1000000000) or int(member.paid) % DAILY_WAGE != 0 or not _integer(member.prepaid,0,1) or (member.prepaid > 0 and (member.contract != "paid" or member.paid < DAILY_WAGE or member.status != "active")):
			return "Ungültiger Lohnvertrag."
		if member.status == "dismissed" and (member.order != "home" or member.assignment != ""):
			return "Entlassene Person mit aktivem Auftrag."
		for key: String in ["morale","bond","meals","rations","shortage"]:
			var upper: int = {"morale":100,"bond":100,"meals":1000000000,"rations":112,"shortage":2}[key]
			if not _integer(member[key],-100 if key == "bond" else 0,upper):
				return "Ungültige Versorgung oder Beziehung."
		if typeof(member.skills) != TYPE_DICTIONARY or typeof(member.equipment) != TYPE_DICTIONARY or typeof(member.memories) != TYPE_ARRAY or member.memories.size() > 32:
			return "Ungültiger Personenvertrag."
		for skill: Variant in member.skills:
			if skill not in SKILLS or not _integer(member.skills[skill],0,100):
				return "Ungültige persönliche Fähigkeit."
		for slot: Variant in member.equipment:
			if not KIT.has(member.equipment[slot]) or KIT[member.equipment[slot]] != slot or (slot != "tool" and not world.village.has("city_trade")):
				return "Unbekannter Besitz im Gefolge."
		if member.equipment.has("tool"):
			staffs += 1
		for note: Variant in member.memories:
			if typeof(note) != TYPE_STRING or note.is_empty() or note.length() > 240:
				return "Ungültige persönliche Erinnerung."
		if typeof(member.practice) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(member.practice) or member.practice < 0 or member.practice >= LESSON_SECONDS or int(member.rations) > capacity(member):
			return "Übungszeit oder Traglast ist ungültig."
		if member.order == "train":
			if member.lesson not in ["perception","endurance"] or int(member.skills.get(member.lesson,0)) >= 10:
				return "Ungültige laufende Übung."
		elif member.lesson != "" or member.practice != 0:
			return "Übungszeit ohne laufende Übung."
	if staffs != int(party.staff_made):
		return "Die hergestellten Wanderstäbe sind nicht bilanziert."
	return ""

static func _keys(value: Variant, keys: Array) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.size() == keys.size() and value.has_all(keys)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(value) and value == floor(value) and value >= low and value <= high


static func travelling(world: Dictionary, uid: String) -> bool:
	var member: Dictionary = world.get("world_state",{}).get("party",{}).get("members",{}).get(uid,{})
	return member.get("status","") == "active" and member.order != "home"

static func reconcile(world: Dictionary) -> void:
	for uid: String in world.world_state.party.members:
		var person := resident(world,uid)
		var member: Dictionary = world.world_state.party.members[uid]
		if member.status == "active" and not person.get("alive",true):
			member.status = "dismissed"
			member.prepaid = 0
			member.assignment = ""
			_order(member,"home")
			remember(member,"Im Dorf verstorben.")
	clear_vacant_roles(world)

static func village_reserve_size() -> int:
	var count := 0
	for person: Dictionary in preload("res://scripts/domain/village_economy.gd").PEOPLE:
		if not Life.NPCS.has(person.id):
			count += 1
	return count

static func migrate_legacy(world: Dictionary) -> void:
	var friend: Variant = world.get("companion")
	if typeof(friend) == TYPE_DICTIONARY and friend.get("met") == true and friend.get("choice") == "help":
		var member := new_member()
		remember(member,"Die frühere Begleitung bleibt bestehen.")
		world.world_state.party.members[FRIEND] = member
	# Only reconcile a balanced original four-person ledger. Corrupt fields
	# still reach strict validation and cause the whole load to be rejected.
	var pop: Variant = world.get("population")
	var squad: Variant = world.get("squad")
	if typeof(world.get("village")) != TYPE_DICTIONARY or world.village.get("enabled") != true:
		return
	if typeof(pop) != TYPE_DICTIONARY or typeof(squad) != TYPE_DICTIONARY or not _integer(squad.get("recruits"),0,3):
		return
	if pop.get("total") == 4 and pop.get("workers") == 4 - int(squad.recruits):
		pop.total = village_reserve_size()
		pop.workers = int(pop.total) - int(squad.recruits)

static func normalize(world: Dictionary) -> void:
	var party: Dictionary = world.world_state.party
	party.staff_stock = int(party.staff_stock)
	party.staff_made = int(party.staff_made)
	for member: Dictionary in party.members.values():
		for field: String in ["rations","meals","bond","morale","shortage","paid","prepaid"]:
			member[field] = int(member[field])
		for skill: String in member.skills:
			member.skills[skill] = int(member.skills[skill])


## Older regional careers have no village.behavior record. Only those worlds
## store an observed body position with the member. The established convention
## measures the common friend's body centre, and a named villager's feet.
static func observe_travellers(world: Dictionary, observations: Variant) -> void:
	if typeof(observations) != TYPE_DICTIONARY:
		return
	var members: Dictionary = world.world_state.party.members
	for uid: String in members:
		var id := local_id(world, uid)
		var sample: Variant = observations.get(id)
		if sample is Dictionary and NpcBehavior._position(sample.get("position")):
			members[uid].travel_position = sample.position.duplicate()
