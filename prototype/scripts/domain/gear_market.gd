extends RefCounted
## Equipment shops, owned gear, equipping and the storage chest at home (D-058).
##
## Data: res://assets/shops/gear_catalog.json. WorldModel alone commits these
## commands and saves; every owned piece is proven by a purchase receipt and
## every denarius by the same receipts. A piece carries its family and quality
## 0-4 and feeds the shared combat formula (scripts/battle/combat_formula.gd,
## D-042) through combat_inputs(); nothing here computes damage.
##
## Gates, each tested on its own:
##   era      item_families.json / era_registry.json decide what exists when;
##            items outside their window are not offered at all.
##   age      nobody under 18 buys or wears gear with a combat slot.
##   access   training, service, an owned mount or a held appointment.
##   tier     Q3 needs skill >= 45 or specialist access, Q4 skill >= 65, a
##            proven achievement and specialist access (handbook p. 113 ff.).
##   money    resources.denarii; the merchant treasury must be able to pay out.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const EraRegistry = preload("res://scripts/domain/era_registry.gd")
const CityTrade = preload("res://scripts/city_trade.gd")
const TribalWorld = preload("res://scripts/domain/tribal_world.gd")
const CATALOG_PATH := "res://assets/shops/gear_catalog.json"
const FAMILIES_PATH := "res://assets/troops/item_families.json"
const FORMAT := "imperathen-gear-catalog"
const VERSION := 1
const RANGE := 3.0
const MAX_COUNT := 1000000
const QUALITIES := 5
const SLOTS := ["main_hand", "sidearm", "missile", "shield", "torso", "mount", "mount_gear"]
const HOME := "home"
const COMMAND_FIELDS := {
	"gear_enable": [],
	"gear_buy": ["shop_id", "item_id", "quality"],
	"gear_sell": ["shop_id", "uid"],
	"gear_equip": ["uid"],
	"gear_store": ["uid"],
	"gear_take": ["uid"]
}

static var _catalog: Dictionary = {}
static var _families: Dictionary = {}


# --- Catalog ---------------------------------------------------------------

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) if FileAccess.file_exists(CATALOG_PATH) else null
		var problems := catalog_errors(parsed)
		_catalog = parsed if problems.is_empty() else {"format": FORMAT, "schema": VERSION, "items": {}, "shops": {}, "quality": [], "errors": problems}
	return _catalog


static func families() -> Dictionary:
	if _families.is_empty() and FileAccess.file_exists(FAMILIES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FAMILIES_PATH))
		if parsed is Dictionary and parsed.get("families") is Array:
			for family: Variant in parsed.families:
				if family is Dictionary and family.has("family_id"):
					_families[str(family.family_id)] = family
	return _families


static func reset_cache_for_tests() -> void:
	_catalog = {}
	_families = {}


static func catalog_errors(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary or data.get("format") != FORMAT or int(data.get("schema", 0)) != VERSION:
		errors.append("unknown gear catalog format")
		return errors
	if not data.get("quality") is Array or data.quality.size() != QUALITIES:
		errors.append("five quality tiers are required")
	if not data.get("items") is Dictionary or not data.get("shops") is Dictionary:
		errors.append("items or shops missing")
		return errors
	var known := families()
	for id: String in data.items:
		var item: Dictionary = data.items[id]
		for key: String in ["name", "family", "slot", "class", "skill", "access", "model", "attach"]:
			if not item.has(key):
				errors.append("%s: %s missing" % [id, key])
		if not str(item.get("slot", "")) in SLOTS:
			errors.append("%s: unknown slot" % id)
		if not item.has("era") and not known.has(str(item.get("family", ""))):
			errors.append("%s: family %s has no entry in item_families.json and no own era" % [id, str(item.get("family", ""))])
		var priced := int(item.has("prices")) + int(item.has("q2_price")) + int(item.has("fixed_price"))
		if priced != 1:
			errors.append("%s: exactly one of prices, q2_price or fixed_price is required" % id)
		if item.has("prices") and (not item.prices is Array or item.prices.size() != QUALITIES):
			errors.append("%s: five prices are required" % id)
		if bool(item.get("listed", true)) and str(item.get("model", "")).is_empty():
			errors.append("%s: a listed item needs a model (no text-only goods)" % id)
	for shop_id: String in data.shops:
		var shop: Dictionary = data.shops[shop_id]
		if not shop.get("stock") is Dictionary:
			errors.append("%s: stock missing" % shop_id)
			continue
		for id: String in shop.stock:
			if not data.items.has(id) or not shop.stock[id] is Array or shop.stock[id].size() != QUALITIES:
				errors.append("%s: stock of %s is not a known item with five tiers" % [shop_id, id])
	return errors


static func item(item_id: String) -> Dictionary:
	return catalog().items.get(item_id, {})


static func price(item_id: String, quality: int) -> int:
	var entry := item(item_id)
	if entry.is_empty() or quality < 0 or quality >= QUALITIES:
		return 0
	if entry.has("fixed_price"):
		return int(entry.fixed_price)
	if entry.has("prices"):
		return int(entry.prices[quality])
	return maxi(1, roundi(float(entry.q2_price) * float(catalog().price_ratio_for_supplements[quality])))


static func sell_price(item_id: String, quality: int) -> int:
	return maxi(1, floori(float(price(item_id, quality)) * float(catalog().get("sell_ratio", 0.4))))


static func tiers(item_id: String) -> Array:
	var entry := item(item_id)
	return [int(entry.fixed_quality)] if entry.has("fixed_quality") else [0, 1, 2, 3, 4]


static func model_path(item_id: String, lod: int) -> String:
	var entry := item(item_id)
	if entry.is_empty() or str(entry.model).is_empty():
		return ""
	return "res://assets/meshy/%s/%s_%d.glb" % [entry.model_dir, entry.model, clampi(lod, 0, int(entry.lods) - 1)]


# --- Era -------------------------------------------------------------------

## The day the world has reached: campaign start of the save plus the days the
## world model has already lived through.
static func world_jdn(data: Dictionary) -> int:
	var start_year := int(data.get("village", {}).get("history", {}).get("start_year", Calendar.CAMPAIGN_START.year))
	if not Calendar.is_valid_year(start_year):
		return -1
	var start := Calendar.to_jdn(start_year, int(Calendar.CAMPAIGN_START.month), int(Calendar.CAMPAIGN_START.day))
	return Calendar.add_days(start, TribalWorld.world_calendar_day(data))


static func era_window(item_id: String) -> Dictionary:
	var entry := item(item_id)
	if entry.is_empty():
		return {}
	var span: Variant = entry.get("era", families().get(str(entry.family), null))
	if not span is Dictionary:
		return {}
	return {"valid_from": int(span.valid_from), "valid_to": int(span.valid_to), "attestation": str(span.get("attestation", ""))}


static func era_open(item_id: String, jdn: int, overrides: Dictionary = {}) -> bool:
	var span := era_window(item_id)
	if span.is_empty() or not EraRegistry.asset_available("story", jdn, int(span.valid_from), int(span.valid_to)):
		return false
	var era_id := str(item(item_id).get("era_id", ""))
	return era_id.is_empty() or EraRegistry.available(era_id, jdn, overrides)


# --- Access ----------------------------------------------------------------

## Everything a gate may read, taken from state other systems already prove.
## Appointments have no granting system yet; the list stays empty until the
## career system writes one, so appointment-bound goods stay locked.
static func access_context(data: Dictionary) -> Dictionary:
	var player: Dictionary = data.get("player", {})
	var social: Dictionary = data.get("village", {}).get("social", {})
	var skills: Dictionary = CityTrade.skills(data)
	var allies: Array[String] = []
	var npcs: Variant = social.get("npcs", {})
	if npcs is Dictionary:
		for id: String in npcs:
			if npcs[id] is Dictionary and npcs[id].get("ally", false) == true:
				allies.append(id)
	var achievements: Array[String] = []
	for id: String in ["watch_duty", "village_defense", "frontier_delivery", "valley_victory"]:
		if CityTrade.reward_proven(data, id):
			achievements.append(id)
	return {
		"age": int(player.get("age", 0)), "trained": CityTrade.trained_soldier(data), "service": CityTrade.trained_soldier(data),
		"mount": _owns_slot(data, "mount"), "appointments": [], "allies": allies, "achievements": achievements,
		"profession": str(social.get("profession", "")),
		"skills": {"combat": int(skills.combat), "defense": int(skills.defense), "command": int(skills.command), "riding": 0},
		"jdn": world_jdn(data)
	}


## "" when the rule set is met, otherwise the reason shown to the player.
static func access_reason(rules: Dictionary, context: Dictionary) -> String:
	if int(context.age) < int(rules.get("age_min", 0)):
		return "Erst als Erwachsener (ab %d Jahren)." % int(rules.age_min)
	if rules.get("training", false) and not context.trained:
		return "Setzt die abgeschlossene Waffenausbildung voraus."
	if rules.get("service", false) and not context.service:
		return "Nur für Soldaten im Dienst."
	if rules.get("mount", false) and not context.mount:
		return "Setzt ein eigenes Pferd voraus."
	var needed: Variant = rules.get("appointment", [])
	if needed is Array and not needed.is_empty():
		for id: Variant in needed:
			if context.appointments.has(id):
				return ""
		return "Nur mit Ernennung (%s); ein Rang wird verliehen, nicht gekauft." % ", ".join(PackedStringArray(needed))
	return ""


static func specialist(shop_id: String, context: Dictionary) -> bool:
	var rule: Dictionary = catalog().get("tier_rules", {}).get("specialist_access", {}).get(shop_id, {})
	if rule.has("profession") and context.profession == str(rule.profession):
		return true
	var contact: Variant = rule.get("contact")
	return contact is Dictionary and contact.get("ally", false) and context.allies.has(str(contact.npc))


static func tier_reason(shop_id: String, item_id: String, quality: int, context: Dictionary) -> String:
	if quality < 3:
		return ""
	var rules: Dictionary = catalog().get("tier_rules", {})
	var skill := str(item(item_id).get("skill", "combat"))
	var have := int(context.skills.get(skill, 0))
	var expert := specialist(shop_id, context)
	if quality == 3:
		if have >= int(rules.q3_skill) or expert:
			return ""
		return "Hochwertige Stücke: Können %d/%d oder ein Fürsprecher im Fach." % [have, int(rules.q3_skill)]
	if have < int(rules.q4_skill):
		return "Meisterarbeit: Können %d/%d." % [have, int(rules.q4_skill)]
	var proven := false
	for id: Variant in rules.get("achievements", {}).get(skill, []):
		proven = proven or context.achievements.has(id)
	if not proven:
		return "Meisterarbeit: ein bestätigter Erfolg in diesem Fach fehlt."
	if not expert:
		return "Meisterarbeit gibt der Meister nur auf Fürsprache ab."
	return ""


## The complete reason chain for one offer, in the order a player meets it.
static func offer_reason(shop_id: String, item_id: String, quality: int, context: Dictionary) -> String:
	var shop: Dictionary = catalog().shops.get(shop_id, {})
	var entry := item(item_id)
	if shop.is_empty() or entry.is_empty() or not shop.stock.has(item_id) or not quality in tiers(item_id):
		return "Diese Verkaufsstelle führt diesen Gegenstand nicht."
	if not bool(entry.get("listed", true)) or not era_open(item_id, int(context.jdn)):
		return "Diesen Gegenstand gibt es hier und heute nicht."
	var reason := access_reason(shop.get("access", {}), context)
	if not reason.is_empty():
		return str(shop.get("locked_reason", reason))
	reason = access_reason(entry.access, context)
	if not reason.is_empty():
		return reason
	return tier_reason(shop_id, item_id, quality, context)


# --- State -----------------------------------------------------------------

static func enabled(data: Dictionary) -> bool:
	return typeof(data.get("village")) == TYPE_DICTIONARY and data.village.has("gear")


static func _initial() -> Dictionary:
	var purchases := {}
	var sales := {}
	for shop_id: String in catalog().shops:
		purchases[shop_id] = {}
		sales[shop_id] = {}
		for id: String in catalog().shops[shop_id].stock:
			purchases[shop_id][id] = [0, 0, 0, 0, 0]
			sales[shop_id][id] = [0, 0, 0, 0, 0]
	var equipped := {}
	for slot: String in SLOTS:
		equipped[slot] = 0
	return {"version": VERSION, "serial": 1, "items": [], "equipped": equipped, "purchases": purchases, "sales": sales}


static func validate_arguments(command: String, args: Dictionary) -> String:
	if not COMMAND_FIELDS.has(command) or not _keys(args, COMMAND_FIELDS[command]):
		return "Der Ausrüstungsauftrag enthält fehlende oder unerlaubte Angaben."
	if args.has("shop_id") and (typeof(args.shop_id) != TYPE_STRING or not catalog().shops.has(args.shop_id)):
		return "Diese Verkaufsstelle gibt es nicht."
	if args.has("item_id") and (typeof(args.item_id) != TYPE_STRING or not catalog().items.has(args.item_id)):
		return "Dieser Gegenstand gehört nicht zum Ausrüstungskatalog."
	if args.has("quality") and not _integer(args.quality, 0, QUALITIES - 1):
		return "Die Qualitätsstufe muss zwischen 0 und 4 liegen."
	if args.has("uid") and not _integer(args.uid, 1, MAX_COUNT):
		return "Eine gültige Gegenstandsnummer fehlt."
	return ""


## Called only on WorldModel's private candidate, after complete state validation.
static func apply(data: Dictionary, command: String, args: Dictionary, sites: Dictionary = {}) -> Dictionary:
	var error := validate_arguments(command, args)
	if not error.is_empty():
		return _result(false, error)
	if command == "gear_enable":
		if not bool(data.get("village", {}).get("enabled", false)):
			return _result(false, "Die Ausrüstungsläden gehören zur römischen Dorfwelt.")
		if enabled(data):
			return _result(true, "Die Ausrüstungsläden sind bereits bekannt.")
		if not catalog().get("errors", []).is_empty():
			return _result(false, "Der Ausrüstungskatalog ist fehlerhaft.")
		data.village.gear = _initial()
		return _result(true, "Schmied, Markt, Stall und Ausstatter führen jetzt Buch über deine Ausrüstung.")
	if not enabled(data):
		return _result(false, "Dieser Spielstand verwendet die Ausrüstungsläden noch nicht.")
	error = _ready_reason(data)
	if not error.is_empty():
		return _result(false, error)
	var gear: Dictionary = data.village.gear
	var context := access_context(data)
	match command:
		"gear_buy":
			var shop_id: String = args.shop_id
			var item_id: String = args.item_id
			var quality := int(args.quality)
			error = _site_reason(data, shop_id, sites)
			if error.is_empty():
				error = offer_reason(shop_id, item_id, quality, context)
			if not error.is_empty():
				return _result(false, error)
			if stock(data, shop_id, item_id, quality) <= 0:
				return _result(false, "Dieses Stück ist hier nicht vorrätig.")
			if gear.items.size() >= int(catalog().get("max_owned", 48)):
				return _result(false, "Mehr Ausrüstung kannst du nicht besitzen. Verkaufe oder lagere zuerst.")
			var cost := price(item_id, quality)
			error = _money_reason(data, -cost)
			if not error.is_empty():
				return _result(false, error)
			_transfer_money(data, -cost)
			gear.purchases[shop_id][item_id][quality] = int(gear.purchases[shop_id][item_id][quality]) + 1
			var uid := int(gear.serial)
			gear.serial = uid + 1
			gear.items.append({"uid": uid, "id": item_id, "q": quality, "wear": 0.0, "at": "carried"})
			return _result(true, "%s (%s) gekauft: %d Denare." % [item(item_id).name, quality_name(quality), cost], {"uid": uid})
		"gear_sell":
			var shop_id: String = args.shop_id
			var index := _index(gear, int(args.uid))
			if index < 0:
				return _result(false, "Diesen Gegenstand besitzt du nicht.")
			var piece: Dictionary = gear.items[index]
			error = _site_reason(data, shop_id, sites)
			if not error.is_empty():
				return _result(false, error)
			if not catalog().shops[shop_id].stock.has(piece.id):
				return _result(false, "Diese Verkaufsstelle kauft diesen Gegenstand nicht an.")
			if piece.at != "carried":
				return _result(false, "Hole den Gegenstand zuerst aus der Truhe zu Hause.")
			if gear.equipped.values().has(int(piece.uid)):
				return _result(false, "Lege diesen Gegenstand vor dem Verkauf ab.")
			var gain := sell_price(str(piece.id), int(piece.q))
			error = _money_reason(data, gain)
			if not error.is_empty():
				return _result(false, error)
			_transfer_money(data, gain)
			gear.sales[shop_id][piece.id][int(piece.q)] = int(gear.sales[shop_id][piece.id][int(piece.q)]) + 1
			gear.items.remove_at(index)
			return _result(true, "%s (%s) verkauft: %d Denare." % [item(str(piece.id)).name, quality_name(int(piece.q)), gain])
		"gear_equip":
			var index := _index(gear, int(args.uid))
			if index < 0:
				return _result(false, "Diesen Gegenstand besitzt du nicht.")
			var piece: Dictionary = gear.items[index]
			var entry := item(str(piece.id))
			var slot := str(entry.slot)
			if int(gear.equipped[slot]) == int(piece.uid):
				gear.equipped[slot] = 0
				return _result(true, "%s abgelegt." % entry.name)
			if piece.at != "carried":
				return _result(false, "Der Gegenstand liegt in der Truhe zu Hause.")
			error = wear_reason(str(piece.id), context)
			if not error.is_empty():
				return _result(false, error)
			gear.equipped[slot] = int(piece.uid)
			return _result(true, "%s (%s) angelegt." % [entry.name, quality_name(int(piece.q))])
		"gear_store", "gear_take":
			var index := _index(gear, int(args.uid))
			if index < 0:
				return _result(false, "Diesen Gegenstand besitzt du nicht.")
			var piece: Dictionary = gear.items[index]
			error = _site_reason(data, HOME, sites)
			if not error.is_empty():
				return _result(false, error)
			var storing := command == "gear_store"
			if (piece.at == HOME) == storing:
				return _result(false, "Der Gegenstand liegt bereits dort.")
			if storing:
				if gear.equipped.values().has(int(piece.uid)):
					return _result(false, "Lege diesen Gegenstand zuerst ab.")
				if _count_at(gear, HOME) >= int(catalog().home.storage_slots):
					return _result(false, "Die Truhe zu Hause ist voll.")
			piece.at = HOME if storing else "carried"
			return _result(true, "%s %s." % [item(str(piece.id)).name, "in die Truhe gelegt" if storing else "aus der Truhe genommen"])
	return _result(false, "Unbekannter Ausrüstungsauftrag.")


## Wearing follows the same age and training rules as buying, without the
## shop: an inherited or gifted piece still needs the right to carry it.
static func wear_reason(item_id: String, context: Dictionary) -> String:
	var rules: Dictionary = item(item_id).access.duplicate()
	rules.erase("mount")
	if str(item(item_id).slot) != "mount" and int(context.age) < 18:
		return "Kampfausrüstung gehört zu deinem späteren Erwachsenenweg."
	return access_reason(rules, context)


static func stock(data: Dictionary, shop_id: String, item_id: String, quality: int) -> int:
	var gear: Dictionary = data.village.gear
	return int(catalog().shops[shop_id].stock[item_id][quality]) - int(gear.purchases[shop_id][item_id][quality]) + int(gear.sales[shop_id][item_id][quality])


static func quality_name(quality: int) -> String:
	return "Q%d %s" % [quality, str(catalog().quality[quality].name)]


static func money_effect(data: Dictionary) -> int:
	# Derived contribution to WorldModel's money proof, like CityTrade.money_effect.
	if not enabled(data):
		return 0
	var gear: Dictionary = data.village.gear
	var total := 0
	for shop_id: String in catalog().shops:
		for id: String in catalog().shops[shop_id].stock:
			for quality in QUALITIES:
				total -= int(gear.purchases[shop_id][id][quality]) * price(id, quality)
				total += int(gear.sales[shop_id][id][quality]) * sell_price(id, quality)
	return total


static func validate(data: Dictionary) -> String:
	if not enabled(data):
		return ""
	if not bool(data.village.get("enabled", false)):
		return "Die Ausrüstung gehört zu einer deaktivierten Dorfwelt."
	var record: Variant = data.village.gear
	if not _keys(record, ["version", "serial", "items", "equipped", "purchases", "sales"]):
		return "Der Ausrüstungsbestand ist unvollständig oder unbekannt."
	var gear: Dictionary = record
	if not _integer(gear.version, VERSION, VERSION) or not _integer(gear.serial, 1, MAX_COUNT):
		return "Version oder Zähler der Ausrüstung sind ungültig."
	var shops: Dictionary = catalog().shops
	if not _keys(gear.purchases, shops.keys()) or not _keys(gear.sales, shops.keys()):
		return "Das Ausrüstungsbuch enthält unbekannte Verkaufsstellen."
	var expected := {}
	for shop_id: String in shops:
		var listed: Array = shops[shop_id].stock.keys()
		if not _keys(gear.purchases[shop_id], listed) or not _keys(gear.sales[shop_id], listed):
			return "Ein Ausrüstungseintrag gehört nicht zum Ladensortiment."
		for id: String in listed:
			for book: Dictionary in [gear.purchases, gear.sales]:
				var row: Variant = book[shop_id][id]
				if typeof(row) != TYPE_ARRAY or row.size() != QUALITIES:
					return "Käufe und Verkäufe müssen je Qualitätsstufe gebucht sein."
				for value: Variant in row:
					if not _integer(value, 0, MAX_COUNT):
						return "Käufe und Verkäufe müssen begrenzte ganze Mengen sein."
			for quality in QUALITIES:
				var left := stock(data, shop_id, id, quality)
				if left < 0 or left > MAX_COUNT:
					return "Eine Verkaufsstelle hat mehr Ausrüstung ausgegeben, als sie besitzt."
				var key := "%s:%d" % [id, quality]
				expected[key] = int(expected.get(key, 0)) + int(gear.purchases[shop_id][id][quality]) - int(gear.sales[shop_id][id][quality])
	if typeof(gear.items) != TYPE_ARRAY or gear.items.size() > int(catalog().get("max_owned", 48)):
		return "Die Ausrüstungsliste ist ungültig."
	var seen := {}
	var last := 0
	var stored := 0
	for value: Variant in gear.items:
		if not _keys(value, ["uid", "id", "q", "wear", "at"]):
			return "Ein Ausrüstungsstück ist unvollständig."
		var piece: Dictionary = value
		if not _integer(piece.uid, 1, MAX_COUNT) or int(piece.uid) <= last or int(piece.uid) >= int(gear.serial):
			return "Die Gegenstandsnummern sind nicht eindeutig und aufsteigend."
		last = int(piece.uid)
		if typeof(piece.id) != TYPE_STRING or not catalog().items.has(piece.id) or not _integer(piece.q, 0, QUALITIES - 1) or not int(piece.q) in tiers(piece.id):
			return "Ein Ausrüstungsstück gehört nicht zum Katalog."
		if typeof(piece.wear) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(piece.wear)) or float(piece.wear) < 0.0 or float(piece.wear) > 1.0:
			return "Der Verschleiß eines Stücks ist ungültig."
		if not piece.at in ["carried", HOME]:
			return "Ein Ausrüstungsstück liegt an einem unbekannten Ort."
		stored += int(piece.at == HOME)
		var key := "%s:%d" % [piece.id, int(piece.q)]
		seen[key] = int(seen.get(key, 0)) + 1
	if stored > int(catalog().home.storage_slots):
		return "In der Truhe zu Hause liegt mehr, als hineinpasst."
	for key: String in expected:
		if int(expected[key]) != int(seen.get(key, 0)):
			return "Der Besitz von %s ist nicht durch Kauf und Verkauf belegt." % key
	for key: String in seen:
		if not expected.has(key):
			return "Ein Ausrüstungsstück stammt aus keinem Laden."
	if not _keys(gear.equipped, SLOTS):
		return "Die Ausrüstungsplätze sind unvollständig."
	var context := access_context(data)
	for slot: String in SLOTS:
		var uid: Variant = gear.equipped[slot]
		if not _integer(uid, 0, MAX_COUNT):
			return "Ein Ausrüstungsplatz enthält keine Gegenstandsnummer."
		if int(uid) == 0:
			continue
		var index := _index(gear, int(uid))
		if index < 0 or str(item(str(gear.items[index].id)).slot) != slot or gear.items[index].at != "carried":
			return "Ein angelegter Gegenstand fehlt oder liegt auf dem falschen Platz."
		if not wear_reason(str(gear.items[index].id), context).is_empty():
			return "Ein angelegter Gegenstand ist dieser Person nicht erlaubt."
	return ""


static func restore_integer_fields(data: Dictionary) -> void:
	if not enabled(data):
		return
	var gear: Dictionary = data.village.gear
	gear.version = int(gear.version)
	gear.serial = int(gear.serial)
	for piece: Dictionary in gear.items:
		piece.uid = int(piece.uid)
		piece.q = int(piece.q)
		piece.wear = float(piece.wear)
	for slot: String in gear.equipped:
		gear.equipped[slot] = int(gear.equipped[slot])
	for book: Dictionary in [gear.purchases, gear.sales]:
		for shop: Dictionary in book.values():
			for id: String in shop:
				for quality in shop[id].size():
					shop[id][quality] = int(shop[id][quality])


# --- Read models -----------------------------------------------------------

static func view(data: Dictionary, shop_id := "", sites: Dictionary = {}) -> Dictionary:
	var result := {"enabled": enabled(data), "money": int(data.get("resources", {}).get("denarii", 0)), "shop_id": shop_id,
		"shop_name": "", "shop_reason": "", "offers": [], "inventory": [], "equipped": {}, "home": {"stored": 0, "slots": int(catalog().get("home", {}).get("storage_slots", 0)), "reason": ""}}
	if not enabled(data):
		return result
	var error := validate(data)
	if not error.is_empty():
		result["error"] = error
		return result
	var gear: Dictionary = data.village.gear
	var context := access_context(data)
	var ready := _ready_reason(data)
	var home_reason := _site_reason(data, HOME, sites)
	result.home.stored = _count_at(gear, HOME)
	result.home.reason = home_reason
	result.equipped = gear.equipped.duplicate()
	for piece: Dictionary in gear.items:
		var entry := item(str(piece.id))
		var worn: bool = int(gear.equipped[entry.slot]) == int(piece.uid)
		var wear_block := wear_reason(str(piece.id), context)
		result.inventory.append({"uid": int(piece.uid), "item_id": piece.id, "name": entry.name, "slot": entry.slot,
			"quality": int(piece.q), "quality_name": quality_name(int(piece.q)), "wear": float(piece.wear), "at": piece.at,
			"equipped": worn, "can_equip": ready.is_empty() and piece.at == "carried" and wear_block.is_empty(),
			"equip_reason": wear_block, "sell_price": sell_price(str(piece.id), int(piece.q)),
			"can_store": ready.is_empty() and home_reason.is_empty() and piece.at == "carried" and not worn and _count_at(gear, HOME) < int(catalog().home.storage_slots),
			"can_take": ready.is_empty() and home_reason.is_empty() and piece.at == HOME,
			"model": model_path(str(piece.id), 0)})
	if catalog().shops.has(shop_id):
		var shop: Dictionary = catalog().shops[shop_id]
		result.shop_name = shop.name
		var site_reason := _site_reason(data, shop_id, sites)
		result.shop_reason = site_reason if not site_reason.is_empty() else ready
		for id: String in shop.stock:
			var entry := item(id)
			# Goods outside their era or without a model are not shown at all.
			if not bool(entry.get("listed", true)) or not era_open(id, int(context.jdn)):
				continue
			for quality: int in tiers(id):
				if int(shop.stock[id][quality]) == 0 and int(gear.sales[shop_id][id][quality]) == 0:
					continue
				var reason := offer_reason(shop_id, id, quality, context)
				var left := stock(data, shop_id, id, quality)
				var cost := price(id, quality)
				var affordable := _money_reason(data, -cost)
				result.offers.append({"item_id": id, "name": entry.name, "slot": entry.slot, "quality": quality,
					"quality_name": quality_name(quality), "price": cost, "sell_price": sell_price(id, quality), "stock": left,
					"can_buy": result.shop_reason.is_empty() and reason.is_empty() and left > 0 and affordable.is_empty() and gear.items.size() < int(catalog().get("max_owned", 48)),
					"reason": reason if not reason.is_empty() else (affordable if left > 0 else "Nicht vorrätig."),
					"model": model_path(id, 0), "look": catalog().quality[quality].look, "visible": catalog().quality[quality].visible,
					"design_stats": entry.get("design_stats", {})})
	return result


## What the character visibly carries: one entry per filled slot.
static func equipped_models(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not enabled(data) or not validate(data).is_empty():
		return result
	var gear: Dictionary = data.village.gear
	for slot: String in SLOTS:
		var index := _index(gear, int(gear.equipped[slot]))
		if index < 0:
			continue
		var piece: Dictionary = gear.items[index]
		var entry := item(str(piece.id))
		result.append({"slot": slot, "item_id": piece.id, "quality": int(piece.q), "wear": float(piece.wear),
			"model": entry.model, "model_dir": entry.model_dir, "lods": int(entry.lods), "attach": entry.attach})
	return result


## Inputs of the shared combat formula (D-042): family, quality and wear of
## the carried weapon and shield. Pieces without a combat family are left out.
static func combat_inputs(data: Dictionary) -> Dictionary:
	var result := {"weapon": {}, "missile": {}, "shield": {}, "armor": {}}
	for piece: Dictionary in equipped_models(data):
		var family := str(item(str(piece.item_id)).get("combat_family", ""))
		if family.is_empty():
			continue
		var value := {"family": family, "quality": int(piece.quality), "wear": float(piece.wear)}
		match str(piece.slot):
			"main_hand": result.weapon = value
			"missile": result.missile = value
			"shield": result.shield = value
			"torso": result.armor["torso"] = value
	return result


## Every catalog entry with its era window and model state, for ledgers and QA.
static func registry(jdn: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in catalog().items:
		var entry := item(id)
		var span := era_window(id)
		result.append({"item_id": id, "name": entry.name, "family": entry.family, "valid_from": int(span.get("valid_from", 0)),
			"valid_to": int(span.get("valid_to", 0)), "attestation": str(span.get("attestation", "")),
			"era_open": era_open(id, jdn), "listed": bool(entry.get("listed", true)), "model": entry.model,
			"unlisted_reason": str(entry.get("unlisted_reason", ""))})
	return result


# --- Internals -------------------------------------------------------------

static func _owns_slot(data: Dictionary, slot: String) -> bool:
	if not enabled(data) or typeof(data.village.gear.get("items")) != TYPE_ARRAY:
		return false
	for piece: Variant in data.village.gear.items:
		if piece is Dictionary and catalog().items.has(piece.get("id", "")) and str(item(str(piece.id)).slot) == slot:
			return true
	return false


static func _index(gear: Dictionary, uid: int) -> int:
	if uid <= 0:
		return -1
	for index in gear.items.size():
		if int(gear.items[index].uid) == uid:
			return index
	return -1


static func _count_at(gear: Dictionary, place: String) -> int:
	var count := 0
	for piece: Dictionary in gear.items:
		count += int(piece.at == place)
	return count


static func _ready_reason(data: Dictionary) -> String:
	if int(data.get("player", {}).get("health", 0)) <= 0:
		return "Du kannst gerade keinen Handel treiben."
	if bool(data.get("village", {}).get("raid", {}).get("active", false)) or bool(data.get("encounter", {}).get("active", false)):
		return "Während des Angriffs ruht der Handel."
	return ""


## Shops and the home chest need a real place. Without a supplied anchor the
## place is not connected to this settlement and stays closed.
static func _site_reason(data: Dictionary, place: String, sites: Dictionary) -> String:
	var label := str(catalog().home.name) if place == HOME else str(catalog().shops[place].name)
	if not sites.has(place) or typeof(sites[place]) != TYPE_VECTOR3 or not (sites[place] as Vector3).is_finite():
		return "%s ist an diesem Ort nicht erreichbar." % label
	var at: Array = data.get("player", {}).get("position", [])
	if at.size() != 3 or Vector3(float(at[0]), float(at[1]), float(at[2])).distance_to(sites[place]) > RANGE:
		return "Gehe näher heran: %s." % label
	return ""


static func _money_reason(data: Dictionary, delta: int) -> String:
	var money := int(data.resources.denarii)
	var treasury := int(data.village.economy.stocks.merchant_denarii)
	if money + delta < 0:
		return "Dafür reichen deine Denare nicht."
	if treasury - delta < 0:
		return "Die Händlerkasse kann diesen Betrag gerade nicht auszahlen."
	if money + delta > MAX_COUNT or treasury - delta > MAX_COUNT:
		return "Diese Zahlung würde den zulässigen Geldbestand überschreiten."
	return ""


static func _transfer_money(data: Dictionary, delta: int) -> void:
	data.resources.denarii = int(data.resources.denarii) + delta
	data.village.economy.stocks.merchant_denarii = int(data.village.economy.stocks.merchant_denarii) - delta


static func _keys(value: Variant, expected: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= low and float(value) <= high and float(value) == floorf(float(value))


static func _result(ok: bool, message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": ok, "message": message}
	result.merge(extra)
	return result
