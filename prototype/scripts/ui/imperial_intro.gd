extends Control
## Real-time title sequence in trailer rhythm. Drum hits reveal a marching legion
## in storm light, standards and banners rise, the aquila climbs into the light
## shafts, a gladius cuts across with motion blur and sparks and leaves a trail of
## blood that reveals IMPERATHEN on the impact, then VENI · VIDI · VICI lands word
## by word. Time-driven (no tweens) so it relayouts on rotation, records
## deterministically with --write-movie and can be stepped in tests. Tap, click
## or a key skips it. Effect density follows the graphics profile.

signal finished

const RomanStyle = preload("res://scripts/ui/roman_style.gd")
const Fx = preload("res://scripts/ui/imperial_fx.gd")
const BackdropShader = preload("res://shaders/intro_backdrop.gdshader")
const TRAILER_PATH := "res://assets/ui/intro_trailer.ogg"

## Timeline in seconds; tools/ui/build_intro_trailer.py places its hits on the
## same marks, so sound and picture stay locked.
const FULL_DURATION := 10.8
const SHORT_DURATION := 3.0
const HIT_LEGION := 0.45
const HIT_STANDARDS := 1.45
const HIT_EAGLE := 2.45
const SWEEP_START := 3.55
const SWEEP_END := 4.25
const MOTTO_WORDS: Array[float] = [5.55, 6.15, 6.75]
const TITLE_SHEEN := 4.75
const EAGLE_SHEEN := 7.6
const FADE_OUT := 1.0
const CUT_ANGLE := -0.05
const MOTTO_GAP := 0.3
## Where the short title card starts in the trailer audio (just before impact).
const SHORT_AUDIO_OFFSET := SWEEP_END - 0.35
const BLUR_GHOSTS := 4

var full := true
var reduce_motion := false
var elapsed := 0.0
var duration := FULL_DURATION
var quality := "balanced"
var audio_db := -6.0
var _level := 1
var _done := false
var _camera: Control
var _backdrop: ColorRect
var _stage: Control
var _far: Fx.LegionColumn
var _far_standards: Fx.StandardBearers
var _near: Fx.LegionColumn
var _near_standards: Fx.StandardBearers
var _fog_back: ColorRect
var _fog_front: ColorRect
var _banners: Array[Fx.Banner] = []
var _eagle: TextureRect
var _eagle_glow: TextureRect
var _embers: CPUParticles2D
var _title_clip: Control
var _title: Label
var _flare: TextureRect
var _motto: Label
var _cut: Node2D
var _sword: Sprite2D
var _ghosts: Array[Sprite2D] = []
var _streak: BladeStreak
var _blade_sparks: CPUParticles2D
var _impact_sparks: CPUParticles2D
var _blood: BloodStroke
var _flash: ColorRect
var _bars: Array[ColorRect] = []
var _sound: AudioStreamPlayer
var _sound_played := false
var _impact_fired := false
var _title_rect := Rect2()
var _eagle_home := Vector2.ZERO
var _portrait := false
var _content := Rect2()


## Blood trail: layered wet body with a moving specular line, drips with heavy
## heads and droplets flung off the blade. Deterministic for a given length.
class BloodStroke extends Node2D:
	var length := 0.0
	var reveal := 0.0
	var drip_time := 0.0
	var thickness := 10.0
	var _drips: Array[Dictionary] = []
	var _spray: Array[Dictionary] = []

	func configure(total: float, stroke: float) -> void:
		length = total
		thickness = stroke
		_drips.clear()
		_spray.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = 2611
		for index in range(12):
			var position := total * (0.05 + 0.9 * (index + rng.randf_range(-0.3, 0.3)) / 11.0)
			_drips.append({"x": position, "length": stroke * rng.randf_range(1.6, 5.2),
				"width": stroke * rng.randf_range(0.35, 0.62), "delay": rng.randf_range(0.12, 0.6),
				"speed": rng.randf_range(0.8, 1.6)})
		for index in range(26):
			_spray.append({"x": total * rng.randf_range(0.05, 1.0), "vx": stroke * rng.randf_range(8.0, 40.0),
				"vy": -stroke * rng.randf_range(4.0, 22.0), "size": stroke * rng.randf_range(0.12, 0.34)})
		queue_redraw()

	func set_state(revealed: float, seconds_after_cut: float) -> void:
		reveal = revealed
		drip_time = seconds_after_cut
		queue_redraw()

	func _width(x: float) -> float:
		var u := clampf(x / maxf(1.0, length), 0.0, 1.0)
		var taper := smoothstep(0.0, 0.06, u) * smoothstep(1.0, 0.8, u)
		return thickness * (0.3 + 0.7 * taper) * (0.85 + 0.15 * sin(x * 0.045))

	func _band(top: PackedVector2Array, bottom: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
		var shape := PackedVector2Array()
		for index in range(top.size()):
			shape.append(top[index].lerp(bottom[index], a))
		for index in range(top.size() - 1, -1, -1):
			shape.append(top[index].lerp(bottom[index], b))
		return shape

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
		# Darkening as it settles: fresh arterial red to deep wine.
		var settle := clampf(drip_time / 3.0, 0.0, 1.0)
		var edge := Color("3e0305").lerp(Color("2a0204"), settle)
		var body := Color("8c0b10").lerp(Color("6a070b"), settle)
		var core := Color("c3161b").lerp(Color("8f0d12"), settle)
		draw_colored_polygon(_band(top, bottom, -0.08, 1.08), edge)
		draw_colored_polygon(_band(top, bottom, 0.1, 0.86), body)
		draw_colored_polygon(_band(top, bottom, 0.22, 0.6), core)
		var shine := PackedVector2Array()
		for index in range(top.size()):
			shine.append(top[index].lerp(bottom[index], 0.26))
		draw_polyline(shine, Color(1.0, 0.62, 0.55, 0.42), maxf(1.0, thickness * 0.1), true)
		# A travelling glint sells the wet surface.
		var glint_x := fposmod(drip_time * length * 0.45, length * 1.6) - length * 0.3
		if glint_x > 0.0 and glint_x < visible_length:
			var gw := thickness * 3.0
			var gy := sin(glint_x * 0.021) * thickness * 0.18 - _width(glint_x) * 0.18
			draw_line(Vector2(glint_x - gw, gy), Vector2(glint_x + gw, gy), Color(1.0, 0.85, 0.8, 0.55), maxf(1.0, thickness * 0.12), true)
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
			var neck := w * (0.22 + 0.1 * (1.0 - grow))
			var body_shape := PackedVector2Array([Vector2(x - w * 0.55, base_y - 1.0), Vector2(x + w * 0.55, base_y - 1.0),
				Vector2(x + neck, tip.y - w * 0.45), Vector2(x - neck, tip.y - w * 0.45)])
			draw_colored_polygon(body_shape, body)
			draw_circle(tip, w * 0.46, body)
			draw_circle(tip + Vector2(w * 0.05, w * 0.05), w * 0.3, core)
			draw_circle(tip + Vector2(-w * 0.14, -w * 0.16), w * 0.12, Color(1.0, 0.7, 0.65, 0.55))
		# Droplets flung forward off the blade for half a second after it passes.
		for drop: Dictionary in _spray:
			var x0: float = drop.x
			if x0 > visible_length:
				continue
			var age := drip_time - (x0 / maxf(1.0, length)) * 0.85
			if age <= 0.0 or age > 0.7:
				continue
			var p := Vector2(x0 + float(drop.vx) * age, float(drop.vy) * age + 0.5 * thickness * 90.0 * age * age)
			var fade := 1.0 - age / 0.7
			var r: float = float(drop.size) * (0.6 + 0.4 * fade)
			draw_circle(p, r, Color(body, fade))
			draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1.0, 0.6, 0.55, 0.5 * fade))


## Hot streak behind the blade: the motion-blur smear of the edge.
class BladeStreak extends Node2D:
	var tip := 0.0
	var length := 0.0
	var thickness := 6.0
	var strength := 0.0

	func set_state(tip_x: float, trail: float, alpha: float) -> void:
		tip = tip_x
		length = trail
		strength = alpha
		queue_redraw()

	func _draw() -> void:
		if strength <= 0.01 or length <= 1.0:
			return
		var tail := tip - length
		var hot := Color(1.0, 0.95, 0.85, 0.85 * strength)
		var warm := Color(1.0, 0.6, 0.3, 0.0)
		draw_polygon(PackedVector2Array([Vector2(tail, 0), Vector2(tip, -thickness * 0.5), Vector2(tip, thickness * 0.5)]),
			PackedColorArray([warm, hot, hot]))
		var glow := Color(1.0, 0.7, 0.4, 0.25 * strength)
		draw_polygon(PackedVector2Array([Vector2(tail, 0), Vector2(tip, -thickness * 2.2), Vector2(tip, thickness * 2.2)]),
			PackedColorArray([warm, glow, glow]))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_level = Fx.effect_level(quality)
	_camera = Control.new()
	_camera.name = "Camera"
	_camera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_camera)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BackdropShader
	material.set_shader_parameter("detail", _level)
	_backdrop.material = material
	_camera.add_child(_backdrop)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera.add_child(_stage)
	if _level >= 1:
		_far = Fx.LegionColumn.new()
		_far.name = "FarCohort"
		_stage.add_child(_far)
		_far_standards = Fx.StandardBearers.new()
		_far_standards.name = "FarStandards"
		_far_standards.column = _far
		_far_standards.every = 4
		_stage.add_child(_far_standards)
		_fog_back = Fx.fog(_level)
		_fog_back.name = "FogBack"
		_stage.add_child(_fog_back)
	for side in range(2):
		var banner := Fx.Banner.new()
		banner.name = "Banner%s" % ("Left" if side == 0 else "Right")
		banner.phase = side * 2.3
		_stage.add_child(banner)
		_banners.append(banner)
	var aquila: Texture2D = load(RomanStyle.AQUILA_PATH)
	_eagle_glow = _texture_rect("AquilaGlow", aquila)
	_eagle_glow.material = Fx.additive()
	_eagle_glow.self_modulate = Color(1.0, 0.62, 0.25, 0.0)
	_eagle = _texture_rect("Aquila", aquila)
	var eagle_metal := Fx.metal_material(0.9)
	eagle_metal.set_shader_parameter("ramp", 0.0)
	_eagle.material = eagle_metal
	_near = Fx.LegionColumn.new()
	_near.name = "NearCohort"
	_stage.add_child(_near)
	_near_standards = Fx.StandardBearers.new()
	_near_standards.name = "NearStandards"
	_near_standards.column = _near
	_stage.add_child(_near_standards)
	_fog_front = Fx.fog(_level, Color(0.2, 0.07, 0.05))
	_fog_front.name = "FogFront"
	_stage.add_child(_fog_front)
	_flare = _texture_rect("TitleFlare", _flare_texture())
	_flare.stretch_mode = TextureRect.STRETCH_SCALE
	_flare.material = Fx.additive()
	_flare.self_modulate = Color(1.0, 0.7, 0.4, 0.0)
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
	_title.material = Fx.metal_material(1.0)
	_title_clip.add_child(_title)
	_motto = Label.new()
	_motto.name = "Motto"
	_motto.text = "VENI · VIDI · VICI"
	_motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motto.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_motto.material = Fx.metal_material(0.8)
	_stage.add_child(_motto)
	_cut = Node2D.new()
	_cut.name = "Cut"
	_stage.add_child(_cut)
	_blood = BloodStroke.new()
	_blood.name = "BloodTrail"
	_cut.add_child(_blood)
	_streak = BladeStreak.new()
	_streak.name = "BladeStreak"
	_streak.material = Fx.additive()
	_cut.add_child(_streak)
	var gladius: Texture2D = load(RomanStyle.GLADIUS_PATH)
	for index in range(BLUR_GHOSTS if _level >= 1 else 2):
		var ghost := Sprite2D.new()
		ghost.name = "GladiusBlur%d" % index
		ghost.texture = gladius
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ghost.modulate = Color(1.0, 0.9, 0.8, 0.32 / (index + 1.0))
		_cut.add_child(ghost)
		_ghosts.append(ghost)
	_sword = Sprite2D.new()
	_sword.name = "Gladius"
	_sword.texture = gladius
	_sword.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cut.add_child(_sword)
	_blade_sparks = Fx.sparks(14 if _level == 0 else 30)
	_blade_sparks.name = "BladeSparks"
	_blade_sparks.one_shot = false
	_blade_sparks.explosiveness = 0.0
	_blade_sparks.lifetime = 0.55
	_blade_sparks.direction = Vector2(-1, -0.6)
	_cut.add_child(_blade_sparks)
	_impact_sparks = Fx.sparks([40, 90, 150][_level])
	_impact_sparks.name = "ImpactSparks"
	_stage.add_child(_impact_sparks)
	_embers = Fx.embers([24, 56, 96][_level])
	_stage.add_child(_embers)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1.0, 0.92, 0.8, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.material = Fx.additive()
	add_child(_flash)
	for index in range(2):
		var bar := ColorRect.new()
		bar.name = "Letterbox%d" % index
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		_bars.append(bar)
	_sound = AudioStreamPlayer.new()
	_sound.name = "TrailerSound"
	if ResourceLoader.exists(TRAILER_PATH):
		_sound.stream = load(TRAILER_PATH)
	add_child(_sound)
	resized.connect(_layout)
	_layout()
	_apply()


func _exit_tree() -> void:
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null


func play(full_sequence: bool, reduced_motion: bool) -> void:
	full = full_sequence and not reduced_motion
	reduce_motion = reduced_motion
	duration = FULL_DURATION if full else SHORT_DURATION
	elapsed = 0.0
	_done = false
	_sound_played = false
	_impact_fired = false
	if is_instance_valid(_embers):
		_embers.emitting = not reduce_motion
	for banner in _banners:
		banner.set_wind(0.2 if reduce_motion else 1.0)
	_apply()


func set_quality(profile: String) -> void:
	quality = profile


func skip() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_sound) and _sound.playing:
		var fade := create_tween()
		fade.tween_property(_sound, "volume_db", -50.0, 0.4)
		fade.tween_callback(_sound.stop)
	finished.emit()


func is_done() -> bool:
	return _done


func advance(delta: float) -> void:
	if _done:
		return
	elapsed += delta
	if not _sound_played and _sound.stream != null:
		_sound_played = true
		if RomanStyle.audio_available():
			_sound.volume_db = audio_db
			_sound.play(0.0 if full else SHORT_AUDIO_OFFSET)
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
	_portrait = area.y > area.x * 1.15
	_camera.size = area
	_camera.pivot_offset = area * 0.5
	_backdrop.size = area
	_flash.size = area
	_stage.size = area
	# Cinemascope bars in landscape (2.39:1); phones in portrait use the full height.
	var bar := 0.0 if _portrait else maxf(0.0, (area.y - area.x / 2.39) * 0.5)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(area.x, bar)
	_bars[1].position = Vector2(0, area.y - bar)
	_bars[1].size = Vector2(area.x, bar)
	_content = Rect2(0, bar, area.x, area.y - bar * 2.0)
	var top := _content.position.y
	var h := _content.size.y
	var material := _backdrop.material as ShaderMaterial
	var eagle_width := minf(area.x * (0.92 if _portrait else 0.44), h * (1.0 if _portrait else 0.78))
	var eagle_size := Vector2(eagle_width, eagle_width * 760.0 / 1400.0)
	_eagle_home = Vector2(area.x * 0.5, top + h * (0.33 if _portrait else 0.3))
	for node: TextureRect in [_eagle, _eagle_glow]:
		node.size = eagle_size
		node.pivot_offset = eagle_size * 0.5
	(_eagle.material as ShaderMaterial).set_shader_parameter("extent", eagle_size)
	material.set_shader_parameter("focus", Vector2(0.5, _eagle_home.y / area.y))
	material.set_shader_parameter("aspect", area.x / area.y)
	# The title leaves room for the camera push-in (up to about 8 %).
	var title_size := _fit_title(area.x * (0.84 if _portrait else 0.7), h * 0.17)
	RomanStyle.style_title(_title, title_size)
	var title_height := title_size * 1.35
	var title_center_y := top + h * (0.53 if _portrait else 0.62)
	var title_width := minf(area.x * 0.9, RomanStyle.font(800, 4).get_string_size("IMPERATHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x + title_size * 0.4)
	_title_rect = Rect2((area.x - title_width) * 0.5, title_center_y - title_height * 0.5, title_width, title_height)
	_title.position = Vector2.ZERO
	_title.size = _title_rect.size
	_title_clip.position = _title_rect.position
	var title_material := _title.material as ShaderMaterial
	title_material.set_shader_parameter("extent", _title_rect.size)
	var cap := title_size * 0.36 / title_height
	title_material.set_shader_parameter("band", Vector2(0.5 - cap * 1.05, 0.5 + cap * 0.95))
	RomanStyle.style_caps(_motto, maxi(14, roundi(title_size * 0.38)), RomanStyle.GOLD_LIGHT, maxi(4, roundi(title_size * 0.14)))
	_motto.add_theme_constant_override("outline_size", maxi(3, roundi(title_size * 0.05)))
	_motto.size = Vector2(area.x, title_size * 0.62)
	_motto.position = Vector2(0, _title_rect.end.y + title_size * MOTTO_GAP)
	var motto_material := _motto.material as ShaderMaterial
	motto_material.set_shader_parameter("extent", _motto.size)
	motto_material.set_shader_parameter("band", Vector2(0.2, 0.8))
	_flare.size = Vector2(area.x * 1.2, maxf(10.0, title_size * 0.5))
	_flare.position = Vector2(-area.x * 0.1, title_center_y - _flare.size.y * 0.5)
	var text_width := RomanStyle.font(800, 4).get_string_size("IMPERATHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var stroke_length := minf(area.x * 0.98, text_width * 1.12)
	_cut.position = Vector2((area.x - stroke_length) * 0.5, title_center_y + title_size * 0.5)
	_cut.rotation = CUT_ANGLE
	_blood.configure(stroke_length, maxf(5.0, title_size * 0.13))
	var sword_length := clampf(area.x * 0.55, 260.0, 900.0)
	_sword.scale = Vector2.ONE * (sword_length / 1200.0)
	for ghost in _ghosts:
		ghost.scale = _sword.scale
	_streak.thickness = maxf(3.0, title_size * 0.07)
	_impact_sparks.position = Vector2(_cut.position.x + stroke_length * 0.92, _cut.position.y - stroke_length * 0.92 * sin(-CUT_ANGLE))
	# Parallax layers: far cohort on the horizon, near cohort cut by the frame.
	var bottom := _content.end.y
	if _far != null:
		var far_height := h * (0.17 if _portrait else 0.2)
		_far.position = Vector2(0, top + h * (0.74 if _portrait else 0.8))
		_far_standards.position = _far.position
		_far.configure(area.x * 1.1, far_height, int(area.x / (far_height * 0.36)) + 3, 77)
		_far.set_look(2.0 if _level >= 2 else 1.2, 0.55, 0.8, Color(0.09, 0.03, 0.025))
		_far.pace = 0.5
		_fog_back.position = Vector2(-area.x * 0.05, top + h * 0.55)
		_fog_back.size = Vector2(area.x * 1.1, h * 0.45)
		_set_fog(_fog_back, 0.7, area.x / (h * 0.45), 0.35)
	var near_height := h * (0.5 if _portrait else 0.66)
	_near.position = Vector2(0, bottom + near_height * 0.36)
	_near.configure(area.x * 1.1, near_height, int(area.x / (near_height * 0.36)) + 3, 19)
	_near.spacing = 0.5
	_near.set_look(0.0, 1.0, 1.0)
	_near.pace = 0.55
	_near_standards.position = _near.position
	_near_standards.clear_from = _title_rect.position.x + area.x * 0.08
	_near_standards.clear_to = _title_rect.end.x - area.x * 0.08
	_fog_front.position = Vector2(-area.x * 0.05, bottom - h * 0.16)
	_fog_front.size = Vector2(area.x * 1.1, h * 0.2)
	_set_fog(_fog_front, 0.55, area.x / (h * 0.2), 0.6)
	# Banners hang into the frame at the sides (portrait: from the top corners).
	var banner_w := minf(area.x * (0.2 if _portrait else 0.1), h * 0.2)
	var banner_h := h * (0.3 if _portrait else 0.58)
	for side in range(2):
		var banner := _banners[side]
		banner.size = Vector2(banner_w, banner_h)
		var x := area.x * (0.06 if side == 0 else 0.94) - banner_w * 0.5
		banner.position = Vector2(x, top - banner_w * 0.05)
	_embers.position = Vector2(area.x * 0.5, bottom + 10)
	_embers.emission_rect_extents = Vector2(area.x * 0.55, 8)
	_apply()


func _set_fog(rect: ColorRect, density: float, aspect: float, top_fade: float) -> void:
	var material := rect.material as ShaderMaterial
	material.set_shader_parameter("density", density)
	material.set_shader_parameter("aspect", aspect)
	material.set_shader_parameter("top_fade", top_fade)


func _fit_title(available_width: float, max_height: float) -> int:
	var probe := RomanStyle.font(800, 4)
	var desired := int(max_height)
	var measured := probe.get_string_size("IMPERATHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, desired).x
	if measured > available_width and measured > 0:
		desired = int(desired * available_width / measured)
	return maxi(28, desired)


## 1 at the hit, decaying with the given time constant; 0 before the hit.
func _kick(t: float, at: float, decay: float) -> float:
	return 0.0 if t < at else exp(-(t - at) / decay)


func _apply() -> void:
	if not is_instance_valid(_stage) or size.x < 8:
		return
	var area := size
	var t := elapsed
	var final_state := not full
	var calm := reduce_motion
	var fade_in := clampf(t / 0.6, 0.0, 1.0) if final_state else 1.0
	var fade_out := 1.0 - smoothstep(duration - (0.6 if final_state else FADE_OUT), duration, t)
	modulate.a = minf(fade_in, fade_out)
	var material := _backdrop.material as ShaderMaterial
	var clock := t + (8.0 if final_state else 0.0)
	material.set_shader_parameter("clock", clock)
	# Trailer beats: black, then each hit lights another layer.
	var legion_on := 1.0 if final_state else smoothstep(HIT_LEGION - 0.02, HIT_LEGION + 0.25, t)
	var standards_on := 1.0 if final_state else _ease_back(clampf((t - HIT_STANDARDS) / 0.45, 0.0, 1.0))
	var eagle_on := 1.0 if final_state else smoothstep(HIT_EAGLE, HIT_EAGLE + 1.2, t)
	var impact := 0.0 if final_state else _kick(t, SWEEP_END, 0.18)
	var hit_flash := 0.0
	if not final_state:
		for mark in [HIT_LEGION, HIT_STANDARDS, HIT_EAGLE]:
			hit_flash = maxf(hit_flash, _kick(t, mark, 0.09) * 0.55)
		for mark in MOTTO_WORDS:
			hit_flash = maxf(hit_flash, _kick(t, mark, 0.07) * 0.18)
	hit_flash = maxf(hit_flash, impact)
	material.set_shader_parameter("glow", 0.15 + 0.55 * legion_on + 0.3 * eagle_on)
	material.set_shader_parameter("rays", 0.25 * legion_on + 0.95 * eagle_on + impact * 0.8)
	material.set_shader_parameter("flash", hit_flash * 0.22)
	_flash.color.a = hit_flash * (0.12 if calm else 0.24)
	# Cohorts march through the haze; light from the eagle rims them.
	if _far != null:
		_far.set_clock(clock)
		_far.modulate.a = legion_on
		_far_standards.set_state(clock, standards_on)
		_far_standards.glow = 0.45 + 0.35 * eagle_on
		_far_standards.modulate.a = legion_on * 0.75
		(_fog_back.material as ShaderMaterial).set_shader_parameter("clock", clock)
		_fog_back.modulate.a = 0.35 + 0.65 * legion_on
	_near.set_clock(clock)
	_near.modulate.a = legion_on
	(_near.material as ShaderMaterial).set_shader_parameter("rim_strength", 0.5 + 0.7 * eagle_on + impact * 0.6)
	_near_standards.set_state(clock, standards_on)
	_near_standards.glow = 0.6 + 0.5 * eagle_on + impact * 0.4
	(_fog_front.material as ShaderMaterial).set_shader_parameter("clock", clock * 1.3)
	for banner in _banners:
		var drop := 1.0 if final_state else _ease_back(clampf((t - HIT_STANDARDS - 0.05) / 0.5, 0.0, 1.0))
		banner.set_clock(clock)
		banner.set_light(0.55 + 0.45 * eagle_on + impact * 0.4)
		banner.modulate.a = clampf(drop * 1.5, 0.0, 1.0)
		banner.position.y = _content.position.y - banner.size.x * 0.05 - (1.0 - drop) * banner.size.y * 0.6
	# Eagle rises from below into its place behind the title.
	var rise := 1.0 if final_state else _ease_out(clampf((t - HIT_EAGLE) / 1.6, 0.0, 1.0))
	var eagle_alpha := eagle_on
	var center := _eagle_home + Vector2(0, (1.0 - rise) * area.y * 0.4)
	for node: TextureRect in [_eagle, _eagle_glow]:
		node.position = center - node.size * 0.5
		node.scale = Vector2.ONE * (0.82 + 0.18 * rise)
	_eagle.modulate.a = eagle_alpha
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	_eagle_glow.self_modulate.a = eagle_alpha * (0.2 + 0.1 * pulse + impact * 0.4) * rise
	_eagle_glow.scale *= 1.03
	var eagle_sweep := clampf((t - (EAGLE_SHEEN if not final_state else 0.9)) / 1.1, 0.0, 1.0)
	(_eagle.material as ShaderMaterial).set_shader_parameter("sheen", lerpf(-0.4, 1.4, eagle_sweep) if eagle_sweep > 0.0 and eagle_sweep < 1.0 else -2.0)
	# Gladius sweep with motion blur, sparks and the blood trail along the cut line.
	var stroke := _blood.length
	var sweep := 1.0 if final_state else clampf((t - SWEEP_START) / (SWEEP_END - SWEEP_START), 0.0, 1.0)
	var eased := sweep * sweep * (3.0 - 2.0 * sweep)
	var sword_length := 1200.0 * _sword.scale.x
	var travel_from := -_cut.position.x - sword_length * 0.5
	var travel_to := area.x - _cut.position.x + sword_length * 0.6
	var tip := lerpf(travel_from + sword_length * 0.5, travel_to + sword_length * 0.5, eased)
	var speed := 6.0 * sweep * (1.0 - sweep)
	var sweeping := not final_state and sweep > 0.0 and sweep < 1.0
	_sword.position = Vector2(tip - sword_length * 0.5, -_blood.thickness * 0.2)
	_sword.visible = sweeping
	var span := travel_to - travel_from
	for index in range(_ghosts.size()):
		var ghost := _ghosts[index]
		ghost.visible = sweeping and not calm
		ghost.position = _sword.position - Vector2(span * speed * 0.028 * (index + 1), 0)
	_streak.set_state(tip - sword_length * 0.04, span * speed * 0.16, speed / 1.5 if sweeping and not calm else 0.0)
	_streak.position.y = _sword.position.y
	_blade_sparks.emitting = sweeping and not calm and tip > 0.0 and tip < stroke + sword_length * 0.2
	_blade_sparks.position = Vector2(clampf(tip - sword_length * 0.35, 0.0, stroke), 0)
	var revealed := clampf(tip - 18.0, 0.0, stroke) if not final_state else stroke
	var after_cut := 4.0 if final_state else maxf(0.0, t - SWEEP_START)
	_blood.set_state(revealed, after_cut)
	if not final_state and not _impact_fired and t >= SWEEP_END:
		_impact_fired = true
		if not calm:
			_impact_sparks.restart()
			_impact_sparks.emitting = true
	# The title appears where the blade has passed, then glows hot on impact.
	var tip_screen := _cut.position.x + tip * cos(_cut.rotation)
	var reveal_width := _title_rect.size.x if final_state else clampf(tip_screen - _title_rect.position.x, 0.0, _title_rect.size.x)
	_title_clip.size = Vector2(reveal_width, _title_rect.size.y)
	var title_material := _title.material as ShaderMaterial
	title_material.set_shader_parameter("heat", impact * 0.9)
	var title_sweep := clampf((t - (TITLE_SHEEN if not final_state else 0.5)) / 0.9, 0.0, 1.0)
	title_material.set_shader_parameter("sheen", lerpf(-0.3, 1.3, title_sweep) if title_sweep > 0.0 and title_sweep < 1.0 else -2.0)
	var flare := impact
	if not final_state:
		for mark in MOTTO_WORDS:
			flare = maxf(flare, _kick(t, mark, 0.12) * 0.35)
	flare = maxf(flare, 0.12 * (1.0 if t > SWEEP_END or final_state else 0.0))
	_flare.self_modulate.a = flare
	# VENI · VIDI · VICI lands word by word on the drum hits.
	var words := 3 if final_state else 0
	if not final_state:
		for mark in MOTTO_WORDS:
			if t >= mark:
				words += 1
	_motto.visible_characters = [0, 4, 11, -1][words]
	_motto.modulate.a = 1.0 if words > 0 else 0.0
	var word_punch := 0.0
	if not final_state and words > 0:
		word_punch = _kick(t, MOTTO_WORDS[words - 1], 0.1)
	_motto.pivot_offset = _motto.size * 0.5
	_motto.scale = Vector2.ONE * (1.0 + word_punch * (0.0 if calm else 0.06))
	_motto.position.y = _title_rect.end.y + _title.get_theme_font_size("font_size") * MOTTO_GAP
	(_motto.material as ShaderMaterial).set_shader_parameter("heat", word_punch * 0.5)
	# Camera: slow push-in with parallax drift, punch and shake on the hits.
	var progress := clampf(t / maxf(0.1, duration), 0.0, 1.0)
	var push := 0.0 if calm else 0.07 * _ease_out(progress)
	var punch := 0.0 if calm else impact * 0.035 + word_punch * 0.008
	_camera.scale = Vector2.ONE * (1.0 + push + punch)
	var drift := 0.0 if calm else lerpf(-1.0, 1.0, _ease_out(progress)) * area.x * 0.012
	if _far != null:
		_far.position.x = -drift * 0.5
		_far_standards.position = _far.position
	_near.position.x = drift * 1.6
	_near_standards.position = _near.position
	var shake := 0.0
	if not final_state and not calm:
		shake = impact * area.y * 0.02 + word_punch * area.y * 0.004
		for mark in [HIT_LEGION, HIT_STANDARDS, HIT_EAGLE]:
			shake = maxf(shake, _kick(t, mark, 0.08) * area.y * 0.006)
	_camera.position = Vector2(sin(t * 91.0), cos(t * 73.0)) * shake


func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _ease_back(value: float) -> float:
	if value <= 0.0:
		return 0.0
	if value >= 1.0:
		return 1.0
	var c := 1.6
	return 1.0 + (c + 1.0) * pow(value - 1.0, 3.0) + c * pow(value - 1.0, 2.0)


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


## Anamorphic lens streak for the impact: bright core fading to both sides.
func _flare_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.2, Color(1, 1, 1, 0.45))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var horizontal := GradientTexture2D.new()
	horizontal.gradient = gradient
	horizontal.width = 256
	horizontal.height = 16
	horizontal.fill = GradientTexture2D.FILL_RADIAL
	horizontal.fill_from = Vector2(0.5, 0.5)
	horizontal.fill_to = Vector2(1.0, 0.5)
	return horizontal
