extends RefCounted
## Shows one melee_core fighter on a visible rig. Presentation only: it reads
## the authoritative state (position, yaw, clip time, guard, dodge, reaction)
## and poses the actual skeleton at exactly that clip time. It never advances
## time, finds contact or changes the state.

const Core = preload("res://scripts/domain/melee/melee_core.gd")
const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const MeleePose = preload("res://scripts/visuals/melee_pose.gd")

var fighter_id := ""
var kit := ""
var root: Node3D
var person: Node3D
var model: Node3D
var pose := MeleePose.new()
var ground_offset := 0.0
var _weapon_axis := Vector3.ZERO
var _last_state := ""
## Crossfade between authoritative states (strike -> recoil, guard -> stance).
const TRANSITION := 0.14


## A VillagePerson (hero, Meshy) whose origin stands 0.9 m above the ground.
func bind_person(target: Node3D, kit_id: String, id: String) -> bool:
	fighter_id = id
	kit = kit_id
	root = target
	person = target
	model = target.body
	ground_offset = 0.9
	return pose.bind(model, kit_id)


## A raw battle rig (soldiers/*.glb) under a holder node with its origin on
## the ground; `axis` is the measured weapon axis in Hand_R space.
func bind_rig(holder: Node3D, rig: Node3D, kit_id: String, id: String, axis: Vector3) -> bool:
	fighter_id = id
	kit = kit_id
	root = holder
	person = null
	model = rig
	ground_offset = 0.0
	_weapon_axis = axis
	return pose.bind(rig, kit_id, axis)


func apply(state: Dictionary, delta: float = 1.0 / 60.0) -> void:
	var f: Dictionary = state.fighters.get(fighter_id, {})
	if f.is_empty() or root == null:
		return
	var label := "%s:%s%s%s" % [f.action, f.move, f.guard_style, str(f.react.get("kind", "")) if typeof(f.react) == TYPE_DICTIONARY else ""]
	if label != _last_state:
		# Strikes, guards and dodges start from the stance pose itself, so
		# entering them from idle needs no blend; a strike is never blended,
		# keeping the rendered weapon identical to the measured track.
		var from_idle := _last_state.begins_with("idle:")
		if f.action == "attack" or (from_idle and f.action in ["guard", "dodge"]) or _last_state.is_empty():
			pose.capture_transition(0.0)
		else:
			pose.capture_transition(TRANSITION)
		_last_state = label
	pose.advance(delta)
	if person != null and person.body != model:
		# A level-of-detail reload replaced the model; rebind to it.
		model = person.body
		pose.bind(model, kit, _weapon_axis)
	root.position = Vector3(float(f.x), ground_offset, float(f.z))
	root.rotation.y = float(f.yaw)
	match str(f.action):
		"attack":
			var timing := Tracks.timing(kit, str(f.move))
			var normalized := float(f.t) / float(timing.duration)
			if kit == "youth_unarmed" and person != null:
				person.sample_combat(str(f.move), normalized)
			else:
				pose.strike(str(f.move), normalized)
		"guard":
			pose.guard(str(f.guard_style), float(f.guard_t))
		"dodge":
			pose.dodge(str(f.dodge), float(f.dodge_t), Core._leg_factor(f))
		"react", "down":
			var r: Dictionary = f.react
			var basis := Basis(Vector3.UP, -float(f.yaw))
			var push := basis * Vector3(float(r.push[0]), 0.0, float(r.push[1]))
			var step := basis * Vector3(float(r.step[0]), 0.0, float(r.step[1]))
			# Godot local (-Z forward) to the pose module's fighter space.
			pose.reaction(Vector3(push.x, 0.0, -push.z), float(r.strength), float(r.t), float(r.duration), Vector3(step.x, 0.0, -step.z))
		_:
			pose.stance_pose()
