extends Node3D
## The original stand supplies roof, counter and collision. Only the six
## loaves on these display boards are samples from the bakery's real stock.
const KIT := preload("res://assets/city/bakery/market_bakery.glb")
const STAND := "Market_31_Type2_Build1_Size1"
var _shown := -1
var loaves: Array[MeshInstance3D] = []

func install(city: Node3D) -> bool:
	var stand := city.find_child(STAND, true, false) as MeshInstance3D
	if stand == null or not stand.mesh is ArrayMesh:
		return false
	var surface := -1
	for index in stand.mesh.get_surface_count():
		var mat := stand.mesh.surface_get_material(index)
		if mat != null and mat.resource_name == "Ochre_Plaster":
			surface = index
			break
	if surface < 0:
		return false
	var dressing := KIT.instantiate() as Node3D
	for index in 6:
		var loaf := dressing.find_child("Panis_%02d" % index, true, false) as MeshInstance3D
		if loaf == null:
			loaves.clear()
			dressing.free()
			return false
		loaves.append(loaf)
	# The ochre surface consists exclusively of the old twelve cylinders.
	# Keep the shared market prototype intact for every other stand.
	var counter := stand.mesh.duplicate() as ArrayMesh
	counter.surface_remove(surface)
	stand.mesh = counter
	stand.add_child(self)
	add_child(dressing)
	return true

func set_stock(count: int) -> void:
	var available := clampi(count, 0, loaves.size())
	if available != _shown:
		_shown = available
		for index in loaves.size():
			loaves[index].visible = index < available
