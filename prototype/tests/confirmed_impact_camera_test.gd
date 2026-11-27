extends SceneTree
const Camera := preload("res://scripts/rendering/confirmed_impact_camera.gd")
func _initialize() -> void:
	var event := {"target_id":"adult_enemy","hit":true,"armed":true,"practice":false,"before_health":8,"after_health":0,"target_position":Vector2(1,2)}
	var ok := Camera.eligible(event,25,true)
	ok = ok and not Camera.eligible(event,12,true) and not Camera.eligible(event,25,false)
	for field in ["hit","armed"]:
		var changed := event.duplicate()
		changed[field] = false
		ok = ok and not Camera.eligible(changed,25,true)
	var surviving := event.duplicate()
	surviving.after_health = 1
	ok = ok and not Camera.eligible(surviving,25,true)
	var training := event.duplicate()
	training.target_id = "practice"
	ok = ok and not Camera.eligible(training,25,true)
	ok = ok and Camera.weight(0)==0.0 and Camera.weight(Camera.DURATION)==0.0 and Camera.weight(Camera.DURATION*.5)>.5
	print("CONFIRMED_IMPACT_CAMERA_PASS" if ok else "CONFIRMED_IMPACT_CAMERA_FAIL")
	quit(0 if ok else 1)
