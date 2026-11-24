extends Control
## Real-time title sequence: a legion eagle rises, a gladius cuts across the frame
## and leaves a trail of blood that reveals IMPERATHEN, then VENI · VIDI · VICI.
## Time-driven (no tweens) so it relayouts on rotation, records deterministically
## with --write-movie and can be stepped in tests. Tap, click or a key skips it.

signal finished

const RomanStyle = preload("res://scripts/ui/roman_style.gd")
const BackdropShader = preload("res://shaders/intro_backdrop.gdshader")

const FULL_DURATION := 8.8
const SHORT_DURATION := 3.0
const SWEEP_START := 2.4
const SWEEP_END := 3.25
const FADE_OUT := 1.0
const CUT_ANGLE := -0.05
const MOTTO_GAP := 0.3

var full := true
var reduce_motion := false
var elapsed := 0.0
var duration := FULL_DURATION
var _done := false
var _backdrop: ColorRect
var _stage: Control
var _eagle: TextureRect
var _eagle_glow: TextureRect
var _embers: CPUParticles2D
var _title_clip: Control
var _title: Label
var _motto: Label
var _cut: Node2D
var _sword: Sprite2D
var _blood: BloodStroke
var _sound: AudioStreamPlayer
var _sound_played := false
var _title_rect := Rect2()
var _eagle_home := Vector2.ZERO


## Blood trail with drips. Geometry is deterministic for a given length.
class BloodStroke extends Node2D:
	var length := 0.0
	var reveal := 0.0
	var drip_time := 0.0
	var thickness := 10.0
	var _drips: Array[Dictionary] = []

	func configure(total: float, stroke: float) -> void:
		length = total
		thickness = stroke
		_drips.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = 2611
		for index in range(11):
			var position := total * (0.06 + 0.88 * (index + rng.randf_range(-0.3, 0.3)) / 10.0)
			_drips.append({"x": position, "length": stroke * rng.randf_range(1.4, 4.6),
				"width": stroke * rng.randf_range(0.35, 0.6), "delay": rng.randf_range(0.15, 0.7),
				"speed": rng.randf_range(0.9, 1.7)})
		queue_redraw()

	func set_state(revealed: float, seconds_after_cut: float) -> void:
		reveal = revealed
		drip_time = seconds_after_cut
		queue_redraw()

	func _width(x: float) -> float:
		var u := clampf(x / maxf(1.0, length), 0.0, 1.0)
		var taper := smoothstep(0.0, 0.07, u) * smoothstep(1.0, 0.82, u)
		return thickness * (0.35 + 0.65 * taper) * (0.85 + 0.15 * sin(x * 0.045))

	func _draw() -> void:
		var visible_length := clampf(reveal, 0.0, length)
		if visible_length <= 2.0:
			return
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		var steps := maxi(2, int(visible_length / 6.0))
		for index in range(steps + 1):
			var x := visible_length * index / steps
			var w := _width(x)
			var wobble := sin(x * 0.021) * thickness * 0.18
			top.append(Vector2(x, wobble - w * 0.45))
			bottom.append(Vector2(x, wobble + w * 0.55))
		var outline := top.duplicate()
		var reversed_bottom := bottom.duplicate()
		reversed_bottom.reverse()
		outline.append_array(reversed_bottom)
		draw_colored_polygon(outline, Color("5e0608"))
		var core := PackedVector2Array()
		for index in range(top.size()):
			core.append(top[index].lerp(bottom[index], 0.18))
		for index in range(top.size() - 1, -1, -1):
			core.append(top[index].lerp(bottom[index], 0.72))
		draw_colored_polygon(core, Color("9a0f12"))
		var shine := PackedVector2Array()
		for index in range(top.size()):
			shine.append(top[index].lerp(bottom[index], 0.28))
		draw_polyline(shine, Color(1.0, 0.55, 0.5, 0.35), maxf(1.0, thickness * 0.12), true)
		for drip: Dictionary in _drips:
			var x: float = drip.x
			if x > visible_length:
				continue
			var age := drip_time - float(drip.delay) - (x / maxf(1.0, length)) * 0.4
			if age <= 0.0:
				continue
			var grow := 1.0 - exp(-age * float(drip.speed))
			var drop_length: float = float(drip.length) * grow
			var w: float = drip.width
			var base_y := sin(x * 0.021) * thickness * 0.18 + _width(x) * 0.4
			var tip := Vector2(x, base_y + drop_length)
			var body := PackedVector2Array([Vector2(x - w * 0.5, base_y - 1.0), Vector2(x + w * 0.5, base_y - 1.0),
				Vector2(x + w * 0.22, tip.y - w * 0.4), Vector2(x - w * 0.22, tip.y - w * 0.4)])
			draw_colored_polygon(body, Color("6d080b"))
			draw_circle(tip, w * 0.42, Color("7a0a0d"))
			draw_circle(tip + Vector2(-w * 0.12, -w * 0.14), w * 0.12, Color(1.0, 0.6, 0.55, 0.4))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BackdropShader
	_backdrop.material = material
	add_child(_backdrop)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	var aquila: Texture2D = load(RomanStyle.AQUILA_PATH)
	_eagle_glow = _texture_rect("AquilaGlow", aquila)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_eagle_glow.material = additive
	_eagle_glow.self_modulate = Color(1.0, 0.62, 0.25, 0.0)
	_eagle = _texture_rect("Aquila", aquila)
	_embers = CPUParticles2D.new()
	_embers.name = "Embers"
	_embers.amount = 64
	_embers.lifetime = 6.0
	_embers.preprocess = 3.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2(0.1, -1.0)
	_embers.spread = 18.0
	_embers.gravity = Vector2(0, -8)
	_embers.initial_velocity_min = 22.0
	_embers.initial_velocity_max = 60.0
	_embers.scale_amount_min = 0.25
	_embers.scale_amount_max = 0.7
	_embers.texture = _ember_texture()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.35, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.72, 0.3, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.4, 0.15, 0.0))
	_embers.color_ramp = ramp
	_stage.add_child(_embers)
	_title_clip = Control.new()
	_title_clip.name = "TitleReveal"
	_title_clip.clip_contents = true
	_title_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_title_clip)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "IMPERATHEN"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_clip.add_child(_title)
	_motto = Label.new()
	_motto.name = "Motto"
	_motto.text = "VENI · VIDI · VICI"
	_motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_motto)
	_cut = Node2D.new()
	_cut.name = "Cut"
	_stage.add_child(_cut)
	_blood = BloodStroke.new()
	_blood.name = "BloodTrail"
	_cut.add_child(_blood)
	_sword = Sprite2D.new()
	_sword.name = "Gladius"
	_sword.texture = load(RomanStyle.GLADIUS_PATH)
	_sword.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cut.add_child(_sword)
	_sound = AudioStreamPlayer.new()
	_sound.name = "SwordSound"
	_sound.stream = _sword_sound()
	_sound.volume_db = -6.0
	add_child(_sound)
	resized.connect(_layout)
	_layout()
	_apply()


func play(full_sequence: bool, reduced_motion: bool) -> void:
	full = full_sequence and not reduced_motion
	reduce_motion = reduced_motion
	duration = FULL_DURATION if full else SHORT_DURATION
	elapsed = 0.0
	_done = false
	_sound_played = false
	if is_instance_valid(_embers):
		_embers.emitting = not reduce_motion
	_apply()


func skip() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func is_done() -> bool:
	return _done


func advance(delta: float) -> void:
	if _done:
		return
	elapsed += delta
	if full and not _sound_played and elapsed >= SWEEP_START - 0.08:
		_sound_played = true
		if RomanStyle.audio_available():
			_sound.play()
	_apply()
	if elapsed >= duration:
		skip()


func _process(delta: float) -> void:
	advance(delta)


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		skip()


func _layout() -> void:
	if not is_instance_valid(_stage):
		return
	var area := size
	if area.x < 8 or area.y < 8:
		return
	var portrait := area.y > area.x * 1.15
	var material := _backdrop.material as ShaderMaterial
	var eagle_width := minf(area.x * (0.94 if portrait else 0.5), area.y * (1.05 if portrait else 0.85))
	var eagle_size := Vector2(eagle_width, eagle_width * 760.0 / 1400.0)
	_eagle_home = Vector2(area.x * 0.5, area.y * (0.34 if portrait else 0.31))
	for node: TextureRect in [_eagle, _eagle_glow]:
		node.size = eagle_size
		node.pivot_offset = eagle_size * 0.5
	_eagle_glow.size = eagle_size
	material.set_shader_parameter("focus", Vector2(0.5, _eagle_home.y / area.y))
	material.set_shader_parameter("aspect", area.x / area.y)
	var title_size := _fit_title(area.x * (0.9 if portrait else 0.74), area.y * 0.15)
	RomanStyle.style_title(_title, title_size)
	var title_height := title_size * 1.35
	var title_center_y := area.y * (0.53 if portrait else 0.6)
	_title_rect = Rect2(area.x * 0.03, title_center_y - title_height * 0.5, area.x * 0.94, title_height)
	_title.position = Vector2.ZERO
	_title.size = _title_rect.size
	_title_clip.position = _title_rect.position
	RomanStyle.style_caps(_motto, maxi(14, roundi(title_size * 0.3)), RomanStyle.PARCHMENT, maxi(4, roundi(title_size * 0.12)))
	_motto.size = Vector2(area.x, title_size * 0.6)
	_motto.position = Vector2(0, _title_rect.end.y + title_size * MOTTO_GAP)
	var text_width := RomanStyle.font(800, 4).get_string_size("IMPERATHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var stroke_length := minf(area.x * 0.98, text_width * 1.12)
	_cut.position = Vector2((area.x - stroke_length) * 0.5, title_center_y + title_size * 0.5)
	_cut.rotation = CUT_ANGLE
	_blood.configure(stroke_length, maxf(5.0, title_size * 0.13))
	var sword_length := clampf(area.x * 0.55, 260.0, 900.0)
	_sword.scale = Vector2.ONE * (sword_length / 1200.0)
	_embers.position = Vector2(area.x * 0.5, area.y + 10)
	_embers.emission_rect_extents = Vector2(area.x * 0.55, 8)
	_apply()


func _fit_title(available_width: float, max_height: float) -> int:
	var probe := RomanStyle.font(800, 4)
	var desired := int(max_height)
	var measured := probe.get_string_size("IMPERATHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, desired).x
	if measured > available_width and measured > 0:
		desired = int(desired * available_width / measured)
	return maxi(28, desired)


func _apply() -> void:
	if not is_instance_valid(_stage) or size.x < 8:
		return
	var area := size
	var t := elapsed
	var final_state := not full
	var fade_in := clampf(t / 0.6, 0.0, 1.0) if final_state else smoothstep(0.0, 0.8, t)
	var fade_out := 1.0 - smoothstep(duration - (0.6 if final_state else FADE_OUT), duration, t)
	modulate.a = minf(fade_in, fade_out)
	# Eagle rises from below into its place behind the title.
	var rise := 1.0 if final_state else _ease_out(clampf((t - 0.3) / 3.5, 0.0, 1.0))
	var eagle_alpha := 0.9 if final_state else smoothstep(0.3, 2.0, t) * 0.9
	var center := _eagle_home + Vector2(0, (1.0 - rise) * area.y * 0.38)
	for node: TextureRect in [_eagle, _eagle_glow]:
		node.position = center - node.size * 0.5
		node.scale = Vector2.ONE * (0.84 + 0.16 * rise)
	_eagle.modulate.a = eagle_alpha
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	_eagle_glow.self_modulate.a = eagle_alpha * (0.18 + 0.1 * pulse) * rise
	_eagle_glow.scale *= 1.02
	# Gladius sweep and blood trail along the cut line (local x axis).
	var stroke := _blood.length
	var sweep := 1.0 if final_state else clampf((t - SWEEP_START) / (SWEEP_END - SWEEP_START), 0.0, 1.0)
	var eased := sweep * sweep * (3.0 - 2.0 * sweep)
	var sword_length := 1200.0 * _sword.scale.x
	var travel_from := -_cut.position.x - sword_length * 0.5
	var travel_to := area.x - _cut.position.x + sword_length * 0.6
	var tip := lerpf(travel_from + sword_length * 0.5, travel_to + sword_length * 0.5, eased)
	_sword.position = Vector2(tip - sword_length * 0.5, -_blood.thickness * 0.2)
	_sword.visible = not final_state and sweep > 0.0 and sweep < 1.0
	var revealed := clampf(tip - 18.0, 0.0, stroke) if not final_state else stroke
	var after_cut := 4.0 if final_state else maxf(0.0, t - SWEEP_START)
	_blood.set_state(revealed, after_cut)
	# The title appears where the blade has passed.
	var tip_screen := _cut.position.x + tip * cos(_cut.rotation)
	var reveal_width := _title_rect.size.x if final_state else clampf(tip_screen - _title_rect.position.x, 0.0, _title_rect.size.x)
	_title_clip.size = Vector2(reveal_width, _title_rect.size.y)
	var flash := 0.0 if final_state else exp(-pow((t - SWEEP_END - 0.15) * 4.0, 2.0))
	_title.modulate = Color(1.0 + flash * 0.5, 1.0 + flash * 0.4, 1.0 + flash * 0.2)
	var motto_in := 1.0 if final_state else smoothstep(4.0, 5.0, t)
	_motto.modulate.a = motto_in
	_motto.position.y = _title_rect.end.y + _title.get_theme_font_size("font_size") * MOTTO_GAP + (1.0 - motto_in) * 14.0
	# Short impact shake when the blade leaves the frame.
	var shake := 0.0
	if not final_state and not reduce_motion and t > SWEEP_END - 0.1 and t < SWEEP_END + 0.18:
		shake = (1.0 - (t - SWEEP_END + 0.1) / 0.28) * 7.0
	_stage.position = Vector2(sin(t * 90.0), cos(t * 71.0)) * shake


func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _texture_rect(node_name: String, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stage.add_child(rect)
	return rect


func _ember_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 16
	texture.height = 16
	return texture


func _sword_sound() -> AudioStreamWAV:
	# Air swish (noise with a falling band) followed by a short ring of steel.
	var rate := 22050
	var count := int(rate * 1.1)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1124
	var low := 0.0
	var band := 0.0
	for index in range(count):
		var t := float(index) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		var cutoff := lerpf(0.55, 0.08, clampf(t / 0.35, 0.0, 1.0))
		low += (noise - low) * cutoff
		band += (low - band) * 0.25
		var swish := (low - band) * sin(PI * clampf(t / 0.38, 0.0, 1.0)) * 1.6
		var ring := 0.0
		if t > 0.3:
			var age := t - 0.3
			ring = (sin(TAU * 2350.0 * age) + 0.6 * sin(TAU * 3720.0 * age) + 0.35 * sin(TAU * 5190.0 * age)) * exp(-age * 5.5) * 0.22 * minf(1.0, age * 400.0)
		samples.encode_s16(index * 2, int(clampf(swish + ring, -1.0, 1.0) * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = samples
	return stream
