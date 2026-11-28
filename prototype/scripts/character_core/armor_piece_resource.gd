class_name ArmorPieceResource
extends Resource
## Runtime descriptor of one already catalogued wearable rigid prop.
## No prices, combat stats, age permissions or inventory authority live here.
## Skinned garments and missing socket profiles are not certified by this type.
const Gear = preload("res://scripts/domain/gear_market.gd")
const PLACES: Dictionary = {
	"gladius": ["hand_right", "hip_right", "hip_left", "back"],
	"pugio": ["hip_right", "hip_left", "hand_right", "back"],
	"pilum": ["hand_right", "back"],
	"spear": ["hand_right", "back"],
	"hand_axe": ["hand_right"],
	"sling": ["hip_left", "hip_right", "hand_right"],
	"scutum": ["hand_left", "back"],
	"round_shield": ["hand_left"],
	"cavalry_shield": ["hand_left", "back"],
	"cavalry_lance": ["hand_right", "back"],
	"spatha": ["hand_right", "hip_right", "hip_left", "back"]
}

@export var item_id: String = ""
@export var slot: String = ""
@export var quality: int = 0
@export var lod: int = 0
@export var model_path: String = ""
@export var default_place: String = ""

static func from_catalog(id: String, tier: int, detail: int) -> ArmorPieceResource:
	var entry: Dictionary = Gear.item(id)
	if entry.is_empty() or not PLACES.has(id) or not bool(entry.get("listed", true)):
		return null
	if detail < 0 or detail > 3 or tier < 0 or tier >= Gear.QUALITIES or not tier in Gear.tiers(id):
		return null
	var lods: int = int(entry.get("lods", 0))
	if lods < 1:
		return null
	var resolved_lod: int = mini(detail, lods - 1) if lods > 2 else (0 if detail <= 1 else lods - 1)
	var path: String = Gear.model_path(id, resolved_lod)
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	var descriptor: ArmorPieceResource = ArmorPieceResource.new()
	descriptor.item_id = id
	descriptor.slot = str(entry.slot)
	descriptor.quality = tier
	descriptor.lod = resolved_lod
	descriptor.model_path = path
	descriptor.default_place = str(entry.attach)
	if not descriptor.supports_place(descriptor.default_place):
		return null
	return descriptor

func supports_place(place: String) -> bool:
	return PLACES.has(item_id) and place in PLACES[item_id]
