extends Node3D
## Isolated, age-appropriate practice inside the existing Roman city.
## Uses the same authoritative offline combat timing as the Valdora campaign,
## but never reads or writes the campaign's money, quests, health or save.
## There is no NPC damage or adult weapon entitlement in this preview.

const Model = preload("res://scripts/domain/world_model.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
const DUMMY := "res://assets/village/training_dummy.glb"
const PRACTICE_WORLD := Vector3(0.0, 0.0, -7.0)
const TECHNIQUE := "jab_right"
const TARGET_SELECTION_MARGIN := 0.15
var available := false
var model
var dummy: Node3D


func _ready() -> void:
	name = "CityTraining"
	model = Model.new()
	model.new_game("italia", true, true)
	available = Combat.enabled(model.data)
	if ResourceLoader.exists(DUMMY, "PackedScene"):
		var packed := load(DUMMY) as PackedScene
		if packed != null:
			dummy = packed.instantiate() as Node3D
			if dummy != null:
				dummy.name = "OriginalVillageTrainingDummy"
				dummy.position = PRACTICE_WORLD
				add_child(dummy)
	if not is_instance_valid(dummy):
		available = false
		push_warning("The original training dummy model cannot be loaded.")
		return
	var sign := Label3D.new()
	sign.name = "PracticeSign"
	sign.text = "ÜBUNGSPFAHL · UNBEWAFFNET"
	sign.position = PRACTICE_WORLD + Vector3(0, 2.7, 0)
	sign.font_size = 25
	sign.pixel_size = 0.0024
	sign.modulate = Color("ead4a4")
	sign.outline_modulate = Color("18120f")
	sign.visibility_range_end = 12.0
	add_child(sign)


func execute_attack(position: Vector3, yaw: float) -> Dictionary:
	if not available or not position.is_finite() or not is_finite(yaw):
		return {"ok":false,"message":"Der Übungsplatz ist nicht verfügbar."}
	model.set_player_position(position)
	var forward := Vector3.FORWARD.rotated(Vector3.UP,yaw)
	var delta := Vector2(PRACTICE_WORLD.x-position.x,PRACTICE_WORLD.z-position.z)
	# Select only a plausible target. The measured swept strike remains the
	# sole authority for contact, facing, and any awarded training progress.
	var reach := float(Combat.measured(TECHNIQUE).reach) * Combat.strike_scale(model.data, TECHNIQUE)
	var target_id := "practice" if delta.length() <= reach + Combat.PRACTICE_RADIUS + TARGET_SELECTION_MARGIN and delta.length() >= Combat.MIN_CONTACT_DISTANCE else "air"
	var result: Dictionary = Combat.execute(model.data,"village_unarmed_attack",{
		"technique":TECHNIQUE,"target_id":target_id,
		"facing_x":forward.x,"facing_z":forward.z
	})
	return result


func execute_block() -> Dictionary:
	if not available:
		return {"ok":false,"message":"Der Übungsplatz ist nicht verfügbar."}
	return Combat.execute(model.data,"village_unarmed_guard",{})


func tick(delta: float, observed_position: Vector3 = Vector3.INF) -> Dictionary:
	if not available:
		return {}
	# The city player may still be braking during wind-up. Use observed world
	# geometry rather than the stale attack-button position for contact.
	if observed_position.is_finite():
		model.set_player_position(observed_position)
	return Combat.advance(model.data,delta,Callable(self,"_sight_clear"))


func state() -> Dictionary:
	return Combat.view(model.data) if available else {}


func _sight_clear(from: Vector2, to: Vector2) -> bool:
	var origin := Vector3(from.x,1.15,from.y)
	var endpoint := Vector3(to.x,1.15,to.y)
	if origin.distance_squared_to(endpoint)<0.0001:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin,endpoint,1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
