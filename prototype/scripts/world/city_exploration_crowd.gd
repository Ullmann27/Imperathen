extends Node3D
## Stream authored city occupants from the optional private model pack.
## Market sellers represented by the active pedestrian system are not duplicated.
const LAYOUT := "res://assets/world/city_crowd_layout.json"
const RenderProfile := preload("res://scripts/rendering/render_profile.gd")
## Streamed figures at crowd density 1.0 (Hoch). Higher profile densities ask
## for more; the authored entries of the layout remain the actual ceiling.
const REFERENCE_CROWD := 12
const RANGE := 100.0
const MERCHANT_IDS := {"foodstall":"CityMerchant01","bakery":"CityMerchant02","clothier":"CityMerchant03","thermopolium":"CityMerchant04"}
var profile := "balanced"
var paused := false
var entries: Array[Dictionary] = []
var active: Dictionary = {}
var _pending_path := ""
var _pending_id := -1
var _wanted: Array[int] = []
var _excluded: Dictionary = {}

func exclude_market_shop(shop: String) -> void:
	if MERCHANT_IDS.has(shop):
		_excluded[MERCHANT_IDS[shop]] = true

func _ready() -> void:
	name = "CityIdleCrowd"
	if not FileAccess.file_exists(LAYOUT):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if not data is Dictionary or data.get("format","")!="imperathen-city-idle-crowd":
		return
	for item: Variant in data.get("entries",[]):
		if item is Dictionary and item.get("position") is Array and item.position.size()==3 and item.has("path") and item.has("id"):
			entries.append(item)

func limit() -> int:
	return roundi(REFERENCE_CROWD * RenderProfile.density(profile, "crowd"))

func point(index: int) -> Vector3:
	var at: Array = entries[index].position
	return Vector3(float(at[0]),float(at[1]),float(at[2]))

func tick(observer: Vector3) -> void:
	var nearby: Array[Dictionary] = []
	for index in entries.size():
		if _excluded.has(entries[index].id):
			continue
		var distance := observer.distance_squared_to(point(index))
		if distance<RANGE*RANGE:
			nearby.append({"index":index,"distance":distance})
	nearby.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
	_wanted.clear()
	for row: Dictionary in nearby.slice(0,limit()):
		_wanted.append(int(row.index))
	for index: int in active.keys():
		if index not in _wanted:
			var old: Node3D = active[index]
			old.hide()
			old.queue_free()
			active.erase(index)
	if not _pending_path.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_pending_path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_pending_path) as PackedScene
			if packed!=null and _pending_id in _wanted and active.size()<limit():
				_spawn(_pending_id,packed)
			_pending_path = ""
		elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			ResourceLoader.load_threaded_get(_pending_path)
			_pending_path = ""
		return
	for index: int in _wanted:
		if active.has(index):
			continue
		var path := str(entries[index].path)
		if "%d" in path:
			path = path % (2 if profile in ["low","balanced"] else 1)
		if ResourceLoader.exists(path,"PackedScene") and ResourceLoader.load_threaded_request(path,"PackedScene",false)==OK:
			_pending_path = path
			_pending_id = index
			return

func _spawn(index: int,packed: PackedScene) -> void:
	var model := packed.instantiate() as Node3D
	if model==null:
		return
	var actor := StaticBody3D.new()
	actor.name = str(entries[index].id)
	actor.collision_layer = 1
	actor.collision_mask = 0
	actor.position = point(index)
	var query := PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*2,actor.position+Vector3.DOWN*2,1)
	var ground := get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty():
		actor.position.y = float(ground.position.y)+0.004
	actor.rotation.y = float(entries[index].get("heading",0.0))
	add_child(actor)
	actor.add_child(model)
	model.rotation.y = PI
	var bounds := AABB()
	var found := false
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:
			continue
		var relative := model.global_transform.affine_inverse()*mesh.global_transform
		var box: AABB = relative*mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	model.position.y = -bounds.position.y
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = clampf(bounds.size.y,1.0,2.2)
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = capsule.height*0.5
	actor.add_child(shape)
	for animator: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false):
		for clip: StringName in animator.get_animation_list():
			if str(clip)=="idle" or str(clip).ends_with("/idle"):
				var animation := animator.get_animation(clip)
				animation.loop_mode = Animation.LOOP_LINEAR
				animator.play(clip)
				animator.seek(fmod(float(index)*0.37,maxf(animation.length,0.01)),true)
				animator.speed_scale = 0.0 if paused else 1.0
				break
	active[index] = actor

func set_paused(value: bool) -> void:
	paused = value
	for index: int in active.keys():
		var actor: Node3D = active[index]
		for animator: AnimationPlayer in actor.find_children("*","AnimationPlayer",true,false):
			animator.speed_scale = 0.0 if paused else 1.0

func _exit_tree() -> void:
	if not _pending_path.is_empty():
		var path := _pending_path
		_pending_path = ""
		ResourceLoader.load_threaded_get(path)
