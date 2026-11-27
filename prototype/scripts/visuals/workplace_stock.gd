extends RefCounted
## Exact imported stock models, never substitute inventory or production.
## The number of visible piles follows the existing resource ledger. Their
## authored dimensions and material textures stay intact.
const Props := preload("res://scripts/visuals/meshy_world_props.gd")
const FULL := {"forest":240,"rock":180,"harvest":240}
const TYPES := {"woodcamp":"forest","quarry":"rock","farm":"harvest"}

static func pile_count(quantity: int, capacity: int, slots: int = 3) -> int:
	if quantity <= 0 or capacity <= 0 or slots <= 0:
		return 0
	return clampi(ceili(float(quantity)/float(capacity)*slots),1,slots)

static func build(parent: Node3D, workplace: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if not TYPES.has(workplace):
		return result
	var imported_id := {"woodcamp":"resource_firewood","quarry":"resource_limestone"}.get(workplace,"") as String
	for index: int in 3:
		var model: Node3D
		if not imported_id.is_empty():
			model = Props.instantiate(imported_id,1)
		elif workplace == "farm":
			var packed := load("res://assets/world/waystation/grain_load.glb") as PackedScene
			if packed != null:
				model = packed.instantiate() as Node3D
		if model == null:
			continue
		model.name = "StockPile%d" % index
		model.position = Vector3(-1.45 + float(index)*1.45,0,-0.80)
		model.scale = Vector3.ONE * (0.68 if workplace == "quarry" else 0.60 if workplace == "woodcamp" else 0.55)
		for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
			body.collision_layer = 0
			body.collision_mask = 0
		if model is CollisionObject3D:
			(model as CollisionObject3D).collision_layer = 0
			(model as CollisionObject3D).collision_mask = 0
		parent.add_child(model)
		result.append(model)
	return result

static func sync(piles: Array, workplace: String, stocks: Dictionary) -> void:
	if not TYPES.has(workplace):
		return
	var key := str(TYPES[workplace])
	var count := pile_count(int(stocks.get(key,0)),int(FULL[key]),piles.size())
	for index: int in piles.size():
		if is_instance_valid(piles[index]):
			(piles[index] as Node3D).visible = index < count
