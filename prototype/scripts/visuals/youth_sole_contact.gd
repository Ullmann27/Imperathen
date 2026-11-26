extends RefCounted
## Bounded CPU sample of the original skinned sandals. The physics body keeps
## ownership of movement, collision and actual ground level.

var rig: Skeleton3D
var samples: Array[Dictionary] = []
var run_clearance: Array = []
var last_lowest_world_y := INF
var last_correction_m := 0.0
var last_target_y := INF
## Bind-space sandal sole planes per side from the offline retarget report
## (Vector4: normal xyz, offset w). Empty for reports without calibration.
var sole_planes: Array[Vector4] = []
var slab_sample_count := 0
const SOLE_CONTACT_BAND_M := .004
const SAMPLES_PER_REGION := 24
## Offline retarget report. It is produced by the youth build and is absent in
## checkouts and builds without the original youth, where only the legacy
## bind-pose band applies.
const MOTION_REPORT := "res://assets/animations/accad_youth_motion.json"
static var _report_read := false
static var _report: Dictionary = {}


## Reads the report once per process instead of on every LOD reload, and never
## asks the JSON parser for a file that does not exist.
static func motion_report() -> Dictionary:
	if not _report_read:
		_report_read = true
		if FileAccess.file_exists(MOTION_REPORT):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOTION_REPORT))
			if parsed is Dictionary:
				_report = parsed
	return _report


func bind(model: Node3D, level: int) -> void:
	samples.clear()
	run_clearance.clear()
	sole_planes.clear()
	slab_sample_count=0
	rig = null
	if not is_instance_valid(model):
		return
	var lod_report: Dictionary = {}
	var lods: Array = motion_report().get("lods",[])
	if level>=0 and level<lods.size() and lods[level] is Dictionary:
		lod_report=lods[level]
	var planes: Dictionary = lod_report.get("sole_planes",{})
	for side_name in ["L","R"]:
		var plane: Dictionary = planes.get(side_name,{})
		var n: Array = plane.get("rest_normal",[])
		if n.size()==3 and plane.has("plane_offset"):
			sole_planes.append(Vector4(float(n[0]),float(n[1]),float(n[2]),float(plane.plane_offset)))
	if sole_planes.size()!=2:
		sole_planes.clear()
	var mesh := model.find_child("MeshyYouthBody",true,false) as MeshInstance3D
	if not is_instance_valid(mesh) or mesh.mesh == null or mesh.skin == null:
		return
	rig = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
	if not is_instance_valid(rig):
		return
	var bone_ids := PackedInt32Array()
	var foot_sides := PackedInt32Array()
	var binds: Array[Transform3D] = []
	for i in mesh.skin.get_bind_count():
		var bone_name := String(mesh.skin.get_bind_name(i))
		var bone := rig.find_bone(bone_name) if not bone_name.is_empty() else mesh.skin.get_bind_bone(i)
		if bone < 0 or bone >= rig.get_bone_count():
			samples.clear()
			return
		bone_ids.append(bone)
		binds.append(mesh.skin.get_bind_pose(i))
		var name := rig.get_bone_name(bone)
		foot_sides.append(1 if name in ["Foot_L","Toe_L"] else (2 if name in ["Foot_R","Toe_R"] else 0))
	# Two pools per side: the lowest bind-pose band (legacy) and the actual
	# sandal slab, which only becomes the contact surface once the inward
	# rolled original feet are flattened by the retargeted clips.
	var candidates: Array = [[],[]]
	var slab_candidates: Array = [[],[]]
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or joints.size()!=weights.size() or joints.size()!=vertices.size()*4:
			continue
		for v in vertices.size():
			# Same metric sole band and slab rule as the offline retargeter.
			var in_band := vertices[v].y <= .065
			var plane_distance := INF
			if not sole_planes.is_empty():
				var x_side := 0 if vertices[v].x>0.0 else 1
				var plane: Vector4 = sole_planes[x_side]
				plane_distance=Vector3(plane.x,plane.y,plane.z).dot(vertices[v])+plane.w
			var on_slab := plane_distance<=SOLE_CONTACT_BAND_M
			if not in_band and not on_slab:
				continue
			# Classify by foot weight first; only foot vertices pay for the
			# bind-space transforms below.
			var side_weights := Vector2.ZERO
			for slot in 4:
				var k := v*4+slot
				var index := joints[k]
				if index<0 or index>=bone_ids.size() or weights[k]<=0.0:
					continue
				if foot_sides[index]==1: side_weights.x+=weights[k]
				if foot_sides[index]==2: side_weights.y+=weights[k]
			var side := 0 if side_weights.x>=.6 else (1 if side_weights.y>=.6 else -1)
			if side<0:
				continue
			# The slab rule uses the plane of the vertex's own foot.
			if on_slab and (side==0)!=(vertices[v].x>0.0):
				on_slab=false
			if not in_band and not on_slab:
				continue
			var ids := PackedInt32Array()
			var local := PackedVector3Array()
			var amounts := PackedFloat32Array()
			for slot in 4:
				var k := v*4+slot
				var index := joints[k]
				var w := weights[k]
				if index<0 or index>=bone_ids.size() or w<=0.0:
					continue
				ids.append(bone_ids[index])
				local.append(binds[index]*vertices[v])
				amounts.append(w)
			if ids.size()>0:
				var value := {"y":vertices[v].y,"z":vertices[v].z,"d":plane_distance,
					"bones":ids,"local":local,"weights":amounts}
				if in_band:
					candidates[side].append(value)
				if on_slab:
					slab_candidates[side].append(value)
	for side in 2:
		var foot: Array = candidates[side]
		if foot.is_empty() and slab_candidates[side].is_empty():
			samples.clear()
			slab_sample_count=0
			return
		foot.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.y)<float(b.y))
		_take_regions(foot)
		# Most protruding slab/heel/toe-cap vertices first.
		var slab: Array = slab_candidates[side]
		slab.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.d)<float(b.d))
		slab_sample_count+=_take_regions(slab)
	if not lod_report.is_empty():
		run_clearance=lod_report.get("clips",{}).get("run",{}).get("sole_clearance_curve_m",[])


## Include the heel and forefoot halves independently; a dense heel patch
## must not hide the toe contact at push-off. Returns the samples added.
func _take_regions(foot: Array) -> int:
	if foot.is_empty():
		return 0
	var minimum_z := INF
	var maximum_z := -INF
	for value: Dictionary in foot:
		minimum_z=minf(minimum_z,float(value.z))
		maximum_z=maxf(maximum_z,float(value.z))
	var mid := (minimum_z+maximum_z)*.5
	var counts := [0,0]
	for value: Dictionary in foot:
		var region := 0 if float(value.z)<mid else 1
		if counts[region]<SAMPLES_PER_REGION:
			samples.append(value)
			counts[region]+=1
	return counts[0]+counts[1]


func clearance(action: String, phase: float) -> float:
	if action!="run" or run_clearance.size()<2:
		return 0.0
	var at := clampf(phase,0.0,1.0)*float(run_clearance.size()-1)
	var i := floori(at)
	return lerpf(float(run_clearance[i]),float(run_clearance[mini(i+1,run_clearance.size()-1)]),at-float(i))


func measure_lowest() -> float:
	if not is_instance_valid(rig) or samples.is_empty():
		return INF
	rig.force_update_all_bone_transforms()
	var poses: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		poses.append(rig.global_transform*rig.get_bone_global_pose(bone))
	var lowest := INF
	for sample: Dictionary in samples:
		var point := Vector3.ZERO
		for i in sample.bones.size():
			point+=(poses[int(sample.bones[i])]*Vector3(sample.local[i]))*float(sample.weights[i])
		lowest=minf(lowest,point.y)
	return lowest


func apply_to_floor(floor_y: float, action: String, phase: float) -> void:
	last_lowest_world_y=measure_lowest()
	last_correction_m=0.0
	last_target_y=INF
	if not is_finite(last_lowest_world_y) or not is_finite(floor_y) or action=="death":
		return
	last_target_y=floor_y+.003+clearance(action,phase)
	# Keep the recorded flight phase of a run. Only translate the visual
	# pelvis, never stretch a limb, alter the capsule or move the player.
	var correction := clampf(last_target_y-last_lowest_world_y,-.16,.16)
	if absf(correction)<.001:
		return
	var pelvis := rig.find_bone("Pelvis")
	if pelvis<0:
		return
	var local_up := rig.global_basis.inverse()*Vector3.UP
	var parent := rig.get_bone_parent(pelvis)
	if parent>=0:
		local_up=rig.get_bone_global_pose(parent).basis.inverse()*local_up
	rig.set_bone_pose_position(pelvis,rig.get_bone_pose_position(pelvis)+local_up*correction)
	rig.force_update_all_bone_transforms()
	last_correction_m=correction
	last_lowest_world_y=measure_lowest()
