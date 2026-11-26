extends RefCounted
## Shared village life: original fictional encounters in a documented historical era.
## The WorldModel owns transactions and time. Presentation cannot award experience.

const Childhood = preload("res://scripts/story/village_childhood.gd")
const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const WorldCalendar = preload("res://scripts/domain/world_calendar.gd")
const WorldClock = preload("res://scripts/domain/world_clock.gd")
const VERSION := 1
const DAY_SECONDS := 120.0
const STEP := 0.1
const RANGE := 3.2
const FIRST_WARNING := 120.0
const WARNING_SECONDS := 45.0
const RAID_SECONDS := 150.0
const RAID_INTERVAL := 360.0
const SCOUT_POINT := Vector2(-16.0, -19.0)
const ALARM_POINT := Vector2(0.0, -16.0)
const RESCUE_POINT := Vector2(5.0, -9.0)
const WORKPLACE_POSITIONS := Childhood.WORKPLACE_POSITIONS
const GOODS := ["wood", "grain", "denarii", "stone"]
const NPCS := {
	"decimus": {"name":"Decimus", "role":"Dorfverwalter", "x":2.0, "z":9.0, "profession":"", "cost":{}, "greeting":"Trajan herrscht in Rom. Hier trage ich die Verantwortung. Die Angreifer haben uns Vorräte und Werkzeug genommen. Hilf beim Wiederaufbau; Vertrauen verdienst du dir mit Taten.", "reply":"Sprich mit den Handwerkern. Wenn du die Arbeitsgruppen koordinierst, bleibt jede Person nur an einem Ort eingeteilt."},
	"aelia": {"name":"Aelia", "role":"Steinmetzin", "x":20.0, "z":17.0, "profession":"mason", "cost":{"wood":2}, "greeting":"Diese Mauer fällt, wenn wir nur die sichtbaren Steine ersetzen. Zuerst brauchen wir eine sichere Stütze. Bring mir zwei Holzstücke, dann zeige ich dir, worauf es ankommt.", "reply":"Du hast an die Stütze gedacht. Jetzt können wir die beschädigte Stelle wirklich sichern."},
	"varro": {"name":"Varro", "role":"Späher und Jäger", "x":-10.0, "z":-13.0, "profession":"scout", "cost":{"grain":2}, "greeting":"Eine Spur erzählt, wie viele Menschen hier waren und wohin sie gingen. Für die nächste Runde brauche ich zwei Rationen. Bei einer Warnung sehen wir uns die Spur am nördlichen Waldrand an.", "reply":"Mit dem Proviant komme ich weit genug hinaus. Den Waldrand findest du nordwestlich vom Dorf."},
	"fabius": {"name":"Fabius", "role":"Holzfäller", "x":-12.0, "z":3.0, "profession":"woodcutter", "cost":{"grain":2}, "greeting":"Allein zwischen fallenden Stämmen zu arbeiten ist töricht. Unser Lager braucht immer zwei Leute. Zwei Rationen helfen uns, die erste gemeinsame Schicht durchzuhalten.", "reply":"Danke. Wenn einer fällt, muss der andere helfen können. Deshalb bleibt unser Lager zu zweit besetzt."},
	"aurelia": {"name":"Aurelia", "role":"Heilerin", "x":8.0, "z":18.0, "profession":"healer", "cost":{"grain":2}, "greeting":"Ein Verband ersetzt kein Essen und keine Ruhe. Ich versorge die Verletzten. Zwei Rationen würden helfen; bei einem Angriff bring die Menschen vom nördlichen Weg zu uns.", "reply":"Diese Rationen gehen an Menschen, die gerade nicht arbeiten können. So kommen sie wieder auf die Beine."},
	"cassia": {"name":"Cassia", "role":"Händlerin", "x":5.0, "z":0.0, "profession":"trader", "cost":{"wood":2}, "greeting":"Ohne sichere Wege kommt kein Händler. Zwei Holzstücke richten die gebrochene Wagenstrebe. Danach kann ich dir zeigen, wie man Vorrat, Fracht und Preis zusammenrechnet.", "reply":"Der Wagen hält wieder. Eine gute Zusage ist nur so viel wert wie das, was anschließend tatsächlich ankommt."},
	"severus": {"name":"Severus", "role":"Wachausbilder", "x":0.0, "z":-7.0, "profession":"guard", "cost":{"wood":2}, "greeting":"Mut ist nicht blindes Losrennen. Für den Übungsschild fehlen zwei Holzstücke. Bei einer Warnung läutest du am Nordposten Alarm. Im Kampf zählen Abstand, Ausdauer und der richtige Augenblick.", "reply":"Der Übungsschild ist bereit. Beobachte den Ansatz eines Angriffs: Blocken und Ausweichen wirken nur im richtigen Zeitfenster."}
}
const PROFESSIONS := {"":"Noch offen", "mason":"Steinmetzlehre", "scout":"Späherlehre", "woodcutter":"Holzfällerlehre", "healer":"Heilkundelehre", "trader":"Handelslehre", "guard":"Wachausbildung", "smith":"Beginnende Schmiedelehre"}
const COMMAND_FIELDS := {
	"village_talk":["npc_id","choice"], "village_learn":["npc_id"], "village_ally":["npc_id"],
	"village_scout":[], "village_alarm":[], "village_strike":["enemy_id"],
	"village_block":[], "village_dodge":[], "village_rescue":[], "village_recover":[],
	"village_childhood_action":["action_id"], "village_childhood_begin_raid":[]
}
## Historical anchors live with the world clock (WorldClock.history_frame):
## the era registry for the 58 BC campaign, own entries for 100 AD careers.


static func ensure(data: Dictionary) -> void:
	if not data.has("village"):
		data.village = {}
	if typeof(data.village) != TYPE_DICTIONARY:
		return
	if not data.village.has("social"):
		var npcs := {}
		for id: String in NPCS:
			npcs[id] = {"met":false, "trust":0, "helped":false, "declined":false, "learned":false, "ally":false}
		data.village.social = {"version":VERSION, "seconds":0.0, "accumulator":0.0, "npcs":npcs, "profession":"", "ledger":{"wood":0,"grain":0,"denarii":0,"stone":0}}
	if not data.village.has("raid"):
		data.village.raid = {"status":"quiet", "active":false, "number":0, "completed":0, "won":0, "remaining":0.0,
			"next_at":FIRST_WARNING, "enemies":[], "scouted":false, "alarm":false, "rescued":false, "joined":false,
			"participation":0, "player_hits":0, "blocks":0, "dodges":0, "stolen":0, "guard_clock":0.0,
			"strike_cooldown":0.0, "defense_cooldown":0.0, "block_window":0.0, "dodge_window":0.0, "stamina":100.0,
			"outcome":"", "last_summary":"Noch kein Überfall.", "rescue_available":false, "rescue_person_id":""}
	if not data.village.has("attributes"):
		data.village.attributes = {"courage":0,"combat":0,"insight":0,"tactics":0}
	if not data.village.has("history"):
		data.village.history = {"start_year":100,"mode":"historical_baseline", "player_changes":[], "events":[]}
	Abilities.ensure(data)


static func npc_catalog(data: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in NPCS:
		var npc: Dictionary = NPCS[id].duplicate(true)
		npc["id"] = id
		npc.name = Childhood.display_name(data, id, str(npc.name))
		result.append(npc)
	result.append_array(Childhood.npc_catalog(data))
	return result


static func has_npc(data: Dictionary, id: String) -> bool:
	return NPCS.has(id) or Childhood.has_npc(data, id)


static func relationship(data: Dictionary, id: String) -> Dictionary:
	if Childhood.has_npc(data, id):
		return Childhood.relationship(data, id)
	return data.get("village", {}).get("social", {}).get("npcs", {}).get(id, {}).duplicate(true)


static func execute(data: Dictionary, command: String, args: Dictionary = {}) -> Dictionary:
	if not COMMAND_FIELDS.has(command) or not _keys(args, COMMAND_FIELDS[command]):
		return _fail("Der Dorfauftrag enthält fehlende oder unerlaubte Angaben.")
	var invalid := validate(data)
	if not invalid.is_empty():
		return _fail("Ungültiges Dorfleben: " + invalid)
	for key: String in args:
		if typeof(args[key]) != TYPE_STRING or str(args[key]).length() > 64:
			return _fail("Ungültige Gesprächs- oder Zielkennung.")
	var candidate: Dictionary = data.duplicate(true)
	var result := _apply(candidate, command, args)
	if not result.ok:
		return result
	invalid = validate(candidate)
	if not invalid.is_empty():
		return _fail("Dorfauftrag verworfen: " + invalid)
	# Core village commands mutate these domains. Delegated childhood actions may
	# also change the persistent companion relationship (for example I-03 Marcus),
	# but standalone village fixtures legitimately have no companion object.
	for key: String in ["village", "resources", "player"]:
		data[key] = candidate[key]
	if candidate.has("companion"):
		data["companion"] = candidate["companion"]
	return result


static func _apply(data: Dictionary, command: String, args: Dictionary) -> Dictionary:
	var social: Dictionary = data.village.social
	var raid: Dictionary = data.village.raid
	if Childhood.COMMAND_FIELDS.has(command):
		var result := Childhood.execute(data, command, args)
		if not result.ok:
			return result
		if command == "village_childhood_begin_raid":
			_begin_warning(data, true)
			data.village.raid.scouted = true
			data.village.raid.alarm = true
			_begin_raid(data, true)
		elif command == "village_childhood_action":
			var childhood_action := str(args.get("action_id", ""))
			if childhood_action == "i10_defend":
				_begin_warning(data, true)
				data.village.raid.scouted = true
				data.village.raid.alarm = true
				_begin_raid(data, true)
			elif childhood_action == "i10_hide":
				_begin_warning(data, true)
				_resolve_hidden_childhood_raid(data)
		return result
	if Childhood.enabled(data) and command in ["village_learn", "village_ally"]:
		return _fail("Deine erste Lehre und dein Vertrauen entstehen in den gemeinsamen Kindheitsaufgaben, nicht durch einen sofortigen Karrierewechsel.")
	if Childhood.enabled(data) and command == "village_talk" and args.choice != "meet":
		return _fail("Im Kindheitskapitel entstehen Hilfe und Vertrauen durch eure vereinbarten Wege und Übergaben. Sprich über deinen aktuellen Auftrag.")
	if command in ["village_talk", "village_learn", "village_ally"]:
		var id: String = args.npc_id
		if command == "village_talk" and Childhood.has_npc(data, id):
			return Childhood.talk(data, id, args.choice)
		if not NPCS.has(id):
			return _fail("Diese Person gehört nicht zu den bekannten Dorfbewohnern.")
		var npc: Dictionary = NPCS[id]
		if not is_available(data,id):
			return _fail(_absence_reason(data,id))
		if _distance(data, actor_position(data,id)) > RANGE:
			return _fail("Gehe zu %s, bevor ihr miteinander sprecht." % npc.name)
		var relation: Dictionary = social.npcs[id]
		if command == "village_talk":
			if args.choice == "meet":
				if relation.met:
					return _fail("Ihr kennt euch bereits. Ein erneuter Gruß vergibt kein zusätzliches Vertrauen.")
				relation.met = true
				relation.trust = mini(100, int(relation.trust) + 3)
				_event(data,"meeting", "Du lernst %s kennen." % npc.name)
				return _ok(_greeting(data,id))
			if not relation.met:
				return _fail("Lerne die Person zuerst kennen.")
			if id == "decimus":
				return _fail("Die Arbeitskoordination wird über den Auftrag des Verwalters vereinbart.")
			if relation.helped or relation.declined:
				return _fail("Über diese Bitte habt ihr bereits entschieden.")
			if args.choice == "help":
				if not _affords(data,npc.cost):
					return _fail("Für diese Hilfe fehlen die vereinbarten Vorräte: " + _cost_text(npc.cost))
				_pay(data,npc.cost)
				relation.helped = true
				relation.trust = mini(100, int(relation.trust) + 7)
				_change(data,"help_"+id, "Du hilfst %s. Das beeinflusst eure Beziehung." % npc.name)
				return _ok(npc.reply)
			if args.choice == "decline":
				relation.declined = true
				relation.trust = maxi(-100,int(relation.trust)-2)
				_change(data,"decline_"+id, "Du lehnst die Bitte von %s ab." % npc.name)
				return _ok("»Dann frage ich jemand anderen. Du kannst trotzdem wieder mit mir sprechen.«")
			return _fail("Diese Antwort ist nicht verfügbar.")
		if command == "village_learn":
			if npc.profession == "" or not relation.met or not (relation.helped or int(relation.trust)>=8):
				return _fail("Lerne den Mentor kennen und hilf ihm oder verdiene mindestens 8 Vertrauen durch die Dorfverteidigung.")
			if social.profession == npc.profession:
				return _fail("Du lernst diesen Beruf bereits.")
			if raid.active:
				return _fail("Während des Angriffs ruht die Berufsausbildung.")
			var cost := {"denarii":3} if social.profession != "" else {}
			if not _affords(data,cost):
				return _fail("Ein Berufswechsel benötigt 3 Denarii für neues Werkzeug.")
			_pay(data,cost)
			social.profession = npc.profession
			if not relation.learned:
				relation.learned = true
				relation.trust = mini(100, int(relation.trust) + 2)
			_change(data,"profession_"+id, "Du beginnst bei %s: %s." % [npc.name,PROFESSIONS[npc.profession]])
			return _ok("%s beginnt. Andere Lebenswege bleiben offen." % PROFESSIONS[npc.profession])
		if not relation.met or int(relation.trust) < 12:
			return _fail("Ein Bündnis braucht mindestens 12 Vertrauen aus gemeinsamem Handeln.")
		if relation.ally or id == "decimus":
			return _fail("Dieses persönliche Bündnis ist bereits vereinbart oder nicht verfügbar.")
		if not _affords(data,{"grain":2}):
			return _fail("Für die gemeinsame Versorgung werden 2 Getreide benötigt.")
		_pay(data,{"grain":2})
		relation.ally = true
		_change(data,"ally_"+id, "%s steht dir nun als persönlicher Verbündeter bei." % npc.name)
		return _ok("Ihr vereinbart gegenseitige Hilfe. Der Verbündete bleibt eine echte Person mit einer einzigen Arbeitszuweisung.")
	match command:
		"village_scout":
			if raid.status != "warning" or raid.scouted:
				return _fail("Eine neue Spur lässt sich nur einmal während der Überfallwarnung lesen.")
			if not social.npcs.varro.met or _distance(data,SCOUT_POINT) > RANGE:
				return _fail("Sprich mit Varro und untersuche dann die Spur am nordwestlichen Waldrand.")
			raid.scouted = true
			raid.participation += 1
			_gain(data,"insight",2 + int(Abilities.effect_value(data,"scout_insight_bonus")))
			_event(data,"scout", "Du erkennst die Zahl der Angreifer an ihrer tatsächlichen Spur.")
			return _ok("Die Spur zeigt %d Angreifer. Du hast den nördlichen Zugang rechtzeitig ausgekundschaftet." % _enemy_count(raid.number))
		"village_alarm":
			if raid.status != "warning" or raid.alarm:
				return _fail("Der Alarm kann pro Warnung nur einmal ausgelöst werden.")
			if _distance(data,ALARM_POINT) > RANGE:
				return _fail("Gehe zum Nordposten, um den Alarm auszulösen.")
			raid.alarm = true
			raid.participation += 1
			_gain(data,"tactics",2)
			_event(data,"alarm", "Dein rechtzeitiger Alarm gibt der Wache Zeit, sich vorzubereiten.")
			return _ok("Der Alarm ist ausgelöst. Besetzte Wachen unterstützen die Verteidigung.")
		"village_strike":
			if not raid.active:
				return _fail("Es läuft kein Dorfangriff.")
			var enemy := _enemy(raid,args.enemy_id)
			if enemy.is_empty() or int(enemy.health) <= 0:
				return _fail("Dieser Angreifer ist kein lebendes Ziel.")
			if _distance(data,Vector2(enemy.x,enemy.z)) > 2.8:
				return _fail("Der Angreifer ist außerhalb deiner Schlagreichweite.")
			if float(raid.strike_cooldown) > 0.000001 or float(raid.stamina) < 12.0:
				return _fail("Erhole dich kurz: Angriff benötigt Ausdauer und eine freie Schlagfolge.")
			raid.stamina -= 12.0
			raid.strike_cooldown = 0.65
			var damage := 18 + mini(10,int(data.village.attributes.combat)/5) + (4 if social.profession == "guard" else 0)
			enemy.health = maxi(0,int(enemy.health)-damage)
			raid.player_hits += 1
			raid.participation += 1
			if not raid.joined:
				raid.joined = true
				_gain(data,"courage",1)
			_gain(data,"combat",2 if int(enemy.health)==0 else 1)
			if _living_enemies(raid) == 0:
				_finish_raid(data,"defended")
			return _ok("Treffer für %d Schaden. Ausdauer: %d." % [damage,int(raid.stamina)])
		"village_block", "village_dodge":
			if not raid.active or float(raid.defense_cooldown)>0.000001:
				return _fail("Die Abwehr ist gerade nicht verfügbar.")
			var cost := 16.0 if command == "village_block" else 22.0
			if float(raid.stamina) < cost:
				return _fail("Für diese Abwehr fehlt Ausdauer.")
			raid.stamina -= cost
			raid.defense_cooldown = 1.1
			raid.block_window = 0.9 + Abilities.effect_value(data,"block_window_bonus_seconds") if command == "village_block" else 0.0
			raid.dodge_window = 0.55 if command == "village_dodge" else 0.0
			return _ok("Schild oben. Erfahrung gibt es erst für einen wirklich abgewehrten Treffer." if command == "village_block" else "Du weichst aus. Das Zeitfenster schützt nur vor einem tatsächlich folgenden Angriff.")
		"village_recover":
			if raid.active or raid.status == "warning" or data.get("encounter",{}).get("active",false):
				return _fail("Eine ruhige Behandlung ist erst nach der akuten Gefahr möglich.")
			if not is_available(data,"aurelia"):
				return _fail(_absence_reason(data,"aurelia"))
			if not social.npcs.aurelia.met or _distance(data,actor_position(data,"aurelia"))>RANGE:
				return _fail("Gehe zu Aurelia und stelle dich vor, bevor sie dich versorgt.")
			if int(data.player.health)>=100:
				return _fail("Du benötigst gerade keine Behandlung.")
			if not _affords(data,{"grain":1}):
				return _fail("Für die Erholung wird eine Ration Getreide benötigt.")
			_pay(data,{"grain":1})
			data.player.health = mini(100,int(data.player.health)+25)
			return _ok("Aurelia versorgt dich. Eine Ration verbraucht; Gesundheit: %d." % int(data.player.health))
		"village_rescue":
			if not raid.active or not raid.rescue_available or raid.rescued:
				return _fail("Gerade wartet niemand auf diese Rettung.")
			if _distance(data,RESCUE_POINT)>RANGE:
				return _fail("Erreiche die verletzte Person am nördlichen Dorfweg.")
			var rescued_person := _person(data,raid.rescue_person_id)
			if rescued_person.is_empty() or not rescued_person.get("alive",false):
				return _fail("Diese Person befindet sich nicht mehr in der Gefahrenzone.")
			rescued_person.health = mini(100,int(rescued_person.health)+10+(5 if social.profession=="healer" else 0))
			raid.rescued = true
			raid.rescue_available = false
			raid.participation += 1
			_gain(data,"courage",2)
			social.npcs.aurelia.trust = mini(100,int(social.npcs.aurelia.trust)+3)
			_event(data,"rescue", "Du bringst eine gefährdete Person vom Angriffsweg in Sicherheit.")
			return _ok("%s ist in Sicherheit. Aurelia übernimmt die Versorgung." % str(rescued_person.get("name",raid.rescue_person_id)))
	return _fail("Dieser Dorfauftrag ist nicht unterstützt.")


static func apply_unarmed_hit(data: Dictionary, target_id: String, damage: int) -> bool:
	# Internal hit transaction: timing, direction and geometry were checked by
	# CombatActions. No public command accepts a caller-selected damage value.
	if damage <= 0 or damage > 32 or not data.village.raid.active:
		return false
	var raid: Dictionary = data.village.raid
	var enemy := _enemy(raid, target_id)
	if enemy.is_empty() or int(enemy.health) <= 0:
		return false
	enemy.health = maxi(0, int(enemy.health) - damage)
	raid.player_hits += 1
	raid.participation += 1
	if not raid.joined:
		raid.joined = true
		_gain(data, "courage", 1)
	_gain(data, "combat", 2 if int(enemy.health) == 0 else 1)
	if _living_enemies(raid) == 0:
		_finish_raid(data, "defended")
	return true


static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable(), motion_check: Callable = Callable(), observed_raiders: Dictionary = {}) -> bool:
	if not is_finite(delta) or delta<=0.0 or delta>3600.0 or not validate(data).is_empty():
		return false
	var social: Dictionary = data.village.social
	social.accumulator += delta
	var changed := false
	while float(social.accumulator)+0.00000001>=STEP:
		social.accumulator = maxf(0.0,float(social.accumulator)-STEP)
		if social.accumulator<0.00000001:
			social.accumulator = 0.0
		social.seconds = snappedf(float(social.seconds)+STEP,STEP)
		_tick(data, sight_check, motion_check, observed_raiders)
		changed = true
	return changed


static func _tick(data: Dictionary, sight_check: Callable = Callable(), motion_check: Callable = Callable(), observed_raiders: Dictionary = {}) -> void:
	if data.get("encounter",{}).get("active",false):
		return
	var raid: Dictionary = data.village.raid
	for key: String in ["strike_cooldown","defense_cooldown","block_window","dodge_window"]:
		raid[key] = maxf(0.0,float(raid[key])-STEP)
	raid.stamina = minf(100.0,float(raid.stamina)+1.2)
	if raid.status in ["quiet","aftermath"]:
		# Childhood danger is released only after the completed family/market arc
		# and its explicit night event. Wall-clock idling never summons another raid.
		if Childhood.enabled(data):
			return
		if float(data.village.social.seconds)+0.000001>=float(raid.next_at) and _has_home(data) and _met_count(data)>=3:
			_begin_warning(data)
		return
	raid.remaining = maxf(0.0,float(raid.remaining)-STEP)
	if raid.status == "warning":
		if raid.remaining<=0.000001:
			_begin_raid(data)
		return
	if not raid.active:
		return
	for enemy: Dictionary in raid.enemies:
		if int(enemy.health)<=0:
			continue
		var point := Vector2(enemy.x,enemy.z)
		var player := _player_point(data)
		var near := point.distance_to(player)<=2.2
		if data.village.has("unarmed") and near:
			near = sight_check.is_valid() and bool(sight_check.call(point, player))
		if near:
			enemy.attack_timer = maxf(0.0,float(enemy.attack_timer)-STEP)
			if float(enemy.attack_timer)<=0.000001:
				_enemy_attack(data,enemy)
				enemy.attack_timer = 1.8
		else:
			enemy.attack_timer = 0.9
			if not observed_raiders.has(str(enemy.id)):
				var target := player if point.distance_to(player)<7.0 else Vector2(5.0,5.0)
				target = target.clamp(Vector2(-200,-200),Vector2(200,200))
				var next_point := point.move_toward(target,0.12)
				if data.village.has("unarmed"):
					# New combat never teleports a raider through the live collision world.
					var checked: Variant = motion_check.call(point, next_point) if motion_check.is_valid() else point
					if checked is Vector2 and checked.is_finite() and point.distance_to(checked) <= 0.120001:
						point = checked
				else:
					point = next_point
				enemy.x = point.x
				enemy.z = point.y
			if point.distance_to(Vector2(5.0,5.0))<2.0:
				enemy.loot_timer += STEP
				if float(enemy.loot_timer)>=3.0 and int(raid.stolen)<6:
					enemy.loot_timer = 0.0
					var stolen := mini(2,mini(int(data.resources.grain),6-int(raid.stolen)))
					if stolen>0:
						_pay(data,{"grain":stolen})
						raid.stolen += stolen
		if not raid.active:
			return
	_guard_support(data)
	if _living_enemies(raid)==0:
		_finish_raid(data,"defended")
	elif raid.remaining<=0.000001 or int(raid.stolen)>=6:
		_finish_raid(data,"raided")


static func _enemy_attack(data: Dictionary, enemy: Dictionary) -> void:
	var raid: Dictionary = data.village.raid
	if float(raid.dodge_window)>0.000001:
		raid.dodge_window = 0.0
		raid.dodges += 1
		raid.participation += 1
		_gain(data,"insight",1)
		return
	if float(raid.block_window)>0.000001:
		raid.block_window = 0.0
		raid.blocks += 1
		raid.participation += 1
		_gain(data,"combat",1)
		return
	var damage := 5 + mini(3,int(raid.number)/2)
	data.player.health = maxi(1,int(data.player.health)-damage)
	if int(data.player.health)<=1:
		_finish_raid(data,"wounded")
	# Enemy damage is computed here after distance, wind-up and protection checks.
	# No command accepts a caller-selected damage or experience quantity.


static func _guard_support(data: Dictionary) -> void:
	var raid: Dictionary = data.village.raid
	raid.guard_clock += STEP
	if float(raid.guard_clock)<3.0:
		return
	raid.guard_clock -= 3.0
	for enemy: Dictionary in raid.enemies:
		if int(enemy.health)<=0:
			continue
		var nearby := _nearby_defenders(data,Vector2(enemy.x,enemy.z))
		if int(nearby.count)<2:
			continue
		var damage := mini(16,int(nearby.count)*2)+(2 if raid.alarm else 0)+mini(3,int(nearby.allies))
		enemy.health = maxi(0,int(enemy.health)-damage)
		break


static func defense_strength(data: Dictionary) -> int:
	var count := 0
	var economy: Dictionary = data.get("village",{}).get("economy",{})
	var watch_ready := int(economy.get("workplaces",{}).get("watchpost",{}).get("condition",0))>=100
	for person: Dictionary in economy.get("people",[]):
		var duty := str(person.get("assignment",""))
		if bool(person.get("alive",false)) and int(person.get("health",0))>30 and int(person.get("hunger",3))<2 and (duty=="defense" or duty=="watchpost" and watch_ready):
			count += 1
	return count


static func _nearby_defenders(data: Dictionary, position: Vector2) -> Dictionary:
	var count := 0
	var allies := 0
	var economy: Dictionary = data.get("village",{}).get("economy",{})
	var watch_ready := int(economy.get("workplaces",{}).get("watchpost",{}).get("condition",0))>=100
	for person: Dictionary in economy.get("people",[]):
		var duty := str(person.get("assignment",""))
		if not bool(person.get("alive",false)) or int(person.get("health",0))<=30 or int(person.get("hunger",3))>=2 or not (duty=="defense" or duty=="watchpost" and watch_ready):
			continue
		var id := str(person.get("id",""))
		if actor_position(data,id).distance_to(position)>12.0:
			continue
		count += 1
		var relation: Dictionary = data.village.social.npcs.get(id,{})
		allies += 1 if relation.get("ally",false) else 0
	return {"count":count,"allies":allies}


static func actor_position(data: Dictionary, npc_id: String) -> Vector2:
	var raid: Dictionary = data.get("village",{}).get("raid",{})
	if raid.get("active",false) and raid.get("rescue_available",false) and raid.get("rescue_person_id","")==npc_id:
		return RESCUE_POINT
	var childhood_position: Variant = Childhood.actor_override(data, npc_id)
	if typeof(childhood_position) == TYPE_VECTOR2:
		return childhood_position
	var people: Array = data.get("village",{}).get("economy",{}).get("people",[])
	for index in people.size():
		var person: Dictionary = people[index]
		if str(person.get("id",""))!=npc_id:
			continue
		var duty := str(person.get("assignment","idle"))
		if WORKPLACE_POSITIONS.has(duty):
			var rank := 0
			for previous in index:
				if str(people[previous].get("assignment",""))==duty:
					rank += 1
			return WORKPLACE_POSITIONS[duty]+Vector2((rank%2)*2.4-1.2,2.1+floori(float(rank)/2.0)*2.0)
		if NPCS.has(npc_id):
			return Vector2(NPCS[npc_id].x,NPCS[npc_id].z)
		return Vector2(32.0,-18.0+float(index)*2.0)
	if NPCS.has(npc_id):
		return Vector2(NPCS[npc_id].x,NPCS[npc_id].z)
	return Vector2(32.0,-18.0)


static func _begin_warning(data: Dictionary, childhood_night := false) -> void:
	var raid: Dictionary = data.village.raid
	raid.status = "warning"
	raid.active = false
	raid.number += 1
	raid.remaining = WARNING_SECONDS
	raid.enemies = []
	for key: String in ["scouted","alarm","rescued","joined","rescue_available"]:
		raid[key] = false
	for key: String in ["participation","player_hits","blocks","dodges","stolen"]:
		raid[key] = 0
	raid.outcome = ""
	_event(data,"night_alarm" if childhood_night else "warning", "In der Nacht zerreißen Hufschläge und Rufe die vertraute Ruhe. Der Angriff trifft das inzwischen kennengelernte Dorf." if childhood_night else "Am Nordweg wurden bewaffnete Plünderer gesehen. Spähe die Spur aus, löse Alarm aus und teile die Verteidigung ein.")


static func _begin_raid(data: Dictionary, childhood_night := false) -> void:
	var raid: Dictionary = data.village.raid
	raid.status = "active"
	raid.active = true
	raid.remaining = RAID_SECONDS
	raid.guard_clock = 0.0
	raid.rescue_person_id = ""
	if childhood_night and Childhood.enabled(data):
		var mother := _person(data, "julia")
		if not mother.is_empty() and mother.get("alive", false):
			raid.rescue_person_id = "julia"
			mother.health = maxi(1, int(mother.health) - 10)
	else:
		for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
			if person.get("alive",false) and str(person.get("assignment","")) not in ["defense","watchpost"]:
				raid.rescue_person_id = str(person.id)
				person.health = maxi(1,int(person.health)-10)
				break
	raid.rescue_available = raid.rescue_person_id!=""
	for index in _enemy_count(raid.number):
		raid.enemies.append({"id":"raid_%d_%d" % [int(raid.number),index], "x":float(index*5-5),"z":-62.0-float(index%2)*2.0,"health":45,"max_health":45,"attack_timer":0.9,"loot_timer":0.0})
	_event(data,"raid", "Etwa 30 Reiter brechen über Valdora herein. Die Nahkampf-Simulation bildet nur die unmittelbar relevanten Angreifer als volle Kampf-AIs ab; die übrige Formation bleibt eine sichtbare Angriffsmasse." if childhood_night and Childhood.enabled(data) else "Die Plünderer erreichen den Nordweg. Ihr Angriff und die Gefahr für die Vorräte laufen nun in der Spielwelt.")


static func _resolve_hidden_childhood_raid(data: Dictionary) -> void:
	var raid: Dictionary = data.village.raid
	raid.status = "aftermath"
	raid.active = false
	raid.completed += 1
	raid.remaining = 0.0
	raid.enemies = []
	raid.rescue_available = false
	raid.rescue_person_id = ""
	raid.outcome = "raided"
	var stolen := mini(4, int(data.resources.grain))
	if stolen > 0:
		_pay(data, {"grain":stolen})
		raid.stolen = stolen
	raid.next_at = float(data.village.social.seconds) + RAID_INTERVAL
	raid.last_summary = "Du bleibst bei deinen Eltern, während der Angriff durch Valdora geht. Vorräte und Menschen tragen die Folgen weiter."
	_event(data, "raid_hidden", raid.last_summary)
	_change(data, "raid_%d_hidden" % int(raid.number), raid.last_summary)
	Childhood.on_raid_finished(data)


static func _finish_raid(data: Dictionary, outcome: String) -> void:
	var raid: Dictionary = data.village.raid
	if not raid.active:
		return
	raid.active = false
	raid.status = "aftermath"
	raid.completed += 1
	raid.outcome = outcome
	raid.remaining = 0.0
	raid.next_at = float(data.village.social.seconds)+RAID_INTERVAL
	raid.rescue_available = false
	if outcome == "defended":
		raid.won += 1
		if int(raid.participation)>0:
			_gain(data,"courage",1)
			if raid.scouted and raid.alarm:
				_gain(data,"tactics",1)
			for id: String in data.village.social.npcs:
				var relation: Dictionary = data.village.social.npcs[id]
				if relation.met:
					relation.trust = mini(100,int(relation.trust)+2)
		raid.last_summary = "Das Dorf hält stand. Deine Beiträge: %d Treffer, %d Blocks, %d Ausweichmanöver%s." % [int(raid.player_hits),int(raid.blocks),int(raid.dodges),", eine Rettung" if raid.rescued else ""]
	else:
		# Limited losses preserve recovery. Named adults remain in the single roster.
		for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
			if bool(person.get("alive",false)) and str(person.get("assignment","")) in ["defense","watchpost"]:
				person.health = maxi(1,int(person.health)-15)
				break
		raid.last_summary = "Der Angriff endet. Verlorenes Getreide: %d. Versorge Verletzte und sichere den Wiederaufbau." % int(raid.stolen)
	_change(data,"raid_%d_%s" % [int(raid.number),outcome],raid.last_summary)
	if Childhood.enabled(data):
		Childhood.on_raid_finished(data)


static func training_ready(data: Dictionary) -> bool:
	if Childhood.enabled(data):
		return false
	if not data.get("village",{}).has("social"):
		return false
	return float(data.village.social.seconds)+0.000001>=2.0*DAY_SECONDS and _met_count(data)>=3 and int(data.village.raid.completed)>=1


static func view(data: Dictionary) -> Dictionary:
	if not validate(data).is_empty():
		return {}
	var social: Dictionary = data.village.social
	var raid: Dictionary = data.village.raid
	var npcs: Array[Dictionary] = []
	for specification: Dictionary in npc_catalog(data):
		var row: Dictionary = specification.duplicate(true)
		var id: String = row.id
		var position := actor_position(data,id)
		row.x = position.x
		row.z = position.y
		row["relationship"] = relationship(data, id)
		row["available"] = is_available(data,id)
		row["absence_reason"] = "" if row.available else _absence_reason(data,id)
		npcs.append(row)
	var objective := "Lerne Decimus und die Handwerker kennen. Sichere dein Dach und organisiere den Wiederaufbau."
	if raid.status == "warning":
		objective = "Überfallwarnung: Spur am Waldrand prüfen, am Nordposten Alarm schlagen und Wachen einteilen."
	elif raid.active:
		objective = "Verteidige den Nordweg. Schütze die Vorräte und rette die gefährdete Person."
	elif raid.completed>0:
		objective = "Versorge das Dorf weiter. Vertiefe Beziehungen, lerne einen Beruf und bereite die nächste Wache vor."
	var childhood := Childhood.view(data)
	if not childhood.is_empty() and not raid.active:
		objective = childhood.objective
	var history: Dictionary = data.village.history.duplicate(true)
	# Year, ruler and anchors read the one world clock (D-045). No year zero:
	# the year is the clock's own, never start_year + elapsed years.
	var frame := _history_frame(data)
	history["current_year"] = int(frame.year)
	history["year_label"] = str(frame.year_label)
	history["anchors"] = frame.anchors
	return {"title":childhood.get("title", "Ein Dorf wird dein Zuhause"), "objective":objective, "day":childhood.get("day", floori((float(social.seconds)+0.000001)/DAY_SECONDS)+1),
		"seconds":social.seconds, "ruler":_ruler(data, frame),
		"player_authority":"Bewohner", "profession":PROFESSIONS[social.profession], "attributes":data.village.attributes.duplicate(true),
		"npcs":npcs, "raid":raid.duplicate(true), "history":history, "training_ready":training_ready(data), "defenders":defense_strength(data)}


static func dialogue(data: Dictionary, npc_id: String) -> Dictionary:
	if Childhood.enabled(data):
		return Childhood.dialogue(data, npc_id)
	if not NPCS.has(npc_id) or not validate(data).is_empty():
		return {}
	var npc: Dictionary = NPCS[npc_id]
	var relation: Dictionary = data.village.social.npcs[npc_id]
	var choices: Array[Dictionary] = []
	if not is_available(data,npc_id):
		return {"title":"%s · %s" % [npc.name,npc.role],"text":_absence_reason(data,npc_id),"choices":[]}
	if not relation.met:
		choices.append(_choice("Sich vorstellen", "village_talk", {"npc_id":npc_id,"choice":"meet"},true,""))
	elif npc_id == "decimus":
		choices.append(_choice("Beim Wiederaufbau mithelfen", "village_request_work",{},true,""))
	elif not relation.helped and not relation.declined:
		choices.append(_choice("Helfen · "+_cost_text(npc.cost),"village_talk",{"npc_id":npc_id,"choice":"help"},_affords(data,npc.cost),"Benötigt: "+_cost_text(npc.cost)))
		choices.append(_choice("Die Bitte ablehnen", "village_talk",{"npc_id":npc_id,"choice":"decline"},true,""))
	if npc.profession!="" and relation.met:
		var can_learn: bool = (relation.helped or int(relation.trust)>=8) and data.village.social.profession!=npc.profession and not data.village.raid.active and (data.village.social.profession=="" or _affords(data,{"denarii":3}))
		choices.append(_choice("Beruf lernen · "+PROFESSIONS[npc.profession],"village_learn",{"npc_id":npc_id},can_learn,"Benötigt Hilfe oder 8 Vertrauen; Berufswechsel kostet 3 Denarii."))
		if not relation.ally:
			choices.append(_choice("Bündnis schließen · 2 Getreide", "village_ally",{"npc_id":npc_id},int(relation.trust)>=12 and _affords(data,{"grain":2}),"Benötigt 12 Vertrauen und 2 Getreide."))
	if npc_id=="aurelia" and relation.met:
		choices.append(_choice("Verletzungen versorgen · 1 Getreide", "village_recover",{},not data.village.raid.active and data.village.raid.status!="warning" and not data.get("encounter",{}).get("active",false) and int(data.player.health)<100 and _affords(data,{"grain":1}),"Erfordert eine ruhige Lage, eine Ration und eine Verletzung."))
	var text := _greeting(data,npc_id)
	if relation.helped:
		text = npc.reply+"\n\nVertrauen: %d. %s" % [int(relation.trust),"Ihr seid Verbündete." if relation.ally else "Eure Beziehung entwickelt sich durch eure Entscheidungen."]
	elif relation.declined:
		text = "»Du konntest bei meiner Bitte nicht helfen. Reden können wir trotzdem.«\n\nVertrauen: %d." % int(relation.trust)
	return {"title":"%s · %s" % [npc.name,npc.role],"text":text,"choices":choices}


static func validate(data: Dictionary) -> String:
	if typeof(data.get("village"))!=TYPE_DICTIONARY:
		return "Dorfzustand fehlt."
	var village: Dictionary = data.village
	for key: String in ["social","raid","attributes","history"]:
		if typeof(village.get(key))!=TYPE_DICTIONARY:
			return "Ungültiger Dorfbereich: "+key
	var social: Dictionary = village.social
	if not _keys(social,["version","seconds","accumulator","npcs","profession","ledger"]) or social.version!=VERSION or not _number(social.seconds,0.0,1000000000.0) or not _number(social.accumulator,0.0,STEP+0.00000001):
		return "Ungültige Dorfzeit."
	if typeof(social.profession)!=TYPE_STRING or not PROFESSIONS.has(social.profession) or not _keys(social.npcs,NPCS.keys()) or not _keys(social.ledger,GOODS):
		return "Ungültiger Beruf, Gesprächskreis oder Güterbeleg."
	for good: String in GOODS:
		if not _integer(social.ledger[good],-1000000,1000000):
			return "Ungültige Güterbilanz."
	for id: String in NPCS:
		var npc: Variant = social.npcs[id]
		if not _keys(npc,["met","trust","helped","declined","learned","ally"]) or not _integer(npc.trust,-100,100):
			return "Ungültige Beziehung."
		for key: String in ["met","helped","declined","learned","ally"]:
			if typeof(npc[key])!=TYPE_BOOL:
				return "Beziehungen benötigen klare Wahrheitswerte."
		if npc.helped and npc.declined or (npc.helped or npc.declined or npc.learned or npc.ally) and not npc.met:
			return "Widersprüchliche Beziehungsgeschichte."
	if not _keys(village.attributes,["courage","combat","insight","tactics"]):
		return "Ungültige Fähigkeiten."
	var ability_error := Abilities.validate(data)
	if not ability_error.is_empty():
		return ability_error
	for value: Variant in village.attributes.values():
		if not _integer(value,0,10000):
			return "Fähigkeiten müssen begrenzt und ganzzahlig sein."
	var raid: Dictionary = village.raid
	if not _keys(raid,["status","active","number","completed","won","remaining","next_at","enemies","scouted","alarm","rescued","joined","participation","player_hits","blocks","dodges","stolen","guard_clock","strike_cooldown","defense_cooldown","block_window","dodge_window","stamina","outcome","last_summary","rescue_available","rescue_person_id"]):
		return "Unvollständiger Überfallzustand."
	if typeof(raid.status)!=TYPE_STRING or raid.status not in ["quiet","warning","active","aftermath"] or typeof(raid.active)!=TYPE_BOOL or raid.active!=(raid.status=="active"):
		return "Widersprüchlicher Überfallstatus."
	for key: String in ["scouted","alarm","rescued","joined","rescue_available"]:
		if typeof(raid[key])!=TYPE_BOOL:
			return "Ungültige Überfallentscheidung."
	for key: String in ["number","completed","won","participation","player_hits","blocks","dodges","stolen"]:
		if not _integer(raid[key],0,1000000):
			return "Ungültiger Ereigniszähler."
	if raid.completed>raid.number or raid.won>raid.completed or raid.stolen>6:
		return "Unmögliche Überfallbilanz."
	for key: String in ["remaining","guard_clock","strike_cooldown","defense_cooldown","block_window","dodge_window"]:
		if not _number(raid[key],0.0,3600.0):
			return "Ungültige Kampfzeit."
	if not _number(raid.next_at,0.0,1000001000.0) or not _number(raid.stamina,0.0,100.0) or typeof(raid.outcome)!=TYPE_STRING or raid.outcome not in ["","defended","raided","wounded"] or typeof(raid.last_summary)!=TYPE_STRING or raid.last_summary.length()>1024:
		return "Ungültige Überfallfolge."
	if typeof(raid.rescue_person_id)!=TYPE_STRING or raid.rescue_person_id.length()>64:
		return "Ungültige Rettungsidentität."
	if raid.rescue_available and (not raid.active or raid.rescued or raid.rescue_person_id=="" or _person(data,raid.rescue_person_id).is_empty()):
		return "Rettung und vorhandene Bevölkerung widersprechen sich."
	if typeof(raid.enemies)!=TYPE_ARRAY or raid.enemies.size()>6:
		return "Ungültige Angreiferliste."
	var ids := {}
	for enemy: Variant in raid.enemies:
		if not _keys(enemy,["id","x","z","health","max_health","attack_timer","loot_timer"]) or typeof(enemy.id)!=TYPE_STRING or enemy.id.length()>64 or ids.has(enemy.id):
			return "Ungültige Angreiferidentität."
		ids[enemy.id] = true
		if not _integer(enemy.max_health,45,45) or not _integer(enemy.health,0,45) or not _number(enemy.x,-200.0,200.0) or not _number(enemy.z,-200.0,200.0) or not _number(enemy.attack_timer,0.0,3.0) or not _number(enemy.loot_timer,0.0,RAID_SECONDS+1.0):
			return "Ungültiger Angreiferzustand."
	var history: Dictionary = village.history
	var expected_start_year := -58 if Childhood.enabled(data) else 100
	if not _keys(history,["start_year","mode","player_changes","events"]) or history.start_year!=expected_start_year or typeof(history.mode)!=TYPE_STRING or history.mode not in ["historical_baseline","fictional_branch"]:
		return "Ungültiger Geschichtsrahmen."
	if typeof(history.player_changes)!=TYPE_ARRAY or history.player_changes.size()>128 or typeof(history.events)!=TYPE_ARRAY or history.events.size()>64:
		return "Unbegrenztes Geschichtsprotokoll."
	for item: Variant in history.player_changes:
		if typeof(item)!=TYPE_STRING or item.length()>80:
			return "Ungültiger Geschichtsverzweig."
	for item: Variant in history.events:
		if not _keys(item,["seconds","kind","text","provenance"]) or not _number(item.seconds,0.0,1000000000.0) or typeof(item.kind)!=TYPE_STRING or item.kind.length()>40 or typeof(item.text)!=TYPE_STRING or item.text.length()>1024 or item.provenance!="fictional_playable_event":
			return "Ungültiger Chronikbeleg."
	return Childhood.validate(data)


## The historical frame of the world date. Village data without a clock (the
## module's own fixtures) reads the same registry for the spring of its start
## year plus elapsed years, counted without a year zero.
static func _history_frame(data: Dictionary) -> Dictionary:
	if WorldCalendar.validate_world_time(data.get("calendar")):
		return WorldClock.history_frame(data)
	var start := int(data.village.history.start_year)
	var year := WorldCalendar.add_years(start, int(data.get("progress",{}).get("years_elapsed",0)))
	return WorldClock.frame_at(WorldCalendar.season_start(year, 0), start != WorldClock.CAMPAIGN_ORIGIN_YEAR, str(data.get("origin_id","italia"))=="italia")


static func _ruler(data: Dictionary, frame: Dictionary = {}) -> String:
	if str(data.get("origin_id","italia"))!="italia":
		return "Bestehende Ortsverwaltung"
	if frame.is_empty():
		frame = _history_frame(data)
	return "%s · Dorfverwalter Decimus" % str(frame.ruler)


## Decimus names Trajan only while Trajan rules on the world date.
static func _trajan_rules(data: Dictionary) -> bool:
	return str(data.get("origin_id","italia"))=="italia" and str(_history_frame(data).ruler) == "Trajan"


static func _greeting(data: Dictionary, id: String) -> String:
	if Childhood.enabled(data):
		return str(Childhood.dialogue(data, id).get("text", ""))
	if id=="decimus" and not _trajan_rules(data):
		return "Die örtliche Verwaltung trägt hier die Verantwortung. Hilf beim Wiederaufbau und lerne die Menschen kennen. Vertrauen verdienst du dir mit Taten."
	return NPCS[id].greeting


static func _choice(label: String, command: String, payload: Dictionary, enabled: bool, reason: String) -> Dictionary:
	return {"label":label,"command":command,"payload":payload,"enabled":enabled,"reason":"" if enabled else reason}


static func _met_count(data: Dictionary) -> int:
	var result := 0
	for npc: Dictionary in data.village.social.npcs.values():
		result += 1 if npc.met else 0
	return result


static func _has_home(data: Dictionary) -> bool:
	for building: Dictionary in data.get("buildings",[]):
		if bool(building.get("completed",false)):
			return true
	return false


static func _player_point(data: Dictionary) -> Vector2:
	var position: Array = data.player.position
	return Vector2(float(position[0]),float(position[2]))


static func _distance(data: Dictionary, point: Vector2) -> float:
	return _player_point(data).distance_to(point)


static func is_available(data: Dictionary, npc_id: String) -> bool:
	if not has_npc(data, npc_id):
		return false
	if npc_id=="decimus":
		return true
	var person := _person(data,npc_id)
	return not person.is_empty() and bool(person.get("alive",false)) and not data.get("village",{}).get("militia",[]).has(npc_id)


static func _absence_reason(data: Dictionary, npc_id: String) -> String:
	var person := _person(data,npc_id)
	var name: String = str(Childhood.EXTRA_NPCS.get(npc_id, NPCS.get(npc_id, {})).get("name", npc_id))
	if person.is_empty():
		return "Diese Person ist zurzeit nicht im Dorf."
	if not person.get("alive",false):
		return "%s ist verstorben. Eure gemeinsame Geschichte bleibt in Erinnerung." % name
	return "%s ist mit deinem Wachtrupp im Dienst. Die zivile Arbeit und Ausbildung ruhen." % name


static func _person(data: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
		if str(person.get("id",""))==id:
			return person
	return {}


static func _enemy(raid: Dictionary, id: String) -> Dictionary:
	for enemy: Dictionary in raid.enemies:
		if enemy.id==id:
			return enemy
	return {}


static func _enemy_count(number: int) -> int:
	return mini(6,2+number)


static func _living_enemies(raid: Dictionary) -> int:
	var count := 0
	for enemy: Dictionary in raid.enemies:
		count += 1 if int(enemy.health)>0 else 0
	return count


static func _affords(data: Dictionary, cost: Dictionary) -> bool:
	for good: String in cost:
		if int(data.resources.get(good,0))<int(cost[good]):
			return false
	return true


static func _pay(data: Dictionary, cost: Dictionary) -> void:
	for good: String in cost:
		data.resources[good] = int(data.resources.get(good,0))-int(cost[good])
		data.village.social.ledger[good] -= int(cost[good])


static func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	var names := {"wood":"Holz","grain":"Getreide","denarii":"Denarii","stone":"Stein"}
	for good: String in cost:
		parts.append("%d %s" % [int(cost[good]),names[good]])
	return ", ".join(parts)


static func _gain(data: Dictionary, attribute: String, amount: int) -> void:
	data.village.attributes[attribute] = mini(10000,int(data.village.attributes[attribute])+amount)


static func _event(data: Dictionary, kind: String, text: String) -> void:
	data.village.history.events.append({"seconds":data.village.social.seconds,"kind":kind,"text":text,"provenance":"fictional_playable_event"})
	if data.village.history.events.size()>64:
		data.village.history.events.pop_front()


static func _change(data: Dictionary, id: String, text: String) -> void:
	var history: Dictionary = data.village.history
	history.mode = "fictional_branch"
	if not history.player_changes.has(id):
		history.player_changes.append(id)
		if history.player_changes.size()>128:
			history.player_changes.pop_front()
	_event(data,"player_choice",text)


static func _keys(value: Variant, expected: Array) -> bool:
	if typeof(value)!=TYPE_DICTIONARY or value.size()!=expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value,minimum,maximum) and float(value)==floorf(float(value))


static func _ok(message: String) -> Dictionary:
	return {"ok":true,"message":message}


static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
