extends RefCounted
## Finite local trade. Shared whole denarii and a saved As remainder form one wallet.
## Prices are game balance, not reconstructed ancient prices. No floating money.

const Life = preload("res://scripts/story/village_life.gd")
const VERSION := 1
const AS_PER_DENARIUS := 16
const AS_PER_SESTERTIUS := 4
const MAX_RESOURCE := 1000000
const MAX_COUNTER := 1000000000
const MAX_CASH := MAX_RESOURCE * AS_PER_DENARIUS + 15
const RANGE := 3.2
const INITIAL_MERCHANT_ASSES := 1920
const INITIAL_STOCK := {"grain":64, "wood":48, "stone":24}
const GOODS := {
	"grain":{"name":"Getreide", "buy_asses":3, "sell_asses":1},
	"wood":{"name":"Holz", "buy_asses":4, "sell_asses":2},
	"stone":{"name":"Stein", "buy_asses":6, "sell_asses":3}
}
const LEDGER_KEYS := ["wood", "grain", "denarii", "stone"]
const COMMAND_FIELDS := {
	"village_trade_buy":["resource", "quantity", "quote_revision"],
	"village_trade_sell":["resource", "quantity", "quote_revision"]
}


static func initial_state() -> Dictionary:
	return {
		"version":VERSION, "change_asses":0,
		"merchant_asses":INITIAL_MERCHANT_ASSES,
		"stock":INITIAL_STOCK.duplicate(),
		"ledger":{"wood":0, "grain":0, "denarii":0, "stone":0},
		"cash_delta_asses":0, "revision":0,
		"bought":{"grain":0, "wood":0, "stone":0},
		"sold":{"grain":0, "wood":0, "stone":0}
	}


static func ensure(data: Dictionary) -> void:
	if not data.has("village"):
		data.village = {}
	if typeof(data.village) == TYPE_DICTIONARY and not data.village.has("trade"):
		data.village.trade = initial_state()


static func execute(data: Dictionary, command: String, args: Dictionary = {}) -> Dictionary:
	if not COMMAND_FIELDS.has(command) or not _keys(args, COMMAND_FIELDS[command]):
		return _fail("Der Handelsauftrag enthält fehlende oder unerlaubte Angaben.")
	if typeof(args.resource) != TYPE_STRING or not GOODS.has(args.resource):
		return _fail("Diese Ware wird auf dem Dorfmarkt nicht gehandelt.")
	if not _integer(args.quantity, 1, 20) or not _integer(args.quote_revision, 0, MAX_COUNTER):
		return _fail("Handelsmenge oder Angebotskennung ist ungültig.")
	var error := validate(data)
	if not error.is_empty():
		return _fail("Ungültiger Handelsbestand: " + error)
	var reason := availability_reason(data)
	if not reason.is_empty():
		return _fail(reason)
	var trade: Dictionary = data.village.trade
	if int(args.quote_revision) != int(trade.revision):
		return _fail("Dieses Angebot wurde bereits verwendet. Prüfe Cassias aktuellen Bestand.")
	if int(trade.revision) >= MAX_COUNTER:
		return _fail("Das Handelsbuch kann keinen weiteren Vorgang aufnehmen.")
	var resource: String = args.resource
	var quantity := int(args.quantity)
	var buying := command == "village_trade_buy"
	var price := int(GOODS[resource].buy_asses if buying else GOODS[resource].sell_asses) * quantity
	var wallet := int(data.resources.denarii) * AS_PER_DENARIUS + int(trade.change_asses)
	if buying:
		if int(trade.stock[resource]) < quantity:
			return _fail("Cassia hat davon nicht mehr genug vorrätig.")
		if wallet < price:
			return _fail("Dafür fehlen Münzen. Der Preis ist %s." % format_asses(price))
		if int(data.resources[resource]) > MAX_RESOURCE - quantity or int(trade.merchant_asses) > MAX_CASH - price:
			return _fail("Für diesen Kauf fehlt Platz im Waren- oder Münzbestand.")
	else:
		if int(data.resources[resource]) < quantity:
			return _fail("Du kannst nur tatsächlich vorhandene Ware verkaufen.")
		if int(trade.merchant_asses) < price:
			return _fail("Cassias Kasse reicht für diesen Ankauf nicht aus.")
		if wallet > MAX_CASH - price or int(trade.stock[resource]) > MAX_RESOURCE - quantity:
			return _fail("Für diesen Verkauf fehlt Platz im Waren- oder Münzbestand.")
	# Copy only the mutable owned branches. Positions, people and story stay observed.
	var candidate := data.duplicate(false)
	candidate.resources = data.resources.duplicate(true)
	candidate.village = data.village.duplicate(false)
	candidate.village.trade = trade.duplicate(true)
	var account: Dictionary = candidate.village.trade
	var goods_delta := quantity if buying else -quantity
	var money_delta := -price if buying else price
	var next_wallet := wallet + money_delta
	var previous_denarii := int(candidate.resources.denarii)
	candidate.resources.denarii = floori(float(next_wallet) / float(AS_PER_DENARIUS))
	account.change_asses = next_wallet % AS_PER_DENARIUS
	account.ledger.denarii = int(account.ledger.denarii) + int(candidate.resources.denarii) - previous_denarii
	account.cash_delta_asses = int(account.cash_delta_asses) + money_delta
	account.merchant_asses = int(account.merchant_asses) - money_delta
	candidate.resources[resource] = int(candidate.resources[resource]) + goods_delta
	account.stock[resource] = int(account.stock[resource]) - goods_delta
	account.ledger[resource] = int(account.ledger[resource]) + goods_delta
	var counter: Dictionary = account.bought if buying else account.sold
	counter[resource] = int(counter[resource]) + quantity
	account.revision = int(account.revision) + 1
	error = validate(candidate)
	if not error.is_empty():
		return _fail("Der Handel wurde vollständig verworfen: " + error)
	data.resources = candidate.resources
	data.village.trade = account
	return {"ok":true, "message":"%d %s %s; %s %s." % [
		quantity, GOODS[resource].name, "gekauft" if buying else "verkauft",
		format_asses(price), "bezahlt" if buying else "erhalten"]}


static func availability_reason(data: Dictionary) -> String:
	var village: Variant = data.get("village", {})
	if typeof(village) != TYPE_DICTIONARY or village.get("enabled", false) != true:
		return "Dieser Dorfmarkt gehört zum römischen Dorfabschnitt."
	var raid: Variant = village.get("raid", {})
	if typeof(raid) == TYPE_DICTIONARY and (raid.get("active", false) == true or raid.get("status", "quiet") == "warning"):
		return "Während der Gefahr bringt Cassia die Waren in Sicherheit."
	var childhood: Variant = village.get("childhood", {})
	if typeof(childhood) == TYPE_DICTIONARY:
		var night: Variant = childhood.get("night_raid", {})
		if typeof(night) == TYPE_DICTIONARY and night.get("phase", "dormant") in ["approach", "attack"]:
			return "Cassia schließt den Markt während des nächtlichen Überfalls."
	var economy: Variant = village.get("economy", {})
	if typeof(economy) != TYPE_DICTIONARY or typeof(economy.get("people")) != TYPE_ARRAY:
		return "Cassias tatsächlicher Aufenthaltsort ist nicht verfügbar."
	var merchant: Dictionary = {}
	for person: Variant in economy.people:
		if typeof(person) == TYPE_DICTIONARY and person.get("id", "") == "cassia":
			merchant = person
			break
	var militia: Variant = village.get("militia", [])
	if merchant.is_empty() or merchant.get("alive", false) != true or (typeof(militia) == TYPE_ARRAY and militia.has("cassia")):
		return "Cassia ist gerade nicht als Händlerin im Dorf verfügbar."
	if not _integer(merchant.get("health"), 40, 100) or not _integer(merchant.get("hunger"), 0, 79) or str(merchant.get("assignment", "idle")) == "defense":
		return "Cassia kann derzeit keinen Handel führen."
	var player: Variant = data.get("player", {})
	if typeof(player) != TYPE_DICTIONARY or typeof(player.get("position")) != TYPE_ARRAY or player.position.size() != 3:
		return "Dein tatsächlicher Standort fehlt."
	for value: Variant in player.position:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return "Dein tatsächlicher Standort ist ungültig."
	var actual := Vector2(float(player.position[0]), float(player.position[2]))
	if actual.distance_to(Life.actor_position(data, "cassia")) > RANGE:
		return "Geh zu Cassia, um ihre Waren und Münzen persönlich zu tauschen."
	return ""


static func view(data: Dictionary) -> Dictionary:
	var error := validate(data)
	if not error.is_empty():
		return {"available":false, "reason":"Der Handelsbestand ist ungültig.", "goods":[], "text":"Der Handelsbestand ist ungültig.", "choices":[]}
	var trade: Dictionary = data.village.trade
	var reason := availability_reason(data)
	var wallet := int(data.resources.denarii) * AS_PER_DENARIUS + int(trade.change_asses)
	var items: Array[Dictionary] = []
	var choices: Array[Dictionary] = []
	var text_lines: PackedStringArray = ["Dein Geld: %s" % format_asses(wallet), "Cassias Kasse: %s" % format_asses(int(trade.merchant_asses))]
	if not reason.is_empty():
		text_lines.append(reason)
	for resource: String in GOODS:
		var good: Dictionary = GOODS[resource]
		var item := {"id":resource, "name":good.name,
			"player_quantity":int(data.resources[resource]), "merchant_quantity":int(trade.stock[resource]),
			"buy_asses":int(good.buy_asses), "sell_asses":int(good.sell_asses),
			"buy_text":format_asses(int(good.buy_asses)), "sell_text":format_asses(int(good.sell_asses)),
			"can_buy":reason.is_empty() and int(trade.stock[resource]) > 0 and wallet >= int(good.buy_asses) and int(data.resources[resource]) < MAX_RESOURCE and int(trade.merchant_asses) <= MAX_CASH - int(good.buy_asses),
			"can_sell":reason.is_empty() and int(data.resources[resource]) > 0 and int(trade.merchant_asses) >= int(good.sell_asses) and wallet <= MAX_CASH - int(good.sell_asses) and int(trade.stock[resource]) < MAX_RESOURCE}
		items.append(item)
		text_lines.append("%s: bei dir %d · bei Cassia %d" % [good.name, item.player_quantity, item.merchant_quantity])
		for buying: bool in [true, false]:
			var enabled: bool = item.can_buy if buying else item.can_sell
			var item_reason := reason
			if item_reason.is_empty() and not enabled:
				item_reason = "Ware, Geld oder Platz im Bestand reichen für diesen Handel nicht aus."
			choices.append({"id":("buy_" if buying else "sell_") + resource,
				"label":"1 %s %s · %s" % [good.name, "kaufen" if buying else "verkaufen", item.buy_text if buying else item.sell_text],
				"command":"village_trade_buy" if buying else "village_trade_sell",
				"args":{"resource":resource, "quantity":1, "quote_revision":int(trade.revision)},
				"enabled":enabled, "reason":item_reason})
	text_lines.append("1 Denar = 4 Sesterzen = 16 As.")
	return {"available":reason.is_empty(), "reason":reason, "goods":items,
		"text":"\n".join(text_lines), "choices":choices,
		"wallet_asses":wallet, "wallet_text":format_asses(wallet),
		"merchant_asses":int(trade.merchant_asses), "merchant_text":format_asses(int(trade.merchant_asses)),
		"quote_revision":int(trade.revision), "transactions":int(trade.revision),
		"bought":trade.bought.duplicate(true), "sold":trade.sold.duplicate(true),
		"currency_note":"1 Denar = 4 Sesterzen = 16 As. Die Warenpreise sind Spielbalance."}


static func format_asses(amount: int) -> String:
	if amount <= 0:
		return "0 As"
	var pieces: PackedStringArray = []
	var denarii := floori(float(amount) / float(AS_PER_DENARIUS))
	var remainder := amount % AS_PER_DENARIUS
	var sestertii := floori(float(remainder) / float(AS_PER_SESTERTIUS))
	var asses := remainder % AS_PER_SESTERTIUS
	if denarii > 0:
		pieces.append("%d %s" % [denarii, "Denar" if denarii == 1 else "Denare"])
	if sestertii > 0:
		pieces.append("%d %s" % [sestertii, "Sesterz" if sestertii == 1 else "Sesterzen"])
	if asses > 0:
		pieces.append("%d As" % asses)
	return " + ".join(pieces)


static func validate(data: Dictionary) -> String:
	if typeof(data.get("resources")) != TYPE_DICTIONARY or typeof(data.get("village")) != TYPE_DICTIONARY:
		return "Waren- oder Dorfzustand fehlt."
	if typeof(data.village.get("trade")) != TYPE_DICTIONARY:
		return "Handelsbuch fehlt."
	var trade: Dictionary = data.village.trade
	if not _keys(trade, ["version", "change_asses", "merchant_asses", "stock", "ledger", "cash_delta_asses", "revision", "bought", "sold"]) or not _integer(trade.version, VERSION, VERSION):
		return "Ungültiges Handelsformat."
	if not _integer(trade.change_asses, 0, 15) or not _integer(trade.merchant_asses, 0, MAX_CASH) or not _integer(trade.cash_delta_asses, -MAX_CASH, MAX_CASH) or not _integer(trade.revision, 0, MAX_COUNTER):
		return "Ungültiger Münz- oder Angebotsstand."
	if not _keys(trade.stock, GOODS.keys()) or not _keys(trade.bought, GOODS.keys()) or not _keys(trade.sold, GOODS.keys()) or not _keys(trade.ledger, LEDGER_KEYS):
		return "Unvollständige Warenbilanz."
	for resource: String in LEDGER_KEYS:
		if not _integer(data.resources.get(resource), 0, MAX_RESOURCE) or not _integer(trade.ledger[resource], -MAX_COUNTER, MAX_COUNTER):
			return "Ungültiger tatsächlicher Warenbestand."
	var expected_cash := 0
	var total_units := 0
	for resource: String in GOODS:
		if not _integer(trade.stock[resource], 0, MAX_RESOURCE) or not _integer(trade.bought[resource], 0, MAX_COUNTER) or not _integer(trade.sold[resource], 0, MAX_COUNTER):
			return "Ungültige Handelsmenge."
		if int(trade.stock[resource]) + int(trade.ledger[resource]) != int(INITIAL_STOCK[resource]):
			return "Ware wurde ohne Gegenbestand erzeugt oder entfernt."
		if int(trade.ledger[resource]) != int(trade.bought[resource]) - int(trade.sold[resource]):
			return "Kauf- und Verkaufsbeleg widersprechen dem Bestand."
		expected_cash += int(trade.sold[resource]) * int(GOODS[resource].sell_asses) - int(trade.bought[resource]) * int(GOODS[resource].buy_asses)
		total_units += int(trade.bought[resource]) + int(trade.sold[resource])
	if expected_cash != int(trade.cash_delta_asses) or int(trade.merchant_asses) + expected_cash != INITIAL_MERCHANT_ASSES:
		return "Spieler- und Händlerkasse widersprechen dem Handelsbeleg."
	if int(trade.ledger.denarii) * AS_PER_DENARIUS + int(trade.change_asses) != expected_cash:
		return "Denare und Kleingeld passen nicht zur gemeinsamen Geldbilanz."
	if (int(trade.revision) == 0) != (total_units == 0) or int(trade.revision) > total_units or total_units > int(trade.revision) * 20:
		return "Angebotsfolge und Handelsmengen widersprechen einander."
	return ""


static func _keys(value: Variant, expected: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= float(minimum) and float(value) <= float(maximum)


static func _fail(message: String) -> Dictionary:
	return {"ok":false, "message":message}
