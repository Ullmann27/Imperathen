class_name CityAmbientPeople
extends Node3D
## Presentation-only Roman pedestrians on the existing authored market road.
## Uses real CharacterBody3D motion and two-height wall occlusion. No economic
## WorldModel, free coins, scripted quest success or separate player camera.

const People = preload("res://scripts/visuals/village_person.gd")
const ANCHOR_PATH := "res://assets/city_detail/shops/city_market_anchors.json"
const COUNTS := {"low":0,"balanced":2,"high":4,"very_high":6}
const APPEARANCES := ["civilian_woman","civilian_man","elder","civilian_man","civilian_woman","civilian_man"]
const TARGET_HEIGHTS := [1.63,1.72,1.66,1.78,1.69,1.74]
const WALK_SPEED := [0.94,1.11,1.02,1.20,0.98,1.17]
const WALK_ACCELERATION := 3.2
const TALK_DISTANCE := 1.5
const FOOT_HEIGHT_TOLERANCE := 1.2

var quality_profile := "balanced"
var review_camera: Camera3D
var active := true
var citizens: Array[Dictionary] = []
var _elapsed := 0.0
var _status := "uninitialized"


func setup(city: Node3D, camera: Camera3D, requested_profile: String) -> Dictionary:
	var report := {"ok":false,"status":"unavailable","merchants":0,"visitors":0,
		"transaction_authority":false,"campaign_changed":false,"actors":0}
	if not COUNTS.has(requested_profile):
		report.status = "unknown_profile"
		return report
	if not is_instance_valid(city) or city.name!="RomanCity" or not is_instance_valid(camera):
		report.status = "missing_existing_city_or_camera"
		return report
	if not FileAccess.file_exists(ANCHOR_PATH):
		report.status = "missing_shop_anchor_manifest"
		return report
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANCHOR_PATH))
	if typeof(loaded)!=TYPE_DICTIONARY or str(loaded.get("format",""))!="imperathen-city-market-anchors":
		report.status = "invalid_shop_manifest"
		return report
	if loaded.get("authoritative_commerce_enabled",true)!=false:
		report.status = "unexpected_commerce_contract"
		return report
	if typeof(loaded.get("shops"))!=TYPE_ARRAY or loaded.shops.size()!=6:
		report.status = "invalid_shop_count"
		return report
	quality_profile = requested_profile
	review_camera = camera
	if requested_profile=="low":
		_clear_people()
		_status = "disabled_for_low"
		report.ok = true
		report.status = _status
		return report
	# Use the actual authored stalls; no synthetic stand or housing replacement.
	var anchors: Array[Dictionary] = []
	for row: Variant in loaded.shops:
		if typeof(row)!=TYPE_DICTIONARY or not row.has("stand_node") or not row.has("center_godot_m"):
			report.status = "invalid_shop_record"
			return report
		var stand := city.find_child(str(row.stand_node),true,false) as Node3D
		if not is_instance_valid(stand):
			report.status = "missing_original_shop_stand"
			return report
		var source: Array = row.center_godot_m
		if source.size()!=3:
			report.status = "invalid_shop_coordinate"
			return report
		anchors.append({"shop_id":str(row.shop_id),
			"world":Vector3(float(source[0]),float(source[1]),float(source[2]))})
	anchors.sort_custom(func(left: Dictionary,right: Dictionary)->bool:
		return absf((left.world as Vector3).x) < absf((right.world as Vector3).x))
	_clear_people()
	_elapsed = 0.0
	for index in mini(int(COUNTS[requested_profile]),anchors.size()):
		_add_couple(str(anchors[index].shop_id),anchors[index].world,index)
	_status = "ready"
	report.ok = true
	report.status = _status
	report.merchants = citizens.size()
	report.visitors = citizens.size()
	report.actors = citizens.size()*2
	return report


func _clear_people() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	citizens.clear()


func _person_body(name_in_scene: String, position: Vector3, mobile: bool) -> CollisionObject3D:
	var actor: CollisionObject3D = CharacterBody3D.new() if mobile else StaticBody3D.new()
	actor.name = name_in_scene
	actor.collision_layer = 2
	actor.collision_mask = 1 if mobile else 0
	actor.position = position
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.72
	capsule.radius = 0.26
	collision.name = "PersonalSpace"
	collision.shape = capsule
	collision.position.y = 0.86
	actor.add_child(collision)
	if mobile:
		(actor as CharacterBody3D).floor_snap_length = 0.32
	add_child(actor)
	return actor


func _visual(actor: Node3D, age: int, appearance: String, variant: int, height: float) -> Node3D:
	var figure := People.new()
	figure.name = "Figure"
	figure.profile = quality_profile
	actor.add_child(figure)
	figure.configure_resident("italia",age,appearance,variant,review_camera)
	# The imported figure pivots differ by LOD; fit the displayed authored
	# geometry rather than guessing every adult has identical body height.
	var combined := AABB()
	var found := false
	for mesh: MeshInstance3D in figure.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null:
			continue
		var local_box: AABB = (figure.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		combined = combined.merge(local_box) if found else local_box
		found = true
	if found and combined.size.y > 0.1:
		var factor := height / combined.size.y
		figure.scale = Vector3.ONE*factor
		figure.position.y = -combined.position.y*factor
	return figure


func _add_couple(shop: String, base: Vector3, index: int) -> void:
	var vendor_at := base+Vector3(-0.94,0,5.25)
	var waiting_at := base+Vector3(2.85,0,7.8)
	var speaking_at := base+Vector3(0.28,0,5.30)
	var vendor := _person_body("CityVendor_"+shop,vendor_at,false)
	var customer := _person_body("CityVisitor_"+shop,waiting_at,true)
	var vendor_figure := _visual(vendor,30+index*4,APPEARANCES[index],index*3,TARGET_HEIGHTS[index])
	var visitor_figure := _visual(customer,22+index*5,APPEARANCES[(index+3)%APPEARANCES.size()],index*3+7,TARGET_HEIGHTS[(index+2)%TARGET_HEIGHTS.size()])
	citizens.append({"shop":shop,"vendor":vendor,"customer":customer,
		"vendor_figure":vendor_figure,"visitor_figure":visitor_figure,
		"near":speaking_at,"far":waiting_at,"phase":float(index)*2.3,
		"walking":false,"talking":false,"blocked_seconds":0.0})


func set_active(value: bool) -> void:
	active = value
	if not value:
		for record: Dictionary in citizens:
			var character := record.customer as CharacterBody3D
			character.velocity = Vector3.ZERO
			(record.vendor_figure as Node3D).set_conversation_focus(false)
			(record.visitor_figure as Node3D).set_conversation_focus(false)
			(record.visitor_figure as Node3D).drive(0)
			record.talking = false


func _physics_process(delta: float) -> void:
	if not active or citizens.is_empty():
		return
	_elapsed += delta
	for index in citizens.size():
		var record: Dictionary = citizens[index]
		var character := record.customer as CharacterBody3D
		var vendor := record.vendor as StaticBody3D
		var visitor_figure := record.visitor_figure as Node3D
		var vendor_figure := record.vendor_figure as Node3D
		# Each household has a different phase and realistic slow walking pace.
		# No animation accelerates the body and no route step teleports a citizen.
		var cycle := 17.0+float(index)*1.35
		var phase := fposmod(_elapsed+float(record.phase),cycle)
		var near_interval := phase >= 5.0 and phase < 10.0
		var moving_to_counter := phase < 5.0
		var leaving := phase >= 10.0 and phase < 15.0
		var destination: Vector3 = record.near if moving_to_counter or near_interval else record.far
		var displacement := destination-character.position
		var horizontal := Vector3(displacement.x,0,displacement.z)
		var should_walk := (moving_to_counter or leaving) and horizontal.length() > 0.20
		var planned_speed := WALK_SPEED[index] if should_walk else 0.0
		var wanted := horizontal.normalized()*planned_speed if should_walk else Vector3.ZERO
		character.velocity.x = move_toward(character.velocity.x,wanted.x,delta*WALK_ACCELERATION)
		character.velocity.z = move_toward(character.velocity.z,wanted.z,delta*WALK_ACCELERATION)
		character.velocity.y = -0.25 if character.is_on_floor() else character.velocity.y-19.6*delta
		var before := character.position
		character.move_and_slide()
		var actual := character.get_real_velocity()
		var velocity := Vector3(actual.x,0,actual.z)
		visitor_figure.drive(velocity.length())
		if velocity.length()>0.10:
			var yaw := atan2(-velocity.x,-velocity.z)
			visitor_figure.rotation.y = lerp_angle(visitor_figure.rotation.y,yaw,minf(1.0,delta*3.1))
		var progressed: float = Vector2(character.position.x-before.x,character.position.z-before.z).length()
		if should_walk and progressed < delta*0.04:
			record.blocked_seconds = minf(3.0,float(record.blocked_seconds)+delta)
		else:
			record.blocked_seconds = 0.0
		# Physically obstructed pedestrians stay in place, then retry on their
		# next slow schedule; the code never warps through an obstacle.
		var meets := near_interval and velocity.length()<0.09 and float(record.blocked_seconds)<0.60
		meets = meets and Vector2(character.position.x,character.position.z).distance_to(
			Vector2(vendor.position.x,vendor.position.z)) <= TALK_DISTANCE
		meets = meets and _clear_speech_line(character.global_position,vendor.global_position)
		if meets:
			_turn_towards(visitor_figure,character.position,vendor.position,delta)
			_turn_towards(vendor_figure,vendor.position,character.position,delta)
		if meets != bool(record.talking):
			visitor_figure.set_conversation_focus(meets)
			vendor_figure.set_conversation_focus(meets)
			record.talking = meets
		if not meets:
			vendor_figure.keep_working()


func _turn_towards(figure: Node3D, position: Vector3, target: Vector3, delta: float) -> void:
	var delta_world := target-position
	if Vector2(delta_world.x,delta_world.z).length_squared() > 0.01:
		figure.rotation.y = lerp_angle(figure.rotation.y,atan2(-delta_world.x,-delta_world.z),minf(1.0,delta*2.8))


func _clear_speech_line(first: Vector3, second: Vector3) -> bool:
	if not is_inside_tree() or not first.is_finite() or not second.is_finite():
		return false
	var distance := Vector2(first.x,first.z).distance_to(Vector2(second.x,second.z))
	if distance > TALK_DISTANCE or absf(first.y-second.y)>FOOT_HEIGHT_TOLERANCE:
		return false
	# Buildings are on scenery collision layer 1. Citizen bodies have their
	# own layer and cannot accidentally mask a real wall.
	for height in [0.85,1.45]:
		var offset := Vector3.UP*height
		var query := PhysicsRayQueryParameters3D.create(first+offset,second+offset,1)
		query.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true
