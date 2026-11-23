extends Control
## North-up local map of the real authored houses; target comes from quest state.
const Layout = preload("res://scripts/world/village/village_layout.gd")
var view: Dictionary = {}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func update_view(value: Dictionary) -> void:
	if view==value:
		return
	view=value
	queue_redraw()

func _map(point: Vector2) -> Vector2:
	return Vector2(10+(point.x+60.0)/120.0*(size.x-20),23+(point.y+60.0)/100.0*(size.y-51))

func _draw() -> void:
	var bronze := Color("b99563")
	var cream := Color("eadfc9")
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(size.x*.5-5,16),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,13,bronze)
	var road := PackedVector2Array([_map(Vector2(0,-49)),_map(Vector2(0,28))])
	draw_polyline(road,Color("796f55"),2.0,true)
	for home: Dictionary in Layout.HOMES:
		var rect: Rect2=Layout.house_footprint(home)
		var at:=_map(rect.position)
		var end:=_map(rect.end)
		draw_rect(Rect2(at,end-at),Color("7e735f"))
	var player: Vector2=view.get("player",Vector2.ZERO)
	var at:=_map(player)
	var heading:=float(view.get("heading",0.0))
	var tip:=Vector2(0,-6).rotated(-heading)
	var right:=Vector2(4,4).rotated(-heading)
	var left:=Vector2(-4,4).rotated(-heading)
	if view.get("has_target",false):
		var target: Vector2=view.get("target",Vector2.ZERO)
		var mapped:=_map(target)
		draw_line(at,mapped,Color(bronze,.5),1.5,true)
		draw_circle(mapped,4,bronze)
		draw_arc(mapped,7,0,TAU,24,cream,1.0,true)
		var distance:=player.distance_to(target)
		draw_string(font,Vector2(10,size.y-9),"Ziel · %d m"%roundi(distance),HORIZONTAL_ALIGNMENT_LEFT,-1,13,cream)
	else:
		draw_string(font,Vector2(10,size.y-9),"Valdora",HORIZONTAL_ALIGNMENT_LEFT,-1,13,cream)
	draw_colored_polygon(PackedVector2Array([at+tip,at+right,at+left]),cream)

func _background() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.035,.065,.065,.9)
	style.border_color=Color("87724f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
