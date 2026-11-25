extends Node3D
## Independent first-person walk: no campaign, save or economy state.
const Field := preload("res://scripts/viva_country/country_field.gd")
const Sun := preload("res://scripts/viva_country/country_sun.gd")
const Pad := preload("res://scripts/ui/touch_pad.gd")
const Look := preload("res://scripts/ui/touch_look.gd")
var interactive := true
var field: Node3D
var daylight: Node3D
var player: CharacterBody3D
var camera: Camera3D
var built := false
var quality := "high"
var _axis := Vector2.ZERO
var _yaw := PI
var _pitch := -0.10
var _status: Label
var _hud_clock := 0.0

func _ready() -> void:
	field=Field.new()
	add_child(field)
	if not field.build():
		printerr("COUNTRY_BUILD_FAIL "+str(field.errors))
		set_physics_process(false)
		return
	daylight=Sun.new()
	add_child(daylight)
	player=CharacterBody3D.new()
	player.name="CountryWalker"
	player.collision_layer=2
	player.collision_mask=1
	player.floor_snap_length=0.28
	player.floor_max_angle=deg_to_rad(48.0)
	var capsule:=CapsuleShape3D.new()
	capsule.height=1.64
	capsule.radius=0.24
	var shape:=CollisionShape3D.new()
	shape.shape=capsule
	shape.position.y=0.82
	player.add_child(shape)
	add_child(player)
	var start: Array=field.manifest.probes[0]
	player.position=Vector3(start[0],start[1]+0.04,start[2])
	camera=Camera3D.new()
	camera.name="CountryEye"
	camera.position=Vector3(0,1.63,0)
	camera.fov=65.0
	camera.near=0.045
	camera.far=100.0
	player.add_child(camera)
	camera.current=true
	_update_look()
	_apply_quality("high")
	if interactive:
		_ui()
	else:
		set_physics_process(false)
	built=true

func _update_look() -> void:
	camera.rotation=Vector3(_pitch,_yaw,0)

func _look_by(delta: Vector2) -> void:
	_yaw=wrapf(_yaw-delta.x*0.004,-PI,PI)
	_pitch=clampf(_pitch-delta.y*0.003,-1.28,0.8)
	_update_look()

func _apply_quality(id: String) -> void:
	quality=id if Field.PROFILE.has(id) else "balanced"
	field.set_detail(quality,player.position,true)
	daylight.set_quality(quality)
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED if quality=="low" else Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size(1024 if quality=="low" else (2048 if quality=="balanced" else 4096),true)

func _ui() -> void:
	var layer:=CanvasLayer.new()
	add_child(layer)
	var root_control:=Control.new()
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var look:=Look.new()
	root_control.add_child(look)
	look.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look.look_changed.connect(_look_by)
	var pad:=Pad.new()
	root_control.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left=18
	pad.offset_top=-190
	pad.offset_right=190
	pad.offset_bottom=-18
	pad.axis_changed.connect(func(v:Vector2): _axis=v)
	var row:=HBoxContainer.new()
	row.position=Vector2(16,16)
	row.add_theme_constant_override("separation",8)
	root_control.add_child(row)
	for config: Array in [["Licht",["morning","noon","afternoon"],["Morgen","Mittag","Nachmittag"],2],["Grafik",["low","balanced","high","very_high"],["Leicht","Ausgewogen","Hoch","Sehr hoch"],2]]:
		var picker:=OptionButton.new()
		picker.custom_minimum_size=Vector2(148,48)
		picker.focus_mode=Control.FOCUS_NONE
		for caption: String in config[2]:
			picker.add_item(caption)
		picker.select(int(config[3]))
		var ids: Array=config[1]
		if config[0]=="Licht":
			picker.item_selected.connect(func(index:int): daylight.set_daylight(ids[index]))
		else:
			picker.item_selected.connect(func(index:int): _apply_quality(ids[index]))
		row.add_child(picker)
	_status=Label.new()
	_status.position=Vector2(18,76)
	_status.add_theme_color_override("font_shadow_color",Color.BLACK)
	_status.add_theme_constant_override("shadow_offset_x",1)
	_status.add_theme_constant_override("shadow_offset_y",2)
	_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root_control.add_child(_status)

func _physics_process(delta: float) -> void:
	if not built:
		return
	var axis:=_axis
	axis.x+=float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
	axis.y+=float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))
	axis=axis.limit_length(1.0)
	var direction:=Vector3(axis.x,0,axis.y).rotated(Vector3.UP,_yaw)
	var target:=direction*1.45
	player.velocity.x=move_toward(player.velocity.x,target.x,delta*5.0)
	player.velocity.z=move_toward(player.velocity.z,target.z,delta*5.0)
	player.velocity.y=-0.35 if player.is_on_floor() else player.velocity.y-19.6*delta
	player.move_and_slide()
	var position:=player.position
	position.z=clampf(position.z,0.5,35.5)
	position.x=clampf(position.x,Field.center(position.z)-9.2,Field.center(position.z)+9.2)
	player.position=position
	if player.position.y < -2.0:
		var start: Array=field.manifest.probes[0]
		player.position=Vector3(start[0],start[1]+0.1,start[2])
		player.velocity=Vector3.ZERO
	field.set_detail(quality,player.position)
	_hud_clock+=delta
	if _status!=null and _hud_clock>0.3:
		_hud_clock=0
		_status.text="VIVA ROMA · FELDWEG 01\nWASD / Stick · Umsehen: Wischen / rechte Maustaste\n%d Grasbüschel · %d Kiesel · %d Quelldreiecke" % [field.counts.grass,field.counts.stones,field.counts.triangles]

func _unhandled_input(event: InputEvent) -> void:
	if interactive and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_look_by(event.relative)
