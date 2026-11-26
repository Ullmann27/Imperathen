extends Node3D
## A local practice animal for the free-city QA route. Campaign ownership uses
## the stable market and is intentionally independent of this test animal.

signal feedback(text: String)

const Controller := preload("res://scripts/world/mount_controller.gd")
const MODEL := "res://assets/horse/valdora_horse_rig.glb"
const CLIP_SPEED := {&"idle": 0.0, &"walk": 1.0113, &"trot": 2.1, &"canter": 3.3237}
var controller: Controller
var horse: CharacterBody3D
var animation: AnimationPlayer


func install(player: CharacterBody3D, figure: Node3D, at: Vector3, heading: float) -> bool:
	if not ResourceLoader.exists(MODEL, "PackedScene"):
		return false
	var packed := load(MODEL) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		model.free()
		return false
	var skeleton := skeletons[0] as Skeleton3D
	if skeleton.find_bone("SOCKET_RIDER") < 0:
		model.free()
		return false
	var seat := BoneAttachment3D.new()
	seat.name = "RiderSeat"
	seat.bone_name = "SOCKET_RIDER"
	skeleton.add_child(seat)
	animation = players[0] as AnimationPlayer
	for clip: StringName in CLIP_SPEED:
		if not animation.has_animation(clip):
			animation = null
			model.free()
			return false
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	horse = CharacterBody3D.new()
	horse.name = "PracticeHorse"
	horse.position = at
	horse.rotation.y = heading
	horse.collision_layer = 1
	horse.collision_mask = 1
	horse.floor_snap_length = 0.23
	horse.floor_max_angle = deg_to_rad(43.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.82, 1.55, 1.92)
	var hitbox := CollisionShape3D.new()
	hitbox.position.y = 0.775
	hitbox.shape = shape
	horse.add_child(hitbox)
	horse.add_child(model)
	add_child(horse)
	controller = Controller.new()
	add_child(controller)
	if not controller.configure(player, figure, horse, seat):
		return false
	controller.action_feedback.connect(func(text: String) -> void: feedback.emit(text))
	animation.play(&"idle")
	return true


func advance(delta: float, axis: Vector2, camera_yaw: float, faster: bool) -> bool:
	var controlled := controller.advance(delta, axis, camera_yaw, faster)
	var clip := controller.riding_gait()
	if animation.current_animation != clip:
		animation.play(clip, 0.15)
	var nominal: float = CLIP_SPEED[clip]
	animation.speed_scale = clampf(controller.riding_speed() / nominal, 0.35, 1.65) if nominal > 0.0 else 1.0
	return controlled
