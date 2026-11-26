extends RefCounted
## Items purchased at the existing shops can travel in a person's pack.
## Kept and eaten units both still count in the market's acquisition ledger.
const FOOD := ["bread","cheese","dried_figs","olives"]
const ITEMS := ["water"] + FOOD

static func packed(member: Dictionary, item: String) -> int:
	var ledger: Dictionary = member.get("provisions",{}).get(item,{})
	return int(ledger.get("issued",0)) - int(ledger.get("consumed",0))

static func food(member: Dictionary) -> int:
	var count := 0
	for item: String in FOOD:
		count += packed(member,item)
	return count

static func load_count(member: Dictionary) -> int:
	return int(member.rations) + food(member) + packed(member,"water")

static func give(trade: Dictionary, member: Dictionary, item: String, quantity: int, capacity: int) -> Dictionary:
	if item not in ITEMS or load_count(member)+quantity > capacity or int(trade.get("inventory",{}).get(item,0)) < quantity:
		return {"ok":false,"message":"Dafür fehlen gekaufte Vorräte oder freier Trageplatz."}
	if not member.has("provisions"):
		member.provisions = {}
	if not member.provisions.has(item):
		member.provisions[item] = {"issued":0,"consumed":0}
	trade.inventory[item] -= quantity
	member.provisions[item].issued += quantity
	return {"ok":true,"message":"Der Reisevorrat liegt jetzt im persönlichen Gepäck."}

static func consume(member: Dictionary, items: Array, needed: int) -> int:
	var total := 0
	for item: String in items:
		var amount := mini(needed-total,packed(member,item))
		if amount > 0:
			member.provisions[item].consumed += amount
			total += amount
		if total == needed:
			break
	return total

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.is_empty():
		return false
	for item: Variant in value:
		var lot: Variant = value[item]
		if item not in ITEMS or not lot is Dictionary or lot.size() != 2 or not lot.has_all(["issued","consumed"]):
			return false
		for key in ["issued","consumed"]:
			var amount: Variant = lot[key]
			if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(amount)) or floorf(amount) != amount or amount < 0 or amount > 1000000000:
				return false
		if lot.issued < 1 or lot.consumed > lot.issued:
			return false
	return true
