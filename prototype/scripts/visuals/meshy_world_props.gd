extends RefCounted
## Only already prepared, metric derivatives. Never instantiate an unrigged
## raw source as an actor; gameplay authority and stock counts stay unchanged.
const ROOT := "res://assets/meshy/props/%s_%d.glb"

static func instantiate(stable_id: String, tier: int = 1) -> Node3D:
	for level: int in [clampi(tier,0,2),0,2]:
		var path := ROOT % [stable_id,level]
		if not ResourceLoader.exists(path, "PackedScene"):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var result := packed.instantiate() as Node3D
		if result == null:
			continue
		# These are presentation instances. Original worksite/stock collision
		# remains authoritative; imported convex proxies must not block routes.
		for body: CollisionObject3D in result.find_children("*","CollisionObject3D",true,false):
			body.collision_layer = 0
			body.collision_mask = 0
		if result is CollisionObject3D:
			(result as CollisionObject3D).collision_layer = 0
			(result as CollisionObject3D).collision_mask = 0
		result.set_meta("meshy_asset_id",stable_id)
		return result
	return null
