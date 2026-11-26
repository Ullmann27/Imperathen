extends Node3D
## Presentation of a domain person. The enclosing body owns collision and movement.

const COLORS := {"italia":"a45c47","germania":"809081","han":"ad9865","wa":"e0d1b7","vistula":"797b78"}
const COMPANION_COLORS := {"italia":"ddd0ab","germania":"91907a","han":"8197a4","wa":"d4c7ac","vistula":"ac6853"}
const HAIR := {"italia":["",""],"germania":["","braid"],"han":["knot","knot"],"wa":["tie","tie"],"vistula":["braid","braid"]}
const COMPANIONS := {"italia":"marcus","germania":"albrun","han":"lin","wa":"aki","vistula":"mira"}
const LOOPS := ["idle","march","run","talk","work"]
const FacialMotion := preload("res://scripts/visuals/facial_motion.gd")
const CharacterMotion := preload("res://scripts/visuals/character_motion.gd")
const YouthSoleContact := preload("res://scripts/visuals/youth_sole_contact.gd")
const HandPose := preload("res://scripts/visuals/hand_pose.gd")
const PracticeGear := preload("res://scripts/visuals/practice_gear.gd")
const ServiceGear := preload("res://scripts/visuals/service_gear.gd")
const MeshyCharacters := preload("res://scripts/visuals/meshy_character_registry.gd")
const MeshyEquipment := preload("res://scripts/visuals/meshy_equipment.gd")
const RaiderStrike := preload("res://scripts/domain/raider_strike.gd")
const HERO_PATH := "res://assets/characters/hero_quality_%d.glb"
const MESHY_YOUTH_PATH := "res://assets/characters/hero_meshy_italia_%d.glb"
# ACCAD measured cycle distance, retargeted to the original 1.50 m youth.
# The retarget report and the source-specific test verify these values.
const YOUTH_MOCAP_STRIDES := {"march":1.36795,"run":2.38253}
const FRONTIER_PATH := "res://assets/characters/frontier_%s_%d.glb"
const APPEARANCES := ["civilian_man", "civilian_woman", "elder", "legionary", "officer", "spearman", "archer"]
const CLOTH_TINTS := [Color(1.0, 1.0, 1.0), Color(0.72, 0.90, 1.10), Color(1.10, 0.75, 0.60), Color(0.75, 1.05, 0.79), Color(1.15, 1.06, 0.76), Color(0.76, 0.73, 0.84)]
const RESIDENT_HEIGHTS := [0.97, 1.03, 1.0, 0.95, 1.04, 0.99]
const LOD_DISTANCES := [11.0,23.0,44.0]
const CROWD_LOD_DISTANCES := [6.0,15.0,30.0]
static var scenes := {}
static var materials := {}
var role := "player"
var home := "italia"
var age := 12
var identity := "player"
var profile := "balanced"
var detail := -1
var body: Node3D
var animator: AnimationPlayer
var _animation_sources: Dictionary = {}
var active_model_path := ""
var clip := "idle"
var phase := 0.0
var speed := 0.0
var _remaining := 0.0
var _check_lod := 0.0
var _posed := false
var _blade: MeshInstance3D
var _face := FacialMotion.new()
var _motion := CharacterMotion.new()
var _hands := HandPose.new()
var _turn_rate := 0.0
var _combat_id := ""
var _combat_progress := 0.0
var _combat_duration := 0.0
var _combat_external := false
var _has_sword := false
var _has_shield := false
var _lod_profile := ""
var appearance_id := ""
var appearance_variation := 0
var _loaned_gear := false
var _gear_nodes: Array[Node3D] = []
var meshy_asset_id := ""
var _meshy_youth := false
var _conversation_focused := false
var _armed_style := ""
## Retimed raider blow: the clip's measured contact frame is reached after
## _strike_windup seconds, then the follow-through plays at its own speed.
var _strike_windup := 0.0
var _strike_contact := 0.0
var _strike_elapsed := 0.0
var _armed_sequence := 0
var _service_gear := false
var _service_nodes: Array[Node3D] = []
var _service_external := false
var _motion_identity := ""
var youth_ground_floor_y := INF
var _youth_soles := YouthSoleContact.new()


func _ready() -> void:
	add_to_group("village_people")


func configure(kind: String, origin: String, years: int) -> void:
	if role == kind and home == origin and age == years and body:
		return
	role = kind
	home = origin
	age = years
	identity = COMPANIONS.get(home,"marcus") if role == "companion" else ("hero_"+home if role == "player" else role)
	_reload(maxi(0,detail))


func configure_appearance(new_appearance: String, variation: int = 0) -> void:
	var selected := new_appearance if new_appearance in APPEARANCES else ""
	var selected_variation := posmod(variation, 18)
	if selected == appearance_id and selected_variation == appearance_variation and body:
		return
	appearance_id = selected
	appearance_variation = selected_variation
	if not appearance_id.is_empty():
		identity = "resident_%s_%d" % [appearance_id, appearance_variation]
	_reload(maxi(0, detail))


func configure_meshy(stable_id: String) -> bool:
	# Keep authored child/player identity and retain the current live fallback
	# until a complete imported derivative set exists.
	var selected := stable_id if age >= 18 and role not in ["player", "companion"] and MeshyCharacters.has_complete_set(stable_id) and MeshyEquipment.has_complete_set(stable_id) else ""
	if selected != meshy_asset_id:
		meshy_asset_id = selected
		_reload(maxi(0, detail))
	return not selected.is_empty()


func configure_meshy_youth(enabled: bool = true) -> bool:
	# Exact adolescent identity; this is not an adult or companion morph.
	var selected := enabled and role=="player" and home=="italia" and age>=12 and age<18
	if selected:
		for level in 4:
			selected = selected and ResourceLoader.exists(MESHY_YOUTH_PATH % level,"PackedScene")
	if selected!=_meshy_youth:
		_meshy_youth = selected
		if body:
			_reload(maxi(0,detail))
	return selected


func configure_resident(origin: String, years: int, new_appearance: String, variation: int = 0, camera: Camera3D = null) -> void:
	# Resident population builders already know the complete identity. Configure
	# it atomically so they never load an unused generic body or a near LOD first.
	var selected := new_appearance if new_appearance in APPEARANCES else ""
	var selected_variation := posmod(variation, 18)
	var changed := role != "resident" or home != origin or age != years or appearance_id != selected or appearance_variation != selected_variation
	role = "resident"
	home = origin
	age = years
	appearance_id = selected
	appearance_variation = selected_variation
	identity = "resident_%s_%d" % [appearance_id, appearance_variation] if not appearance_id.is_empty() else "resident"
	if not changed and body:
		refresh_lod(camera)
		return
	var level := detail if detail >= 0 else 2
	if is_instance_valid(camera) and is_inside_tree() and camera.is_inside_tree():
		level = _distance_lod(global_position.distance_to(camera.global_position))
		_lod_profile = profile
	_reload(level)


func _frontier_identity() -> String:
	# The new civilian anatomy is adult. Existing youth characters keep their
	# original age route and cannot accidentally receive an adult resident mesh.
	if age < 18:
		return ""
	if not appearance_id.is_empty():
		return appearance_id
	if home == "italia":
		return {"mentor": "officer", "recruit": "spearman", "enemy": "legionary"}.get(role, "")
	return ""


func _path(level: int) -> String:
	if role == "regional_worker":
		var worker_name := home + "_farmer" if home in ["han", "wa"] else "farmer"
		return "res://assets/landscape/" + worker_name + ".glb"
	if role not in ["player", "companion"] and not meshy_asset_id.is_empty():
		var meshy_path := MeshyCharacters.path_for(meshy_asset_id, age, level)
		if not meshy_path.is_empty():
			return meshy_path
	# This asset has an authored Italia identity. Other origins and companions
	# keep their own appearances until their replacement models are available.
	if role == "player" and home == "italia":
		if _meshy_youth and age>=12 and age<18:
			var youth_complete := true
			for candidate in 4:
				youth_complete = youth_complete and ResourceLoader.exists(MESHY_YOUTH_PATH % candidate,"PackedScene")
			if youth_complete:
				return MESHY_YOUTH_PATH % level
		var complete_set := true
		for candidate in 4:
			if not ResourceLoader.exists(HERO_PATH % candidate, "PackedScene"):
				complete_set = false
		if complete_set:
			return HERO_PATH % level
	var frontier := _frontier_identity()
	if not frontier.is_empty():
		var complete_set := true
		for candidate in 4:
			if not ResourceLoader.exists(FRONTIER_PATH % [frontier, candidate], "PackedScene"):
				complete_set = false
		if complete_set:
			return FRONTIER_PATH % [frontier, level]
	return _legacy_path(level)


func _legacy_path(level: int) -> String:
	if role in ["mentor","recruit","enemy"]:
		var equipment := "officer" if role == "mentor" else ("spear" if role == "recruit" else "heavy")
		if level >= 2:
			return "res://assets/village_characters/%s_%d.glb" % [equipment,level]
		var lod: String = ["near","mid"][level]
		return "res://assets/soldiers/%s_%s.glb" % [equipment,lod]
	return "res://assets/village_characters/villager_%d.glb" % level


func _reload(level: int) -> void:
	level = clampi(level, 0, 3)
	var saved_phase := phase
	var previous_path := active_model_path
	var contacts := _motion.capture_world_contacts() if body and _motion_identity==identity else {}
	var transition := _motion.capture_lod_transition() if body and _motion_identity==identity and level!=detail else {}
	var previous_scale := body.scale if body else Vector3.ONE
	var previous_detail := detail
	var path := _path(level)
	var replacement := _instantiate(path)
	if not replacement and path != _legacy_path(level):
		path = _legacy_path(level)
		replacement = _instantiate(path)
	if not replacement:
		push_warning("Character model unavailable: " + path)
		return
	# Load and validate before removing the current model. A failed optional
	# asset must not make a visible actor disappear during a quality transition.
	_blade = null
	if body:
		remove_child(body)
		body.free()
	_gear_nodes.clear()
	_service_nodes.clear()
	detail = level
	body = replacement
	active_model_path = path
	body.name = "Model"
	body.rotation.y = PI
	var size_factor := 1.0
	if role in ["player","companion"]:
		size_factor = 1.14 if age >= 18 else 1.0
		if role == "companion": size_factor *= 0.97
	elif active_model_path.begins_with("res://assets/characters/frontier_") and _frontier_identity() in ["civilian_man", "civilian_woman", "elder"]:
		size_factor = 1.14 * float(RESIDENT_HEIGHTS[appearance_variation % RESIDENT_HEIGHTS.size()])
	body.scale = Vector3.ONE * size_factor
	add_child(body)
	body.position.y = -0.9
	animator = body.find_child("AnimationPlayer",true,false) as AnimationPlayer
	_animation_sources.clear()
	if animator:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for animation_name: StringName in animator.get_animation_list():
			_animation_sources[str(animation_name)] = animator.get_animation(animation_name)
		# Imported scenes share libraries and animations. Own the small name
		# maps; copy an animation only if this actor needs another loop mode.
		for library_name: StringName in animator.get_animation_library_list():
			var library := animator.get_animation_library(library_name).duplicate() as AnimationLibrary
			animator.remove_animation_library(library_name)
			animator.add_animation_library(library_name, library)
	for shape: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
		_style(shape)
	_hands.bind(body, active_model_path)
	_face.bind(body, identity)
	var imported_youth := active_model_path.begins_with("res://assets/characters/hero_meshy_italia_")
	var civilian_motion := role in ["player", "companion", "regional_worker"] or (role == "resident" and _frontier_identity() in ["", "civilian_man", "civilian_woman", "elder"])
	_motion.bind(body, civilian_motion and not imported_youth, identity)
	_youth_soles.bind(body if imported_youth else null,detail)
	_motion_identity = identity
	_motion.restore_world_contacts(contacts)
	# The external tracks target this authored hero family. Never reuse them
	# on a differently weighted Meshy or frontier character by bone name alone.
	_motion.external_gestures = active_model_path.begins_with("res://assets/characters/hero_quality_")
	# Reattach loaned gear before evaluating an existing shield pose on the
	# new skeleton. LOD changes must not silently erase a valid guard.
	_sync_loaned_gear()
	_sync_service_gear()
	_play(clip,saved_phase,0)
	_face.pose("attack" if not _combat_id.is_empty() else clip,saved_phase,detail)
	if not _combat_id.is_empty():
		_sample_combat_pose(_combat_id, _combat_progress)
		_hands.set_grip(0.18 + 0.82 * smoothstep(0.0, 0.15, _combat_progress) * (1.0 - smoothstep(0.82, 1.0, _combat_progress)))
	if active_model_path.begins_with("res://assets/meshy/characters/"):
		MeshyEquipment.attach(body, meshy_asset_id, detail)
	if not contacts.is_empty():
		_plant_contacts(0.0)
		# A replacement pose is not another simulation tick. The root may
		# already have moved while phase still names the previous stance.
		# Keep the rendered contact, but preserve its real release history.
		_motion.restore_world_contacts(contacts)
	# Restore the exact displayed crossfade pose only between tiers of the
	# same character family, after sampling and contact reconstruction.
	# Keep the original transition clock; never restart it on each LOD swap.
	if previous_path.ends_with("_%d.glb" % previous_detail) and path.ends_with("_%d.glb" % level) and previous_path.trim_suffix("_%d.glb" % previous_detail)==path.trim_suffix("_%d.glb" % level) and previous_scale.is_equal_approx(body.scale):
		_motion.restore_lod_transition(transition)
	# Retaining every hero PackedScene would also retain every embedded texture
	# tier. Live instances keep their own references; inactive tiers may unload.
	if path.begins_with("res://assets/characters/hero_quality_") or previous_path.begins_with("res://assets/characters/hero_quality_"):
		for cached_path: String in scenes.keys():
			if cached_path.begins_with("res://assets/characters/hero_quality_") and cached_path != path:
				scenes.erase(cached_path)
	if path.begins_with("res://assets/characters/hero_meshy_italia_") or previous_path.begins_with("res://assets/characters/hero_meshy_italia_"):
		for cached_path: String in scenes.keys():
			if cached_path.begins_with("res://assets/characters/hero_meshy_italia_") and cached_path!=path:
				scenes.erase(cached_path)
	elif path.begins_with("res://assets/characters/frontier_"):
		var family := "res://assets/characters/frontier_" + _frontier_identity() + "_"
		for cached_path: String in scenes.keys():
			if cached_path.begins_with(family) and cached_path != path:
				scenes.erase(cached_path)
	elif path.begins_with("res://assets/meshy/characters/"):
		var family := MeshyCharacters.family_prefix(meshy_asset_id)
		for cached_path: String in scenes.keys():
			if cached_path.begins_with(family) and cached_path != path:
				scenes.erase(cached_path)


func _instantiate(path: String) -> Node3D:
	if not scenes.has(path):
		if not ResourceLoader.exists(path, "PackedScene"):
			return null
		var scene := load(path) as PackedScene
		if not scene:
			return null
		scenes[path] = scene
	var instance: Node = (scenes[path] as PackedScene).instantiate()
	if instance is Node3D:
		return instance as Node3D
	instance.free()
	scenes.erase(path)
	return null


func _style(shape: MeshInstance3D) -> void:
	if not shape.mesh: return
	var part := String(shape.name)
	if part.begins_with("Garment_"):
		shape.visible = part == "Garment_"+home
	if part.begins_with("Hair_"):
		var style: String = HAIR.get(home,["",""])[int(role=="companion")]
		shape.visible = part == "Hair_"+style
	if part == "PracticeBlade":
		_blade = shape
		shape.visible = false
	for key in ["Mature","Companion"]:
		var slot := shape.find_blend_shape_by_name(key)
		if slot >= 0:
			shape.set_blend_shape_value(slot,float(age >= 18 if key == "Mature" else role == "companion"))
	for i in range(shape.mesh.get_surface_count()):
		var source := shape.mesh.surface_get_material(i) as StandardMaterial3D
		if not source: continue
		if "CharacterPalette" in source.resource_name:
			source.vertex_color_use_as_albedo = true
		elif source.resource_name == "PortraitSkin":
			var face_id := identity
			if role == "resident": face_id = "hero_" + home
			if age >= 18 and home == "italia": face_id = "adult_marcus" if role == "companion" else "adult_italia"
			if not materials.has(face_id):
				var face := source.duplicate() as StandardMaterial3D
				face.vertex_color_use_as_albedo = false
				face.albedo_texture = load("res://assets/village_characters/faces/%s.webp" % face_id)
				face.roughness = 0.77
				materials[face_id] = face
			shape.set_surface_override_material(i,materials[face_id])
		elif active_model_path.begins_with("res://assets/characters/frontier_") and source.resource_name in ["FrontierCloth", "HeroHair", "FrontierGreyHair"]:
			var key := "%d/frontier/%d" % [source.get_instance_id(), appearance_variation]
			var mat: StandardMaterial3D
			if materials.has(key):
				mat = (materials[key] as WeakRef).get_ref() as StandardMaterial3D
			if not mat:
				mat = source.duplicate() as StandardMaterial3D
				if source.resource_name == "FrontierCloth":
					mat.albedo_color *= CLOTH_TINTS[appearance_variation % CLOTH_TINTS.size()]
				elif source.resource_name == "HeroHair":
					var hair_variant := floori(float(appearance_variation) / 6.0) % 3
					mat.albedo_color *= [Color(0.60, 0.52, 0.44), Color(1.0, 0.88, 0.68), Color(0.72, 0.76, 0.76)][hair_variant]
				else:
					mat.albedo_color *= Color(0.84, 0.86, 0.84) if appearance_variation % 2 else Color(1.15, 1.13, 1.09)
				# Inactive LOD textures may unload; live actor overrides own the
				# material. A cache must not retain all four texture tiers forever.
				materials[key] = weakref(mat)
			shape.set_surface_override_material(i, mat)
		elif source.resource_name in ["Civilian_Linen","Overgarment"] or (role == "enemy" and not active_model_path.begins_with("res://assets/characters/frontier_") and not active_model_path.begins_with("res://assets/meshy/characters/")):
			var key := "%d/%s/%s" % [source.get_instance_id(),home,role]
			if not materials.has(key):
				var mat := source.duplicate() as StandardMaterial3D
				var color := Color(COLORS.get(home,"b88753"))
				if role == "companion": color = Color(COMPANION_COLORS.get(home,"ddd0ab"))
				if role == "enemy": color = Color("#a78f79")
				mat.albedo_color = color
				materials[key] = mat
			shape.set_surface_override_material(i,materials[key])


func drive(metres_per_second: float, turn_radians_per_second: float = 0.0) -> void:
	speed = maxf(0.0, metres_per_second) if is_finite(metres_per_second) else 0.0
	_turn_rate = clampf(turn_radians_per_second, -3.0, 3.0) if is_finite(turn_radians_per_second) else 0.0
	if _combat_id.is_empty() and not _service_external:
		_posed = false
		# Work and speech are stationary activities. An actual moving body
		# must not glide while its previous gesture is still playing.
		if clip in ["work", "talk"] and speed >= 0.10:
			_conversation_focused = false
			_remaining = 0.0
			_play(_locomotion_clip(), 0.0, 0.13)


func set_equipment(sword: bool, shield: bool = false) -> void:
	_has_sword = sword
	_has_shield = shield
	_update_weapon_visibility()


func set_service_gear(enabled: bool) -> void:
	var allowed := enabled and role == "player" and age >= 18
	if allowed == _service_gear:
		return
	_service_gear = allowed
	_has_sword = allowed
	_has_shield = allowed
	if not allowed:
		_service_external = false
	_sync_service_gear()
	_update_weapon_visibility()


func _sync_service_gear() -> void:
	if not body:
		return
	if _service_gear and role == "player" and age >= 18 and _service_nodes.is_empty():
		_service_nodes = ServiceGear.attach(body)
	_update_weapon_visibility()


func _update_weapon_visibility() -> void:
	var authorized := role == "player" and age >= 18
	var armed_action := clip in ["attack","train","block"]
	if is_instance_valid(_blade):
		_blade.visible = _has_sword and authorized and armed_action and (_service_nodes.is_empty() or not _service_gear)
	for node: Node3D in _service_nodes:
		if is_instance_valid(node):
			node.visible = _service_gear and authorized and armed_action


func sample_service_combat(style: String, normalized: float) -> bool:
	if not _service_gear or not _can_armed_style(style):
		return false
	# This sampled pose is owned by the domain clock. Rendering cannot advance
	# the attack independently, even if physics or draw rates differ.
	var accepted := sample_armed_pose(style,normalized)
	_service_external = accepted
	return accepted


func sample_combat(technique: String, normalized: float) -> void:
	if not technique in CharacterMotion.TECHNIQUES:
		return
	_service_external = false
	_armed_style = ""
	_conversation_focused = false
	if _combat_id.is_empty():
		if _uses_youth_mocap() and animator.has_animation(technique):
			_motion.capture_transition(0.10)
			_motion.reset_world_contacts()
		else:
			_play("idle", 0.0, 0.0)
	_combat_id = technique
	_combat_progress = clampf(normalized, 0.0, 1.0)
	_combat_external = true
	_posed = true
	clip = technique
	phase = _combat_progress
	if _blade:
		_blade.visible = false
	_sample_combat_pose(technique, _combat_progress)
	_hands.set_grip(0.18 + 0.82 * smoothstep(0.0, 0.15, _combat_progress) * (1.0 - smoothstep(0.82, 1.0, _combat_progress)))
	_face.pose("attack", _combat_progress, detail)
	_ground_youth()


func cue_combat(technique: String, duration: float) -> void:
	if not technique in CharacterMotion.TECHNIQUES or not is_finite(duration) or duration <= 0.0:
		return
	sample_combat(technique, 0.0)
	_combat_duration = duration
	_combat_external = false
	_posed = false


func cancel_action() -> void:
	_strike_windup = 0.0
	_service_external = false
	_conversation_focused = false
	_combat_id = ""
	_combat_duration = 0.0
	_combat_progress = 0.0
	_combat_external = false
	_remaining = 0.0
	_posed = false
	_play("idle", 0.0, 0.12)


func strike_contact_seconds() -> float:
	var length := animator.get_animation("attack").length if animator and animator.has_animation("attack") else 0.8
	return RaiderStrike.clip_contact_seconds(active_model_path, length)


func cue_strike(seconds_to_contact: float) -> float:
	# Presentation of a domain-timed raider blow. The wind-up is stretched or
	# compressed so the weapon's contact frame coincides with the rule tick
	# that resolves the blow; the follow-through keeps the clip's own speed.
	cue("attack")
	if clip != "attack" or not animator or animator.current_animation == "" or not is_finite(seconds_to_contact) or seconds_to_contact <= 0.0:
		return 0.0
	var length := animator.current_animation_length
	_strike_contact = clampf(strike_contact_seconds(), 0.05, length)
	_strike_windup = seconds_to_contact
	_strike_elapsed = 0.0
	_remaining = _strike_windup+length-_strike_contact
	return _strike_windup


func strike_progress() -> Dictionary:
	return {"active":_strike_windup > 0.0 and clip == "attack", "elapsed":_strike_elapsed, "windup":_strike_windup,
		"contact":_strike_contact, "clip_time":animator.current_animation_position if animator and animator.current_animation != "" else 0.0}


func _strike_clip_time(elapsed: float) -> float:
	return RaiderStrike.clip_time(elapsed, _strike_windup, _strike_contact)


func cue(action: String, preferred_style: String = "") -> void:
	if action == "death" and clip == "death": return
	_strike_windup = 0.0
	_service_external = false
	if action != "talk":
		_conversation_focused = false
	_combat_id = ""
	_combat_external = false
	_posed = false
	_armed_style = ""
	if action in ["attack", "train"] and _can_armed_style("cut_inward"):
		var variants := CharacterMotion.ARMED_ATTACKS if not _has_meshy_axe() else ["cut_inward","cut_outward","overhead","turn_cut"]
		_armed_style = preferred_style if preferred_style in variants and _can_armed_style(preferred_style) else str(variants[_armed_sequence % variants.size()])
		_armed_sequence = (_armed_sequence + 1) % variants.size()
	elif action == "block" and _can_armed_style("guard_front"):
		_armed_style = preferred_style if preferred_style in CharacterMotion.SHIELD_GUARDS else "guard_front"
	_play(action,0,0.12)
	_remaining = animator.current_animation_length if animator and animator.current_animation != "" else 0.8


func _has_meshy_axe() -> bool:
	return meshy_asset_id == "unit_germanic_axe_fighter" and active_model_path.begins_with("res://assets/meshy/characters/unit_germanic_axe_fighter_")


func _can_armed_style(style: String) -> bool:
	if not _motion.available:
		return false
	if style in CharacterMotion.SHIELD_GUARDS:
		# Only a real attached shield qualifies; a flag alone is not a prop.
		return (_loaned_gear and not _gear_nodes.is_empty()) or (_service_gear and _service_nodes.size() == 2 and age >= 18) or _has_meshy_axe()
	if style in CharacterMotion.ARMED_ATTACKS:
		return age >= 18 and ((_has_sword and role == "player" and (is_instance_valid(_blade) or (_service_gear and _service_nodes.size() == 2))) or (_has_meshy_axe() and style != "thrust"))
	return false


func sample_armed_pose(style: String, normalized: float) -> bool:
	if not _can_armed_style(style) or not is_finite(normalized):
		return false
	_conversation_focused = false
	_combat_id = ""
	_combat_external = false
	_posed = true
	_armed_style = style
	_play("block" if style in CharacterMotion.SHIELD_GUARDS else "attack",normalized,0.0)
	_face.pose(clip,phase,detail)
	return true


func cue_unarmed(action: String) -> bool:
	# Compatibility for authored presentation cues. Actual hits and the live
	# action clock remain in the model and reach us through sample_combat.
	if not CharacterMotion.TIMING.has(action) or not animator or not _motion.available:
		return false
	cue_combat(action, float(CharacterMotion.TIMING[action].z))
	return true


func set_loaned_gear(enabled: bool) -> void:
	_loaned_gear = enabled
	_sync_loaned_gear()


func _sync_loaned_gear() -> void:
	if not body: return
	if _loaned_gear and _gear_nodes.is_empty():
		_gear_nodes = PracticeGear.attach(body)
	for node: Node3D in _gear_nodes:
		if is_instance_valid(node): node.visible = _loaned_gear


func reset_motion() -> void:
	_strike_windup = 0.0
	_motion.reset_world_contacts()
	_service_external = false
	_conversation_focused = false
	_combat_id = ""
	_combat_external = false
	_combat_progress = 0.0
	_remaining = 0
	speed = 0
	_posed = false
	_play("idle",0,0)
	_face.pose("idle",0,detail)


func set_conversation_focus(enabled: bool) -> void:
	if enabled == _conversation_focused:
		return
	if enabled:
		if clip == "death":
			return
		drive(0.0)
		_conversation_focused = true
		cue("talk")
	else:
		_conversation_focused = false
		if clip == "talk":
			cancel_action()


func keep_talking() -> void:
	if speed >= 0.06 or not _combat_id.is_empty() or _posed or clip == "death":
		return
	if _remaining > 0.0 and clip not in ["idle", "march", "run", "talk"]:
		return
	if clip != "talk":
		cue("talk")
	_remaining = maxf(_remaining, 0.30)


func keep_working() -> void:
	# Work hints can arrive from state refreshes as well as the physics clock.
	# They must never overwrite locomotion, a sampled combat pose, or a reaction.
	if speed >= 0.10 or not _combat_id.is_empty() or _posed or clip == "death":
		return
	if _remaining > 0.0 and clip not in ["idle", "march", "run", "work"]:
		return
	if clip != "work":
		cue("work")
	_remaining = 0.3


func _locomotion_clip() -> String:
	var stop_threshold := 0.06 if clip in ["march", "run"] else 0.10
	var run_threshold := 2.25 if clip == "run" else 2.55
	return "idle" if speed < stop_threshold else ("march" if speed < run_threshold else "run")


func _uses_youth_mocap() -> bool:
	# Never attach these source-specific tracks to another skin or adult rig.
	return active_model_path.begins_with("res://assets/characters/hero_meshy_italia_") and is_instance_valid(animator) and animator.has_animation("jab_right")


func _sample_combat_pose(technique: String, progress: float) -> void:
	if _uses_youth_mocap() and animator.has_animation(technique):
		# The domain owns elapsed time and contact windows. Use that exact
		# phase, not an independently advancing cosmetic attack timer.
		var animation := _playback_animation(technique,false)
		if animator.current_animation != technique:
			animator.play(technique,0.0)
		animator.seek(clampf(progress,0.0,1.0)*animation.length,true)
		animator.advance(0.0)
		_motion.blend_transition()
	else:
		_motion.combat(technique,progress)


func locomotion_stride(action: String) -> float:
	# One complete cycle advances this distance in world metres. It must match
	# the actual imported family, including attached Meshy and legacy soldiers;
	# using the old villager stride for these rigs made their planted feet slide.
	var model_scale := maxf(body.scale.y, 0.01) if body else 1.0
	if _uses_youth_mocap() and YOUTH_MOCAP_STRIDES.has(action):
		return float(YOUTH_MOCAP_STRIDES[action])*model_scale
	if _motion.available and _motion.civilian:
		return maxf(0.01, _motion.gait_stride(action, speed / model_scale) * model_scale)
	var soldier_gait := active_model_path.begins_with("res://assets/soldiers/") or active_model_path.begins_with("res://assets/meshy/characters/") or active_model_path.begins_with("res://assets/characters/hero_meshy_italia_")
	soldier_gait = soldier_gait or (active_model_path.begins_with("res://assets/characters/frontier_") and _frontier_identity() in ["legionary", "officer", "spearman", "archer"])
	for family: String in ["heavy", "officer", "spear"]:
		soldier_gait = soldier_gait or active_model_path.begins_with("res://assets/village_characters/" + family + "_")
	var stride := (1.30 if action == "march" else 1.75) if soldier_gait else (1.10 if action == "march" else 1.49)
	return stride * model_scale


func sample_pose(action: String, normalized: float) -> void:
	if action in CharacterMotion.TECHNIQUES:
		sample_combat(action, normalized)
		return
	_armed_style = ""
	_conversation_focused = false
	_combat_id = ""
	_combat_external = false
	_posed = true
	_play(action,normalized,0)
	_face.pose(action,normalized,detail)
	_apply_motion(true)


func _play(action: String, normalized: float, blend: float) -> void:
	if action != "attack":
		_strike_windup = 0.0
	_motion.capture_transition(blend if action != clip else 0.0)
	clip = action
	if action not in ["attack","train","block"]:
		_armed_style = ""
	_update_weapon_visibility()
	phase = clampf(normalized,0,1)
	if not animator: return
	var name_in_file := action
	if not animator.has_animation(name_in_file):
		name_in_file = "attack" if action == "train" else "idle"
	if not animator.has_animation(name_in_file): return
	var animation := _playback_animation(name_in_file, action in LOOPS)
	# One transition owner on the motion-capture rig; avoid blending the
	# AnimationPlayer and manual pose transition a second time.
	animator.play(name_in_file,0.0 if _uses_youth_mocap() else blend)
	animator.seek(phase*animation.length,true)
	animator.advance(0)
	_apply_motion()


func _playback_animation(name_in_file: String, looping: bool) -> Animation:
	var mode := Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	var animation := animator.get_animation(name_in_file)
	if animation.loop_mode == mode:
		return animation
	# Always resolve from the imported source, even after this clip has used
	# another variant. Returning to idle must recover the shared idle resource.
	animation = CharacterMotion.playback_animation(_animation_sources[name_in_file], mode)
	if animator.get_animation(name_in_file) != animation:
		var slash := name_in_file.find("/")
		var library_name := name_in_file.substr(0, slash) if slash >= 0 else ""
		var animation_name := name_in_file.substr(slash + 1)
		var library := animator.get_animation_library(library_name)
		library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)
	return animation


func _apply_motion(review: bool = false) -> void:
	if active_model_path.begins_with("res://assets/characters/hero_meshy_italia_"):
		# Preserve the fitted adolescent rig's authored limb and sword clips.
		_motion.blend_transition()
		return
	if clip in ["attack","train","block"] and _can_armed_style(_armed_style):
		if _has_meshy_axe() and _armed_style in CharacterMotion.ARMED_ATTACKS:
			_apply_imported_axe_pose()
		else:
			_motion.armed_pose(_armed_style,phase,_can_armed_style("guard_front"))
		_hands.set_grip(0.95)
	elif clip in ["idle", "march", "run", "talk"]:
		_hands.set_grip(0.18 if clip != "run" else 0.34)
		if _motion.civilian:
			_motion.locomotion(clip, phase, -1.0 if review and clip in ["march", "run"] else speed / maxf(body.scale.y, 0.01), _turn_rate)
		else:
			_motion.imported_ambient(clip, phase)
	elif clip in ["attack", "train"] and role in ["player", "companion"] and not _has_sword:
		_hands.set_grip(0.18 + 0.82 * sin(phase * PI))
		_motion.combat("jab_right", phase)
	elif clip in ["work", "gather"] and animator and not animator.has_animation(clip):
		_hands.set_grip(0.34)
		_motion.imported_work(phase)
	else:
		_hands.set_grip(0.18)
	_motion.blend_transition()


func _apply_imported_axe_pose() -> void:
	# Preserve the imported actor's own skin-compatible attack as the base.
	# Its coat/arm seam has different weights than the authored hero. Apply
	# a conservative local-space overlay instead of replacing every joint.
	# Resample the base on each call so the overlay cannot accumulate.
	var rig := _motion.skeleton
	if not is_instance_valid(rig) or not animator or not animator.has_animation("attack"):
		return
	var animation := animator.get_animation("attack")
	animator.seek(clampf(phase, 0.0, 1.0) * animation.length, true)
	animator.advance(0)
	var base_positions: Array[Vector3] = []
	var base_rotations: Array[Quaternion] = []
	var base_scales: Array[Vector3] = []
	for bone in rig.get_bone_count():
		base_positions.append(rig.get_bone_pose_position(bone))
		base_rotations.append(rig.get_bone_pose_rotation(bone))
		base_scales.append(rig.get_bone_pose_scale(bone))
	if not _motion.armed_pose(_armed_style, phase, true):
		return
	const OVERLAY_WEIGHT := 0.15
	for bone in rig.get_bone_count():
		rig.set_bone_pose_position(bone, base_positions[bone].lerp(rig.get_bone_pose_position(bone), OVERLAY_WEIGHT))
		rig.set_bone_pose_rotation(bone, base_rotations[bone].slerp(rig.get_bone_pose_rotation(bone), OVERLAY_WEIGHT))
		rig.set_bone_pose_scale(bone, base_scales[bone])
	rig.force_update_all_bone_transforms()


func _distance_lod(distance: float) -> int:
	var factor := float({"low":0.55,"balanced":0.86,"high":1.15,"very_high":1.5}.get(profile,1.0))
	var distances: Array = CROWD_LOD_DISTANCES if role == "resident" else LOD_DISTANCES
	var level := 0
	for threshold: float in distances:
		if distance >= threshold * factor: level += 1
	return level


func refresh_lod(camera: Camera3D) -> void:
	if not is_instance_valid(camera) or not body: return
	var distance := global_position.distance_to(camera.global_position)
	var factor := float({"low":0.55,"balanced":0.86,"high":1.15,"very_high":1.5}.get(profile,1.0))
	var distances: Array = CROWD_LOD_DISTANCES if role == "resident" else LOD_DISTANCES
	var level := _distance_lod(distance)
	var same_profile := profile == _lod_profile
	_lod_profile = profile
	# A narrow dead band prevents repeated asset loads when walking along a LOD
	# boundary. An explicit graphics-profile change is applied without delay.
	if same_profile and detail >= 0:
		if level > detail and distance < float(distances[detail]) * factor * 1.10:
			return
		if level < detail and distance > float(distances[detail - 1]) * factor * 0.90:
			return
	if level != detail: _reload(level)


func _process(delta: float) -> void:
	_motion.advance(delta)
	_check_lod -= delta
	if _check_lod <= 0:
		_check_lod = 0.32
		refresh_lod(get_viewport().get_camera_3d())
	if not _combat_id.is_empty():
		if not _combat_external and _combat_duration > 0.0:
			_combat_progress = minf(1.0, _combat_progress + delta / _combat_duration)
			phase = _combat_progress
			_sample_combat_pose(_combat_id, _combat_progress)
			_hands.set_grip(0.18 + 0.82 * smoothstep(0.0, 0.15, _combat_progress) * (1.0 - smoothstep(0.82, 1.0, _combat_progress)))
			_face.advance(delta, "attack", detail)
			if _combat_progress >= 1.0:
				cancel_action()
		_ground_youth()
		return
	if _posed or _service_external:
		_ground_youth()
		return
	if clip != "death":
		_remaining = maxf(0,_remaining - delta)
		if _remaining <= 0 and not (_conversation_focused and clip == "talk"):
			var next := _locomotion_clip()
			if next != clip:
				var carry_phase := phase if clip in ["march", "run"] and next in ["march", "run"] else 0.0
				_play(next, carry_phase, 0.20 if _uses_youth_mocap() else 0.13)
	if animator and animator.is_playing():
		var advance := delta
		if clip in ["march","run"]:
			var stride := locomotion_stride(clip)
			advance *= speed * animator.current_animation_length / stride
		elif clip == "attack" and _strike_windup > 0.0:
			advance = _strike_clip_time(_strike_elapsed+delta)-_strike_clip_time(_strike_elapsed)
			_strike_elapsed += delta
		animator.advance(advance)
		if animator.current_animation != "":
			phase = animator.current_animation_position / animator.current_animation_length
	_apply_motion()
	_plant_contacts(delta)
	_ground_youth()
	_face.advance(delta,clip,detail)


func _ground_youth() -> void:
	if _uses_youth_mocap() and is_finite(youth_ground_floor_y):
		_youth_soles.apply_to_floor(youth_ground_floor_y,clip,phase)


func _plant_contacts(delta: float) -> void:
	# The recorded defensive step already includes its own foot placement.
	# Do not lock both ankles through a captured guard or flatten toe roll.
	if _uses_youth_mocap() and clip in ["idle","block"]:
		_motion.reset_world_contacts()
		return
	var stance := 0.40 if clip == "run" else 0.58
	if _motion.civilian:
		stance = 0.32 if clip == "run" else 0.53
	elif active_model_path.contains("meshy/") or active_model_path.begins_with("res://assets/characters/hero_meshy_italia_"):
		stance = 0.40 if clip == "run" else 0.56
	var preserve_roll := _uses_youth_mocap() and clip in ["march","run"]
	if preserve_roll:
		stance = 0.35 if clip == "run" else 0.56
	_motion.plant_world_feet(clip, phase, delta, stance,preserve_roll)


func world_foot_supported(side: String) -> bool:
	return _motion.world_foot_supported(side)
