extends "res://tests/motion_world_measurement.gd"
## Add animation phase to diagnostics without changing observations or limits.

func _observe_person(sample: Dictionary, actor: Node3D, figure: Node3D) -> void:
	super._observe_person(sample, actor, figure)
	var frame: int = sample.actors[str(actor.get_instance_id())].frame
	for metric: String in sample.worst:
		var context: Dictionary = sample.worst[metric]
		if int(context.frame) == frame and str(context.actor) == str(actor.name):
			context["animation_phase"] = figure.phase
