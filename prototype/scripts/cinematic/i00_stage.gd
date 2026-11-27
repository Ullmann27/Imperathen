extends Node3D
## Original cinematic staging for I-00 "Drei Legionen im Regen".
##
## This is deliberately presentation-only. Caesar/Labienus use replaceable
## placeholder character visuals until historically reviewed hero assets exist.
## The legion blocks have no collision, AI, inventory, morale or combat authority.

const Person = preload("res://scripts/visuals/village_person.gd")
const Ranks = preload("res://scripts/visuals/far_ranks.gd")
const Art = preload("res://scripts/world/village_art.gd")
const Vexillum := preload("res://scripts/cinematic/i00_vexillum.gd")
const CampScenery := preload("res://scripts/cinematic/i00_camp_scenery.gd")
const MESHY_SIGNIFER := "unit_roman_signifer"

const OFFSET := Vector3(180.0, 0.0, 160.0)
const ANCHORS := {
	"i00_standard": Vector3(-9.0, 0.0, -3.0),
	"i00_legions": Vector3(0.0, 0.0, -11.0),
	"i00_caesar": Vector3(-2.4, 0.0, 2.2),
	"i00_labienus": Vector3(2.4, 0.0, 2.0),
	"i00_road": Vector3(0.0, 0.0, -24.0),
}

var _built := false
var _speakers: Dictionary = {}
var _iron: StandardMaterial3D
var _shield: StandardMaterial3D
var _wood: StandardMaterial3D
var _legions: Node3D
var _legion_clock := 0.0
var _wind_clock := 0.0
var _pose_tick := 0.0
var _presentation_paused := false
var _standards: Array[Node3D] = []
var _foreground: Array[Node3D] = []


func ensure_built() -> void:
	if _built:
		return
	_built = true
	position = OFFSET
	_iron = Art.material(Color("5e625f"), 0.62)
	_iron.metallic = 0.42
	_shield = Art.material(Color("6d3029"), 0.70)
	_shield.metallic = 0.10
	_wood = Art.material(Color("554638"), 0.94)
	_build_ground()
	_build_legions()
	_build_commanders()
	_build_rain()


func anchor(key: String) -> Vector3:
	ensure_built()
	var local_anchor: Vector3 = ANCHORS.get(key, Vector3.ZERO)
	# Tests and editor tooling may query the deterministic authored anchors before
	# this presentation-only stage is attached to the SceneTree. Avoid emitting
	# an engine error there; production still respects the complete parent/global
	# transform once the stage is actually mounted.
	if not is_inside_tree():
		return position + local_anchor
	return to_global(local_anchor)


func speaker(id: String) -> Node3D:
	ensure_built()
	return _speakers.get(id) as Node3D


func _build_ground() -> void:
	CampScenery.build(self)
	for x in [-9.0, 0.0, 9.0]:
		_standard(Vector3(x, 0.0, -3.0))


func _standard(at: Vector3) -> void:
	var node := Vexillum.new()
	node.name = "CommandVexillum_%d" % _standards.size()
	node.position = at
	add_child(node)
	var bronze := Art.material(Color("89744d"), .52, false)
	bronze.metallic = .62
	node.build(_wood, bronze, float(_standards.size())*1.37)
	_standards.append(node)


func _build_legions() -> void:
	# Nine detailed front-row rigs REPLACE nine former far silhouettes.
	# The remaining 45 share the existing animated formation batch.
	_legions = Ranks.new()
	_legions.name = "LegionBlocks"
	add_child(_legions)
	var transforms: Array = []
	var phases: Array = []
	for block in 3:
		var center_x := -9.0+float(block)*9.0
		for row in 6:
			for column in 3:
				var at := Vector3(center_x+float(column-1)*.92,0,-8.0-float(row)*1.28)
				var slot: int = block*18+row*3+column
				var phase := fposmod(float(slot+1)*.381966,1.0)
				if row == 0:
					_foreground_soldier(at, slot, block == 0 and column == 1, phase)
				else:
					transforms.append(Transform3D(Basis.IDENTITY,at))
					phases.append(Ranks.gait_data("idle",phase,phase+1.0))
	_legions.sync({"spear":transforms},{"spear":phases})
	_legions.set_step_fraction(0.0)


func _foreground_soldier(at: Vector3, slot: int, signifer: bool, phase: float) -> void:
	var figure := Person.new()
	figure.name = "FrontRank_%02d" % slot
	figure.position = at+Vector3.UP*.90
	figure.rotation.y = PI
	figure.detail = 0
	figure.set_cinematic_detail(true)
	add_child(figure)
	figure.configure_resident("italia", 29+slot%13, "legionary", slot+31)
	if signifer:
		figure.configure_meshy(MESHY_SIGNIFER)
	figure.set_meta("i00_slot",slot)
	figure.set_meta("i00_phase",phase)
	figure.set_meta("i00_source",figure.active_model_path)
	figure.set_process(false)
	figure.set_physics_process(false)
	figure.sample_pose("idle",phase)
	_foreground.append(figure)


func set_presentation_paused(value: bool) -> void:
	if _presentation_paused == value:
		return
	_presentation_paused = value
	var rain := get_node_or_null("Rain") as GPUParticles3D
	if rain:
		rain.speed_scale = 0.0 if value else 1.0


func _process(delta: float) -> void:
	if not _built or not is_visible_in_tree() or _presentation_paused or not is_finite(delta) or delta <= 0.0:
		return
	_legion_clock = fposmod(_legion_clock+delta,2.0)
	_wind_clock = fposmod(_wind_clock+delta,40.0)
	_legions.set_step_fraction(_legion_clock/2.0)
	for standard: Node3D in _standards:
		standard.call("sample_wind",_wind_clock)
	_pose_tick += delta
	if _pose_tick >= 1.0/30.0:
		_pose_tick = fposmod(_pose_tick,1.0/30.0)
		for figure: Node3D in _foreground:
			figure.call("sample_pose","idle",fposmod(_legion_clock/2.0+float(figure.get_meta("i00_phase")),1.0))


func _build_commanders() -> void:
	_speakers["caesar"] = _commander("Caesar", ANCHORS.i00_caesar, "officer", 0)
	_speakers["labienus"] = _commander("Labienus", ANCHORS.i00_labienus, "officer", 1)


func _commander(label: String, at: Vector3, appearance: String, variation: int) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = at
	root.set_meta("historical_visual_status", "placeholder_pending_reference_review")
	add_child(root)
	var figure := Person.new()
	figure.name = "Figure"
	figure.position.y = 0.90
	figure.detail = 0
	figure.set_cinematic_detail(true)
	root.add_child(figure)
	figure.configure_resident("italia", 42, appearance, variation, null)
	return figure


func _build_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 700
	rain.lifetime = 1.35
	rain.randomness = 0.35
	rain.position = Vector3(0.0, 11.0, -8.0)
	rain.visibility_aabb = AABB(Vector3(-28,-12,-34), Vector3(56,26,68))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(25.0, 1.0, 29.0)
	process.direction = Vector3(0.08, -1.0, 0.04)
	process.spread = 4.0
	process.initial_velocity_min = 16.0
	process.initial_velocity_max = 21.0
	process.gravity = Vector3(0.0, -4.0, 0.0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.36, 0.012)
	rain.draw_pass_1 = drop
	var rain_material := Art.transparent_material(Color(0.68, 0.76, 0.82, 0.38))
	rain.material_override = rain_material
	add_child(rain)
