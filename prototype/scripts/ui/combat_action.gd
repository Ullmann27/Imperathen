extends "res://scripts/ui/touch_action.gd"
## Original vector glyphs. Text stays visible for readability and accessibility.
var glyph := "fist"

func _draw() -> void:
	var c:=Color("e4ca9b")
	var p:=Vector2(19,size.y*.5)
	if glyph=="fist":
		var points:=PackedVector2Array([p+Vector2(-8,6),p+Vector2(-9,-3),p+Vector2(-5,-7),p+Vector2(4,-7),p+Vector2(8,-3),p+Vector2(7,5),p+Vector2(1,8),p+Vector2(-8,6)])
		draw_polyline(points,c,2.0,true)
		for x in [-4,0,4]:
			draw_line(p+Vector2(x,-5),p+Vector2(x,0),c,1.0,true)
	elif glyph=="kick":
		draw_polyline(PackedVector2Array([p+Vector2(-5,-9),p+Vector2(-1,0),p+Vector2(7,4),p+Vector2(10,4)]),c,3.0,true)
		draw_line(p+Vector2(-1,0),p+Vector2(-6,9),c,2.0,true)
	elif glyph=="guard":
		draw_polyline(PackedVector2Array([p+Vector2(-8,-7),p+Vector2(0,-10),p+Vector2(8,-7),p+Vector2(6,4),p+Vector2(0,10),p+Vector2(-6,4),p+Vector2(-8,-7)]),c,2.0,true)
	elif glyph=="head":
		draw_circle(p,7,c,false,2.0,true)
		draw_line(p+Vector2(5,-5),p+Vector2(11,-5),c,2.0,true)
	else:
		draw_arc(p,8,-PI*.7,PI*.7,20,c,2,true)
		draw_line(p+Vector2(6,-5),p+Vector2(11,-4),c,2,true)
