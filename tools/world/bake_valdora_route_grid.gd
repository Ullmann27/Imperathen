extends SceneTree
## Bake the actual village's static obstructions on the walker's layer.
## Run Godot with --path prototype --script ../tools/world/bake_valdora_route_grid.gd.
const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const OUTPUT := "res://assets/world/waystation/valdora_walk_grid.json"

func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var model := Model.new()
	model.new_game("italia", true, true, false, true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_physics_process(false)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.26
	capsule.radius = 0.28
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	# Civilian feet and furniture have separate bodies. Ignore temporary actors
	# and attached gear, include the walls, props, fences and all thresholds.
	var excluded: Array[RID] = []
	for body: CharacterBody3D in world.find_children("*","CharacterBody3D",true,false):
		excluded.append(body.get_rid())
	query.exclude = excluded
	var rows := []
	var blocked := 0
	for z in 197:
		var row := ""
		for x in 237:
			var at := Vector2(-59+x*0.5,-57+z*0.5)
			query.transform = Transform3D(Basis.IDENTITY,Vector3(at.x,1.10,at.y))
			var obstructed := not space.intersect_shape(query,1).is_empty()
			row += "#" if obstructed else "."
			blocked += int(obstructed)
		rows.append(row)
	blocked += _close_isolated_cells(rows)
	var file := FileAccess.open(OUTPUT,FileAccess.WRITE)
	if file == null or blocked < 100 or blocked > 30000:
		printerr("No valid walk grid")
		quit(1)
		return
	file.store_string(JSON.stringify({"origin":[-59,-57],"cell":0.5,"rows":rows},"\t")+"\n")
	file.close()
	print("VALDORA_ROUTE_GRID samples=",237*197," blocked=",blocked)
	world.queue_free()
	await process_frame
	quit()

## Empty samples inside closed furniture are solid for route guidance. Retain
## the outdoor component and the interiors actually connected by a doorway.
func _close_isolated_cells(rows: Array) -> int:
	var width := str(rows[0]).length()
	var height := rows.size()
	var reached := PackedByteArray()
	reached.resize(width * height)
	var stack: Array[Vector2i] = [Vector2i(118,120)] # 0,3: central village street
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
			continue
		var index := point.y * width + point.x
		if reached[index] or str(rows[point.y]).unicode_at(point.x) != 46:
			continue
		reached[index] = 1
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			stack.append(point + step)
	var blocked := 0
	for z in height:
		var masked := ""
		for x in width:
			var walkable := bool(reached[z * width + x])
			blocked += int(not walkable and str(rows[z]).unicode_at(x) == 46)
			masked += "." if walkable else "#"
		rows[z] = masked
	return blocked
