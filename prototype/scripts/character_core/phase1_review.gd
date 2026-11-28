extends Node3D
## Standalone review scene; does not change the existing campaign input map.
@onready var actor: CharacterCore = $ImperathenCharacter
@onready var camera: Camera3D = $Camera3D
@onready var status: Label = $CanvasLayer/Status
var _camera_offset: Vector3 = Vector3(4.0,2.7,5.0)

func _physics_process(_delta: float) -> void:
	var direction: Vector3 = Vector3(
		float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		0.0,
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var gait: int = CharacterCore.Gait.WALK
	if Input.is_physical_key_pressed(KEY_SHIFT):
		gait = CharacterCore.Gait.SPRINT
	elif Input.is_physical_key_pressed(KEY_CTRL):
		gait = CharacterCore.Gait.RUN
	actor.request_motion(direction,clampf(direction.length(),0.0,1.0),gait)
	var turn: float = float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
	if turn != 0.0:
		actor.request_facing((-actor.global_basis.z).rotated(Vector3.UP,turn*0.8))
	else:
		actor.clear_facing()
	if Input.is_physical_key_pressed(KEY_F):
		actor.set_look_target(actor.global_position+Vector3(3.0,1.6,-2.0))
	else:
		actor.clear_look_target()

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.is_character_ready():
		return
	var desired: Vector3 = actor.global_position+_camera_offset
	camera.global_position = camera.global_position.lerp(desired,1.0-exp(-6.0*delta))
	camera.look_at(actor.global_position+Vector3.UP*1.1)
	status.text = "IMPERATHEN · Phase 1\nWASD: Gehen | Strg: Laufen | Shift: Sprint | Q/E: Drehen | F: Blick\nTempo %.2f m/s · Zustand %s · Hüfte %.3f m" % [actor.get_planar_speed(),str(CharacterCore.Gait.keys()[actor.get_motion_state()]),actor.get_pelvis_offset()]
