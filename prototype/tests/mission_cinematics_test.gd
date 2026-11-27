extends SceneTree
const Model = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Cinematics = preload("res://scripts/story/mission_cinematics.gd")
const Director = preload("res://scripts/cinematic/opening_director.gd")
const Direction := preload("res://scripts/story/campaign_direction.gd")

func _initialize() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var previous: Dictionary = {}
	var following: Dictionary = {}
	for step: Dictionary in Childhood.STEPS:
		if step.id=="deliver_kindling":
			previous=step
		elif step.id=="apprentice_permission":
			following=step
	var before := JSON.stringify(model.data)
	var scene := Cinematics.sequence_for(model.data,previous,following)
	var checks: bool = not scene.is_empty() and str(scene.get("id",""))=="mission_transition_deliver_kindling"
	if checks:
		checks = scene.beats.size()>=2 and scene.beats[0].actor_id=="sextus" and scene.beats[0].shot_id=="mission_reaction" and scene.beats[0].get("silent",false)
		checks = checks and scene.objective_text==following.objective
		for beat: Dictionary in scene.beats:
			checks = checks and beat.shot_id in Director.SHOT_IDS and float(beat.duration)>0.0 and str(beat.get("text","")) != str(previous.text)
		for index in range(2,32):
			checks = checks and not Direction.introduction("I-%02d" % index).is_empty()
		var boundary := Cinematics.sequence_for(model.data,{"id":"old_step","mission":"I-05","npc":"sextus","text":"Already heard","result":"Confirmed outcome"},{"id":"new_step","mission":"I-06","objective":"New objective"})
		checks = checks and not boundary.is_empty() and str(boundary.beats[-1].text) == Direction.introduction("I-06")
	checks = checks and Cinematics.sequence_for(model.data,previous,previous).is_empty()
	checks = checks and JSON.stringify(model.data)==before
	print("MISSION_CINEMATICS_PASS" if checks else "MISSION_CINEMATICS_FAIL")
	quit(0 if checks else 1)
