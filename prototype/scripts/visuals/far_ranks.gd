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
		var name: String = ["march","run","retreat"][mode-1]
		var leg := (1.0-smoothstep(.10,.74,vertex.y))*(1.0-smoothstep(.205,.27,absf(vertex.x)))
		var phase_offset := 0.0 if vertex.x < 0.0 else .5
		var t := fposmod(phase+phase_offset,1.0)
		if vertex.y <= .121 and absf(vertex.x) < .205 and t > float(STANCE[name]):
			var u := (t-float(STANCE[name]))/(1.0-float(STANCE[name]))
			var pitch := deg_to_rad(14.0)*sin(TAU*u)*sin(PI*u)
			var ankle := Vector3(-.126 if vertex.x < 0 else .126,.12,0)
			vertex = ankle+Basis(Vector3.RIGHT,pitch)*(vertex-ankle)
		var lift := -.068-.062*cos(TAU*phase*2.0) if mode == 2 else -.088-.035*cos(TAU*phase*2.0)
		var pelvis_weight := smoothstep(.12,.78,vertex.y)
		return vertex+foot_offset(phase+phase_offset,name)*leg+Vector3.UP*lift*pelvis_weight
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
