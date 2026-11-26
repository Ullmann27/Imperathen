extends RefCounted
## Reconstructed adult practice contracts for the existing valley battle. The
## scenario id is the receipt. Its named candidates and depot cannot be used
## to issue supplies into the campaign.
const Catalog := preload("res://scripts/battle/troop_catalog.gd")
const PREFIX := "muster_58bc"
const DEPOT := {"denarii": 30, "grain": 12, "horses": 4, "fodder": 4}
const OFFERS := {
	"aux_eques_gallicus": {"count": 4, "title": "Haeduische Reiter", "origin": "aeduian_allies",
		"at": Vector2(-15, 13), "shape": "loose", "cost": {"denarii": 20, "grain": 4, "horses": 4, "fodder": 4}},
	"cisalpine_militia_spear": {"count": 5, "title": "Ortswehr", "origin": "valdora_district",
		"at": Vector2(13, 13), "shape": "line", "cost": {"denarii": 10, "grain": 5}},
	"aux_sagittarius_creticus": {"count": 4, "title": "Kretische Freiwillige", "origin": "creta",
		"at": Vector2(7, 17), "shape": "loose", "cost": {"denarii": 12, "grain": 4}},
}


static func remaining(contracts: Array) -> Dictionary:
	var stock := DEPOT.duplicate()
	for troop_id: String in contracts:
		for commodity: String in OFFERS[troop_id].cost:
			stock[commodity] -= int(OFFERS[troop_id].cost[commodity])
	return stock


static func scenario(base: Dictionary, contracts: Array) -> Dictionary:
	var accepted := []
	var companies: Array = base.companies.duplicate(true)
	var catalog := Catalog.load_default()
	for troop_id: String in OFFERS:
		if not contracts.has(troop_id):
			continue
		var troop := Catalog.troop(catalog, troop_id)
		if troop.is_empty() or not Catalog.valid_at(troop, int(base.year)) or troop.get("battle_kind", "").is_empty():
			return {}
		var offer: Dictionary = OFFERS[troop_id]
		var company := {"id": "muster_" + troop_id, "title": offer.title, "side": "ally",
			"kind": troop.battle_kind, "shape": offer.shape, "at": offer.at, "count": offer.count,
			"troop_id": troop_id, "origin": offer.origin, "commandable_by": ["legatus_valdora"]}
		companies.append(company)
		accepted.append(troop_id)
	if accepted.size() != contracts.size():
		return {}
	for count: int in remaining(accepted).values():
		if count < 0:
			return {}
	var plan := base.duplicate()
	plan.id = PREFIX if accepted.is_empty() else PREFIX + "+" + "+".join(accepted)
	plan.contracts = accepted
	plan.companies = companies
	return plan


static func restore_plan(base: Dictionary, key: String) -> Dictionary:
	var parts := key.split("+")
	if parts[0] != PREFIX or parts.size() > OFFERS.size() + 1:
		return {}
	var plan := scenario(base, Array(parts.slice(1)))
	return plan if plan.get("id", "") == key else {}
