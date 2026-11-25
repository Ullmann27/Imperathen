extends SceneTree
## Echte Körperbewegung gegen Boden, Wände, Personen und die Maße des Hauseingangs.

const Follow = preload("res://scripts/story/companion_follow.gd")
const DT := 1.0/60.0
var checks := 0
var failures: Array[String] = []
var stage: Node3D
var metrics: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _run() -> void:
	await _wall_and_stop()
	await _person_and_pause()
	await _moving_target()
	await _changed_destination()
	await _enclosed_target()
	await _unsupported_ground()
	await _raised_home()
	await _long_distance()
	print("COMPANION_NAVIGATION_METRICS "+JSON.stringify(metrics))
	print("Companion navigation: %d checks, %d failures" % [checks,failures.size()])
	print("COMPANION_NAVIGATION_PASS" if failures.is_empty() else "COMPANION_NAVIGATION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _new_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)


func _clear_stage() -> void:
	stage.queue_free()
	await physics_frame
	await physics_frame


func _box(at: Vector3, size: Vector3, layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.add_child(shape)
	stage.add_child(body)
	return body


func _person(at: Vector3, layer := 8) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 1|2|4|8
	body.floor_snap_length = 0.3
	body.safe_margin = 0.006
	var shape := CollisionShape3D.new()
	shape.position.y = 0.9
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.29
	capsule.height = 1.72
	shape.shape = capsule
	body.add_child(shape)
	stage.add_child(body)
	return body


func _flat_floor() -> void:
	_box(Vector3(0,-0.5,0),Vector3(220,1,220))


func _settle() -> void:
	await physics_frame
	await physics_frame


func _wall_and_stop() -> void:
	_new_stage()
	_flat_floor()
	_box(Vector3(0,1.5,0),Vector3(1,3,12))
	var actor := _person(Vector3(-8,0,0))
	var nav := Follow.new()
	await _settle()
	var max_side := 0.0
	var crossed := false
	var max_step := 0.0
	var minimum_floor := 0.0
	for tick in 900:
		await physics_frame
		var before := actor.position
		nav.move(actor,Vector3(8,0,0),DT)
		max_side = maxf(max_side,absf(actor.position.z))
		crossed = crossed or absf(actor.position.x) < 0.78 and absf(actor.position.z) < 6.25
		max_step = maxf(max_step,Vector2(actor.position.x-before.x,actor.position.z-before.z).length())
		minimum_floor = minf(minimum_floor,actor.position.y)
	var gap := Vector2(actor.position.x-8,actor.position.z).length()
	_check(max_side >= 6.25 and not crossed,"Begleiter umgeht die zwölf Meter breite Wand mit seinem echten Körper")
	_check(gap >= 1.65 and gap <= 1.76,"Folgen endet am geforderten Abstand von 1,7 Metern")
	_check(max_step <= 3.8*DT+0.012,"Umgehung enthält keinen Teleport und keinen Aufholsprung")
	_check(minimum_floor >= -0.05 and actor.is_on_floor(),"Während der Wandumgehung bleibt die Kapsel über dem Boden")
	_check(nav.status == "arrived" and nav.actual_speed < 0.01,"Ankunft stoppt den gemessenen Bewegungsantrieb")
	metrics.wall = {"gap":gap,"max_side":max_side,"max_step":max_step,"status":nav.status,"position":str(actor.position)}
	await _clear_stage()


func _person_and_pause() -> void:
	_new_stage()
	_flat_floor()
	var actor := _person(Vector3(-4,0,0))
	var resident := _person(Vector3(0,0,0))
	var nav := Follow.new()
	await _settle()
	var minimum_gap := 100.0
	var side := 0.0
	for tick in 420:
		await physics_frame
		nav.move(actor,Vector3(4,0,0),DT,3.8,0.7)
		minimum_gap = minf(minimum_gap,Vector2(actor.position.x-resident.position.x,actor.position.z-resident.position.z).length())
		side = maxf(side,absf(actor.position.z))
	_check(minimum_gap >= 0.57 and side >= 0.58,"Ein Bewohner auf Kollisionsschicht 8 wird körperlich umgangen")
	_check(Vector2(actor.position.x-4,actor.position.z).length() <= 0.76,"Ausweichen vor einer Person erreicht weiterhin das Ziel")
	var before := actor.position
	for tick in 45:
		await physics_frame
		nav.pause(actor)
	_check(actor.position.is_equal_approx(before) and actor.velocity == Vector3.ZERO and nav.actual_speed == 0.0,"Pause hält Körper und Bewegungsmetadaten unverändert an")
	_check(actor.get_meta("companion_navigation","") == "paused","Pausenstatus ist für die Weltsteuerung lesbar")
	nav.reset()
	for tick in 420:
		await physics_frame
		nav.move(actor,Vector3(-4,0,0),DT,3.8,0.1)
	_check(Vector2(actor.position.x+4,actor.position.z).length() < 0.18,"Nach Reset erfolgt auch der Rückweg körperlich am Bewohner vorbei")
	metrics.person = {"minimum_gap":minimum_gap,"side":side,"return":str(actor.position)}
	await _clear_stage()


func _enclosed_target() -> void:
	_new_stage()
	_flat_floor()
	_box(Vector3(4,1.5,0),Vector3(4,3,4))
	var actor := _person(Vector3(-5,0,0))
	var nav := Follow.new()
	await _settle()
	var inside := false
	var max_step := 0.0
	for tick in 480:
		await physics_frame
		var before := actor.position
		nav.move(actor,Vector3(4,0,0),DT,3.8,0.1)
		inside = inside or absf(actor.position.x-4) < 2.25 and absf(actor.position.z) < 2.25
		max_step = maxf(max_step,before.distance_to(actor.position))
	_check(not inside and Vector2(actor.position.x-4,actor.position.z).length() > 2.25,"Ein Ziel in massiver Geometrie wird weder betreten noch per Teleport erreicht")
	_check(max_step < 0.12 and actor.is_on_floor(),"Unerreichbares Ziel verursacht keinen Sprung und keinen Bodenverlust")
	_check(nav.expanded_nodes <= Follow.MAX_NODES,"Auch die erfolglose Suche hält das feste Knotenbudget ein")
	metrics.enclosed = {"status":nav.status,"nodes":nav.expanded_nodes,"position":str(actor.position)}
	await _clear_stage()


func _unsupported_ground() -> void:
	_new_stage()
	_box(Vector3(-12,-0.5,0),Vector3(20,1,30))
	_box(Vector3(12,-0.5,0),Vector3(20,1,30))
	var actor := _person(Vector3(-5,0,0))
	var nav := Follow.new()
	await _settle()
	var lowest := 0.0
	for tick in 360:
		await physics_frame
		nav.move(actor,Vector3(5,0,0),DT,3.8,0.1)
		lowest = minf(lowest,actor.position.y)
	_check(lowest >= -0.05 and actor.position.x < -2.20,"Fehlender Boden wird als Wegsperre erkannt und nicht überlaufen")
	metrics.gap = {"position":str(actor.position),"lowest":lowest}
	await _clear_stage()


func _raised_home() -> void:
	_new_stage()
	_flat_floor()
	# Maße des vorhandenen romanischen Dorfhauses aus regional_village.gd:
	# erhöhter Boden, Türbreite 1,38 m, reale Rampe und Schwellenpodest.
	_box(Vector3(0,0.3925*0.5,0),Vector3(5.28,0.3925,4.26))
	for side in [-1,1]:
		_box(Vector3(2.85*side,1.68,0),Vector3(0.29,3.35,4.70))
		_box(Vector3(side*(2.85+0.69)*0.5,1.68,2.35),Vector3(2.85-0.69,3.35,0.29))
	_box(Vector3(0,1.68,-2.35),Vector3(5.7,3.35,0.29))
	_box(Vector3(0,0.415,2.50),Vector3(1.25,0.06,0.90))
	var pitch := atan2(0.445,1.05)
	var ramp := _box(Vector3(0,0.445*0.5-0.03*cos(pitch),3.475-0.03*sin(pitch)),Vector3(1.25,0.06,Vector2(1.05,0.445).length()))
	ramp.rotation.x = pitch
	var actor := _person(Vector3(4,0,0))
	var nav := Follow.new()
	await _settle()
	var highest := 0.0
	var doorway := false
	for tick in 1000:
		await physics_frame
		nav.move(actor,Vector3(0,0.3925,-0.5),DT,3.8,0.15)
		highest = maxf(highest,actor.position.y)
		doorway = doorway or absf(actor.position.x) < 0.45 and actor.position.z > 2.15 and actor.position.z < 2.6
	_check(doorway and Vector2(actor.position.x,actor.position.z+0.5).length() < 0.22,"Begleiter findet von der Hausseite die schmale Türöffnung")
	_check(highest > 0.35 and actor.position.y > 0.34 and actor.position.y < 0.42,"Begleiter betritt den erhöhten Familienboden über die reale Rampe")
	metrics.home_entry = {"highest":highest,"position":str(actor.position),"status":nav.status,"nodes":nav.expanded_nodes}
	for tick in 600:
		await physics_frame
		nav.move(actor,Vector3(0,0,6),DT,3.8,0.15)
	_check(Vector2(actor.position.x,actor.position.z-6).length() < 0.22 and actor.position.y < 0.02 and actor.position.y > -0.05,"Rückweg führt durch die Tür und über die Rampe zurück zum Terrain")
	metrics.home_return = str(actor.position)
	await _clear_stage()


func _long_distance() -> void:
	_new_stage()
	_flat_floor()
	var actor := _person(Vector3(-40,0,0))
	var nav := Follow.new()
	await _settle()
	for tick in 1400:
		await physics_frame
		nav.move(actor,Vector3(40,0,0),DT,3.8,1.7)
	_check(Vector2(actor.position.x-40,actor.position.z).length() < 1.77,"Achtzig Meter Anlaufstrecke funktioniert ohne sechs Meter Reichweitengrenze")
	_check(nav.status == "arrived" and nav.actual_speed < 0.01,"Lange Annäherung endet mit sauberem Stillstand")
	metrics.long_distance = {"position":str(actor.position),"status":nav.status}
	await _clear_stage()


func _moving_target() -> void:
	_new_stage()
	_flat_floor()
	var actor := _person(Vector3(0,0,0))
	var player := _person(Vector3(3,0,0),2)
	var nav := Follow.new()
	await _settle()
	var nearest := 100.0
	var worst_late_gap := 0.0
	var late_speed_min := 100.0
	var late_speed_max := 0.0
	for tick in 360:
		await physics_frame
		player.velocity = Vector3(1.45,-0.3,0)
		player.move_and_slide()
		# Zielhöhe entspricht dem zentrierten Spieler-Origin; der Controller
		# muss trotzdem selbst die Bodenhöhe der Fuß-Origin-Figur ermitteln.
		nav.move(actor,player.global_position+Vector3.UP*0.9,DT)
		var gap := Vector2(actor.position.x-player.position.x,actor.position.z-player.position.z).length()
		nearest = minf(nearest,gap)
		if tick >= 120:
			worst_late_gap = maxf(worst_late_gap,gap)
			late_speed_min = minf(late_speed_min,nav.actual_speed)
			late_speed_max = maxf(late_speed_max,nav.actual_speed)
	_check(nearest >= 1.65 and worst_late_gap < 1.76,"Ein tatsächlich gehender Spieler wird mit gleichbleibendem Abstand verfolgt")
	_check(late_speed_min > 1.35 and late_speed_max < 1.55,"Bei gleichmäßigem Gehen entstehen keine abwechselnden Lauf- und Stillstandsbilder")
	player.velocity = Vector3.ZERO
	for tick in 90:
		await physics_frame
		nav.move(actor,player.global_position+Vector3.UP*0.9,DT)
	_check(nav.status == "arrived" and nav.actual_speed < 0.01,"Hält der echte Zielkörper an, endet auch die Folgebewegung")
	metrics.moving_target = {"nearest":nearest,"worst_gap":worst_late_gap,"minimum_speed":late_speed_min,"maximum_speed":late_speed_max}
	await _clear_stage()


func _changed_destination() -> void:
	for during_search in [true,false]:
		_new_stage()
		_flat_floor()
		_box(Vector3(0,1.5,0),Vector3(1,3,12))
		var actor := _person(Vector3(-8,0,0))
		var nav := Follow.new()
		await _settle()
		var reached_phase := false
		for tick in 450:
			await physics_frame
			nav.move(actor,Vector3(8,0,0),DT)
			if during_search and nav.status == "planning" or not during_search and not nav.path.is_empty() and actor.position.z > 1.0:
				reached_phase = true
				break
		var label := "Suche" if during_search else "Umgehung"
		_check(reached_phase,"Zielwechsel wird während tatsächlicher "+label+" geprüft")
		var changed_at := actor.position
		var new_target := Vector3(-8,0,-8)
		var maximum_step := 0.0
		var continued_old_direction := 0.0
		var aligned_progress := 0.0
		var after_second := actor.position
		for tick in 300:
			await physics_frame
			var before := actor.position
			nav.move(actor,new_target,DT)
			maximum_step = maxf(maximum_step,Vector2(actor.position.x-before.x,actor.position.z-before.z).length())
			continued_old_direction = maxf(continued_old_direction,actor.position.z-before.z)
			var toward := Vector3(new_target.x-before.x,0.0,new_target.z-before.z).normalized()
			if Vector3.FORWARD.rotated(Vector3.UP,actor.rotation.y).dot(toward) > 0.99:
				aligned_progress += maxf(0.0,(actor.position-before).dot(toward))
			if tick == 59:
				after_second = actor.position
		# The old assertion measured 2.3 m of first-second speed, not whether
		# the superseded route was abandoned. A bounded turn may spend part
		# of that second facing the new path before actual forward travel.
		_check(continued_old_direction <= 0.0001,"Zielwechsel während "+label+" führt keinen weiteren Schritt entlang der alten Umgehung aus")
		_check(aligned_progress > 1.0,"Nach der begrenzten Ausrichtung macht die Figur Fortschritt zum neuen Ziel während "+label)
		_check(Vector2(actor.position.x-new_target.x,actor.position.z-new_target.z).length() <= 1.76 and nav.status == "arrived","Nach Zielwechsel während "+label+" wird das neue Ziel erreicht")
		_check(maximum_step <= 3.8*DT+0.012,"Zielwechsel während "+label+" enthält keinen Positionssprung")
		metrics["retarget_search" if during_search else "retarget_path"] = {"changed_at":str(changed_at),"after_second":str(after_second),"maximum_step":maximum_step,"continued_old_direction":continued_old_direction,"aligned_progress":aligned_progress,"final":str(actor.position)}
		await _clear_stage()
