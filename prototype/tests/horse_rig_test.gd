extends SceneTree

const CLIPS := {
	"idle": [120, 0.0, 1.0, {"HL": 0.0, "FL": 0.0, "HR": 0.0, "FR": 0.0}],
	"walk": [62, 1.045, .66, {"HL": 0.0, "FL": .24, "HR": .50, "FR": .74}],
	"trot": [44, 1.540, .445, {"HL": 0.0, "FR": 0.0, "HR": .50, "FL": .50}],
	"canter": [38, 2.105, .317, {"HL": 0.0, "HR": .165, "FL": .165, "FR": .336}],
}
const SOCKETS := {
	"SOCKET_SADDLE": Vector3(0, 1.255353, .080781),
	"SOCKET_RIDER": Vector3(0, 1.305353, .080781),
	"SOCKET_REIN_L": Vector3(-.091, 1.225, -.922),
	"SOCKET_REIN_R": Vector3(-.205, 1.241, -.927),
	"SOCKET_HEAD": Vector3(-.147359, 1.213611, -.956936),
	"SOCKET_HOOF_FL": Vector3(-.146, 0, -.260),
	"SOCKET_HOOF_HL": Vector3(-.167, 0, .745),
	"SOCKET_HOOF_FR": Vector3(.146, 0, -.260),
	"SOCKET_HOOF_HR": Vector3(.167, 0, .745),
}

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func instance_of(node: Node, type: StringName) -> Node:
	if node.is_class(type):
		return node
	for child in node.get_children():
		var found := instance_of(child, type)
		if found != null:
			return found
	return null

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://assets/horse/valdora_horse_rig.glb") as PackedScene
	if packed == null:
		push_error("Das exportierte Pferd fehlt oder konnte nicht importiert werden.")
		quit(1)
		return
	var horse := packed.instantiate()
	root.add_child(horse)
	var skeleton := instance_of(horse, &"Skeleton3D") as Skeleton3D
	var player := instance_of(horse, &"AnimationPlayer") as AnimationPlayer
	var body := instance_of(horse, &"MeshInstance3D") as MeshInstance3D
	if skeleton == null or player == null or body == null:
		push_error("Import ohne Skelett, AnimationPlayer oder Pferdemesh")
		quit(1)
		return
	var bounds := body.global_transform * body.get_aabb()
	check(skeleton.get_bone_count() == 37, "Skelett hat nicht 37 Knochen")
	check(bounds.position.y >= -.001 and bounds.end.y > 1.65, "Größe oder Bodenbezug ungültig")
	check(body.get_surface_override_material(0) != null or body.mesh.surface_get_material(0) != null, "Material fehlt")
	var anchors := {}
	for socket: String in SOCKETS:
		var idx := skeleton.find_bone(socket)
		if idx < 0:
			check(false, "Fehlender Sockel %s" % socket)
			continue
		var transform := skeleton.global_transform * skeleton.get_bone_global_rest(idx)
		anchors[socket] = {"position": str(transform.origin), "up": str(transform.basis.y), "forward": str(-transform.basis.z)}
		check(transform.origin.distance_to(SOCKETS[socket]) < .001, "Restposition %s: %s" % [socket, transform.origin])
		check(transform.basis.y.normalized().dot(Vector3.UP) > .999, "Y-Sockelachse zeigt nicht nach oben: %s %s" % [socket,transform.basis.y])
		check((-transform.basis.z).normalized().dot(Vector3.FORWARD) > .999, "Sockel zeigt nicht in Reitrichtung: %s %s" % [socket,-transform.basis.z])
	var checks := {}
	for clip: String in CLIPS:
		if not player.has_animation(clip):
			check(false, "Fehlender Clip %s" % clip)
			continue
		var props: Array = CLIPS[clip]
		var samples: int = props[0]
		var distance: float = props[1]
		var duty: float = props[2]
		var offsets: Dictionary = props[3]
		var length := player.get_animation(clip).length
		check(absf(length - float(samples)/60.)<.00015, "%s hat falsche Dauer %.7f" % [clip,length])
		player.play(clip)
		player.advance(0.)
		player.pause()
		var maximum_floor_error := 0.
		var maximum_drift := 0.
		var min_support := 4
		var max_support := 0
		var flight_frames := 0
		var previous := {}
		for i in range(samples + 1):
			var fraction := float(i) / float(samples)
			var count := 0
			player.seek(fraction*length, true)
			skeleton.force_update_all_bone_transforms()
			for foot: String in offsets:
				var idx := skeleton.find_bone("SOCKET_HOOF_" + foot)
				if idx < 0:
					continue
				var phase := fposmod(fmod(fraction, 1.) - float(offsets[foot]), 1.0)
				var planted := phase < duty and (absf(phase-duty) > .002 or clip=="idle")
				if planted:
					var marker := skeleton.to_global(skeleton.get_bone_global_pose(idx).origin)
					var translated := marker + Vector3.FORWARD*distance*fraction
					count += 1
					maximum_floor_error = maxf(maximum_floor_error, absf(marker.y))
					if previous.has(foot):
						maximum_drift = maxf(maximum_drift, translated.distance_to(previous[foot]))
					previous[foot] = translated
				else:
					previous.erase(foot)
			min_support = mini(min_support,count)
			max_support = maxi(max_support,count)
			if count == 0:
				flight_frames += 1
		var max_allowed_error := .002
		check(maximum_floor_error < max_allowed_error, "%s Fussbodenabweichung %.7f" % [clip,maximum_floor_error])
		check(maximum_drift < .003, "%s Standgleiten %.7f" % [clip,maximum_drift])
		check((clip in ["idle","walk"] and flight_frames==0) or (clip in ["trot","canter"] and flight_frames>0), "%s stützt in falscher Sequenz" % clip)
		check(clip!="idle" or min_support==4,"Halt hat keine vier Hufe am Boden")
		check(clip!="walk" or min_support>=2,"Schritt hat weniger als zwei Stützhufe")
		check(clip!="trot" or max_support==2,"Trab hat mehr als zwei Stützhufe")
		check(clip!="canter" or max_support==3,"Galopp hat keinen kurzzeitigen Dreibeinübergang")
		checks[clip]={"length_s":length, "cycle_distance_m":distance, "min_support":min_support, "max_support":max_support,
			"airborne_frames":flight_frames,"max_hoof_floor_error_m":maximum_floor_error,"max_hoof_drift_m":maximum_drift}
	var evidence := {"godot":Engine.get_version_info().string,"bones":skeleton.get_bone_count(),
		"clips":checks,"sockets":anchors,"bounds":str(bounds),"failures":failures}
	print("HORSE_GODOT_EVIDENCE ",JSON.stringify(evidence))
	horse.free()
	print("HORSE_RIG_" + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
