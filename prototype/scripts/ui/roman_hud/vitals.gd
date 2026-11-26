extends Control
## Vitality and stamina as two slim bronze gauges. The HUD director shows
## them only when they matter (damage, exertion, danger); at full strength in
## calm exploration they rest invisible.

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")

var health := 100.0:
	set(value):
		health = clampf(value, 0.0, 100.0)
		queue_redraw()
var stamina := 100.0:
	set(value):
		stamina = clampf(value, 0.0, 100.0)
		queue_redraw()
var show_stamina := true:
	set(value):
		show_stamina = value
		queue_redraw()
var _shown_health := 100.0
var _shown_stamina := 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	var step := delta * 60.0
	var next_health := move_toward(_shown_health, health, step)
	var next_stamina := move_toward(_shown_stamina, stamina, step)
	if next_health != _shown_health or next_stamina != _shown_stamina:
		_shown_health = next_health
		_shown_stamina = next_stamina
		queue_redraw()


func _draw() -> void:
	var rows: Array = [["LEBENSKRAFT", _shown_health, health]]
	if show_stamina:
		rows.append(["AUSDAUER", _shown_stamina, stamina])
	var font := Style.display_font(600, 2)
	var y := 2.0
	var width := size.x - 4.0
	for row: Array in rows:
		var value: float = row[1]
		var low := value < 35.0
		draw_string_outline(font, Vector2(2, y + 9), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.03, 0.02, 0.01, 0.8))
		draw_string(font, Vector2(2, y + 9), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Style.MINIUM.lightened(0.2) if low else Style.CHARTA_MUTED)
		var number := "%d" % roundi(float(row[2]))
		var number_width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(font, Vector2(width - number_width + 2, y + 9), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Style.CHARTA)
		var bar := Rect2(2, y + 13, width, 5)
		draw_rect(bar.grow(1.0), Color(0.03, 0.02, 0.015, 0.75))
		var fill := bar
		fill.size.x = bar.size.x * value / 100.0
		var top := Style.MINIUM if low else (Style.AERUGO if str(row[0]) == "AUSDAUER" else Style.AURUM)
		draw_rect(fill, top)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.5)), Color(1, 1, 1, 0.25))
		draw_rect(bar.grow(1.0), Color(Style.BRONZE, 0.85), false, 1.0)
		y += 26.0
