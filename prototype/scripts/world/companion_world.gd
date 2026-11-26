extends RefCounted
## Bindet dieselben vorhandenen Figuren an die Begleitregie. Nur beobachtete
## Körperpositionen werden gespeichert; Wege bleiben ein flüchtiger Cache.

const Follow = preload("res://scripts/story/companion_follow.gd")
const Story = preload("res://scripts/story/companion_story.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var world: Node3D
var controllers: Dictionary = {"marcus":Follow.new(), "silvanus":Follow.new()}


func _init(owner_world: Node3D) -> void:
	world = owner_world


func actor(id: String) -> CharacterBody3D:
	if id == "marcus":
		return world._companion as CharacterBody3D
	return world.village_life_world.actors.get(id) as CharacterBody3D


func home(id: String) -> Vector3:
	# During the open I-01 morning Silvanus sits at the breakfast table on the
	# raised house floor; afterwards he walks out to his door work.
	if id == "silvanus" and bool(I01.presentation(world._state).get("silvanus_at_table", false)):
		var seat: Vector2 = I01.POINTS.silvanus_table
		return Vector3(seat.x, Layout.HOUSE_FLOOR, seat.y)
	var point: Vector2 = Childhood.POINTS.marcus if id == "marcus" else Childhood.POINTS.father
	return Vector3(point.x, 0.0, point.y)


func reset(data: Dictionary) -> void:
	for id: String in controllers:
		controllers[id].reset()
		var body := actor(id)
		if body == null:
			continue
		body.velocity = Vector3.ZERO
		body.set_meta("companion_controlled", Story.available(data, id))
		if not Childhood.enabled(data):
			if id == "marcus":
				body.global_position = world.to_global(home(id))
			continue
		if id == "silvanus" and not Story.available(data, id):
			continue
		# Einmalige Platzierung beim Neu-/Laden, niemals beim normalen State-Sync.
		body.global_position = Story.restored_position(data, id, world.to_global(home(id)))


func pause() -> void:
	for id: String in controllers:
		var body := actor(id)
		if body != null:
			controllers[id].pause(body)
			body.get_node("Figure").drive(0.0)


func advance(delta: float) -> void:
	var data: Dictionary = world._state
	if not Childhood.enabled(data):
		return
	var paused: bool = not world._active or world._mode != "person" or data.village.raid.active or data.encounter.active
	if paused:
		pause()
		return
	var step := Childhood.current_step(data)
	var specs := Childhood.companion_specs(data)
	var player: Vector3 = world.get_player_position()
	for id: String in controllers:
		var body := actor(id)
		if body == null or not body.visible or not Story.available(data, id):
			continue
		body.set_meta("companion_controlled", true)
		var target := world.to_global(home(id))
		var distance := 0.15
		var speed := 1.45
		var mode := "return"
		if specs.has(id):
			var spec: Dictionary = specs[id]
			target = player
			distance = 2.1 if Story.tone(data, id) == "rival" else 1.7
			speed = 4.1 if Vector2(player.x-body.global_position.x, player.z-body.global_position.z).length() > 5.0 else 2.3
			mode = "follow"
			var stop: Array = spec.get("stops", {}).get(str(step.get("id", "")), [])
			if stop.size() == 2:
				var at := world.to_global(Vector3(float(stop[0]), 0.0, float(stop[1])))
				if Vector2(player.x-at.x, player.z-at.z).length() <= 6.0:
					target = at
					distance = 0.18
					mode = "hold"
		var before := body.global_position
		controllers[id].move(body, target, delta, speed, distance)
		var travelled := body.global_position-before
		var actual_speed := Vector2(travelled.x, travelled.z).length()/maxf(delta, 0.0001)
		# Follow.move already turns this exact body at its bounded angular rate.
		# The visual adapter must not rotate it a second time in the same tick.
		body.get_node("Figure").drive(actual_speed)
		body.set_meta("companion_mode", mode)
		body.set_meta("activity", "march" if actual_speed > 0.05 else "rest")
