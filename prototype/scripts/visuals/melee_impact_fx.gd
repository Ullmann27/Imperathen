extends Node3D
## Pooled level-A impact feedback for the compatibility renderer: CPU
## particle bursts (sparks, splinters, dust, fibre) and the synthesized
## impact sounds of melee_impact_audio.gd (placeholders pending recorded
## foley). CPU particles avoid particle-shader compilation stalls on mobile;
## the pool caps simultaneous bursts at Feedback.MAX_ACTIVE_BURSTS.

const Feedback = preload("res://scripts/domain/melee/melee_feedback.gd")
const Audio = preload("res://scripts/visuals/melee_impact_audio.gd")
const KINDS := ["sparks", "splinters", "dust", "fibre"]
var history: Array = []
var _slots: Array = []
var _next := 0
var _materials := {}
var _meshes := {}


func _ready() -> void:
	for i in Feedback.MAX_ACTIVE_BURSTS:
		var slot := {}
		for kind: String in KINDS:
			var particles := CPUParticles3D.new()
			particles.name = "%s_%d" % [kind, i]
			particles.emitting = false
			particles.one_shot = true
			particles.explosiveness = 1.0
			particles.local_coords = false
			particles.mesh = _mesh(kind)
			particles.material_override = _material(kind)
			particles.color_ramp = _ramp(kind)
			particles.particle_flag_align_y = kind == "sparks"
			add_child(particles)
			slot[kind] = particles
		var player := AudioStreamPlayer3D.new()
		player.name = "Impact_%d" % i
		player.unit_size = 6.0
		player.max_db = 3.0
		add_child(player)
		slot.player = player
		_slots.append(slot)


## Spawn the feedback for one melee event at `point`; `normal` points back
## toward the attacker (out of the struck surface).
func spawn(event: Dictionary, point: Vector3, normal: Vector3) -> Dictionary:
	var feedback := Feedback.for_event(event)
	if feedback.is_empty() or _slots.is_empty():
		return feedback
	var slot: Dictionary = _slots[_next]
	_next = (_next + 1) % _slots.size()
	var up := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	for burst: Dictionary in feedback.bursts:
		var particles: CPUParticles3D = slot[burst.kind]
		particles.emitting = false
		particles.amount = int(burst.count)
		particles.lifetime = float(burst.lifetime)
		particles.direction = up
		particles.spread = float(burst.spread_deg)
		particles.initial_velocity_min = float(burst.speed) * 0.5
		particles.initial_velocity_max = float(burst.speed)
		particles.gravity = Vector3(0.0, float(burst.gravity), 0.0)
		particles.damping_min = 0.5 if burst.kind in ["dust", "fibre"] else 0.0
		particles.damping_max = 1.5 if burst.kind in ["dust", "fibre"] else 0.2
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.4
		particles.position = to_local(point) if is_inside_tree() else point
		particles.restart()
		particles.emitting = true
	var sound: Dictionary = feedback.sound
	var player: AudioStreamPlayer3D = slot.player
	player.stream = Audio.stream(str(sound.id))
	player.volume_db = float(sound.gain_db)
	player.pitch_scale = float(sound.pitch)
	player.position = to_local(point) if is_inside_tree() else point
	if player.is_inside_tree():
		player.play()
	history.append({"type":event.get("type", ""), "sound":sound.id, "bursts":feedback.bursts.map(func(b): return "%s x%d" % [b.kind, b.count])})
	return feedback


## Stop every burst and sound (scene reset, cutscene cut, level change).
func clear() -> void:
	for slot: Dictionary in _slots:
		for kind: String in KINDS:
			(slot[kind] as CPUParticles3D).emitting = false
			(slot[kind] as CPUParticles3D).restart()
			(slot[kind] as CPUParticles3D).emitting = false
		(slot.player as AudioStreamPlayer3D).stop()


func active_particles() -> int:
	var total := 0
	for slot: Dictionary in _slots:
		for kind: String in KINDS:
			var p: CPUParticles3D = slot[kind]
			if p.emitting:
				total += p.amount
	return total


func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		"sparks":
			var quad := QuadMesh.new()
			quad.size = Vector2(0.010, 0.060)
			mesh = quad
		"splinters":
			var box := BoxMesh.new()
			box.size = Vector3(0.010, 0.012, 0.055)
			mesh = box
		"fibre":
			var quad := QuadMesh.new()
			quad.size = Vector2(0.03, 0.03)
			mesh = quad
		_:
			var quad := QuadMesh.new()
			quad.size = Vector2(0.14, 0.14)
			mesh = quad
	_meshes[kind] = mesh
	return mesh


func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match kind:
		"sparks":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"splinters":
			m.roughness = 0.9
		_:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			# Soft radial puff instead of a hard-edged quad (32x32, generated).
			var puff := GradientTexture2D.new()
			puff.width = 32
			puff.height = 32
			puff.fill = GradientTexture2D.FILL_RADIAL
			puff.fill_from = Vector2(0.5, 0.5)
			puff.fill_to = Vector2(1.0, 0.5)
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			puff.gradient = g
			m.albedo_texture = puff
	_materials[kind] = m
	return m


func _ramp(kind: String) -> Gradient:
	var g := Gradient.new()
	match kind:
		"sparks":
			g.set_color(0, Color(1.0, 0.92, 0.6, 1.0))
			g.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
		"splinters":
			g.set_color(0, Color(0.62, 0.44, 0.24, 1.0))
			g.set_color(1, Color(0.45, 0.30, 0.16, 1.0))
		"fibre":
			g.set_color(0, Color(0.78, 0.74, 0.64, 0.9))
			g.set_color(1, Color(0.70, 0.66, 0.58, 0.0))
		_:
			g.set_color(0, Color(0.66, 0.60, 0.50, 0.55))
			g.set_color(1, Color(0.60, 0.55, 0.47, 0.0))
	return g
