extends Node3D
## Batched silhouettes. Transforms supplied to sync() are local to this node.
## Instance color carries the previous root transform, never a pigment tint.

const TribalFigure := preload("res://scripts/visuals/valley_tribal_soldier.gd")
const SoldierVisual = preload("res://scripts/visuals/soldier_visual.gd")
const STANCE := {"march":.58,"run":.40,"retreat":.51}
const CLEARANCE := {"march":.106,"run":.19,"retreat":.134}
const MODES := {"idle":0,"march":1,"run":2,"retreat":3,"attack":4,"shoot":5,
	"block":6,"wall":7,"testudo":8,"hit":9,"death":10}
var _batches: Dictionary = {}
var _last_fraction := -1.0
var instance_tracks: Dictionary = {}


static func gait_data(pose: String, phase0: float, phase1: float) -> Color:
	return Color(phase0,phase1-phase0,float(SoldierVisual.STRIDES.get(pose,0.0)),float(MODES.get(pose,0)))


static func root_data(start: Transform3D, finish: Transform3D) -> Color:
	var offset := finish.basis.inverse()*(start.origin-finish.origin)
	var start_yaw := atan2(start.basis.z.x,start.basis.z.z)
	var end_yaw := atan2(finish.basis.z.x,finish.basis.z.z)
	return Color(offset.x,offset.y,offset.z,wrapf(start_yaw-end_yaw,-PI,PI))


static func interpolated_root(finish: Transform3D, previous: Color, fraction: float) -> Transform3D:
	var remaining := 1.0-clampf(fraction,0.0,1.0)
	return Transform3D(finish.basis*Basis(Vector3.UP,previous.a*remaining),
		finish.origin+finish.basis*Vector3(previous.r,previous.g,previous.b)*remaining)


static func foot_offset(phase: float, gait: String) -> Vector3:
	# Same stance/swing equations and uniform values as rank_stride.gdshader.
	# During stance d(z)/d(phase) = -stride: root travel cancels foot travel.
	if not STANCE.has(gait):
		return Vector3.ZERO
	var t := fposmod(phase,1.0)
	var stance := float(STANCE[gait])
	var stride := float(SoldierVisual.STRIDES[gait])
	if t <= stance:
		return Vector3(0,0,stride*(stance*.5-t))
	var u := (t-stance)/(1.0-stance)
	var u2 := u*u
	var u3 := u2*u
	var tangent := -stride*(1.0-stance)
	var z := (2*u3-3*u2+1)*(-stride*stance*.5)+(u3-2*u2+u)*tangent
	z += (-2*u3+3*u2)*(stride*stance*.5)+(u3-u2)*tangent
	return Vector3(0,float(CLEARANCE[gait])*pow(sin(PI*u),2),z)


## The company source bakes axial bone rotations at 25 FPS, including
## both endpoints. Interpolate those actual authored keys rather than
## applying an ideal continuous ankle trajectory to an unarticulated leg.
## Shared key order: each gait, right then left, frames 0 through N.
const GAIT_NAMES := ["march", "run", "retreat"]
const GAIT_FRAMES := [25, 18, 22]
const GAIT_BASES := [0, 52, 90]
static var _authored_gait_keys := PackedVector4Array()


static func _source_gait_key(name: String, phase: float, left: bool) -> Vector4:
	# Same lower-body equations as art/soldiers/build.py::locomotion.
	var lift := -.068-.062*cos(TAU*phase*2.0) if name == "run" else -.088-.035*cos(TAU*phase*2.0)
	var cycle := fposmod(phase+(.5 if left else 0.0),1.0)
	var stance := float(STANCE[name])
	var stride := float(SoldierVisual.STRIDES[name])
	var foot_y := 0.0
	var foot_height := 0.0
	var foot_pitch := 0.0
	if cycle <= stance:
		foot_y = stride*(cycle-stance*.5)
	else:
		var u := (cycle-stance)/(1.0-stance)
		foot_y = stride*(stance*.5+(1.0-stance)*u-u*u*(3.0-2.0*u))
		foot_height = float(CLEARANCE[name])*pow(sin(PI*u),2.0)
		foot_pitch = deg_to_rad(14.0)*sin(TAU*u)*sin(PI*u)
	var vertical := .89+lift-(.12+foot_height)
	var a := Vector2(.4,.012).length()
	var b := Vector2(.37,.012).length()
	var reach := minf(Vector2(foot_y,vertical).length(),a+b-.00001)
	var hip := atan2(foot_y,vertical)-acos(clampf((a*a+reach*reach-b*b)/(2.0*a*reach),-1.0,1.0))
	var bend := PI-acos(clampf((a*a+b*b-reach*reach)/(2.0*a*b),-1.0,1.0))
	var thigh := hip-atan2(-.012,.4)
	var shin := bend-(atan2(.012,.37)-atan2(-.012,.4))
	return Vector4(thigh,shin,foot_pitch-thigh-shin,lift)


static func authored_gait_keys() -> PackedVector4Array:
	if _authored_gait_keys.is_empty():
		for index in range(GAIT_NAMES.size()):
			var name: String = GAIT_NAMES[index]
			var count: int = GAIT_FRAMES[index]
			for left: bool in [false,true]:
				for frame in range(count+1):
					_authored_gait_keys.append(_source_gait_key(name,float(frame)/float(count),left))
	return _authored_gait_keys


static func _sample_authored_gait(mode: int, phase: float, left: bool) -> Vector4:
	var keys := authored_gait_keys()
	var count: int = GAIT_FRAMES[mode-1]
	var base: int = GAIT_BASES[mode-1]+(count+1 if left else 0)
	var frame := fposmod(phase,1.0)*float(count)
	var index := mini(int(floor(frame)),count-1)
	return keys[base+index].lerp(keys[base+index+1],clampf(frame-float(index),0.0,1.0))


static func _gait_vertex(vertex: Vector3, mode: int, phase: float) -> Vector3:
	var side := -1.0 if vertex.x < 0.0 else 1.0
	var name: String = GAIT_NAMES[mode-1]
	var cycle := fposmod(phase+(.5 if side>0.0 else 0.0),1.0)
	var support: float = STANCE[name]
	var u := clampf((cycle-support)/(1.0-support),0.0,1.0)
	var pitch := deg_to_rad(14.0)*sin(TAU*u)*sin(PI*u)
	var key := _sample_authored_gait(mode,phase,side>0.0)
	# Blender (x,y,z) -> Godot (x,z,-y). Blend the authored leg joints into the skirt.
	var hip := Vector3(side*.105,.89,0.0)
	var knee := Vector3(side*.119,.49,.012)
	var ankle := Vector3(side*.126,.12,0.0)
	var thigh_rotation := Basis(Vector3.RIGHT,key.x)
	var shin_rotation := Basis(Vector3.RIGHT,key.y)
	var upper := hip+thigh_rotation*(vertex-hip)
	var lower := hip+thigh_rotation*(knee+shin_rotation*(vertex-knee)-hip)
	# Use the continuous authored contact path at the sole; interpolation
	# of the upper joints alone causes the planted foot to slide.
	var foot := ankle+Basis(Vector3.RIGHT,pitch)*(vertex-ankle)+foot_offset(cycle,name)-Vector3.UP*key.w
	var ankle_weight := 1.0-smoothstep(.10,.19,vertex.y)
	var shin_weight := 1.0-smoothstep(.40,.58,vertex.y)
	var leg_weight := (1.0-smoothstep(.205,.27,absf(vertex.x)))*(1.0-smoothstep(.75,.95,vertex.y))
	return vertex.lerp(upper.lerp(lower.lerp(foot,ankle_weight),shin_weight),leg_weight)+Vector3.UP*key.w


## Shared company source (art/soldiers/build.py): brace clips bend the
## left thigh -17 degrees and shin +27 degrees, with a grounded pelvis.
## Foot vertices follow both hinges; the upper leg blends across the knee.
## The tiny lift is the source's .011 m floor minus the lowest transformed
## canonical sole, not a per-model fitted correction.
static func guard_vertex(vertex: Vector3) -> Vector3:
	var hip := Vector3(.105, .89, 0.0)
	var knee := Vector3(.119, .49, .012)
	var thigh_rotation := Basis(Vector3.RIGHT, deg_to_rad(-17.0))
	var shin_rotation := Basis(Vector3.RIGHT, deg_to_rad(27.0))
	var upper := hip + thigh_rotation * (vertex - hip)
	var shin := knee + shin_rotation * (vertex - knee)
	var lower := hip + thigh_rotation * (shin - hip)
	var shin_weight := 1.0 - smoothstep(.40, .58, vertex.y)
	var leg_weight := smoothstep(0.0, .04, vertex.x) * (1.0 - smoothstep(.22, .30, absf(vertex.x))) * (1.0 - smoothstep(.75, .95, vertex.y))
	return vertex.lerp(upper.lerp(lower, shin_weight), leg_weight) + Vector3.UP * .0000410085811


static func deformed_vertex(vertex: Vector3, gait: Color, fraction: float) -> Vector3:
	# CPU mirror for numeric regression. A GPU capture is still required to
	# approve the shader/material/mesh combination on the visible play path.
	var mode := int(round(gait.a))
	var phase := gait.r+clampf(fraction,0.0,1.0)*gait.g
	if mode >= 1 and mode <= 3:
		return _gait_vertex(vertex,mode,phase)
	if mode >= 6 and mode <= 8:
		vertex = guard_vertex(vertex)
	var lean := _upper_lean(phase,mode)
	var weight := smoothstep(.65,1.18,vertex.y)
	var pivot := Vector3(0,.8,0)
	return vertex.lerp(pivot+Basis(Vector3.RIGHT,lean)*(vertex-pivot),weight)


static func _upper_lean(phase: float, mode: int) -> float:
	var pulse := sin(PI*clampf(phase,0.0,1.0))
	match mode:
		4: return -.16*pulse
		5: return -.06*pulse
		6: return .08*pulse
		7: return .045
		8: return .07
		9: return .22*pulse
		10: return 1.35*clampf(phase,0.0,1.0)
	return .006*sin(TAU*phase)


func set_step_fraction(fraction: float) -> void:
	fraction = clampf(fraction,0.0,1.0)
	if is_equal_approx(_last_fraction,fraction):
		return
	_last_fraction = fraction
	for batch: MultiMeshInstance3D in _batches.values():
		if batch.visible:
			batch.material_override.set_shader_parameter("step_fraction",fraction)


func sync(by_role: Dictionary, gait_by_role: Dictionary = {}, starts_by_role: Dictionary = {}) -> void:
	for role: String in SoldierVisual.ROLES + TribalFigure.FAMILIES.values():
		var transforms: Array = by_role.get(role,[])
		var batch: MultiMeshInstance3D = _batches.get(role)
		if transforms.is_empty():
			instance_tracks.erase(role)
			if batch:
				batch.multimesh.visible_instance_count = 0
				batch.hide()
			continue
		if batch == null:
			batch = MultiMeshInstance3D.new()
			batch.name = role.capitalize()
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.use_custom_data = true
			batch.multimesh.use_colors = true
			batch.multimesh.mesh = SoldierVisual.far_mesh(role) if role in SoldierVisual.ROLES else TribalFigure.silhouette(role)
			var painted := batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
			var stride := ShaderMaterial.new()
			stride.shader = preload("res://shaders/rank_stride.gdshader")
			stride.set_shader_parameter("pigments",painted.albedo_texture)
			stride.set_shader_parameter("finish_map",painted.roughness_texture)
			stride.set_shader_parameter("step_fraction",maxf(0,_last_fraction))
			stride.set_shader_parameter("stance",Vector3(STANCE.march,STANCE.run,STANCE.retreat))
			stride.set_shader_parameter("clearance",Vector3(CLEARANCE.march,CLEARANCE.run,CLEARANCE.retreat))
			stride.set_shader_parameter("authored_gait_keys",authored_gait_keys())
			batch.material_override = stride
			_batches[role] = batch
			add_child(batch)
		var group := batch.multimesh
		if transforms.size() > group.instance_count:
			group.instance_count = nearest_po2(transforms.size())
		var gait: Array = gait_by_role.get(role,[])
		var starts: Array = starts_by_role.get(role,[])
		instance_tracks[role] = {"ends":transforms.duplicate(),"starts":starts.duplicate(),"gaits":gait.duplicate()}
		for index in transforms.size():
			var finish: Transform3D = transforms[index]
			group.set_instance_transform(index,finish)
			group.set_instance_color(index,root_data(starts[index] if index < starts.size() else finish,finish))
			group.set_instance_custom_data(index,gait[index] if index < gait.size() else Color(0,0,0,0))
		group.visible_instance_count = transforms.size()
		batch.show()
