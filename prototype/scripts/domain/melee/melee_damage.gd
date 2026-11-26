extends RefCounted
## Level A's only door to damage (D-042, handbook p. 79). Every hit of the
## melee core - blade, fist or missile - is resolved by the shared module
## scripts/battle/combat_formula.gd with assets/balance/combat_balance.json:
##   damage = weapon base x quality x competence x zone x protection x contact
## This file holds no balance value and no arithmetic of its own; it only
## translates a core fighter into the formula's inputs.
##
## Shield position enters through geometry: a strike that meets the shield
## box is a block before this is called, so shield_cover is 0 here. The
## contact factor is the physical impact at the measured contact frame
## (sqrt of the energy relative to the stroke's free-air energy).

const Formula = preload("res://scripts/battle/combat_formula.gd")
const Weapons = preload("res://scripts/domain/melee/weapon_catalog.gd")

## Armour a kit's clothing stands for, as pieces of the balance file. Wool,
## leather and linen have no entry there and therefore stop nothing.
const KIT_ARMOR := {"mail":{"torso":{"family":"lorica_hamata", "quality":2, "wear":0.0}}}
## Material an armour piece presents to a blow (impact sound, particles).
const PIECE_MATERIAL := {"lorica_hamata":"iron", "lorica_segmentata":"iron", "helmet_montefortino":"bronze",
	"helmet_coolus":"bronze", "helmet_imperial_gallic":"iron"}
const CLOTHING_MATERIAL := {"mail":"iron", "wool_leather":"leather", "linen":"cloth", "none":"flesh"}
## Core injury kinds as the balance file names them.
const INJURY := {"concussion":"head_wound"}


static func kit_armor(clothing: String) -> Dictionary:
	return (KIT_ARMOR.get(clothing, {}) as Dictionary).duplicate(true)


## What a blow to `zone` lands on: the armour piece there, else the clothing
## on the trunk and limbs, else skin.
static func surface_material(pieces: Dictionary, clothing: String, zone: String) -> String:
	var piece: Dictionary = pieces.get(zone, {})
	if PIECE_MATERIAL.has(piece.get("family", "")):
		return PIECE_MATERIAL[piece.family]
	if zone == "head":
		return "flesh"
	return str(CLOTHING_MATERIAL.get(clothing, "flesh"))


static func injury_kinds(injuries: Array) -> Array:
	var kinds: Array = []
	for entry: Variant in injuries:
		var kind := str(entry.get("kind", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)
		kinds.append(INJURY.get(kind, kind))
	return kinds


## hit: weapon_id (weapon_catalog), strike_kind, weapon_quality (0-4),
## weapon_wear (0-1), skill (0-100), stamina (0-100), injuries (core
## entries or kinds), zone, defender_skill, armor_pieces {zone:{family,
## quality, wear}}, impact (0.3-1.3 from the contact), ranged, contact_frame.
## Returns {"damage": int, "terms": the formula's factors + raw,
## contact_frame, strike}, "wear": {weapon, shield, armor}} - pure.
static func compute(hit: Dictionary) -> Dictionary:
	var weapon := {"family":Weapons.balance_family(str(hit.get("weapon_id", ""))), "quality":int(hit.get("weapon_quality", 2)),
		"wear":float(hit.get("weapon_wear", 0.0))}
	var kind := str(hit.get("strike_kind", ""))
	# Missiles keep the balance file's own strike kind (arrow).
	if not bool(hit.get("ranged", false)) and not kind.is_empty():
		weapon.strike = kind
	var result := Formula.resolve_hit({"weapon":weapon,
		"attacker":{"skill":float(hit.get("skill", 55.0)), "stamina":float(hit.get("stamina", 100.0)), "injuries":injury_kinds(hit.get("injuries", []))},
		"defender":{"skill":float(hit.get("defender_skill", 55.0)), "armor":hit.get("armor_pieces", {})},
		"zone":str(hit.get("zone", "torso")), "shield_cover":0.0, "ranged":bool(hit.get("ranged", false)),
		"impact":float(hit.get("impact", 1.0))})
	if not bool(result.get("hit", false)):
		return {"damage":0, "terms":{"error":str(result.get("error", result.get("reason", "")))}, "wear":{"weapon":0.0, "shield":0.0, "armor":0.0}}
	var terms: Dictionary = (result.factors as Dictionary).duplicate()
	terms.raw = float(result.damage)
	terms.strike = str(result.strike)
	terms.contact_frame = int(hit.get("contact_frame", -1))
	return {"damage":int(roundf(float(result.damage))), "terms":terms, "wear":result.wear}
