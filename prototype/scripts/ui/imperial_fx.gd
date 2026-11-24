extends RefCounted
## Cinematic set pieces shared by the title sequence and the main menu: marching
## legion silhouettes (rendered in Blender from the project's own field company
## rigs), standard bearers with vexilla and signa, hanging red-and-gold banners,
## torches, drifting fog and embers. Effect density follows the graphics profile.

const RomanStyle = preload("res://scripts/ui/roman_style.gd")
const FxKit = preload("res://scripts/ui/imperial_fx.gd")
const LEGION_ATLAS := "res://assets/ui/legion_march.png"
const SilhouetteShader = preload("res://shaders/legion_silhouette.gdshader")
const BannerShader = preload("res://shaders/roman_banner.gdshader")
const FlameShader = preload("res://shaders/torch_flame.gdshader")
const FogShader = preload("res://shaders/drifting_fog.gdshader")
const MetalShader = preload("res://shaders/imperial_metal.gdshader")

## Atlas layout written by tools/ui/render_legion_silhouettes.py.
const ATLAS_FRAMES := 12
const ATLAS_CELL := Vector2(192, 288)
const CELL_METRES := 2.6
const STRIDE_METRES := 1.3
const ROLE_HEAVY := 0
const ROLE_SPEAR := 1
const ROLE_OFFICER := 2


## 0 = light (phones on "Leicht"), 1 = balanced, 2 = high / very high.
static func effect_level(profile: String) -> int:
	match profile:
		"low": return 0
		"high", "very_high": return 2
	return 1


static func metal_material(sheen_strength := 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MetalShader
	material.set_shader_parameter("sheen_strength", sheen_strength)
	return material


static func soft_dot(size := 32) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.35, Color(1, 1, 1, 0.45))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = size
	texture.height = size
	return texture


static func additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


static func embers(amount: int, lifetime := 6.0) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "Embers"
	particles.amount = maxi(1, amount)
	particles.lifetime = lifetime
	particles.preprocess = lifetime * 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.direction = Vector2(0.15, -1.0)
	particles.spread = 22.0
	particles.gravity = Vector2(6, -10)
	particles.initial_velocity_min = 25.0
	particles.initial_velocity_max = 70.0
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.45
	particles.texture = soft_dot(32)
	particles.material = additive()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.4, 0.0))
	ramp.add_point(0.12, Color(1.0, 0.72, 0.3, 0.95))
	ramp.add_point(0.7, Color(1.0, 0.45, 0.15, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.9, 0.25, 0.1, 0.0))
	particles.color_ramp = ramp
	return particles


static func sparks(amount: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "Sparks"
	particles.amount = maxi(1, amount)
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.emitting = false
	particles.direction = Vector2(1, -0.4)
	particles.spread = 75.0
	particles.gravity = Vector2(0, 900)
	particles.initial_velocity_min = 260.0
	particles.initial_velocity_max = 900.0
	particles.damping_min = 40.0
	particles.damping_max = 120.0
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.16
	particles.texture = soft_dot(32)
	particles.material = additive()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.85, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.75, 0.3, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.3, 0.05, 0.0))
	particles.color_ramp = ramp
	return particles


static func fog(level: int, tint := Color(0.32, 0.12, 0.08)) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Fog"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FogShader
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("detail", level)
	rect.material = material
	return rect


## A cohort marching across the frame. One draw call per column: every figure is
## a region of the shared atlas and the silhouette shader adds rim light and blur.
class LegionColumn extends Node2D:
	var clock := 0.0
	var span := 1280.0
	var figure_height := 220.0
	var spacing := 0.55
	var pace := 0.75
	var roles: Array[int] = []
	var offsets: Array[float] = []
	var lift: Array[float] = []
	var _atlas: Texture2D

	func _init() -> void:
		_atlas = load(LEGION_ATLAS)
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SilhouetteShader
		material = shader_material
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	## Ranks: count figures per row, a deterministic role pattern and small
	## height and spacing variations so the line does not look stamped.
	func configure(width: float, height: float, count: int, seed: int) -> void:
		span = width
		figure_height = height
		roles.clear()
		offsets.clear()
		lift.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for index in range(count):
			var role := ROLE_SPEAR if index % 3 == 1 else ROLE_HEAVY
			if index % 7 == 3:
				role = ROLE_OFFICER
			roles.append(role)
			offsets.append(rng.randf_range(-0.12, 0.12))
			lift.append(rng.randf_range(-0.03, 0.03))
		queue_redraw()

	func set_look(blur: float, rim_strength: float, opacity: float, body := Color(0.03, 0.018, 0.016)) -> void:
		var shader_material := material as ShaderMaterial
		shader_material.set_shader_parameter("blur", blur)
		shader_material.set_shader_parameter("rim_strength", rim_strength)
		shader_material.set_shader_parameter("opacity", opacity)
		shader_material.set_shader_parameter("body", body)

	func set_clock(seconds: float) -> void:
		clock = seconds
		queue_redraw()

	func figure_count() -> int:
		return roles.size()

	## Screen-space base point (feet) and atlas cell of figure index.
	func figure(index: int) -> Dictionary:
		var cell_width := figure_height * ATLAS_CELL.x / ATLAS_CELL.y
		var step := cell_width * spacing
		var metres_px := figure_height / CELL_METRES
		var travel := clock * pace * STRIDE_METRES * metres_px
		var length := step * roles.size()
		var x := fposmod(index * step + offsets[index] * step + travel, maxf(length, span + cell_width * 2.0)) - cell_width
		var cycle := clock * pace + float(index) * 0.37
		var frame := int(floor(fposmod(cycle, 1.0) * ATLAS_FRAMES)) % ATLAS_FRAMES
		var scale := 1.0 + lift[index]
		return {"x": x, "scale": scale, "frame": frame, "role": roles[index], "cell_width": cell_width}

	func _draw() -> void:
		if _atlas == null:
			return
		for index in range(roles.size()):
			var info := figure(index)
			var h: float = figure_height * float(info.scale)
			var w: float = float(info.cell_width) * float(info.scale)
			var region := Rect2(Vector2(int(info.frame) * ATLAS_CELL.x, int(info.role) * ATLAS_CELL.y), ATLAS_CELL)
			draw_texture_rect_region(_atlas, Rect2(float(info.x), -h, w, h), region)


## Standards raised above a column: red-and-gold vexilla and signa with phalerae.
class StandardBearers extends Node2D:
	var column: LegionColumn
	var every := 5
	var raise := 1.0
	var clock := 0.0
	var glow := 1.0
	## Horizontal span (local x) kept free of standards, e.g. behind the title.
	var clear_from := 0.0
	var clear_to := 0.0

	func set_state(seconds: float, raised: float) -> void:
		clock = seconds
		raise = raised
		queue_redraw()

	func _draw() -> void:
		if column == null or raise <= 0.001:
			return
		var h := column.figure_height
		for index in range(1, column.figure_count(), every):
			var info := column.figure(index)
			var cx: float = float(info.x) + float(info.cell_width) * 0.5
			var margin := h * 0.35
			if clear_to > clear_from and cx > clear_from - margin and cx < clear_to + margin:
				continue
			var bob := sin(clock * column.pace * TAU * 2.0 + index) * h * 0.008
			var pole_top := Vector2(cx + h * 0.02, -h * (0.62 + 0.55 * raise) + bob)
			var pole_bottom := Vector2(cx - h * 0.01, -h * 0.32)
			var dark := Color(0.04, 0.025, 0.02)
			draw_line(pole_bottom, pole_top, dark, maxf(1.5, h * 0.016), true)
			var gold := Color(0.95, 0.72, 0.32) * Color(glow, glow, glow)
			if (index / every) % 2 == 0:
				_vexillum(pole_top, h, gold, index)
			else:
				_signum(pole_top, h, gold)

	func _vexillum(top: Vector2, h: float, gold: Color, index: int) -> void:
		var w := h * 0.3
		var cloth_h := h * 0.26
		var bar_y := top.y + h * 0.05
		draw_line(Vector2(top.x - w * 0.6, bar_y), Vector2(top.x + w * 0.6, bar_y), gold.darkened(0.25), maxf(1.5, h * 0.014), true)
		draw_circle(top, h * 0.018, gold)
		var columns := 6
		var rows := 4
		for row in range(rows):
			for col in range(columns):
				var quad := PackedVector2Array()
				var shades := PackedColorArray()
				for corner in [Vector2(col, row), Vector2(col + 1, row), Vector2(col + 1, row + 1), Vector2(col, row + 1)]:
					var u: float = corner.x / columns
					var v: float = corner.y / rows
					var wave := sin(clock * 2.4 + u * 5.0 + index) * h * 0.022 * v
					quad.append(Vector2(top.x - w * 0.5 + u * w + wave, bar_y + v * cloth_h))
					var light := 0.75 + 0.35 * cos(clock * 2.4 + u * 5.0 + index)
					var red := Color(0.62, 0.06, 0.05) * Color(light, light, light) * Color(glow, glow, glow)
					shades.append(red)
				draw_polygon(quad, shades)
		var fringe_y := bar_y + cloth_h
		var left := Vector2(top.x - w * 0.5 + sin(clock * 2.4 + index) * h * 0.022, fringe_y)
		var right := Vector2(top.x + w * 0.5 + sin(clock * 2.4 + 5.0 + index) * h * 0.022, fringe_y)
		draw_line(left, right, gold, maxf(1.5, h * 0.014), true)
		draw_line(Vector2(top.x - w * 0.5, bar_y), Vector2(top.x - w * 0.5, fringe_y), gold.darkened(0.2), maxf(1.0, h * 0.008), true)
		draw_line(Vector2(top.x + w * 0.5, bar_y), Vector2(top.x + w * 0.5, fringe_y), gold.darkened(0.2), maxf(1.0, h * 0.008), true)

	func _signum(top: Vector2, h: float, gold: Color) -> void:
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -h * 0.07), top + Vector2(h * 0.02, 0), top + Vector2(-h * 0.02, 0)]), gold)
		draw_arc(top + Vector2(0, h * 0.06), h * 0.045, 0.2, PI - 0.2, 12, gold, maxf(1.5, h * 0.012), true)
		for disc in range(4):
			var c := top + Vector2(0, h * (0.14 + disc * 0.075))
			draw_circle(c, h * 0.03, gold.darkened(0.15))
			draw_circle(c + Vector2(-h * 0.008, -h * 0.008), h * 0.012, gold.lightened(0.3))


## Hanging vexillum-style banner on a crossbar, moved by the banner shader.
class Banner extends Control:
	var cloth: ColorRect
	var wind := 1.0
	var phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloth = ColorRect.new()
		cloth.name = "Cloth"
		cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = BannerShader
		shader_material.set_shader_parameter("emblem", load(RomanStyle.AQUILA_PATH))
		shader_material.set_shader_parameter("phase", phase)
		shader_material.set_shader_parameter("wind", wind)
		cloth.material = shader_material
		add_child(cloth)
		resized.connect(_layout)
		_layout()

	func set_clock(seconds: float) -> void:
		if cloth != null:
			(cloth.material as ShaderMaterial).set_shader_parameter("clock", seconds)

	func set_light(value: float) -> void:
		if cloth != null:
			(cloth.material as ShaderMaterial).set_shader_parameter("light", value)

	func set_wind(value: float) -> void:
		wind = value
		if cloth != null:
			(cloth.material as ShaderMaterial).set_shader_parameter("wind", value)

	func _layout() -> void:
		if cloth == null:
			return
		var bar := maxf(4.0, size.x * 0.06)
		cloth.position = Vector2(size.x * 0.08, bar * 0.6)
		cloth.size = Vector2(size.x * 0.84, maxf(1.0, size.y - bar * 0.6))
		var emblem_w := 0.7
		var emblem_h := emblem_w * cloth.size.x / 1.842 / maxf(1.0, cloth.size.y)
		(cloth.material as ShaderMaterial).set_shader_parameter("emblem_rect", Vector4(0.15, 0.2, emblem_w, emblem_h))
		queue_redraw()

	func _draw() -> void:
		var bar := maxf(4.0, size.x * 0.06)
		var bronze_dark := Color(0.32, 0.2, 0.09)
		var gold := Color(0.92, 0.72, 0.36)
		draw_rect(Rect2(0, 0, size.x, bar), bronze_dark)
		draw_rect(Rect2(0, 0, size.x, bar * 0.38), gold)
		for x in [0.0, size.x]:
			draw_circle(Vector2(x, bar * 0.5), bar * 0.75, gold)
			draw_circle(Vector2(x, bar * 0.5), bar * 0.4, bronze_dark)


## Wall torch: iron bracket, additive flame shader, a pulsing halo and sparks.
class Torch extends Control:
	var level := 1
	var calm := false
	var seed := 0.0
	var _flame: ColorRect
	var _halo: TextureRect
	var _sparks: CPUParticles2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_halo = TextureRect.new()
		_halo.name = "Halo"
		_halo.texture = FxKit.soft_dot(64)
		_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_halo.material = FxKit.additive()
		_halo.self_modulate = Color(1.0, 0.55, 0.2, 0.45)
		add_child(_halo)
		_flame = ColorRect.new()
		_flame.name = "Flame"
		_flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = FlameShader
		shader_material.set_shader_parameter("seed", seed)
		_flame.material = shader_material
		add_child(_flame)
		if level >= 1 and not calm:
			_sparks = CPUParticles2D.new()
			_sparks.name = "TorchSparks"
			_sparks.amount = 6 if level == 1 else 12
			_sparks.lifetime = 1.6
			_sparks.preprocess = 1.0
			_sparks.direction = Vector2(0, -1)
			_sparks.spread = 20.0
			_sparks.gravity = Vector2(4, -30)
			_sparks.initial_velocity_min = 20.0
			_sparks.initial_velocity_max = 55.0
			_sparks.scale_amount_min = 0.05
			_sparks.scale_amount_max = 0.12
			_sparks.texture = FxKit.soft_dot(32)
			_sparks.material = FxKit.additive()
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
			ramp.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
			_sparks.color_ramp = ramp
			add_child(_sparks)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		if _flame == null:
			return
		var w := size.x
		_flame.size = Vector2(w, w * 1.7)
		_flame.position = Vector2(0, -w * 1.25)
		_halo.size = Vector2(w * 6.0, w * 6.0)
		_halo.position = Vector2(w * 0.5, -w * 0.5) - _halo.size * 0.5
		if _sparks != null:
			_sparks.position = Vector2(w * 0.5, -w * 0.6)
		queue_redraw()

	func _process(_delta: float) -> void:
		if _halo == null:
			return
		var t := Time.get_ticks_msec() / 1000.0 + seed * 5.0
		_halo.self_modulate.a = 0.42 + 0.08 * sin(t * 9.0) * sin(t * 5.3)

	func _draw() -> void:
		var w := size.x
		var iron := Color(0.07, 0.055, 0.045)
		var rim := Color(0.55, 0.36, 0.18)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12, 0), Vector2(w * 0.88, 0), Vector2(w * 0.66, w * 0.55), Vector2(w * 0.34, w * 0.55)]), iron)
		draw_line(Vector2(w * 0.12, 0), Vector2(w * 0.88, 0), rim, maxf(1.0, w * 0.06), true)
		draw_rect(Rect2(w * 0.42, w * 0.55, w * 0.16, w * 1.6), iron)
		draw_line(Vector2(w * 0.5, w * 1.4), Vector2(w * 1.4, w * 1.9), iron, maxf(1.5, w * 0.1), true)
