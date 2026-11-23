extends SceneTree

const Trade = preload("res://scripts/domain/village_trade.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := _fixture()
	_check(Trade.validate(data).is_empty(), "fresh finite market validates")
	var original := JSON.stringify(data)
	Trade.ensure(data)
	_check(JSON.stringify(data) == original, "ensure does not reset an existing market")
	var result := _trade(data, true, "grain", 1)
	_check(result.ok, "buy a real grain unit")
	_check(data.resources.grain == 13 and data.village.trade.stock.grain == 63, "grain changes both actual inventories")
	_check(data.resources.denarii == 1 and data.village.trade.change_asses == 13, "one Denar is changed into exact small coins")
	_check(data.village.trade.merchant_asses == 1923 and data.village.trade.cash_delta_asses == -3, "merchant cash receives exact payment")
	_check(data.village.trade.ledger.denarii == -1 and data.village.trade.ledger.grain == 1, "legacy whole Denar and goods ledger receive the true carry")
	var paid := JSON.stringify(data)
	result = Trade.execute(data, "village_trade_buy", {"resource":"grain", "quantity":1, "quote_revision":0})
	_check(not result.ok and JSON.stringify(data) == paid, "double-tap cannot charge the old quote twice")
	_check(_trade(data, false, "grain", 1).ok, "sell an owned grain unit")
	_check(data.resources.grain == 12 and data.village.trade.stock.grain == 64, "round trip conserves goods")
	_check(_wallet(data) == 30 and data.village.trade.merchant_asses == 1922, "round trip cannot generate money")
	_check(Trade.validate(data).is_empty(), "net small-coin ledger remains valid")
	data = JSON.parse_string(JSON.stringify(data))
	_check(Trade.validate(data).is_empty(), "JSON round trip preserves coin remainders and finite stocks")
	var restored := JSON.stringify(data)
	result = Trade.execute(data, "village_trade_sell", {"resource":"grain", "quantity":1, "quote_revision":1})
	_check(not result.ok and JSON.stringify(data) == restored, "restored save rejects a consumed quote")
	# Other systems still spend whole denarii; remainder is never a second wallet.
	data.resources.denarii -= 1
	_check(_wallet(data) == 14 and Trade.validate(data).is_empty(), "external whole-Denar cost leaves only genuine small change")
	_check(_trade(data, true, "grain", 4).ok and _wallet(data) == 2, "a purchase can be paid entirely from change")
	var unchanged := JSON.stringify(data)
	_check(not _trade(data, true, "grain", 1).ok and JSON.stringify(data) == unchanged, "insufficient change causes no partial transfer")
	_test_availability()
	_test_finite_stocks()
	_test_invalid_inputs()
	_test_view()
	_check(Trade.format_asses(0) == "0 As", "zero denomination")
	_check(Trade.format_asses(4) == "1 Sesterz", "Sesterz is four As")
	_check(Trade.format_asses(16) == "1 Denar", "Denar is sixteen As")
	_check(Trade.format_asses(21) == "1 Denar + 1 Sesterz + 1 As", "mixed denominations conserve their value")
	for failure: String in failures:
		push_error(failure)
	print(JSON.stringify({"suite":"village_trade", "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)


func _test_availability() -> void:
	var data := _fixture()
	data.player.position = [50.0,1.0,50.0]
	_check(not _trade(data, true, "grain", 1).ok, "remote UI cannot buy from Cassia")
	data.player.position = [5.0,1.0,0.0]
	for mutation in ["dead", "militia", "defense", "ill", "hungry", "raid", "night", "disabled"]:
		var candidate: Dictionary = data.duplicate(true)
		match mutation:
			"dead": candidate.village.economy.people[0].alive = false
			"militia": candidate.village.militia = ["cassia"]
			"defense": candidate.village.economy.people[0].assignment = "defense"
			"ill": candidate.village.economy.people[0].health = 39
			"hungry": candidate.village.economy.people[0].hunger = 80
			"raid": candidate.village.raid.active = true
			"night": candidate.village.childhood = {"night_raid":{"phase":"approach", "elapsed":8.0, "seed":17}}
			"disabled": candidate.village.enabled = false
		var before := JSON.stringify(candidate)
		_check(not _trade(candidate, true, "grain", 1).ok and JSON.stringify(candidate) == before, "unavailable merchant: " + mutation)
	data.village.economy.people[0].assignment = "woodcamp"
	_check(not _trade(data, true, "grain", 1).ok, "Cassia is not duplicated at her former home")
	data.player.position = [-44.2,1.0,14.0]
	_check(_trade(data, true, "grain", 1).ok, "trade follows the same real worker position as conversation")


func _test_finite_stocks() -> void:
	var data := _fixture()
	data.resources.denarii = 100
	for amount in [20,20,20,4]:
		_check(_trade(data, true, "grain", amount).ok, "bounded purchase draws from remaining stock")
	_check(data.village.trade.stock.grain == 0 and data.resources.grain == 76, "all grain has a genuine counter-stock")
	var before := JSON.stringify(data)
	_check(not _trade(data, true, "grain", 1).ok and JSON.stringify(data) == before, "empty merchant does not replenish on demand")
	data = _fixture()
	data.resources.stone = 1000
	for _index in 32:
		_check(_trade(data, false, "stone", 20).ok, "finite merchant cash pays real owned stone")
	_check(data.village.trade.merchant_asses == 0, "merchant can actually run out of cash")
	_check(_wallet(data) == 1952 and data.resources.stone == 360, "exhausted merchant preserves exact money and stock")
	before = JSON.stringify(data)
	_check(not _trade(data, false, "stone", 1).ok and JSON.stringify(data) == before, "no payment is created after treasury depletion")
	_check(Trade.validate(data).is_empty(), "cash-exhausted market remains a valid save state")


func _test_invalid_inputs() -> void:
	var data := _fixture()
	for bad: Variant in [-1,0,21,1.5,NAN,INF,"1",true]:
		var before := JSON.stringify(data)
		var response := Trade.execute(data, "village_trade_buy", {"resource":"grain", "quantity":bad, "quote_revision":0})
		_check(not response.ok and JSON.stringify(data) == before, "invalid quantity is atomic: " + str(bad))
	for bad: Variant in [-1,0.5,NAN,"0",false]:
		_check(not Trade.execute(data, "village_trade_buy", {"resource":"grain", "quantity":1, "quote_revision":bad}).ok, "invalid quote: " + str(bad))
	_check(not Trade.execute(data, "village_trade_buy", {"resource":"gold", "quantity":1, "quote_revision":0}).ok, "unknown currency/commodity is not invented")
	_check(not Trade.execute(data, "village_trade_buy", {"resource":"grain", "quantity":1, "quote_revision":0, "price":0}).ok, "client cannot supply a free price")
	for key: String in ["cash", "stock", "ledger", "change", "counts"]:
		var broken: Dictionary = data.duplicate(true)
		match key:
			"cash": broken.village.trade.merchant_asses += 1
			"stock": broken.village.trade.stock.grain += 1
			"ledger": broken.village.trade.ledger.denarii += 1
			"change": broken.village.trade.change_asses = 16
			"counts": broken.village.trade.bought.grain = 1
		_check(not Trade.validate(broken).is_empty(), "corrupt conserved value rejected: " + key)
	data.resources.grain = 0
	_check(not _trade(data, false, "grain", 1).ok, "cannot sell absent goods")
	data.resources.grain = Trade.MAX_RESOURCE
	_check(not _trade(data, true, "grain", 1).ok, "cannot overflow shared goods storage")


func _test_view() -> void:
	var data := _fixture()
	var before := JSON.stringify(data)
	var presentation := Trade.view(data)
	_check(presentation.available and presentation.choices.size() == 6, "six concrete bounded trade choices")
	_check(presentation.text.contains("2 Denare") and presentation.text.contains("16 As"), "wallet and denomination are visible")
	var first: Dictionary = presentation.choices[0]
	_check(Trade.execute(data, first.command, first.args).ok, "UI choice is a real accepted domain command")
	_check(not Trade.execute(data, first.command, first.args).ok, "the same UI choice cannot be paid twice")
	data = _fixture()
	presentation = Trade.view(data)
	presentation.bought.grain = 99
	presentation.goods[0].merchant_quantity = 99
	_check(JSON.stringify(data) == before, "view dictionaries do not mutate authority")


func _fixture() -> Dictionary:
	var data := {
		"resources":{"wood":4, "grain":12, "denarii":2, "stone":5},
		"player":{"position":[5.0,1.0,0.0]},
		"village":{"enabled":true, "militia":[], "raid":{"active":false, "status":"quiet"},
			"economy":{"people":[{"id":"cassia", "alive":true, "health":100, "hunger":0, "assignment":"idle"}]}}
	}
	Trade.ensure(data)
	return data


func _trade(data: Dictionary, buying: bool, resource: String, quantity: int) -> Dictionary:
	return Trade.execute(data, "village_trade_buy" if buying else "village_trade_sell",
		{"resource":resource, "quantity":quantity, "quote_revision":int(data.village.trade.revision)})


func _wallet(data: Dictionary) -> int:
	return int(data.resources.denarii) * 16 + int(data.village.trade.change_asses)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
