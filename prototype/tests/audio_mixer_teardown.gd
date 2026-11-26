extends RefCounted

static func drain(tree: SceneTree) -> void:
	# AudioServer releases stopped Ogg playback from its mixer thread. The
	# fixed-step test can finish several minutes of story in one mixer tick.
	var periods := 0
	var since_mix := AudioServer.get_time_since_last_mix()
	var deadline := Time.get_ticks_msec() + 500
	while periods < 4 and Time.get_ticks_msec() < deadline:
		OS.delay_msec(2)
		await tree.process_frame
		var elapsed := AudioServer.get_time_since_last_mix()
		if elapsed < since_mix:
			periods += 1
		since_mix = elapsed
