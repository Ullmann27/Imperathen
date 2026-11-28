# ARCHITEKTUR_INDEX

## Autoloads

- `RuntimeDisplay="*res://scripts/ui/runtime_display.gd"`

## prototype/scripts/audio/audio_buses.gd

- `extends RefCounted`
- `static func ensure_layout() -> void`

## prototype/scripts/audio/combat_sfx.gd

- `extends Node3D`
- `func seed_variation(value: int) -> void`
- `func has_group(group: String) -> bool`
- `static func pair_group(material_a: String, material_b: String) -> String`
- `func play_impact(material_a: String, material_b: String, energy: float, position: Vector3) -> Dictionary`
- `func play_weapon_event(event: String, mechanism: String, position: Vector3, energy := 0.7) -> Dictionary`
- `func play_projectile_impact(target_material: String, position: Vector3, energy := 0.8) -> Dictionary`
- `func play_footstep(surface: String, position: Vector3, speed := 1.4) -> Dictionary`

## prototype/scripts/audio/dialogue_player.gd

- `extends Node`
- `signal line_started(line: Dictionary)`
- `signal line_finished(line: Dictionary)`
- `func play(text: String, speaker_label: String, emitter: Node3D = null, mouth_height := 1.55) -> Dictionary`
- `func play_line_id(line_id: String, emitter: Node3D = null, mouth_height := 1.55) -> Dictionary`
- `func stop() -> void`
- `func set_paused(paused: bool) -> void`
- `func is_active() -> bool`
- `func clock() -> float`

## prototype/scripts/audio/face_driver.gd

- `extends Node`
- `func bind(root: Node) -> Dictionary`
- `func set_track(new_track: Dictionary, new_clock: Callable) -> void`
- `func clear() -> void`
- `func sample(t: float) -> void`
- `func blink_weight() -> float`

## prototype/scripts/audio/npc_voices.gd

- `extends RefCounted`
- `static func category_for(appearance: String, age: int) -> String`
- `static func voice_for(npc_id: String, category: String) -> String`
- `static func bark(npc_id: String, category: String, bark_type: String) -> Dictionary`

## prototype/scripts/audio/procedural_test_head.gd

- `extends Node3D`
- `func build() -> void`

## prototype/scripts/audio/voice_lines.gd

- `extends RefCounted`
- `static func text_key(text: String) -> String`
- `static func speaker_id(label: String) -> String`
- `static func index_lines(lines: Array) -> Dictionary`
- `static func manifest() -> Dictionary`
- `static func find(text: String, speaker_label: String = "") -> Dictionary`
- `static func find_line_id(line_id: String) -> Dictionary`
- `static func all_lines() -> Array`
- `static func stream_for(line: Dictionary) -> AudioStream`
- `static func validate_viseme_track(parsed: Variant, line: Dictionary) -> bool`
- `static func viseme_track(line: Dictionary) -> Dictionary`

## prototype/scripts/battle/battle_model.gd

- `extends RefCounted`
- `static func campaign_authority(world: Dictionary) -> String`
- `func muster(troop_id: String) -> Dictionary`
- `static func ground_height(x: float, z: float) -> float`
- `func set_commander(appointment: String) -> bool`
- `func company_ids(formation_group_id: String, active_only: bool = true) -> Array[String]`
- `func hierarchy() -> Dictionary`
- `func soldiers(id: String) -> Array`
- `func soldier_record(uid: String) -> Dictionary`
- `func settlement_events(p_muster: bool = false) -> Array`
- `func roster(id: String) -> Array`
- `func preview(id: String, start: Vector2, end: Vector2) -> Array`
- `func preview_group(ids: Array, start: Vector2, end: Vector2) -> Array`
- `static func can_form(kind: String, shape: String) -> bool`
- `func order(ids: Array, command: String, target: Variant = null, by: String = "") -> Dictionary`
- `func tick(delta: float) -> void`
- `func casualty_morale(s: Dictionary, lost: int, sources: Array) -> float`
- `func strike_input(s: Dictionary, enemy: Dictionary, mode: String) -> Dictionary`
- `func summary() -> Dictionary`
- `func snapshot() -> Dictionary`
- `func restore(save: Dictionary) -> bool`

## prototype/scripts/battle/combat_formula.gd

- `extends RefCounted`
- `static func balance() -> Dictionary`
- `static func validate(b: Variant) -> Array[String]`
- `static func weapon_base(b: Dictionary, weapon: Dictionary) -> float`
- `static func quality(b: Dictionary, weapon: Dictionary) -> float`
- `static func competence(b: Dictionary, attacker: Dictionary) -> float`
- `static func zone(b: Dictionary, zone_id: String) -> float`
- `static func strike(b: Dictionary, weapon: Dictionary) -> String`
- `static func shield_block(b: Dictionary, defender: Dictionary) -> float`
- `static func defense(b: Dictionary, defender: Dictionary, ranged: bool) -> float`
- `static func protection(b: Dictionary, hit: Dictionary, kind: String) -> float`
- `static func contact(b: Dictionary, hit: Dictionary) -> float`
- `static func resolve_hit(hit: Dictionary, b: Dictionary = {}) -> Dictionary`
- `static func shield_cover(b: Dictionary, defender: Dictionary, facing_dot: float, ranged: bool) -> float`
- `static func unit_factor(b: Dictionary, name: String, strike_input: Dictionary) -> float`
- `static func unit_strike(strike_input: Dictionary, b: Dictionary = {}) -> Dictionary`
- `static func ranged_spec(weapon_family: String, b: Dictionary = {}) -> Dictionary`

## prototype/scripts/battle/formation_slots.gd

- `extends RefCounted`
- `static func natural_columns(shape: String, count: int) -> int`
- `static func rank_depth(shape: String) -> float`
- `static func offsets(shape: String, count: int, width: float) -> Array[Vector2]`
- `static func ranks(shape: String, count: int, width: float) -> Array[int]`
- `static func layout(shape: String, count: int, width: float) -> Dictionary`
- `static func world_slots(shape: String, count: int, width: float, center: Vector2, facing: float) -> Array[Vector2]`
- `static func ring_radius(count: int) -> float`

## prototype/scripts/battle/soldier_life.gd

- `extends RefCounted`
- `static func friends(record: Dictionary) -> Array`
- `static func shared_campaigns(a: Dictionary, b: Dictionary) -> Array`
- `static func close_campaign(records: Array, campaign: Dictionary) -> Array`
- `static func leave_reason(record: Dictionary) -> String`
- `static func leave(record: Dictionary, year: int) -> Dictionary`
- `static func promote(record: Dictionary, to_rank: String, year: int) -> Dictionary`
- `static func settlement_events(before: Array, after: Array, at: Dictionary) -> Array`

## prototype/scripts/battle/soldier_roster.gd

- `extends RefCounted`
- `static func mix(v: int) -> int`
- `static func text_salt(text: String) -> int`
- `static func roll(world_seed: int, a: int, b: int = 0, c: int = 0) -> float`
- `static func uid(squad_id: String, index: int) -> String`
- `static func identity(world_seed: int, squad_id: String, index: int, count: int, troop: Dictionary, pool: Dictionary, group: Dictionary, entry_xp: int, discipline: int, year: int, experience: Dictionary = {}, rank: String = "miles") -> Dictionary`
- `static func casualty(world_seed: int, id: String, step: int) -> Dictionary`
- `static func visual_variant(appearance_seed: int, rank: String, variants: int) -> int`
- `static func rescuer(world_seed: int, wounded: Dictionary, in_ranks: Array, step: int) -> String`
- `static func rescue(wounded: Dictionary, helper: Dictionary, year: int, step: int) -> void`
- `static func shift_trust(record: Dictionary, delta: int) -> void`
- `static func note(record: Dictionary, event: String, ref: String, year: int, step: int) -> void`
- `static func recover(record: Dictionary, days: int, year: int) -> Dictionary`
- `static func bond(people: Dictionary, alive: Array) -> float`
- `static func valid_record(r: Variant, original: Dictionary, company: Array, steps: int) -> bool`
- `static func integral(v: Variant) -> bool`
- `static func integers(v: Variant) -> Variant`

## prototype/scripts/battle/troop_catalog.gd

- `extends RefCounted`
- `static func load_default() -> Dictionary`
- `static func read_json(path: String) -> Variant`
- `static func build(families_doc: Variant, troops_doc: Variant, people_doc: Variant) -> Dictionary`
- `static func is_integer(v: Variant, low: int, high: int) -> bool`
- `static func valid_year(v: Variant) -> bool`
- `static func valid_span(entry: Dictionary) -> bool`
- `static func valid_at(entry: Dictionary, year: int) -> bool`
- `static func years_between(from_year: int, to_year: int) -> int`
- `static func year_label(year: int) -> String`
- `static func organization_options(catalog: Dictionary, culture: String, year: int) -> Array[Dictionary]`
- `static func validate(families_doc: Variant, troops_doc: Variant, people_doc: Variant) -> Array[String]`
- `static func unmet_needs(needs: Dictionary, profile: Dictionary) -> Array[String]`
- `static func valid_profile(profile: Variant) -> bool`
- `static func military_options(catalog: Dictionary, profile: Variant) -> Dictionary`
- `static func capped_tiers(catalog: Dictionary, options: Dictionary, troop_id: String, choice: Dictionary) -> Dictionary`
- `static func company_tiers(catalog: Dictionary, troop_id: String, choice: Dictionary) -> Dictionary`
- `static func troop(catalog: Dictionary, troop_id: String) -> Dictionary`
- `static func available(catalog: Dictionary, year: int, culture: String = "", service: String = "") -> Array[String]`
- `static func families_of(catalog: Dictionary, troop_id: String) -> Array[String]`
- `static func resolve_loadout(catalog: Dictionary, troop_id: String) -> Dictionary`
- `static func entry_xp(catalog: Dictionary, troop_id: String) -> int`
- `static func plan_upgrade(catalog: Dictionary, record: Dictionary, to_id: String, year: int, inventory: Array, authorities: Array) -> Dictionary`
- `static func apply_upgrade(catalog: Dictionary, record: Dictionary, to_id: String, year: int, inventory: Array, authorities: Array) -> Dictionary`

## prototype/scripts/battle/valley_field.gd

- `extends RefCounted`
- `static func height(x: float, z: float) -> float`
- `static func clear_segment(a: Vector2, b: Vector2) -> bool`
- `static func project(p: Vector2) -> Vector2`
- `func next_position(p: Vector2, dest: Vector2, distance: float) -> Vector2`

## prototype/scripts/battle/valley_muster.gd

- `extends RefCounted`
- `static func remaining(contracts: Array) -> Dictionary`
- `static func scenario(base: Dictionary, contracts: Array) -> Dictionary`
- `static func restore_plan(base: Dictionary, key: String) -> Dictionary`

## prototype/scripts/character_core/armor_piece_resource.gd

- `class_name ArmorPieceResource`
- `extends Resource`
- `static func from_catalog(id: String, tier: int, detail: int) -> ArmorPieceResource`
- `func supports_place(place: String) -> bool`

## prototype/scripts/character_core/body_pose_modifier.gd

- `extends SkeletonModifier3D`

## prototype/scripts/character_core/character_core.gd

- `class_name CharacterCore`
- `extends CharacterBody3D`
- `signal rig_bound(skeleton: Skeleton3D)`
- `signal motion_state_changed(previous: int, current: int)`
- `signal grounded_changed(grounded: bool)`
- `signal movement_sampled(world_velocity: Vector3, grounded: bool)`
- `signal animation_intent_sampled(world_velocity: Vector3, speed: float, yaw_rate: float, grounded: bool)`
- `signal command_rejected(reason: String)`
- `func is_character_ready() -> bool`
- `func request_motion(world_direction: Vector3, amount: float, gait: int = Gait.WALK) -> bool`
- `func stop_motion() -> void`
- `func request_facing(world_direction: Vector3) -> bool`
- `func clear_facing() -> void`
- `func set_movement_enabled(value: bool) -> void`
- `func set_speed_multiplier(value: float) -> bool`
- `func set_ik_enabled(value: bool) -> void`
- `func set_look_target(world_point: Vector3) -> void`
- `func clear_look_target() -> void`
- `func set_upper_body_clip(clip: StringName, weight: float) -> bool`
- `func clear_upper_body() -> void`
- `func get_character_skeleton() -> Skeleton3D`
- `func get_animation_tree() -> AnimationTree`
- `func get_motion_state() -> int`
- `func get_planar_speed() -> float`
- `func get_yaw_rate() -> float`
- `func get_foot_contact(side: int) -> Dictionary`
- `func get_pelvis_offset() -> float`
- `func get_upper_filter_paths() -> Array[NodePath]`
- `func get_bone_world_transform(bone_name: StringName) -> Transform3D`

## prototype/scripts/character_core/equipment_component.gd

- `class_name EquipmentComponent`
- `extends Node`
- `signal equipment_changed`
- `signal equipment_rejected(reason: String)`
- `signal socket_switched(slot: String, place: String)`
- `signal switch_finished(slot: String, committed: bool)`
- `func is_equipment_ready() -> bool`
- `func get_attachment(slot: String) -> BoneAttachment3D`
- `func get_place(slot: String) -> String`
- `func is_switch_pending() -> bool`
- `func sync_from_world(data: Dictionary, detail: int = 0) -> bool`
- `func request_socket_switch(slot: String, place: String, clip: StringName, timeout_seconds: float = 1.5) -> bool`
- `func commit_socket_switch() -> bool`
- `func finish_socket_switch() -> void`
- `func clear_equipment() -> void`

## prototype/scripts/character_core/foot_alignment_modifier.gd

- `extends SkeletonModifier3D`

## prototype/scripts/character_core/foot_placement.gd

- `extends Node3D`
- `class Leg extends RefCounted`
- `func bind(body: CharacterBody3D, skeleton: Skeleton3D, pelvis: int, spine: int, head: int, leg_names: Array[StringName]) -> bool`
- `func set_enabled(value: bool) -> void`
- `func set_look_target(world_point: Vector3) -> void`
- `func clear_look_target() -> void`
- `func update_pose(delta: float, on_floor: bool, speed: float, yaw_rate: float) -> void`
- `func get_contact(side: int) -> Dictionary`
- `func get_pelvis_offset() -> float`

## prototype/scripts/character_core/locomotion_graph.gd

- `extends RefCounted`
- `func configure(tree: AnimationTree, player: AnimationPlayer, skeleton: Skeleton3D, spine: int, walk: float, run: float, sprint: float) -> bool`
- `func set_upper_body_clip(clip: StringName, weight: float) -> bool`
- `func clear_upper_body() -> void`
- `func advance(delta: float, speed: float, signed_turn: float, grounded: bool) -> void`
- `func get_upper_filter_paths() -> Array[NodePath]`

## prototype/scripts/character_core/phase1_review.gd

- `extends Node3D`

## prototype/scripts/cinematic/i00_camp_scenery.gd

- `extends RefCounted`
- `static func grounded_elevation(at: Vector2) -> float`
- `static func build(parent: Node3D) -> Node3D`

## prototype/scripts/cinematic/i00_stage.gd

- `extends Node3D`
- `func ensure_built() -> void`
- `func anchor(key: String) -> Vector3`
- `func speaker(id: String) -> Node3D`
- `func set_presentation_paused(value: bool) -> void`

## prototype/scripts/cinematic/i00_vexillum.gd

- `extends Node3D`
- `func build(wood: Material, bronze: Material, phase_offset: float) -> void`
- `static func has_original_textile(candidate: MeshInstance3D) -> bool`
- `func sample_wind(seconds: float) -> void`
- `static func displaced(vertex: Vector3, uv: Vector2, seconds: float, phase_offset: float = 0.0) -> Vector3`

## prototype/scripts/cinematic/opening_checkpoint.gd

- `extends RefCounted`
- `static func write(world_id: String, sequence_id: String, index: int, completed: bool, path: String = PATH) -> Error`
- `static func read(world_id: String, path: String = PATH) -> Dictionary`

## prototype/scripts/cinematic/opening_director.gd

- `extends Node3D`
- `signal shot_started(shot_id: String)`
- `signal shot_finished(shot_id: String)`
- `func setup(world: Node3D) -> bool`
- `func play(next_shot: String, seconds: float, reduce_motion := false, beat_seconds: float = -1.0, shot_fraction: float = 0.0) -> bool`
- `func begin_beat(actor_id: String) -> void`
- `func set_paused(value: bool) -> void`
- `func sample(next_shot: String, normalized_time: float, beat_seconds: float = -1.0) -> Dictionary`
- `func snapshot() -> Dictionary`
- `func finish() -> void`
- `func prepare_cinematic_cast(next_shot: String, actor_id: String) -> void`

## prototype/scripts/city_support_district.gd

- `extends Node3D`
- `func interact() -> void`
- `func save_visit() -> void`
- `func load_visit() -> void`

## prototype/scripts/city_support_panel.gd

- `extends CanvasLayer`
- `signal command_requested(command: String, arguments: Dictionary)`
- `signal closed`
- `signal save_requested`
- `signal load_requested`
- `signal quality_requested(profile: String)`
- `signal interact_requested`
- `signal inventory_requested`
- `func update_state(state: Dictionary) -> void`
- `func set_nearest(name: String, distance: float) -> void`
- `func notify(message: String) -> void`
- `func is_open() -> bool`
- `func open_shop(id: String) -> void`
- `func open_inventory() -> void`
- `func close() -> void`

## prototype/scripts/city_trade.gd

- `extends RefCounted`
- `static func enabled(data: Dictionary) -> bool`
- `static func shop_catalog(include_optional := false) -> Array[Dictionary]`
- `static func item_catalog() -> Dictionary`
- `static func validate_arguments(command: String, args: Dictionary) -> String`
- `static func apply(data: Dictionary, command: String, args: Dictionary, sites: Dictionary = {}, quote: Dictionary = {}) -> Dictionary`
- `static func view(data: Dictionary, shop_id := "", sites: Dictionary = {}, quote_item: Callable = Callable()) -> Dictionary`
- `static func skills(data: Dictionary) -> Dictionary`
- `static func equipment_bonuses(data: Dictionary) -> Dictionary`
- `static func service_gear(data: Dictionary) -> bool`
- `static func damage_bonus(data: Dictionary, armed: bool) -> int`
- `static func guard_bonus_seconds(data: Dictionary) -> float`
- `static func command_bonus(data: Dictionary) -> int`
- `static func validate(data: Dictionary) -> String`
- `static func migrate(data: Dictionary) -> void`
- `static func restore_integer_fields(data: Dictionary) -> void`
- `static func money_effect(data: Dictionary, city_goods_only := false) -> int`
- `static func trained_soldier(data: Dictionary) -> bool`
- `static func reward_proven(data: Dictionary, id: String) -> bool`
- `static func selected_horse(data: Dictionary) -> Dictionary`
- `static func simulated_good(item_id: String) -> bool`

## prototype/scripts/city_trade_catalog.gd

- `extends RefCounted`

## prototype/scripts/domain/actor_relations.gd

- `extends RefCounted`
- `static func new_graph() -> Dictionary`
- `static func key(observer: String, subject: String) -> String`
- `static func knows(graph: Dictionary, observer: String, subject: String) -> bool`
- `static func value(graph: Dictionary, observer: String, subject: String, dimension: String) -> float`
- `static func edge(graph: Dictionary, observer: String, subject: String) -> Dictionary`
- `static func introduce(graph: Dictionary, observer: String, subject: String, event_id: String, tick: int, kind: String) -> bool`
- `static func apply(graph: Dictionary, observer: String, subject: String, event_id: String, tick: int, kind: String, deltas: Dictionary) -> Dictionary`
- `static func decay(graph: Dictionary, ticks: int = 1) -> void`
- `static func decay_keys(graph: Dictionary, keys: Array, ticks: int = 1) -> void`
- `static func stance(graph: Dictionary, observer: String, subject: String) -> String`
- `static func observers_of(graph: Dictionary, subject: String) -> Array`
- `static func known_by(graph: Dictionary, observer: String) -> Array`
- `static func remove_actor(graph: Dictionary, actor: String) -> void`
- `static func normalize(graph: Dictionary) -> void`
- `static func validate(graph: Variant, actor_ids: Dictionary, now_tick: int) -> String`
- `static func validate_header(graph: Variant) -> String`
- `static func validate_edges(graph: Dictionary, keys: Array, actor_ids: Dictionary, now_tick: int) -> String`

## prototype/scripts/domain/calendar_ageing_participant.gd

- `extends "res://scripts/domain/time_jump_participant.gd"`
- `func domain() -> String`
- `func advance(domain_state: Dictionary, step: Dictionary, _context: Dictionary) -> Dictionary`

## prototype/scripts/domain/campaign_allegiance.gd

- `extends RefCounted`
- `static func affiliation(world: Dictionary) -> String`
- `static func roman_command(world: Dictionary) -> bool`
- `static func label(world: Dictionary, target: String) -> String`
- `static func available(world: Dictionary) -> bool`
- `static func validate_arguments(_command: String, args: Dictionary) -> String`
- `static func reason(world: Dictionary, cmd: String, target: String) -> String`
- `static func apply(world: Dictionary, cmd: String, args: Dictionary) -> Dictionary`
- `static func view(world: Dictionary) -> Dictionary`
- `static func validate(world: Dictionary) -> String`
- `static func donated_grain(world: Dictionary) -> int`

## prototype/scripts/domain/campaign_timeline.gd

- `extends RefCounted`
- `static func data() -> Dictionary`
- `static func mission(mission_id: String) -> Dictionary`
- `static func missions() -> Array`
- `static func band_missions(band: int) -> Array`
- `static func mission_window(mission_id: String) -> Dictionary`
- `static func protected_ids() -> Array`
- `static func reset_cache_for_tests() -> void`
- `static func load_file(path: String) -> Dictionary`
- `static func validate(source: Dictionary) -> Dictionary`
- `static func finding_keys(report: Dictionary) -> Array`

## prototype/scripts/domain/city_anchors.gd

- `extends RefCounted`
- `static func parse_file(data: Variant, label: String) -> Dictionary`
- `static func entry_error(value: Variant) -> String`
- `static func normalise(value: Dictionary) -> Dictionary`
- `static func load_all(directory: String = DIR) -> Dictionary`
- `static func in_era(anchor: Dictionary, year: int) -> bool`
- `static func open_at(anchor: Dictionary, hour: float) -> bool`
- `static func serves(anchor: Dictionary, tier: String) -> bool`
- `static func tag_value(anchor: Dictionary, prefix: String) -> String`
- `static func has_tag(anchor: Dictionary, tag: String) -> bool`
- `static func usable(index: Dictionary, year: int, present_nodes: Callable = Callable()) -> Array[String]`
- `static func to_json_entry(anchor: Dictionary) -> Dictionary`

## prototype/scripts/domain/city_barks.gd

- `extends RefCounted`
- `static func data() -> Dictionary`
- `static func voice_category(female: bool, age: int) -> String`
- `static func voice_id(resident_id: String, category: String) -> String`
- `static func lines_for(life: RefCounted, event: Dictionary) -> Array`
- `static func vendor_call(life: RefCounted, vendor: int, call: String, slot: int) -> Dictionary`
- `static func greeting(life: RefCounted, person: int, hour: float, slot: int) -> Dictionary`
- `static func recording_list() -> Array`

## prototype/scripts/domain/city_checkpoint.gd

- `extends RefCounted`
- `static func pack_city(state: Dictionary, generation: int, opening_denarii: int) -> Dictionary`
- `static func valid_header(record: Variant) -> bool`
- `static func unpack_city(record: Variant) -> Dictionary`

## prototype/scripts/domain/city_life.gd

- `extends RefCounted`
- `func setup_data() -> bool`
- `func found(seed: int, jdn: int, second_of_day: int) -> bool`
- `func save_state() -> Dictionary`
- `func load_state(saved: Variant) -> bool`
- `static func validate(saved: Variant) -> String`
- `func enter_year(next_year: int) -> bool`
- `static func hour_of(t: int) -> float`
- `func clock() -> Dictionary`
- `func advance_to(now: int, budget_usec: int = 2000) -> Dictionary`
- `func advance(seconds: int, budget_usec: int = 2000) -> Dictionary`
- `func occupants(anchor_id: String) -> Array`
- `func walk_speed_cm(person: int) -> int`
- `func home_of(resident: Dictionary) -> String`
- `func audit() -> Dictionary`
- `func events_since(seq: int) -> Array`
- `func hunger(resident: Dictionary, t: int) -> int`
- `func loneliness(resident: Dictionary, t: int) -> int`
- `func devotion(resident: Dictionary, t: int) -> int`
- `func age(resident: Dictionary) -> int`
- `func business_staffed(number: int, t: int) -> bool`
- `func business_open(number: int, t: int) -> bool`
- `func alarm(t: int, kind: String, anchor_id: String, radius: float, culprit: int = -1) -> Dictionary`
- `func alarm_at(t: int, kind: String, centre: Vector3, radius: float, culprit: int = -1, anchor_id: String = "") -> Dictionary`
- `func set_weather(kind: String, forced: bool = true) -> void`
- `func business_for_shop(shop_id: String) -> int`
- `func offers(number: int) -> Array`
- `func player_trade_good(number: int, shop_item: String) -> String`
- `func player_trade_error(shop_id: String, shop_item: String, quantity: int, denarii: int, buying: bool) -> String`
- `func record_player_trade(shop_id: String, shop_item: String, quantity: int, denarii: int, buying: bool) -> bool`
- `func is_indoors(person: int, now: int) -> bool`
- `func is_walking(person: int, now: int) -> bool`
- `func slot_position(anchor_id: String, slot: int) -> Vector3`
- `func slot_facing(anchor_id: String, slot: int) -> float`
- `func trip_path(person: int) -> PackedVector3Array`
- `func trip_fraction(person: int, now: int) -> float`
- `func position_of(person: int, now: int) -> Vector3`
- `func summary() -> Dictionary`

## prototype/scripts/domain/city_population.gd

- `extends RefCounted`
- `static func mix(a: int, b: int, c: int = 0, d: int = 0) -> int`
- `static func fnv(text: String) -> int`
- `static func between(h: int, low: int, high: int) -> int`
- `static func resident_id(index: int) -> String`
- `static func found(seed: int, index: Dictionary, anchor_ids: Array, economy: Dictionary, year: int) -> Dictionary`
- `static func age_of(resident: Dictionary, year: int) -> int`
- `static func meet(state: Dictionary, observer: int, subject: int, event_id: String, tick: int, kind: String, trust_delta: int) -> void`
- `static func trust(state: Dictionary, observer: int, subject: int) -> float`
- `static func knows(state: Dictionary, observer: int, subject: int) -> bool`

## prototype/scripts/domain/city_social.gd

- `extends RefCounted`
- `static func resident_id(index: int) -> String`
- `static func new_shards() -> Array`
- `static func meeting(state: Dictionary, observer: int, subject: int, event: String, week: int, kind: String, trust: int) -> bool`
- `static func witnessed_theft(state: Dictionary, vendor: int, thief: int, at_second: int) -> bool`
- `static func close_week(state: Dictionary, number: int) -> bool`
- `static func trust(state: Dictionary, observer: int, subject: int) -> float`
- `static func knows(state: Dictionary, observer: int, subject: int) -> bool`
- `static func validate_saved(state: Dictionary, people: Dictionary, week: int) -> String`
- `static func restore(state: Dictionary) -> void`

## prototype/scripts/domain/city_streets.gd

- `extends RefCounted`
- `func load_graph(path: String = PATH) -> bool`
- `func node_position(index: int) -> Vector3`
- `func closest_node(position: Vector3) -> int`
- `func survey_lines() -> PackedVector2Array`
- `func node_for(anchor_id: String, position: Vector3) -> int`
- `func length(from: int, to: int) -> float`
- `func route(from: int, to: int) -> PackedVector3Array`
- `static func along(points: PackedVector3Array, distance: float) -> Array`
- `static func polyline_length(points: PackedVector3Array) -> float`

## prototype/scripts/domain/city_watch.gd

- `extends RefCounted`
- `static func roster(world: Dictionary) -> Array[Dictionary]`
- `static func validate_arguments(command: String, args: Dictionary) -> String`
- `static func reputation(world: Dictionary) -> int`
- `static func apply(world: Dictionary, command: String, args: Dictionary, observed: Dictionary) -> Dictionary`
- `static func validate(world: Dictionary, record: Variant) -> String`

## prototype/scripts/domain/combat_actions.gd

- `extends RefCounted`
- `static func start(data: Dictionary) -> void`
- `static func enabled(data: Dictionary) -> bool`
- `static func is_armed(id: String) -> bool`
- `static func service_gear(data: Dictionary) -> bool`
- `static func available(data: Dictionary, id: String) -> bool`
- `static func validate_arguments(command: String, args: Dictionary) -> String`
- `static func execute(data: Dictionary, command: String, args: Dictionary) -> Dictionary`
- `static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable(), apply_hit: Callable = Callable()) -> Dictionary`
- `static func interrupt(data: Dictionary) -> bool`
- `static func busy(data: Dictionary) -> bool`
- `static func phase(id: String, elapsed: float) -> String`
- `static func hit_damage(data: Dictionary, technique: String, _contact_frame: int) -> int`
- `static func measured(id: String) -> Dictionary`
- `static func strike_kit(id: String) -> String`
- `static func strike_scale(data: Dictionary, id: String) -> float`
- `static func view(data: Dictionary) -> Dictionary`
- `static func validate(data: Dictionary) -> String`
- `static func guard_bonus_seconds(data: Dictionary) -> float`

## prototype/scripts/domain/era_registry.gd

- `extends RefCounted`
- `static func registry() -> Dictionary`
- `static func reset_cache_for_tests() -> void`
- `static func build(data: Dictionary) -> Dictionary`
- `static func validate_data(data: Dictionary) -> Array`
- `static func resolve(content_id: String, reg: Dictionary = {}) -> String`
- `static func entry(content_id: String, reg: Dictionary = {}) -> Dictionary`
- `static func window(content_id: String, overrides: Dictionary = {}, reg: Dictionary = {}) -> Dictionary`
- `static func available(content_id: String, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> bool`
- `static func active(kind: String, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> Array`
- `static func state_at(slot: String, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> String`
- `static func changes_between(from_jdn: int, to_jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> Array`
- `static func validate_overrides(overrides: Dictionary, reg: Dictionary = {}) -> Array`
- `static func era_min_visible(era_min_year: int, jdn: int) -> bool`
- `static func asset_available(play_mode: String, jdn: int, earliest_year: int, latest_year: int = 0) -> bool`
- `static func filter_available(content_ids: Array, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> Array`

## prototype/scripts/domain/gear_market.gd

- `extends RefCounted`
- `static func catalog() -> Dictionary`
- `static func families() -> Dictionary`
- `static func reset_cache_for_tests() -> void`
- `static func catalog_errors(data: Variant) -> Array[String]`
- `static func item(item_id: String) -> Dictionary`
- `static func price(item_id: String, quality: int) -> int`
- `static func sell_price(item_id: String, quality: int) -> int`
- `static func tiers(item_id: String) -> Array`
- `static func model_path(item_id: String, lod: int) -> String`
- `static func world_jdn(data: Dictionary) -> int`
- `static func era_window(item_id: String) -> Dictionary`
- `static func era_open(item_id: String, jdn: int, overrides: Dictionary = {}) -> bool`
- `static func access_context(data: Dictionary) -> Dictionary`
- `static func access_reason(rules: Dictionary, context: Dictionary) -> String`
- `static func specialist(shop_id: String, context: Dictionary) -> bool`
- `static func tier_reason(shop_id: String, item_id: String, quality: int, context: Dictionary) -> String`
- `static func offer_reason(shop_id: String, item_id: String, quality: int, context: Dictionary) -> String`
- `static func enabled(data: Dictionary) -> bool`
- `static func validate_arguments(command: String, args: Dictionary) -> String`
- `static func apply(data: Dictionary, command: String, args: Dictionary, sites: Dictionary = {}) -> Dictionary`
- `static func wear_reason(item_id: String, context: Dictionary) -> String`
- `static func stock(data: Dictionary, shop_id: String, item_id: String, quality: int) -> int`
- `static func quality_name(quality: int) -> String`
- `static func money_effect(data: Dictionary) -> int`
- `static func validate(data: Dictionary) -> String`
- `static func restore_integer_fields(data: Dictionary) -> void`
- `static func view(data: Dictionary, shop_id := "", sites: Dictionary = {}) -> Dictionary`
- `static func equipped_models(data: Dictionary) -> Array[Dictionary]`
- `static func combat_inputs(data: Dictionary) -> Dictionary`
- `static func registry(jdn: int) -> Array[Dictionary]`

## prototype/scripts/domain/local_weather.gd

- `extends RefCounted`
- `static func kind_for(jdn: int, block: int, origin: String) -> String`
- `static func sample(clock: Variant, origin: String, legacy_season: int = 0) -> Dictionary`
- `static func settled_wetness(day: int, block: int, origin: String) -> float`
- `static func city_kind(clock: Variant, origin: String = "italia") -> String`
- `static func for_state(data: Dictionary) -> Dictionary`

## prototype/scripts/domain/melee/combat_impact_hub.gd

- `extends RefCounted`
- `signal impact(record: Dictionary)`

## prototype/scripts/domain/melee/combat_impacts.gd

- `extends RefCounted`
- `static func hub() -> HubScript`
- `static func connect_listener(listener: Callable) -> void`
- `static func disconnect_listener(listener: Callable) -> void`
- `static func has_listeners() -> bool`
- `static func record(event: Dictionary) -> Dictionary`
- `static func publish(events: Array) -> int`

## prototype/scripts/domain/melee/melee_ai.gd

- `extends RefCounted`
- `static func decide(state: Dictionary, id: String, target_id: String, skill: float = -1.0) -> Dictionary`
- `static func reads(state: Dictionary, f: Dictionary, t: Dictionary, skill: float) -> bool`
- `static func open_move(state: Dictionary, f: Dictionary, t: Dictionary, skill: float) -> String`
- `static func best_move(state: Dictionary, f: Dictionary, t: Dictionary) -> Dictionary`
- `static func guard_for(state: Dictionary, f: Dictionary, t: Dictionary) -> String`
- `static func apply(state: Dictionary, id: String, target_id: String, decision: Dictionary, delta: float, speed: float = PACE, motion_check: Callable = Callable()) -> Dictionary`

## prototype/scripts/domain/melee/melee_core.gd

- `extends RefCounted`
- `static func new_state(seed: int) -> Dictionary`
- `static func add_fighter(state: Dictionary, id: String, kit_id: String, options: Dictionary = {}) -> String`
- `static func fighter(state: Dictionary, id: String) -> Dictionary`
- `static func place(state: Dictionary, id: String, x: float, z: float, yaw: float) -> bool`
- `static func face(state: Dictionary, id: String, target_id: String) -> bool`
- `static func move_cost(kit_id: String, move_id: String) -> float`
- `static func command(state: Dictionary, id: String, action: String, args: Dictionary = {}) -> Dictionary`
- `static func morale_event(state: Dictionary, id: String, delta: float, reason: String) -> Array`
- `static func step(state: Dictionary, delta: float, world_clear: Callable = Callable()) -> Array`
- `static func dodge_offset(style: String, seconds: float) -> Vector3`
- `static func shield_usable(f: Dictionary) -> bool`
- `static func shield_lowered(f: Dictionary) -> bool`
- `static func shield_open(f: Dictionary) -> bool`
- `static func shield_world(f: Dictionary) -> Array`
- `static func shield_half(f: Dictionary) -> Vector3`
- `static func strike_world(f: Dictionary, frame: int) -> Array`
- `static func hitstop_frames(energy: float, on_shield: bool) -> int`
- `static func aim_yaw(state: Dictionary, id: String, target_id: String, move_id: String) -> float`
- `static func preview_strike(state: Dictionary, id: String, move_id: String, yaw: float = NAN) -> Dictionary`
- `static func phase(f: Dictionary) -> String`
- `static func nominal_reach(kit_id: String, move_id: String, defender_radius: float, scale: float = 1.0) -> float`
- `static func simulate_strike(attacker_kit: String, move: String, defender_kit: String, distance: float, bearing_deg: float = 0.0, guard: String = "", seed: int = 1, defender_options: Dictionary = {}, attacker_options: Dictionary = {}) -> Dictionary`
- `static func release_point(f: Dictionary, weapon_id: String) -> Vector3`

## prototype/scripts/domain/melee/melee_damage.gd

- `extends RefCounted`
- `static func kit_armor(clothing: String) -> Dictionary`
- `static func surface_material(pieces: Dictionary, clothing: String, zone: String) -> String`
- `static func injury_kinds(injuries: Array) -> Array`
- `static func compute(hit: Dictionary) -> Dictionary`

## prototype/scripts/domain/melee/melee_feedback.gd

- `extends RefCounted`
- `static func for_event(event: Dictionary) -> Dictionary`

## prototype/scripts/domain/melee/melee_geometry.gd

- `extends RefCounted`
- `static func segment_segment(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array`
- `static func body_axis(foot: Vector3, radius: float, height: float) -> Array`
- `static func segment_box(p: Vector3, q: Vector3, center: Vector3, u: Vector3, v: Vector3, half: Vector3, inflate: float) -> float`
- `static func forward(yaw: float) -> Vector3`
- `static func right(yaw: float) -> Vector3`
- `static func to_world(origin: Vector3, yaw: float, scale: float, local: Vector3) -> Vector3`
- `static func to_local(origin: Vector3, yaw: float, world: Vector3) -> Vector3`
- `static func side_of(yaw: float, world_dir: Vector3) -> String`
- `static func fnv(text: String) -> int`
- `static func unit_random(seed_text: String) -> float`

## prototype/scripts/domain/melee/melee_ranged.gd

- `extends RefCounted`
- `static func direction(yaw: float, pitch: float) -> Vector3`
- `static func launch_speed(weapon_id: String) -> float`
- `static func launch_energy(weapon_id: String) -> float`
- `static func energy(weapon_id: String, velocity: Vector3) -> float`
- `static func aim_vacuum(from: Vector3, to: Vector3, speed: float) -> Dictionary`
- `static func aim(weapon_id: String, from: Vector3, to: Vector3) -> Dictionary`
- `static func spread(weapon_id: String, skill: float, fatigue: float, held_s: float) -> float`
- `static func advance(weapon_id: String, position: Vector3, velocity: Vector3, dt: float) -> Array`

## prototype/scripts/domain/melee/melee_track_data.gd

- `extends RefCounted`

## prototype/scripts/domain/melee/melee_tracks.gd

- `extends RefCounted`
- `static func key(kit: String, move: String) -> String`
- `static func has_move(kit: String, move: String) -> bool`
- `static func move(kit: String, move_id: String) -> Dictionary`
- `static func kit(kit_id: String) -> Dictionary`
- `static func moves_of(kit_id: String) -> Array[String]`
- `static func timing(kit_id: String, move_id: String) -> Dictionary`
- `static func frame_of(seconds: float) -> int`
- `static func segment(kit_id: String, move_id: String, frame: int) -> Array`
- `static func shield(kit_id: String, pose_id: String, frame: int) -> Array`
- `static func guard_styles() -> Array[String]`
- `static func sweep_body(kit_id: String, move_id: String, scale: float, origin: Vector3, yaw: float, frame: int, foot: Vector3, radius: float, height: float) -> Dictionary`
- `static func drive_speed(kit_id: String, move_id: String, frame: int, along: float) -> float`

## prototype/scripts/domain/melee/weapon_catalog.gd

- `extends RefCounted`
- `static func document() -> Dictionary`
- `static func ids() -> Array[String]`
- `static func has(id: String) -> bool`
- `static func weapon(id: String) -> Dictionary`
- `static func weapon_class(id: String) -> String`
- `static func is_ranged(id: String) -> bool`
- `static func of_class(cls: String) -> Array[String]`
- `static func available_in(year: int) -> Array[String]`
- `static func material(id: String) -> String`
- `static func impact_material(id: String) -> String`
- `static func effective_mass(id: String) -> float`
- `static func balance_family(id: String) -> String`
- `static func stamina_cost(id: String) -> float`
- `static func one_legged(id: String) -> bool`
- `static func strike_kind(id: String, move_id: String = "") -> String`
- `static func ranged_timing(id: String) -> Dictionary`
- `static func validate(doc: Variant) -> Array[String]`

## prototype/scripts/domain/npc_behavior.gd

- `extends RefCounted`
- `static func enabled(data: Dictionary) -> bool`
- `static func roster() -> Dictionary`
- `static func profile(id: String) -> Dictionary`
- `static func start(data: Dictionary) -> void`
- `static func resume_after_interlude(data: Dictionary) -> void`
- `static func ensure_social(data: Dictionary) -> void`
- `static func observe(data: Dictionary, observations: Variant, complete_snapshot := false) -> void`
- `static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable()) -> void`
- `static func daily_window(data: Dictionary, id: String) -> String`
- `static func view(data: Dictionary, id: String) -> Dictionary`
- `static func social_neighbors(data: Dictionary, id: String) -> Array`
- `static func validate(data: Dictionary) -> String`

## prototype/scripts/domain/npc_social_memory.gd

- `extends RefCounted`
- `static func initial_state() -> Dictionary`
- `static func advance(social: Dictionary, people: Dictionary, available: Dictionary, now: float, delta: float, sight_check: Callable = Callable(), visibility_cache: Variant = null) -> void`
- `static func close_conversation(person: Dictionary, other: Dictionary, sight_check: Callable = Callable(), visibility_cache: Variant = null) -> bool`
- `static func clear_sight(first: Array, second: Array, sight_check: Callable = Callable(), visibility_cache: Variant = null) -> bool`
- `static func pair_key(id: String, other_id: String) -> String`
- `static func relationship(social: Dictionary, id: String, other_id: String) -> Dictionary`
- `static func preference(social: Dictionary, id: String, other_id: String) -> float`
- `static func validate(value: Variant, ids: Array, now: float) -> String`

## prototype/scripts/domain/party_conversations.gd

- `extends RefCounted`
- `static func record(world: Dictionary, step: String, witnesses: Dictionary) -> String`
- `static func name_for(world: Dictionary, uid: String) -> String`
- `static func opinions(world: Dictionary, uid: String) -> Dictionary`
- `static func stance(world: Dictionary, uid: String, other: String, graph: Dictionary) -> String`
- `static func row(world: Dictionary, uid: String) -> Dictionary`
- `static func answer(world: Dictionary, uid: String, step: String, choice: String) -> Dictionary`
- `static func validate(world: Dictionary, outings: Variant, task_roles: Callable) -> String`

## prototype/scripts/domain/person_registry.gd

- `extends RefCounted`
- `static func global_id(space: String, local_id: String) -> String`
- `static func split(global: String) -> Array`
- `static func patrol_uid(world: Dictionary, index: int) -> String`
- `static func collect(world: Dictionary) -> Dictionary`
- `static func soldier_age(world: Dictionary, record: Dictionary) -> int`
- `static func relation_actor(world: Dictionary, actor: String) -> String`
- `static func resolve(world: Dictionary, global: String) -> String`
- `static func validate(world: Dictionary) -> String`

## prototype/scripts/domain/political_offices.gd

- `extends RefCounted`
- `static func validation_errors() -> Array`
- `static func build(data: Dictionary) -> Dictionary`
- `static func get_office(id: String, jdn: int) -> Dictionary`
- `static func available(jdn: int, scope: String = "") -> Array[Dictionary]`
- `static func candidacy(id: String, jdn: int, person: Dictionary, jurisdiction: String) -> Dictionary`

## prototype/scripts/domain/political_persons.gd

- `extends RefCounted`
- `static func ids() -> Array[String]`
- `static func for_world(person_id: String, world: Dictionary) -> Dictionary`
- `static func at_day(person_id: String, jdn: int) -> Dictionary`

## prototype/scripts/domain/raid_route.gd

- `extends RefCounted`
- `static func next_waypoint(from: Vector2, goal: Vector2) -> Vector2`
- `static func loot_point(enemy_id: String) -> Vector2`
- `static func clear(a: Vector2, b: Vector2) -> bool`
- `static func sight_clear(a: Vector2, b: Vector2) -> bool`
- `static func obstacles() -> Array[Rect2]`
- `static func edge(a: int, b: int) -> bool`

## prototype/scripts/domain/raider_strike.gd

- `extends RefCounted`
- `static func windup_seconds() -> float`
- `static func reach() -> float`
- `static func engage_distance() -> float`
- `static func swinging(attack_timer: float) -> bool`
- `static func clip_contact_seconds(model_path: String, clip_length: float) -> float`
- `static func clip_time(elapsed: float, windup: float, contact: float) -> float`

## prototype/scripts/domain/regional_freight.gd

- `extends RefCounted`
- `static func length_m() -> float`
- `static func empty_receipt() -> Dictionary`
- `static func valid(value: Variant) -> bool`
- `static func point_at(metres: float) -> Vector2`
- `static func pose(receipt: Dictionary) -> Dictionary`
- `static func status(economy: Dictionary) -> String`

## prototype/scripts/domain/time_jump_contract.gd

- `extends RefCounted`
- `static func plan(from_clock: Dictionary, to_jdn: int, options: Dictionary = {}) -> Dictionary`
- `static func run(world: Dictionary, participants: Array, jump_plan: Dictionary, options: Dictionary = {}) -> Dictionary`
- `static func step_seed(world_id: String, domain_name: String, step_index: int) -> int`
- `static func life_phase(age: int) -> String`
- `static func actor_time(actor: Dictionary, jdn: int) -> Dictionary`

## prototype/scripts/domain/time_jump_participant.gd

- `extends RefCounted`
- `func domain() -> String`
- `func advance(_domain_state: Dictionary, _step: Dictionary, _context: Dictionary) -> Dictionary`

## prototype/scripts/domain/travel_party.gd

- `extends RefCounted`
- `static func initial() -> Dictionary`
- `static func new_member() -> Dictionary`
- `static func remember(member: Dictionary, note: String) -> void`
- `static func local_id(world: Dictionary, uid: String) -> String`
- `static func resident(world: Dictionary, uid: String) -> Dictionary`
- `static func healthy(world: Dictionary, uid: String) -> bool`
- `static func protected(world: Dictionary) -> bool`
- `static func position(world: Dictionary, uid: String) -> Vector2`
- `static func player_position(world: Dictionary) -> Vector2`
- `static func base_trust(world: Dictionary, uid: String) -> int`
- `static func validate_arguments(command: String, args: Dictionary) -> String`
- `static func mending_choice(world: Dictionary) -> String`
- `static func willing_resident(world: Dictionary, uid: String) -> bool`
- `static func apply(world: Dictionary, command: String, args: Dictionary) -> Dictionary`
- `static func capacity(member: Dictionary) -> int`
- `static func advance_lessons(world: Dictionary, delta: float) -> void`
- `static func settle_days(world: Dictionary, days: int) -> void`
- `static func wages_paid(party: Dictionary) -> int`
- `static func clear_vacant_roles(world: Dictionary) -> void`
- `static func grain_issued(party: Dictionary) -> int`
- `static func view(world: Dictionary) -> Dictionary`
- `static func validate(world: Dictionary) -> String`
- `static func travelling(world: Dictionary, uid: String) -> bool`
- `static func reconcile(world: Dictionary) -> void`
- `static func village_reserve_size() -> int`
- `static func migrate_legacy(world: Dictionary) -> void`
- `static func normalize(world: Dictionary) -> void`
- `static func observe_travellers(world: Dictionary, observations: Variant) -> void`

## prototype/scripts/domain/travel_provisions.gd

- `extends RefCounted`
- `static func packed(member: Dictionary, item: String) -> int`
- `static func food(member: Dictionary) -> int`
- `static func load_count(member: Dictionary) -> int`
- `static func give(trade: Dictionary, member: Dictionary, item: String, quantity: int, capacity: int) -> Dictionary`
- `static func consume(member: Dictionary, items: Array, needed: int) -> int`
- `static func valid(value: Variant) -> bool`

## prototype/scripts/domain/tribal_world.gd

- `extends RefCounted`
- `static func scenario(id: String) -> Dictionary`
- `static func scenario_for_year(year: int) -> String`
- `static func seed_from_text(text: String) -> int`
- `static func new_state(seed: int, scenario_id: String = "bc58_rhine") -> Dictionary`
- `static func year_of(state: Dictionary, tick: int = -1) -> int`
- `static func calendar(state: Dictionary) -> Dictionary`
- `static func year_label(year: int) -> String`
- `static func day(state: Dictionary) -> int`
- `static func trim(state: Dictionary) -> void`
- `static func advance_to_day(state: Dictionary, target_day: int, max_ticks: int = MAX_CATCHUP) -> int`
- `static func advance_ticks(state: Dictionary, ticks: int) -> void`
- `static func tick(state: Dictionary) -> void`
- `static func week_begin(state: Dictionary) -> Dictionary`
- `static func week_step(runner: Dictionary) -> int`
- `static func travel_ticks(km: float) -> int`
- `static func traits(state: Dictionary, gid: String) -> Dictionary`
- `static func government(state: Dictionary, gid: String) -> Dictionary`
- `static func troops_strength(scn: Dictionary, troops: Dictionary) -> float`
- `static func strength(state: Dictionary, gid: String) -> float`
- `static func defence(state: Dictionary, gid: String, warned: bool = false) -> float`
- `static func settlement_class(population: int) -> String`
- `static func expected_defence(state: Dictionary, gid: String) -> float`
- `static func strength_class(value: float) -> String`
- `static func open_dispute(state: Dictionary, a: String, b: String, cause: String, source: String, note: String = "", weeks: int = 52) -> Dictionary`
- `static func close_dispute(state: Dictionary, id: String, reason: String) -> bool`
- `static func dispute_for(state: Dictionary, attacker: String, target: String) -> Dictionary`
- `static func retainers(state: Dictionary, gid: String, with: String = "") -> Array`
- `static func age_of(state: Dictionary, pid: String) -> float`
- `static func trade_terms(state: Dictionary, gid: String, partner: String) -> Dictionary`
- `static func world_calendar_day(world: Dictionary) -> int`
- `static func epoch_jdn(state: Dictionary, origin_year: int = 100) -> int`
- `static func tick_jdn(state: Dictionary, tick: int, origin_year: int = 100) -> int`
- `static func scenario_for_world(world: Dictionary) -> String`
- `static func band_of(state: Dictionary) -> Array`
- `static func writable(world: Dictionary) -> Dictionary`
- `static func arrived_raids(state: Dictionary, target_id: String) -> Array`
- `static func raid_allowed(state: Dictionary, target_id: String) -> Dictionary`
- `static func planned_raids(state: Dictionary, target_id: String) -> Array`
- `static func commit_raid(state: Dictionary, gid: String, target_id: String) -> Dictionary`
- `static func story_raid(state: Dictionary, story_id: String) -> Dictionary`
- `static func commit_story_raid(state: Dictionary, story_id: String) -> Dictionary`
- `static func apply_raid_result(state: Dictionary, expedition_id: String, result: Dictionary) -> Dictionary`
- `static func report_target_state(state: Dictionary, target_id: String, defenders: int, rebuilt: bool) -> bool`
- `static func set_story_lock(state: Dictionary, target_id: String, until_tick: int, reason: String) -> bool`
- `static func record_player_action(state: Dictionary, gid: String, kind: String, note: String = "") -> Dictionary`
- `static func receive_delegation(state: Dictionary, gid: String, grain: int) -> void`
- `static func player_mediate(state: Dictionary, a: String, b: String) -> Dictionary`
- `static func reveal(state: Dictionary, observer: String, subject: String, evidence: String) -> bool`
- `static func actor_ids(state: Dictionary) -> Dictionary`
- `static func visit_report(state: Dictionary, gid: String) -> Dictionary`
- `static func mark_visited(state: Dictionary, gid: String) -> void`
- `static func atlas_view(state: Dictionary, viewer: String = "") -> Array`
- `static func settlement_points(state: Dictionary, viewer: String = "") -> Array`
- `static func chronicle(state: Dictionary, limit: int = 20, viewer: String = "") -> Array`
- `static func observed_facts(state: Dictionary, observer: String) -> Array`
- `static func calendar_at(state: Dictionary, tick: int) -> String`
- `static func totals(state: Dictionary, gid: String) -> Dictionary`
- `static func is_validated(state: Variant) -> bool`
- `static func mark_validated(state: Dictionary) -> void`
- `static func validate_cached(state: Variant) -> String`
- `static func with_extra_days(state: Dictionary, days: int) -> Dictionary`
- `static func validate(state: Variant) -> String`
- `static func next_units(runner: Dictionary) -> int`
- `static func step(runner: Dictionary) -> int`
- `static func copy_begin(source: Dictionary) -> Dictionary`
- `static func copy_step(runner: Dictionary) -> int`
- `static func copy_state(source: Dictionary) -> Dictionary`
- `static func check_begin(state: Variant) -> Dictionary`
- `static func check_step(runner: Dictionary) -> int`
- `static func migrate(state: Variant) -> void`
- `static func normalize(state: Dictionary) -> void`

## prototype/scripts/domain/unarmed_combat.gd

- `extends RefCounted`
- `static func start(data: Dictionary) -> void`
- `static func enabled(data: Dictionary) -> bool`
- `static func is_armed(id: String) -> bool`
- `static func available(data: Dictionary, id: String) -> bool`
- `static func validate_arguments(command: String, args: Dictionary) -> String`
- `static func execute(data: Dictionary, command: String, args: Dictionary) -> Dictionary`
- `static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable(), apply_hit: Callable = Callable()) -> Dictionary`
- `static func interrupt(data: Dictionary) -> bool`
- `static func busy(data: Dictionary) -> bool`
- `static func phase(id: String, elapsed: float) -> String`
- `static func view(data: Dictionary) -> Dictionary`
- `static func validate(data: Dictionary) -> String`

## prototype/scripts/domain/valdora_politics.gd

- `extends RefCounted`
- `static func new_state() -> Dictionary`
- `static func enabled(world: Dictionary) -> bool`
- `static func validate_arguments(command: String, args: Dictionary) -> String`
- `static func view(world: Dictionary) -> Dictionary`
- `static func apply(candidate: Dictionary, command: String, args: Dictionary) -> Dictionary`
- `static func validate(world: Dictionary) -> String`
- `static func normalize(world: Dictionary) -> void`

## prototype/scripts/domain/village_economy.gd

- `extends RefCounted`
- `static func day_length(data: Dictionary) -> float`
- `static func initial_state() -> Dictionary`
- `static func ensure(data: Dictionary) -> void`
- `static func execute(data: Dictionary, command: String, args: Dictionary = {}) -> Dictionary`
- `static func advance(data: Dictionary, delta: float) -> bool`
- `static func view(data: Dictionary) -> Dictionary`
- `static func repair_cost(economy: Dictionary, id: String) -> Dictionary`
- `static func emergency_food_price(data: Dictionary) -> int`
- `static func trade_price(data: Dictionary) -> int`
- `static func validate(data: Dictionary) -> String`

## prototype/scripts/domain/weapon_rules.gd

- `extends RefCounted`
- `static func load_catalog() -> Dictionary`
- `static func can_attack(weapon: Dictionary, attacker: Dictionary, distance_m: float, now_s: float) -> bool`
- `static func attack_preview(weapon: Dictionary, attacker: Dictionary, defender: Dictionary, distance_m: float, now_s: float) -> Dictionary`

## prototype/scripts/domain/world_calendar.gd

- `extends RefCounted`
- `static func is_valid_year(year: int) -> bool`
- `static func to_astronomical(year: int) -> int`
- `static func from_astronomical(astronomical: int) -> int`
- `static func add_years(year: int, years: int) -> int`
- `static func years_between(from_year: int, to_year: int) -> int`
- `static func is_leap_year(year: int) -> bool`
- `static func days_in_month(year: int, month: int) -> int`
- `static func days_in_year(year: int) -> int`
- `static func is_valid_date(year: int, month: int, day: int) -> bool`
- `static func to_jdn(year: int, month: int, day: int) -> int`
- `static func date_to_jdn(date: Dictionary) -> int`
- `static func from_jdn(jdn: int) -> Dictionary`
- `static func max_jdn() -> int`
- `static func year_of(jdn: int) -> int`
- `static func first_day_of_year(year: int) -> int`
- `static func last_day_of_year(year: int) -> int`
- `static func add_days(jdn: int, days: int) -> int`
- `static func days_between(from_jdn_value: int, to_jdn_value: int) -> int`
- `static func add_calendar_years(jdn: int, years: int) -> int`
- `static func add_months(jdn: int, months: int) -> int`
- `static func age_on(birth: Dictionary, on_jdn: int) -> int`
- `static func age_in_year(birth_year: int, year: int) -> int`
- `static func birth_year_for_age(age: int, year: int) -> int`
- `static func season_index(jdn: int, latitude: float = 45.0) -> int`
- `static func season_year(jdn: int) -> int`
- `static func season_start(year: int, index: int) -> int`
- `static func season_turn(jdn: int, origin_year: int = CAMPAIGN_START.year) -> int`
- `static func season_turn_start(turn: int, origin_year: int = CAMPAIGN_START.year) -> int`
- `static func format_year(year: int, language: String = "de") -> String`
- `static func format_date(jdn: int, language: String = "de") -> String`
- `static func auc_year(year: int) -> int`
- `static func roman_numeral(value: int) -> String`
- `static func latin_month_name(year: int, month: int) -> String`
- `static func latin_month_abbreviation(year: int, month: int) -> String`
- `static func roman_day(jdn: int) -> String`
- `static func format_roman(jdn: int, with_auc: bool = true) -> String`
- `static func new_clock(jdn: int, second_of_day: int = 0) -> Dictionary`
- `static func campaign_start_jdn() -> int`
- `static func validate_clock(clock: Variant) -> bool`
- `static func normalize_clock(clock: Variant) -> Dictionary`
- `static func advance_clock(clock: Dictionary, seconds: int) -> Dictionary`
- `static func clock_date(clock: Dictionary) -> Dictionary`
- `static func new_world_time(jdn: int, second_of_day: int, origin_year: int, births: Dictionary = {}) -> Dictionary`
- `static func validate_world_time(value: Variant) -> bool`
- `static func normalize_world_time(value: Variant) -> Dictionary`
- `static func valid_birth(birth: Variant) -> bool`
- `static func world_time_age(world_time: Dictionary, actor_id: String) -> int`
- `static func is_integral(value: Variant) -> bool`

## prototype/scripts/domain/world_clock.gd

- `extends RefCounted`
- `static func origin_year_of(world: Dictionary) -> int`
- `static func start_jdn(origin_year: int) -> int`
- `static func births_for(origin_year: int, age := START_AGE) -> Dictionary`
- `static func new_calendar(origin_year: int, jdn: int, second: int, births: Dictionary) -> Dictionary`
- `static func new_ledger(epoch_jdn: int, epoch_second: int) -> Dictionary`
- `static func start(world: Dictionary, regular_opening: bool = false) -> void`
- `static func village_seconds(world: Dictionary) -> int`
- `static func battle_seconds(world: Dictionary) -> int`
- `static func total_seconds(world: Dictionary) -> int`
- `static func expected_clock(world: Dictionary) -> Dictionary`
- `static func sync(world: Dictionary) -> void`
- `static func book(world: Dictionary, cause: String, seconds: int, reason: String) -> int`
- `static func seconds_to_morning(world: Dictionary) -> int`
- `static func sleep(world: Dictionary, reason := "Schlaf bis zum Morgen") -> int`
- `static func night(world: Dictionary, reason := "Nachtruhe") -> int`
- `static func next_season_jdn(world: Dictionary) -> int`
- `static func season(world: Dictionary, reason := "Eine Jahreszeit vergeht") -> int`
- `static func jdn(world: Dictionary) -> int`
- `static func year(world: Dictionary) -> int`
- `static func elapsed_years(world: Dictionary) -> int`
- `static func age(world: Dictionary, actor := "player") -> int`
- `static func is_legacy(world: Dictionary) -> bool`
- `static func days_since_spring(world: Dictionary, epoch_year: int) -> int`
- `static func season_name(index: int) -> String`
- `static func view(world: Dictionary) -> Dictionary`
- `static func history_frame(world: Dictionary) -> Dictionary`
- `static func frame_at(day: int, legacy: bool, roman: bool, divergences: Dictionary = {}) -> Dictionary`
- `static func validate(world: Dictionary) -> String`
- `static func normalize(world: Dictionary) -> void`

## prototype/scripts/domain/world_model.gd

- `extends RefCounted`
- `signal changed`
- `signal confirmed_combat_contact(event: Dictionary)`
- `func new_game(origin_id := "italia", extended_village := false, childhood_enabled := false, action_combat := false, regular_start := false) -> void`
- `func execute(command: String, args: Dictionary = {}, command_id: String = "") -> Dictionary`
- `func execute_city_at(command: String, args: Dictionary, command_id: String, session: CitySession, sites: Dictionary, position: Vector3, path: String) -> Dictionary`
- `func capture_npc_observations() -> void`
- `func set_player_position(position: Vector3) -> void`
- `func interrupt_combat() -> void`
- `func advance(delta: float) -> void`
- `func calendar_day(state: Dictionary) -> int`
- `func world_time() -> Dictionary`
- `func tribes_pending_weeks() -> int`
- `func pump_tribes(budget: int = TRIBE_UNITS_PER_FRAME) -> Dictionary`
- `func finish_tribes(max_frames: int = 100000) -> int`
- `func advance_city_visit(seconds: int) -> Dictionary`
- `func checkpoint_city(session: CitySession, path: String) -> Dictionary`
- `func pass_calendar_days(days: int, reason: String = "", cause: String = "travel") -> Dictionary`
- `func soldiers() -> Array`
- `func settlement_events() -> Array`
- `func settlement_effects() -> Dictionary`
- `func promote_soldier(uid: String, to_id: String, inventory: Array = [], authorities: Array = []) -> Dictionary`
- `func relation_event(actor: String, group_id: String, kind: String, note: String = "") -> Dictionary`
- `func mission_dispute(a: String, b: String, source: String, note: String = "", weeks: int = 52) -> Dictionary`
- `func checkpoint_valley(battle) -> bool`
- `func save_game(path: String) -> Dictionary`
- `func load_game(path: String) -> Dictionary`
- `func get_frontier_dialog(npc_id: String) -> Dictionary`
- `func get_frontier_objective() -> Dictionary`
- `func party_view() -> Dictionary`
- `func politics_view() -> Dictionary`
- `func act_region(command: String,target: String) -> Dictionary`

## prototype/scripts/domain/world_state.gd

- `extends RefCounted`
- `static func new_state() -> Dictionary`
- `static func migrate(world: Dictionary) -> void`
- `static func bridge_raids(world: Dictionary) -> bool`
- `static func expected_booking(stolen: int) -> Dictionary`
- `static func battle_started(world: Dictionary) -> void`
- `static func battle_ended(world: Dictionary) -> void`
- `static func days_since_battle(world: Dictionary, at_jdn: int = -1) -> int`
- `static func battle_records(world: Dictionary) -> Dictionary`
- `static func soldier(world: Dictionary, uid: String, at_jdn: int = -1) -> Dictionary`
- `static func soldiers(world: Dictionary) -> Array`
- `static func settlement_events(world: Dictionary, at_jdn: int = -1) -> Array`
- `static func settlement_effects(world: Dictionary, at_jdn: int = -1) -> Dictionary`
- `static func settlement_report(world: Dictionary, at_jdn: int = -1) -> Array`
- `static func promotion_reason(world: Dictionary, uid: String) -> String`
- `static func record_promotion(world: Dictionary, uid: String, from_id: String, to_id: String) -> void`
- `static func relation_event(world: Dictionary, actor: String, group_id: String, kind: String, note: String) -> Dictionary`
- `static func mission_dispute(world: Dictionary, a: String, b: String, source: String, note: String, weeks: int) -> Dictionary`
- `static func validate(world: Dictionary) -> String`
- `static func normalize(world: Dictionary) -> void`

## prototype/scripts/formation/formation_agents.gd

- `extends RefCounted`
- `class Agent`
- `class Unit`
- `func agent_time() -> float`
- `static func model_time(model) -> float`
- `func render_fraction(model) -> float`
- `func advance(model) -> int`
- `static func uid_of(man: Dictionary) -> String`
- `func sync_model(model) -> void`
- `func release_external(uid: String) -> Dictionary`
- `func update_external(uid: String, position: Vector2, yaw: float, phase: float, pose: String) -> bool`
- `func return_external(uid: String) -> bool`
- `func state_of(a: Agent) -> Dictionary`
- `static func continuous(a: Agent) -> bool`
- `func present_state(a: Agent, f: float) -> Dictionary`

## prototype/scripts/formation/formation_levels.gd

- `extends RefCounted`
- `func budget() -> Dictionary`
- `func assign(agents: Dictionary, camera_position: Vector3, in_view: Callable, blocked: Callable, delta: float, dying_rigs: int = 0) -> Dictionary`
- `func count(agents: Dictionary, dying_rigs: int = 0) -> Dictionary`

## prototype/scripts/formation/troop_motion.gd

- `extends RefCounted`
- `static func limits(kind: String, extra_load_kg: float = 0.0) -> Dictionary`

## prototype/scripts/main.gd

- `extends Node`

## prototype/scripts/monuments/colosseum.gd

- `class_name Colosseum`
- `extends Node3D`
- `static func available_at(jdn: int) -> bool`
- `static func hypogeum_at(jdn: int) -> bool`
- `func build() -> void`
- `static func bay_point(layout_data: Dictionary, bay: int, u: float, r: float, height: float = 0.0) -> Vector3`
- `func visible_triangles() -> int`

## prototype/scripts/monuments/colosseum_showcase.gd

- `extends Node3D`

## prototype/scripts/monuments/era_gate.gd

- `extends RefCounted`
- `static func apply(root: Node, jdn: int) -> Dictionary`

## prototype/scripts/monuments/monument_materials.gd

- `extends RefCounted`
- `static func material(material_name: String, profile: String = "balanced") -> Material`
- `static func apply(root: Node, profile: String) -> void`
- `static func assign(mesh: Mesh, profile: String) -> void`

## prototype/scripts/rendering/city_architecture_detail.gd

- `class_name CityArchitectureDetail`
- `extends RefCounted`
- `static func module_ids() -> Array[String]`
- `static func create_module(module_id: String, lod: int = 0, with_collision: bool = false) -> Node3D`
- `static func create_multimesh(module_id: String, transforms: Array, lod: int = 0) -> MultiMeshInstance3D`
- `static func module_info(module_id: String) -> Dictionary`
- `static func lod_for_distance(distance_metres: float, quality_index: int = 2) -> int`

## prototype/scripts/rendering/city_character_detail.gd

- `extends RefCounted`
- `static func apply_to(root: Node, profile: String = "high", lod: int = 0) -> int`
- `static func has_normal_basis(arrays: Array) -> bool`

## prototype/scripts/rendering/city_exploration_detail_adapter.gd

- `class_name CityExplorationDetailAdapter`
- `extends RefCounted`
- `static func install(city_root: Node3D, profile: String = "balanced") -> Dictionary`

## prototype/scripts/rendering/city_fountain_water.gd

- `extends RefCounted`
- `static func apply(city: Node3D) -> int`

## prototype/scripts/rendering/city_surface_microdetail.gd

- `class_name CitySurfaceMicrodetail`
- `extends RefCounted`
- `static func install(city: Node3D, profile: String = "balanced") -> Dictionary`

## prototype/scripts/rendering/city_viva_closeup_props.gd

- `extends RefCounted`
- `static func install(city: Node3D, profile: String = "balanced") -> Dictionary`

## prototype/scripts/rendering/confirmed_impact_camera.gd

- `extends RefCounted`
- `static func eligible(event: Dictionary, player_age: int, enabled: bool) -> bool`
- `static func weight(remaining: float) -> float`

## prototype/scripts/rendering/fold7_quality_policy.gd

- `extends RefCounted`
- `static func recommended_profile(is_android: bool, gpu_adapter: String) -> String`
- `static func initial(profile: String) -> Dictionary`
- `static func adaptive(profile: String) -> bool`
- `static func observation_summary(values: Array[float], total: int) -> Dictionary`
- `static func step(profile: String, previous: Dictionary, p95_frame_ms: float, gpu_render_ms: float, frames: int, foreground: bool) -> Dictionary`
- `static func effective_render_scale(base_scale: float, governor: Dictionary) -> float`

## prototype/scripts/rendering/render_bench.gd

- `extends RefCounted`
- `static func renderer_info() -> Dictionary`
- `static func boot_village(root: Window, errors: Array) -> Node`
- `static func stage_village(world: Node3D, view: String, start: Dictionary) -> bool`
- `static func cameras() -> Dictionary`
- `static func showcase() -> Dictionary`
- `static func showcase_shot(view: String) -> Dictionary`
- `static func showcase_views(scene: String) -> Array`
- `static func village_start(world: Node3D) -> Dictionary`
- `static func restore_village(world: Node3D, start: Dictionary) -> void`
- `static func place_player(world: Node3D, at: Vector3, yaw: float, lift: float) -> void`
- `static func floor_height(world: Node3D, at: Vector3) -> float`
- `static func enter_night(world: Node3D) -> Node3D`
- `static func leave_night(world: Node3D) -> void`
- `static func stage_city(city: Node3D, view: String) -> bool`
- `static func rss_kib() -> int`
- `static func next_frame(tree: SceneTree) -> void`
- `static func measure(viewport: Viewport, frames: int) -> Dictionary`
- `static func percentile(values: Array, fraction: float) -> float`
- `static func engine_state(viewport: Viewport, scene: Node) -> Dictionary`
- `static func loaded_assets(scene: Node) -> Dictionary`

## prototype/scripts/rendering/render_profile.gd

- `extends RefCounted`
- `static func profiles() -> Dictionary`
- `static func settings(profile: String) -> Dictionary`
- `static func render(profile: String) -> Dictionary`
- `static func current_profile() -> String`
- `static func last_applied() -> Dictionary`
- `static func renderer() -> String`
- `static func supports(feature: String, method: String = "") -> bool`
- `static func density(profile: String, key: String, fallback := 1.0) -> float`
- `static func texture_tier(profile: String) -> String`
- `static func mount_texture_package(tier: String) -> Dictionary`
- `static func texture_package() -> Dictionary`
- `static func desired_renderer(profile: String) -> String`
- `static func request_renderer(profile: String) -> Dictionary`
- `static func write_renderer_override(wanted: String, current: String, path: String, project_default: String) -> Dictionary`
- `static func apply_viewport(viewport: Viewport, profile: String) -> Dictionary`
- `static func apply_environment(environment: Environment, profile: String, method: String = "") -> bool`
- `static func configure_light(light: Light3D, profile: String) -> void`
- `static func active_environment(viewport: Viewport) -> Environment`

## prototype/scripts/rendering/route_fire_lights.gd

- `extends Node3D`
- `static func village_candidates() -> Array[Vector3]`
- `static func city_candidates() -> Array[Vector3]`
- `func configure(points: Array[Vector3], profile: String) -> void`
- `func set_quality(profile: String) -> void`
- `func set_darkness(value: float) -> void`
- `func set_route_context(player_at: Vector3, route: PackedVector2Array) -> void`

## prototype/scripts/rendering/village_look.gd

- `extends Node3D`
- `func setup(world: Node3D, target: Environment, sky: ShaderMaterial) -> DirectionalLight3D`
- `static func configure_environment(env: Environment, sky: ShaderMaterial) -> void`
- `static func split_tone_lut(shadows: Array, highlights: Array) -> ImageTexture3D`
- `static func apply_season_light(index: int, light: DirectionalLight3D, env: Environment, sky: ShaderMaterial) -> void`
- `func apply_season(index: int) -> void`
- `func set_time_of_day(hours: float) -> void`
- `static func apply_solar_time(hours: float, season_index: int, light: DirectionalLight3D, env: Environment, shader_sky: ShaderMaterial) -> float`
- `func set_route_context(player_at: Vector3, route: PackedVector2Array) -> void`
- `func set_weather(kind: String) -> void`
- `func set_conditions(hours: float, sample: Dictionary) -> void`
- `static func weather_values(sample: Dictionary, kind: String = "clear") -> Dictionary`
- `static func apply_city_weather(light: DirectionalLight3D, env: Environment, darkness: float, sample: Dictionary) -> void`
- `func add_fire_light(parent: Node3D, at: Vector3, kind := "torch") -> OmniLight3D`
- `func apply_quality(next_profile: String) -> void`

## prototype/scripts/rendering/village_surfaces.gd

- `extends RefCounted`
- `static func plaster(tint: Color) -> ShaderMaterial`
- `static func add_wear(material: StandardMaterial3D) -> void`
- `static func set_profile(profile: String) -> void`

## prototype/scripts/rendering/viva_roma_atmosphere.gd

- `extends RefCounted`
- `static func ground_material(profile: String) -> ShaderMaterial`
- `static func configure_sun(sun: DirectionalLight3D, profile: String) -> void`
- `static func environment(profile: String) -> Environment`

## prototype/scripts/roman_material_lab/material_preview.gd

- `extends Node3D`

## prototype/scripts/story/campaign_bible.gd

- `extends RefCounted`
- `static func project() -> String`
- `static func rules() -> Dictionary`
- `static func canonical_actor(role: String) -> Dictionary`
- `static func mission(mission_id: String) -> Dictionary`
- `static func side_quest(quest_id: String) -> Dictionary`
- `static func band(number: int) -> Dictionary`
- `static func main_mission_count() -> int`
- `static func side_quest_count() -> int`
- `static func reset_cache_for_tests() -> void`

## prototype/scripts/story/campaign_direction.gd

- `extends RefCounted`
- `static func introduction(mission_id: String) -> String`

## prototype/scripts/story/chapter_abilities.gd

- `extends RefCounted`
- `static func catalog() -> Array`
- `static func ids() -> Array[String]`
- `static func entry(id: String) -> Dictionary`
- `static func derive(data: Dictionary) -> Array[String]`
- `static func ensure(data: Dictionary) -> void`
- `static func sync(data: Dictionary) -> Array[String]`
- `static func has(data: Dictionary, id: String) -> bool`
- `static func effect_value(data: Dictionary, effect_type: String) -> float`
- `static func names(data: Dictionary) -> Array[String]`
- `static func validate(data: Dictionary) -> String`

## prototype/scripts/story/companion_follow.gd

- `extends RefCounted`
- `func reset() -> void`
- `func pause(body: CharacterBody3D) -> void`
- `func move(body: CharacterBody3D, target: Vector3, delta: float, speed := 3.8, stop_distance := 1.7) -> void`

## prototype/scripts/story/companion_story.gd

- `extends RefCounted`
- `static func actor_uid(data: Dictionary, id: String) -> String`
- `static func member(data: Dictionary, id: String) -> Dictionary`
- `static func available(data: Dictionary, id: String) -> bool`
- `static func task_roles(step: String) -> Dictionary`
- `static func credit(data: Dictionary, step: String, site: Vector2, counterpart := "", sight: Callable = Callable()) -> String`
- `static func for_step(data: Dictionary, mission: String, step: String) -> Dictionary`
- `static func tone(data: Dictionary, id: String) -> String`
- `static func dialogue(data: Dictionary, id: String, mission: String, step: String) -> Dictionary`
- `static func observed_position(data: Dictionary, id: String) -> Variant`
- `static func restored_position(data: Dictionary, id: String, fallback: Vector3) -> Vector3`
- `static func display_name(data: Dictionary, id: String, fallback: String) -> String`

## prototype/scripts/story/frontier_chapter.gd

- `extends RefCounted`
- `static func new_state() -> Dictionary`
- `static func enabled(state: Dictionary) -> bool`
- `static func unlocked(state: Dictionary) -> bool`
- `static func npc_position(npc_id: String) -> Vector3`
- `static func in_range(state: Dictionary, npc_id: String) -> bool`
- `static func talk(state: Dictionary, npc_id: String) -> Dictionary`
- `static func choose(state: Dictionary, npc_id: String, choice: String) -> Dictionary`
- `static func advance(state: Dictionary, delta: float) -> String`
- `static func dialog(state: Dictionary, npc_id: String) -> Dictionary`
- `static func objective(state: Dictionary) -> Dictionary`
- `static func effects(chapter: Dictionary) -> Dictionary`
- `static func validate(state: Dictionary) -> String`

## prototype/scripts/story/i01_film.gd

- `extends RefCounted`
- `static func vid_a(data: Dictionary) -> Dictionary`
- `static func vid_b(data: Dictionary) -> Dictionary`
- `static func vid_c_beats(data: Dictionary, chapter: String, location: String) -> Array[Dictionary]`
- `static func restore(data: Dictionary, sequence_id: String) -> Dictionary`

## prototype/scripts/story/i01_three_cups.gd

- `extends RefCounted`
- `static func slice() -> Dictionary`
- `static func fresh_state() -> Dictionary`
- `static func legacy_state() -> Dictionary`
- `static func active(data: Dictionary) -> bool`
- `static func in_mission(data: Dictionary) -> bool`
- `static func cups(data: Dictionary) -> Dictionary`
- `static func presentation(data: Dictionary) -> Dictionary`
- `static func event_ids(data: Dictionary) -> Array`
- `static func has_event(data: Dictionary, event_id: String) -> bool`
- `static func current_step(data: Dictionary) -> Dictionary`
- `static func options(data: Dictionary, step: Dictionary) -> Array[Dictionary]`
- `static func optional_actions(data: Dictionary) -> Array[Dictionary]`
- `static func contact_name(id: String) -> String`
- `static func contact_line(id: String) -> String`
- `static func line(line_id: String) -> Dictionary`
- `static func consequence(event_id: String) -> Dictionary`
- `static func handles(action: String) -> bool`
- `static func contact_position(data: Dictionary, id: String, villager_position: Vector2) -> Vector2`
- `static func contact_open(data: Dictionary, id: String) -> bool`
- `static func reason(data: Dictionary, action: String, villager_positions: Dictionary = {}) -> String`
- `static func apply(data: Dictionary, action: String, villager_positions: Dictionary = {}) -> Dictionary`
- `static func topic_line(data: Dictionary) -> Dictionary`
- `static func julia_reaction_id(data: Dictionary) -> String`
- `static func expected_events(s: Dictionary) -> Array`
- `static func validate(screenplay: Dictionary, completed: int) -> String`
- `static func migrate(child: Dictionary) -> bool`
- `static func interactables(data: Dictionary, reason_for: Callable) -> Array[Dictionary]`
- `static func hook_lines(data: Dictionary, step_id: String) -> Array[String]`
- `static func hud_place(step: Dictionary) -> String`

## prototype/scripts/story/i03_film.gd

- `extends RefCounted`
- `static func vid_a(data: Dictionary, ctx: Dictionary) -> Dictionary`
- `static func vid_b(data: Dictionary, ctx: Dictionary) -> Dictionary`
- `static func vid_c(data: Dictionary, ctx: Dictionary) -> Dictionary`
- `static func restore(data: Dictionary, sequence_id: String, ctx: Dictionary) -> Dictionary`

## prototype/scripts/story/i03_shortcut.gd

- `extends RefCounted`
- `static func slice() -> Dictionary`
- `static func fresh_state() -> Dictionary`
- `static func legacy_state() -> Dictionary`
- `static func line(line_id: String) -> Dictionary`
- `static func consequence(event_id: String) -> Dictionary`
- `static func event_ids(data: Dictionary) -> Array`
- `static func has_event(data: Dictionary, event_id: String) -> bool`
- `static func handles(action: String) -> bool`
- `static func errand_open(data: Dictionary) -> bool`
- `static func farewell_open(data: Dictionary, ctx: Dictionary) -> bool`
- `static func current_step(data: Dictionary, ctx: Dictionary) -> Dictionary`
- `static func dispute_open(s: Dictionary) -> bool`
- `static func summary(s: Dictionary) -> String`
- `static func marcus_present(data: Dictionary) -> bool`
- `static func marcus_position(data: Dictionary) -> Vector2`
- `static func marcus_stall(ctx: Dictionary) -> Vector2`
- `static func marcus_station(data: Dictionary, ctx: Dictionary) -> String`
- `static func options(data: Dictionary, step: Dictionary) -> Array[Dictionary]`
- `static func reason(data: Dictionary, action: String, ctx: Dictionary) -> String`
- `static func apply(data: Dictionary, action: String, ctx: Dictionary) -> Dictionary`
- `static func marcus_reaction_id(data: Dictionary) -> String`
- `static func resolve_line_id(data: Dictionary) -> String`
- `static func resolve_line(data: Dictionary) -> Dictionary`
- `static func farewell_open_id(data: Dictionary) -> String`
- `static func farewell_reply_id(data: Dictionary) -> String`
- `static func farewell_reply(data: Dictionary) -> Dictionary`
- `static func expected_events(s: Dictionary) -> Array`
- `static func validate(screenplay: Dictionary, companion: Dictionary, carried: Array) -> String`
- `static func migrate(child: Dictionary, companion: Dictionary) -> bool`
- `static func hook_lines(data: Dictionary, step_id: String) -> Array[String]`
- `static func hud_place(step: Dictionary) -> String`

## prototype/scripts/story/i04_film.gd

- `extends RefCounted`
- `static func vid_a(data: Dictionary, ctx: Dictionary) -> Dictionary`
- `static func vid_b(data: Dictionary, ctx: Dictionary) -> Dictionary`
- `static func vid_c_beats(data: Dictionary, chapter: String, location: String) -> Array[Dictionary]`
- `static func restore(data: Dictionary, sequence_id: String, ctx: Dictionary) -> Dictionary`

## prototype/scripts/story/i04_workshop.gd

- `extends RefCounted`
- `static func slice() -> Dictionary`
- `static func fresh_state() -> Dictionary`
- `static func legacy_state() -> Dictionary`
- `static func line(line_id: String) -> Dictionary`
- `static func consequence(event_id: String) -> Dictionary`
- `static func event_ids(data: Dictionary) -> Array`
- `static func has_event(data: Dictionary, event_id: String) -> bool`
- `static func handles(action: String) -> bool`
- `static func active(data: Dictionary, ctx: Dictionary) -> bool`
- `static func current_step(data: Dictionary, ctx: Dictionary) -> Dictionary`
- `static func options(_data: Dictionary, step: Dictionary) -> Array[Dictionary]`
- `static func reason(data: Dictionary, action: String, ctx: Dictionary) -> String`
- `static func apply(data: Dictionary, action: String, ctx: Dictionary) -> Dictionary`
- `static func topic_line_id(data: Dictionary) -> String`
- `static func topic_line(data: Dictionary) -> Dictionary`
- `static func work_line_id(data: Dictionary) -> String`
- `static func nail_kept(data: Dictionary) -> bool`
- `static func expected_events(s: Dictionary) -> Array`
- `static func validate(screenplay: Dictionary, completed: int, index: int, carried: Array) -> String`
- `static func migrate(child: Dictionary, index: int) -> bool`
- `static func hook_lines(data: Dictionary, step_id: String) -> Array[String]`
- `static func hud_place(step: Dictionary) -> String`

## prototype/scripts/story/key_mission_attempts.gd

- `extends RefCounted`
- `static func initial() -> Dictionary`
- `static func valid(record: Variant) -> bool`
- `static func begin(record: Dictionary) -> Dictionary`
- `static func resolve(record: Dictionary, outcome: String) -> Dictionary`

## prototype/scripts/story/life_path_policy.gd

- `class_name LifePathPolicy`
- `extends RefCounted`
- `static func new_state(world_id: String, play_mode: String = "story", initial_career: String = "undecided") -> Dictionary`
- `static func validate(state: Dictionary) -> bool`
- `static func choose_career(state: Dictionary, target: String, earned_offers: Array, alive: bool = true) -> Dictionary`
- `static func choose_continuation(state: Dictionary, choice: String, confirmed_office: String = "none", alive: bool = true) -> Dictionary`
- `static func effective_continuation(state: Dictionary, confirmed_office: String = "none", alive: bool = true) -> String`
- `static func continuation_options(state: Dictionary, confirmed_office: String = "none", alive: bool = true) -> Array`
- `static func elapsed_years(from_year: int, to_year: int) -> int`
- `static func age_at_year(initial_age: int, initial_year: int, year: int) -> int`
- `static func asset_available(play_mode: String, year: int, earliest_year: int, latest_year: int = 0) -> bool`

## prototype/scripts/story/mission_cinematics.gd

- `extends RefCounted`
- `static func sequence_for(data: Dictionary, previous: Dictionary, following: Dictionary) -> Dictionary`
- `static func restore(data: Dictionary, sequence_id: String) -> Dictionary`

## prototype/scripts/story/mission_data.gd

- `extends RefCounted`
- `static func mission_files(band: String) -> Array[Dictionary]`
- `static func raw_steps(band: String) -> Array`
- `static func steps(band: String) -> Array`
- `static func carried_effects(band: String) -> Dictionary`
- `static func source_missions(band: String) -> Dictionary`
- `static func bridge_steps(band: String) -> Dictionary`

## prototype/scripts/story/mission_documents.gd

- `extends RefCounted`
- `static func held(world: Dictionary) -> Array[String]`
- `static func held_documents(world: Dictionary) -> Array[String]`

## prototype/scripts/story/mission_event_batch.gd

- `extends RefCounted`
- `static func stage(screenplay: Dictionary, fields: Array) -> Dictionary`
- `static func commit(screenplay: Dictionary, fields: Array, draft: Dictionary, ledger: String, events: Array[String]) -> bool`

## prototype/scripts/story/opening_story.gd

- `extends RefCounted`
- `static func campaign_year_label() -> String`
- `static func historical_prologue() -> Dictionary`
- `static func childhood(data: Dictionary = {}) -> Dictionary`
- `static func childhood_cards() -> Dictionary`
- `static func sequence(origin_id: String = "italia") -> Dictionary`
- `static func companion_dialog(state: Dictionary) -> Dictionary`
- `static func companion_reply(state: Dictionary) -> String`
- `static func adulthood(state: Dictionary) -> Dictionary`

## prototype/scripts/story/raid_investigation.gd

- `extends RefCounted`
- `static func fresh_state() -> Dictionary`
- `static func phase(data: Dictionary) -> String`
- `static func validate(data: Dictionary) -> String`
- `static func choices(data: Dictionary, npc: String, trust: int) -> Array[Dictionary]`
- `static func question(data: Dictionary, npc: String, topic: String, trust: int) -> Dictionary`
- `static func compare(data: Dictionary, id: String) -> Dictionary`
- `static func view(data: Dictionary) -> Dictionary`

## prototype/scripts/story/village_childhood.gd

- `extends RefCounted`
- `static func start(data: Dictionary) -> bool`
- `static func enabled(data: Dictionary) -> bool`
- `static func active(data: Dictionary) -> bool`
- `static func oath_earned(data: Dictionary) -> bool`
- `static func adult_paths(data: Dictionary) -> Array`
- `static func migrate_legacy_ids(data: Dictionary) -> bool`
- `static func migrate_screenplay(data: Dictionary) -> bool`
- `static func has_npc(data: Dictionary, id: String) -> bool`
- `static func relationship(data: Dictionary, id: String) -> Dictionary`
- `static func npc_catalog(data: Dictionary) -> Array[Dictionary]`
- `static func actor_override(data: Dictionary, id: String) -> Variant`
- `static func execute(data: Dictionary, command: String, args: Dictionary = {}) -> Dictionary`
- `static func talk(data: Dictionary, id: String, choice: String) -> Dictionary`
- `static func advance(data: Dictionary, delta: float) -> bool`
- `static func raids_allowed(data: Dictionary) -> bool`
- `static func on_raid_finished(data: Dictionary) -> void`
- `static func view(data: Dictionary) -> Dictionary`
- `static func hud_title(step: Dictionary, mission_id: String, chapter: String) -> String`
- `static func mission_heading(mission_id: String, chapter: String) -> String`
- `static func dialogue(data: Dictionary, npc_id: String) -> Dictionary`
- `static func interactables(data: Dictionary) -> Array[Dictionary]`
- `static func validate(data: Dictionary) -> String`
- `static func current_step(data: Dictionary) -> Dictionary`
- `static func credit_party_action(data: Dictionary, step: Dictionary, sight: Callable = Callable()) -> String`
- `static func companion_specs(data: Dictionary) -> Dictionary`
- `static func companion_dialogue(data: Dictionary, id: String) -> Dictionary`
- `static func display_name(data: Dictionary, id: String, fallback: String) -> String`
- `static func i04_ctx(data: Dictionary) -> Dictionary`
- `static func i04_reason(data: Dictionary, action: String) -> String`
- `static func i03_ctx(data: Dictionary) -> Dictionary`
- `static func i03_reason(data: Dictionary, action: String) -> String`
- `static func i01_reason(data: Dictionary, action: String) -> String`

## prototype/scripts/story/village_life.gd

- `extends RefCounted`
- `static func ensure(data: Dictionary) -> void`
- `static func npc_catalog(data: Dictionary = {}) -> Array[Dictionary]`
- `static func has_npc(data: Dictionary, id: String) -> bool`
- `static func relationship(data: Dictionary, id: String) -> Dictionary`
- `static func execute(data: Dictionary, command: String, args: Dictionary = {}) -> Dictionary`
- `static func apply_unarmed_hit(data: Dictionary, target_id: String, damage: int) -> bool`
- `static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable(), motion_check: Callable = Callable(), observed_raiders: Dictionary = {}) -> bool`
- `static func interrupt_strike(enemy: Dictionary) -> void`
- `static func raider_goal(data: Dictionary, enemy: Dictionary) -> Vector2`
- `static func raider_waypoint(data: Dictionary, enemy: Dictionary) -> Vector2`
- `static func defense_strength(data: Dictionary) -> int`
- `static func actor_position(data: Dictionary, npc_id: String) -> Vector2`
- `static func training_ready(data: Dictionary) -> bool`
- `static func view(data: Dictionary) -> Dictionary`
- `static func dialogue(data: Dictionary, npc_id: String) -> Dictionary`
- `static func validate(data: Dictionary) -> String`
- `static func is_available(data: Dictionary, npc_id: String) -> bool`

## prototype/scripts/strategy/atlas_data.gd

- `extends RefCounted`
- `static func region_view(id: String, jdn: int = -1) -> Dictionary`

## prototype/scripts/strategy/atlas_screen.gd

- `extends CanvasLayer`
- `signal leave_requested`
- `signal acted(command: String, target: String)`
- `func date_jdn() -> int`
- `static func header(time: Dictionary, season: Dictionary, young: bool, demo: bool) -> String`
- `func refresh(feedback := "") -> void`
- `func tribal_text(region_id: String) -> String`

## prototype/scripts/strategy/globe.gd

- `extends SubViewportContainer`
- `signal region_selected(id: String)`
- `func show_settlements(points: Array) -> void`
- `func focus_region(id: String) -> void`
- `func show_routes(id: String,owned: Array) -> void`

## prototype/scripts/strategy/origins.gd

- `extends RefCounted`

## prototype/scripts/strategy/season_campaign.gd

- `extends RefCounted`
- `static func story_options(data: Dictionary) -> Array`
- `static func new_game(home_id: String = "italia") -> Dictionary`
- `static func validate(data: Dictionary) -> bool`
- `static func summary(data: Dictionary) -> Dictionary`
- `static func region_info(data: Dictionary, id: String) -> Dictionary`
- `static func act(data: Dictionary, command: String, target_id: String = "") -> Dictionary`

## prototype/scripts/tactics/valley_hud.gd

- `extends CanvasLayer`
- `signal requested(action: String, argument: String)`
- `func populate(model) -> void`
- `func add_company(s: Dictionary) -> void`
- `func show_rolls(model) -> void`
- `func report_ready(step: int) -> void`
- `func report_first_stride(step: int, member_id: String, pose: String, distance: float) -> void`
- `func refresh(model, selected: Array, paused: bool, rate: float, message: String) -> void`
- `func blocks(p: Vector2) -> bool`
- `func selection_box(a: Vector2,b: Vector2) -> void`

## prototype/scripts/tactics/valley_landscape.gd

- `extends Node3D`
- `func apply_quality(profile: String) -> void`

## prototype/scripts/tactics/valley_scene.gd

- `extends Node3D`
- `signal leave_requested`
- `signal battle_finished`
- `func set_quality(new_profile: String) -> void`
- `func formation_render_states() -> Dictionary`
- `func formation_far_gait(uid: String) -> Color`
- `func formation_rig_nodes() -> Dictionary`
- `func formation_duplicate_count() -> int`
- `func formation_counters() -> Dictionary`
- `func reset_gesture() -> void`

## prototype/scripts/ui/android_graphics_probe.gd

- `extends Node`

## prototype/scripts/ui/android_village_diagnostics.gd

- `extends Node`
- `func snapshot() -> Dictionary`

## prototype/scripts/ui/combat_action.gd

- `extends "res://scripts/ui/touch_action.gd"`

## prototype/scripts/ui/document_reader.gd

- `extends VBoxContainer`
- `func build(id: String) -> void`
- `static func model_bounds(model: Node3D) -> AABB`

## prototype/scripts/ui/figure_gallery.gd

- `extends MarginContainer`
- `signal closed`
- `static func arrival_ids(home: String, years: int = 12) -> Array`
- `static func texture(id: String) -> Texture2D`
- `static func caption(id: String) -> Dictionary`

## prototype/scripts/ui/game_ui.gd

- `extends CanvasLayer`
- `signal action_requested(action: String, payload: Dictionary)`
- `class Atmosphere extends Control`
- `func show_intro() -> void`
- `func intro_is_full() -> bool`
- `func show_menu(can_continue: bool) -> void`
- `func show_game(state: Dictionary) -> void`
- `func show_cinematic() -> void`
- `func opening_preferences() -> Dictionary`
- `func set_opening_reading(enabled: bool) -> void`
- `func update_state(state: Dictionary) -> void`
- `func show_pause() -> void`
- `func show_dialog(title: String, text: String, choices: Array) -> void`
- `func show_frontier_dialog(dialog: Dictionary) -> void`
- `func show_village_dialog(dialog: Dictionary) -> void`
- `func show_gear_panel(data: Dictionary, feedback: String = "") -> void`
- `func show_party(page: String, data: Dictionary, figures: Dictionary, feedback: String) -> void`
- `func show_village_panel(state: Dictionary, tab := "overview") -> void`
- `func update_navigation(value: Dictionary) -> void`
- `func select_combat_technique(id: String) -> void`
- `func show_combat_palette(state: Dictionary) -> void`
- `func clear_notification() -> void`
- `func notify(message: String) -> void`
- `func set_mode(mode: String) -> void`
- `func set_build_active(active: bool) -> void`
- `func set_quality(profile: String) -> void`
- `func get_quality() -> String`
- `func handle_back() -> bool`
- `static func world_date_text(state: Dictionary) -> String`

## prototype/scripts/ui/imperial_fx.gd

- `extends RefCounted`
- `static func effect_level(profile: String) -> int`
- `static func metal_material(sheen_strength := 1.0) -> ShaderMaterial`
- `static func soft_dot(size := 32) -> Texture2D`
- `static func additive() -> CanvasItemMaterial`
- `static func embers(amount: int, lifetime := 6.0) -> CPUParticles2D`
- `static func sparks(amount: int) -> CPUParticles2D`
- `static func fog(level: int, tint := Color(0.32, 0.12, 0.08)) -> ColorRect`
- `class LegionColumn extends Node2D`
- `LegionColumn`: `func configure(width: float, height: float, count: int, seed: int) -> void`
- `LegionColumn`: `func set_look(blur: float, rim_strength: float, opacity: float, body := Color(0.03, 0.018, 0.016)) -> void`
- `LegionColumn`: `func set_clock(seconds: float) -> void`
- `LegionColumn`: `func figure_count() -> int`
- `LegionColumn`: `func figure(index: int) -> Dictionary`
- `class StandardBearers extends Node2D`
- `StandardBearers`: `func set_state(seconds: float, raised: float) -> void`
- `class Banner extends Control`
- `Banner`: `func set_clock(seconds: float) -> void`
- `Banner`: `func set_light(value: float) -> void`
- `Banner`: `func set_wind(value: float) -> void`
- `class Torch extends Control`

## prototype/scripts/ui/imperial_intro.gd

- `extends Control`
- `signal finished`
- `class BloodStroke extends Node2D`
- `BloodStroke`: `func configure(total: float, stroke: float) -> void`
- `BloodStroke`: `func set_state(revealed: float, seconds_after_cut: float) -> void`
- `class BladeStreak extends Node2D`
- `BladeStreak`: `func set_state(tip_x: float, trail: float, alpha: float) -> void`
- `func play(full_sequence: bool, reduced_motion: bool) -> void`
- `func set_quality(profile: String) -> void`
- `func skip() -> void`
- `func is_done() -> bool`
- `func advance(delta: float) -> void`

## prototype/scripts/ui/opening_overlay.gd

- `extends CanvasLayer`
- `signal advance_requested`
- `signal pause_requested`
- `signal skip_requested`
- `signal reading_mode_changed(enabled: bool)`
- `signal choice_requested(action_id: String)`
- `class FilmShade extends Control`
- `class StoryLine extends Control`
- `func configure(options: Dictionary = {}) -> void`
- `func present(beat: Dictionary, index: int, total: int) -> void`
- `func show_choice_feedback(message: String) -> void`
- `func set_paused(paused: bool) -> void`
- `func set_manual_reading(enabled: bool) -> void`
- `func set_progress(fraction: float) -> void`
- `func finish() -> void`
- `func handle_back() -> bool`

## prototype/scripts/ui/party_panel.gd

- `extends RefCounted`
- `class BronzeWheel extends Control`
- `static func show_wheel(ui, data: Dictionary) -> void`
- `static func show_folio(ui, data: Dictionary, figures: Dictionary, feedback: String) -> void`

## prototype/scripts/ui/party_portrait.gd

- `extends SubViewportContainer`
- `func build(source: Node3D) -> void`

## prototype/scripts/ui/regional_map.gd

- `extends Control`
- `signal destination_selected(id: String)`
- `signal close_requested`
- `signal atlas_requested`
- `func update_view(next: Dictionary) -> void`
- `class MapCanvas extends Control`
- `MapCanvas`: `signal place_selected(id: String)`
- `MapCanvas`: `func update_view(next: Dictionary) -> void`
- `MapCanvas`: `func focus_player() -> void`
- `MapCanvas`: `func zoom(direction: int) -> void`
- `MapCanvas`: `func pixels_per_m() -> float`
- `MapCanvas`: `func project(point: Vector2) -> Vector2`
- `MapCanvas`: `func unproject(pixel: Vector2) -> Vector2`
- `MapCanvas`: `func scale_caption() -> String`

## prototype/scripts/ui/roman_hud/city_route_chart.gd

- `extends PopupPanel`
- `func open_chart(actor: CharacterBody3D, locations: Dictionary, shared: Streets) -> void`
- `func select(id: String) -> void`
- `class Diagram extends Control`

## prototype/scripts/ui/roman_hud/codex.gd

- `extends RefCounted`
- `static func build(ui, state: Dictionary, tab: String) -> Dictionary`
- `static func equipment_view(state: Dictionary) -> Dictionary`
- `static func people_view(ui, state: Dictionary) -> Array[Dictionary]`

## prototype/scripts/ui/roman_hud/compass_ribbon.gd

- `extends Control`
- `signal map_requested`
- `func update_view(value: Dictionary) -> void`
- `func target_heading() -> float`
- `static func bearing(from: Vector2, to: Vector2) -> float`
- `func relative_bearing() -> float`
- `class LocalMap extends Control`
- `LocalMap`: `func update_view(value: Dictionary) -> void`

## prototype/scripts/ui/roman_hud/dialogue_stage.gd

- `extends RefCounted`
- `class LowerThird extends PanelContainer`
- `LowerThird`: `func refit() -> void`
- `static func build(screen: Control, spec: Dictionary) -> Dictionary`

## prototype/scripts/ui/roman_hud/hud_director.gd

- `extends Node`
- `func clear() -> void`
- `func register(id: String, node: CanvasItem, owned := false) -> void`
- `func wake(id: String, seconds := -1.0) -> void`
- `func is_awake(id: String) -> bool`
- `func observe(facts: Dictionary) -> void`
- `func greet() -> void`
- `func calm() -> bool`
- `func presence_target(id: String) -> float`

## prototype/scripts/ui/roman_hud/hud_icons.gd

- `extends RefCounted`
- `static func texture(kind: String, pixels: int, stroke := 1.6) -> Texture2D`
- `static func item_kind(id: String, name := "") -> String`

## prototype/scripts/ui/roman_hud/hud_style.gd

- `extends RefCounted`
- `static func units_per_dp(viewport: Viewport) -> float`
- `static func numeral(index: int) -> String`
- `static func display_font(weight := 600, spacing := 1) -> Font`
- `static func body_font() -> Font`
- `static func label(text: String, size := TYPE_BODY, color := CHARTA, display := false, spacing := 1) -> Label`
- `static func kicker(text: String, size := TYPE_MICRO, color := AURUM) -> Label`
- `static func reveal(control: CanvasItem, reduce_motion: bool, delay := 0.0, slide := Vector2(0, 8)) -> Tween`
- `class VelumBox extends StyleBox`
- `class PlaqueBox extends StyleBox`
- `static func plaque(accent := false, margin := Vector4(18, 14, 18, 14), opacity := 0.9) -> PlaqueBox`
- `static func velum(direction := 0, margin := Vector4(14, 8, 26, 8), strength := 0.62, rule := true) -> VelumBox`
- `static func style_plaque_button(button: Button, primary := false, size := TYPE_CAPTION, active := false) -> void`
- `static func draw_diamond(item: CanvasItem, center: Vector2, radius: float, color: Color) -> void`
- `static func draw_medallion(item: CanvasItem, center: Vector2, radius: float, lit: float, primary := false, pressed := false, disabled := false) -> void`

## prototype/scripts/ui/roman_hud/medallion_button.gd

- `extends "res://scripts/ui/touch_action.gd"`
- `static func box_size(coin_radius: float, caption := true) -> Vector2`
- `func configure(kind: String, coin_radius: float, is_primary := false, caption := true) -> void`
- `func set_action_icon(kind: String) -> void`
- `func reset() -> void`
- `func coin_center() -> Vector2`

## prototype/scripts/ui/roman_hud/menu_kit.gd

- `extends RefCounted`
- `class Backdrop extends ColorRect`
- `Backdrop`: `func animate(reduce_motion: bool) -> void`
- `class Letterbox extends Control`
- `Letterbox`: `func animate(reduce_motion: bool) -> void`
- `class Rule extends Control`
- `class ChoicePlaque extends Button`
- `static func choice(caption: String, index: int, primary := false) -> ChoicePlaque`
- `static func heading(text: String, size := Style.TYPE_CAPTION) -> VBoxContainer`
- `class ItemCard extends PanelContainer`
- `static func item_card(title: String, detail: String, glyph: String, empty := false, quantity := 0) -> ItemCard`
- `class PaperDoll extends Control`

## prototype/scripts/ui/roman_hud/vitals.gd

- `extends Control`

## prototype/scripts/ui/roman_style.gd

- `extends RefCounted`
- `static func font(weight := 600, spacing := 0) -> Font`
- `static func audio_available() -> bool`
- `static func button_styles(primary: bool) -> Dictionary`
- `static func style_button(button: Button, primary: bool, font_size: int) -> void`
- `static func style_title(label: Label, font_size: int) -> void`
- `static func style_caps(label: Label, font_size: int, color := GOLD, spacing := 3) -> void`
- `class TabulaBox extends StyleBox`
- `TabulaBox`: `static func make(kind: String) -> TabulaBox`
- `TabulaBox`: `func silhouette(rect: Rect2) -> PackedVector2Array`
- `class TabletBox extends StyleBox`
- `class MeanderBand extends Control`
- `class LaurelSpray extends Control`

## prototype/scripts/ui/runtime_display.gd

- `extends CanvasLayer`
- `class EnvironmentWatcher extends Node`
- `func apply_quality(profile: String) -> void`
- `static func render_scale_for(output: Vector2i, settings: Dictionary, desktop: bool) -> float`
- `func set_sustained_scene(enabled: bool) -> void`
- `func set_sustained_paused(value: bool) -> void`
- `func quality_report() -> Dictionary`
- `func set_unit_counts(near_count: int, middle_count: int, far_count: int) -> void`
- `func set_diagnostics(enabled: bool) -> void`

## prototype/scripts/ui/safe_area.gd

- `extends RefCounted`
- `static func for_viewport(viewport: Viewport) -> Rect2`
- `static func from_display(screen_safe: Rect2, screen_transform: Transform2D, viewport_size: Vector2) -> Rect2`

## prototype/scripts/ui/touch_action.gd

- `extends Button`
- `func reset() -> void`
- `func set_action_icon(kind: String) -> void`

## prototype/scripts/ui/touch_look.gd

- `extends Control`
- `signal look_changed(delta: Vector2)`
- `signal zoom_changed(factor: float)`
- `func reset() -> void`

## prototype/scripts/ui/touch_modal.gd

- `extends Control`

## prototype/scripts/ui/touch_pad.gd

- `extends Control`
- `signal axis_changed(axis: Vector2)`
- `func reset() -> void`

## prototype/scripts/ui/ui_smoke.gd

- `extends SceneTree`

## prototype/scripts/ui/village_life_panel.gd

- `extends RefCounted`
- `class RegionalMap extends Control`
- `RegionalMap`: `func point(world: Array) -> Vector2`
- `class Meter extends Control`
- `static func show(ui, data: Dictionary, tab := "overview") -> void`

## prototype/scripts/ui/village_navigation.gd

- `extends Control`
- `func update_view(value: Dictionary) -> void`

## prototype/scripts/vegetation/vegetation_ecology.gd

- `extends RefCounted`
- `func height(p: Vector2) -> float`
- `func noise(kind: String, p: Vector2) -> float`
- `static func brook_x(z: float) -> float`
- `static func brook_half_width(z: float) -> float`
- `static func fen_x(z: float) -> float`
- `func water_distance(p: Vector2) -> float`
- `func wetness(p: Vector2) -> float`
- `func slope_deg(p: Vector2) -> float`
- `func wood_edge_x(z: float) -> float`
- `func hill_rise(p: Vector2) -> float`
- `func in_track(p: Vector2, margin := 0.0) -> bool`
- `func near_house(p: Vector2, margin: float) -> bool`
- `func house_clearance(p: Vector2) -> float`
- `func grass_cover(p: Vector2) -> Vector3`
- `func parcel(p: Vector2) -> Dictionary`
- `func build(legacy_sites: Array) -> void`

## prototype/scripts/vegetation/vegetation_field.gd

- `extends Node3D`
- `func build(ground_height: Callable, legacy_sites: Array, brook_source_z := -95.0) -> void`
- `func set_quality(next_profile: String) -> void`
- `func apply_season(index: int) -> void`
- `func set_weather_state(wind: float, wet: float) -> void`
- `func set_wind_time(seconds: float) -> void`
- `func set_player_position(at: Vector3) -> void`
- `func refresh(camera: Camera3D, complete_grass := true) -> void`
- `func stats() -> Dictionary`

## prototype/scripts/vegetation/vegetation_grass.gd

- `extends Node3D`
- `func configure(budget: Dictionary) -> void`
- `func clear() -> void`
- `func update(eye: Vector3, forward: Vector2, half_fov_deg: float, complete := false) -> void`
- `func pending(eye: Vector3) -> bool`
- `func stats() -> Dictionary`

## prototype/scripts/vegetation/vegetation_ground.gd

- `extends RefCounted`
- `func add_mesh(node: MeshInstance3D) -> void`
- `func height(p: Vector2) -> float`
- `static func regional(p: Vector2) -> float`

## prototype/scripts/vegetation/vegetation_library.gd

- `extends RefCounted`
- `static func manifest() -> Dictionary`
- `static func asset_names() -> Array`
- `static func info(name: String) -> Dictionary`
- `static func asset(name: String) -> Dictionary`
- `static func bark_material(texture: String, height: float, kind: String) -> ShaderMaterial`
- `static func leaf_material(texture: String, height: float, kind: String) -> ShaderMaterial`
- `static func card_material(atlas: String) -> ShaderMaterial`
- `static func card_mesh(variant: String, atlas: String) -> Mesh`
- `static func grass_mesh(variant: String) -> Mesh`
- `static func grass_material() -> ShaderMaterial`
- `static func materials() -> Array`

## prototype/scripts/vegetation/vegetation_safe.gd

- `extends RefCounted`
- `static func active() -> bool`
- `static func read_transform(data: PackedFloat32Array, offset: int) -> Transform3D`
- `static func valid_transform(t: Transform3D) -> bool`
- `static func transforms(data: PackedFloat32Array, count: int) -> Array[Transform3D]`
- `static func new_multimesh(mesh: Mesh, capacity: int, bounds: AABB) -> MultiMesh`
- `static func upload(mm: MultiMesh, data: PackedFloat32Array, count: int) -> bool`
- `static func copy_uncompressed(source: Mesh) -> ArrayMesh`
- `static func merge_cards(source: Mesh, data: PackedFloat32Array, count: int, centre: Vector3, atlas := true) -> ArrayMesh`
- `static func crossed_impostor(size: float, bottom: float, views: int, material: Material) -> ArrayMesh`

## prototype/scripts/visuals/authored_ground.gd

- `extends RefCounted`
- `static func sole_lift(path: String, model: Node3D) -> float`

## prototype/scripts/visuals/cc0_gestures.gd

- `extends RefCounted`
- `static func library() -> AnimationLibrary`
- `static func delta(action: String, bone: String, normalized: float) -> Quaternion`

## prototype/scripts/visuals/character_motion.gd

- `extends RefCounted`
- `static func playback_animation(source: Animation, mode: Animation.LoopMode) -> Animation`
- `func bind(model: Node3D, is_civilian: bool, actor_identity: String = "") -> void`
- `func capture_transition(seconds: float) -> void`
- `func advance(delta: float) -> void`
- `func capture_lod_transition() -> Dictionary`
- `func restore_lod_transition(state: Dictionary) -> bool`
- `func reset_world_contacts() -> void`
- `func world_foot_supported(side: String) -> bool`
- `func capture_world_contacts() -> Dictionary`
- `func restore_world_contacts(state: Dictionary) -> void`
- `func plant_world_feet(action: String, phase: float, delta: float, stance: float, preserve_authored_roll: bool = false) -> void`
- `func gait_stride(action: String, metres_per_second: float) -> float`
- `func locomotion(action: String, phase: float, metres_per_second: float, turn_rate: float = 0.0) -> void`
- `func imported_ambient(action: String, phase: float) -> void`
- `func imported_work(phase: float) -> void`
- `func combat(technique: String, progress: float) -> void`
- `func armed_pose(action: String, progress: float, has_shield: bool) -> bool`
- `func blend_transition() -> void`
- `func carry_left() -> void`
- `func reach_world_wrist(side: String, target: Vector3, world_basis: Basis) -> float`

## prototype/scripts/visuals/facial_motion.gd

- `extends RefCounted`
- `func bind(model: Node3D, actor_identity: String) -> void`
- `func advance(delta: float, action: String, detail: int) -> void`
- `func pose(action: String, normalized: float, detail: int) -> void`

## prototype/scripts/visuals/far_ranks.gd

- `extends Node3D`
- `static func gait_data(pose: String, phase0: float, phase1: float) -> Color`
- `static func root_data(start: Transform3D, finish: Transform3D) -> Color`
- `static func interpolated_root(finish: Transform3D, previous: Color, fraction: float) -> Transform3D`
- `static func foot_offset(phase: float, gait: String) -> Vector3`
- `static func deformed_vertex(vertex: Vector3, gait: Color, fraction: float) -> Vector3`
- `func set_step_fraction(fraction: float) -> void`
- `func sync(by_role: Dictionary, gait_by_role: Dictionary = {}, starts_by_role: Dictionary = {}) -> void`

## prototype/scripts/visuals/gear_visuals.gd

- `extends RefCounted`
- `static func instantiate(item_id: String, quality: int, lod: int = 0) -> Node3D`
- `static func fitting_visible(node_name: String, quality: int) -> bool`
- `static func apply_quality(prop: Node3D, quality: int) -> void`
- `static func placements(pieces: Array) -> Array[Dictionary]`
- `static func clear(model: Node3D) -> void`
- `static func attach(model: Node3D, pieces: Array, detail: int) -> Array[Node3D]`

## prototype/scripts/visuals/grove.gd

- `extends Node3D`
- `func populate(placements: Array) -> void`
- `func set_quality(profile: String) -> void`
- `static func set_wind_time(seconds: float) -> void`

## prototype/scripts/visuals/hand_pose.gd

- `extends RefCounted`
- `func bind(model: Node3D, asset_path: String) -> void`
- `func set_grip(amount: float) -> void`

## prototype/scripts/visuals/head_gaze.gd

- `extends RefCounted`
- `func bind(rig: Skeleton3D, preserve_angles: bool = false, mature_offsets: Dictionary = {}) -> void`
- `func available() -> bool`
- `func restore() -> void`
- `func suspend() -> void`
- `func direction_world(bone: int = -1) -> Vector3`
- `func eye_center_world(index: int) -> Vector3`
- `func anchor_world() -> Vector3`
- `static func angles_for(direction: Vector3, actor_basis: Basis) -> Vector2`
- `static func direction_for(angles: Vector2, actor_basis: Basis) -> Vector3`
- `static func damp(current: Vector2, goal: Vector2, rate: float, delta: float) -> Vector2`
- `func apply(delta: float, actor_basis: Basis, point: Vector3, action: String, enabled: bool, natural_scan: bool = false, upper_body: bool = false) -> void`

## prototype/scripts/visuals/marcus_model.gd

- `extends RefCounted`
- `static func installed() -> bool`
- `static func owns(path: String) -> bool`
- `static func eye_offsets(adult: bool) -> Dictionary`

## prototype/scripts/visuals/melee_camera.gd

- `extends RefCounted`
- `func orbit(radians: float) -> void`
- `func zoom_by(factor: float) -> void`
- `func impact(event: Dictionary) -> void`
- `func desired(focus: Vector3, opponent: Vector3, occluder: Array = []) -> Dictionary`
- `func update(focus: Vector3, opponent: Vector3, delta: float, occluder: Array = []) -> Transform3D`
- `func shaking() -> bool`

## prototype/scripts/visuals/melee_impact_audio.gd

- `extends RefCounted`
- `static func stream(id: String) -> AudioStreamWAV`
- `static func samples_for(id: String) -> PackedFloat32Array`
- `static func centroid(samples: PackedFloat32Array) -> float`

## prototype/scripts/visuals/melee_impact_fx.gd

- `extends Node3D`
- `func spawn(event: Dictionary, point: Vector3, normal: Vector3) -> Dictionary`
- `func clear() -> void`
- `func active_particles() -> int`

## prototype/scripts/visuals/melee_pose.gd

- `extends RefCounted`
- `func bind(model: Node3D, kit_id: String, weapon_axis_in_hand: Vector3 = Vector3.ZERO) -> bool`
- `func capture_transition(seconds: float) -> void`
- `func advance(delta: float) -> void`
- `func set_feet(feet: Dictionary) -> void`
- `func stance_feet() -> Dictionary`
- `func strike(move: String, normalized: float) -> bool`
- `func guard(style: String, seconds: float) -> bool`
- `func stance_pose(lowered: float = 0.0) -> bool`
- `static func dodge_root(style: String, seconds: float, root_scale: float = 1.0) -> Vector3`
- `static func dodge_duration(style: String) -> float`
- `func dodge(style: String, seconds: float, root_scale: float = 1.0) -> bool`
- `func reaction(push: Vector3, strength: float, seconds: float, duration: float, root_step: Vector3 = Vector3.ZERO, zone: String = "torso", shield_wide: float = 0.0) -> bool`

## prototype/scripts/visuals/melee_presenter.gd

- `extends RefCounted`
- `func bind_person(target: Node3D, kit_id: String, id: String) -> bool`
- `func bind_rig(holder: Node3D, rig: Node3D, kit_id: String, id: String, axis: Vector3) -> bool`
- `func apply(state: Dictionary, delta: float = 1.0 / 60.0) -> void`

## prototype/scripts/visuals/meshy_asset_registry.gd

- `extends RefCounted`
- `static func metadata(stable_id: String) -> Dictionary`
- `static func source_path(stable_id: String) -> String`
- `static func has_source(stable_id: String) -> bool`
- `static func instantiate(stable_id: String) -> Node3D`
- `static func available(stable_ids: Array[String]) -> Array[String]`
- `static func all_metadata() -> Array[Dictionary]`
- `static func reset_cache_for_tests() -> void`

## prototype/scripts/visuals/meshy_character_registry.gd

- `extends RefCounted`
- `static func story_asset(id: String, origin: String, years: int, appearance: String) -> String`
- `static func owner_asset_allowed(asset: String, named_id: String) -> bool`
- `static func is_owner_civilian(asset: String) -> bool`
- `static func has_complete_set(stable_id: String) -> bool`
- `static func path_for(stable_id: String, age: int, level: int) -> String`
- `static func family_prefix(stable_id: String) -> String`

## prototype/scripts/visuals/meshy_equipment.gd

- `extends RefCounted`
- `static func definition_for(asset_id: String) -> Dictionary`
- `static func has_complete_set(identity: String) -> bool`
- `static func attach(model: Node3D, identity: String, detail: int) -> Array[Node3D]`

## prototype/scripts/visuals/meshy_loadout_registry.gd

- `extends RefCounted`
- `static func metadata(loadout_id: String) -> Dictionary`
- `static func component_ids(loadout_id: String) -> Dictionary`
- `static func available_components(loadout_id: String) -> Dictionary`
- `static func resource_asset(economy_key: String) -> String`
- `static func all_metadata() -> Array[Dictionary]`
- `static func reset_cache_for_tests() -> void`

## prototype/scripts/visuals/meshy_world_props.gd

- `extends RefCounted`
- `static func instantiate(stable_id: String, tier: int = 1) -> Node3D`

## prototype/scripts/visuals/natural_motion.gd

- `extends RefCounted`
- `static func install(model: Node3D, player: AnimationPlayer, model_path: String, relax_arms: bool = true) -> bool`

## prototype/scripts/visuals/party_gear.gd

- `extends RefCounted`
- `static func sync(figure: Node3D, equipment: Dictionary) -> void`

## prototype/scripts/visuals/pose_dress.gd

- `extends RefCounted`
- `func clear() -> void`
- `func bound() -> bool`
- `func bind(model: Node3D) -> bool`
- `func apply(floor_y: float) -> bool`

## prototype/scripts/visuals/practice_gear.gd

- `extends RefCounted`
- `static func attach(model: Node3D) -> Array[Node3D]`

## prototype/scripts/visuals/resident_activity.gd

- `extends RefCounted`
- `static func village_prop(activity: String) -> String`
- `static func city_prop(resident: Dictionary, now: int) -> String`
- `static func standing_work(resident: Dictionary, now: int) -> bool`
- `static func partner_id(resident: Dictionary, now: int) -> int`
- `static func conversation_pairs(requests: Dictionary, buyers: Dictionary) -> Dictionary`
- `static func speaker(first: int, second: int, now: int) -> int`

## prototype/scripts/visuals/resident_footwear.gd

- `extends RefCounted`
- `static func apply(body: Node3D, asset_path: String) -> bool`

## prototype/scripts/visuals/resident_identity.gd

- `extends RefCounted`
- `static func has_person(id: String) -> bool`
- `static func look(resident_id: String, appearance: String, variation: int, years: int) -> Dictionary`
- `static func city_look(uid: String, appearance: String, variation: int, years: int, job: String, wealth: int) -> Dictionary`
- `static func face_vector(item: Dictionary) -> PackedFloat32Array`
- `static func outfit_signature(item: Dictionary) -> String`

## prototype/scripts/visuals/resident_look.gd

- `extends RefCounted`
- `static func signature(look: Dictionary) -> String`
- `static func weights(look: Dictionary) -> Dictionary`
- `static func visible_pieces(look: Dictionary) -> Array[String]`
- `static func apply(body: Node3D, look: Dictionary, level: int) -> void`
- `static func parent_skin(look: Dictionary, source: StandardMaterial3D) -> ShaderMaterial`

## prototype/scripts/visuals/roman_faces.gd

- `extends RefCounted`
- `static func apply(model: Node3D, seed_value: int, look: Dictionary = {}) -> void`

## prototype/scripts/visuals/service_gear.gd

- `extends RefCounted`
- `static func attach(model: Node3D) -> Array[Node3D]`

## prototype/scripts/visuals/social_focus.gd

- `extends RefCounted`
- `func set_dialog(target: Node3D, turn_body: bool = false) -> void`
- `func set_speaker(target: Node3D) -> void`
- `func clear() -> void`
- `func point() -> Vector3`
- `func target() -> Node3D`
- `func update(owner: Node3D, delta: float, allow_ambient: bool) -> void`

## prototype/scripts/visuals/soldier_visual.gd

- `extends Node3D`
- `func configure(new_role: String, new_variant: int = 0) -> void`
- `func set_detail(level: int) -> void`
- `func play_state(new_state: String, phase: float = 0.0) -> void`
- `func present(pose: String, phase: float, delta: float) -> void`
- `func blending() -> bool`
- `func switch_ready() -> bool`
- `func reset_presentation() -> void`
- `func prepare_reuse(new_variant: int, new_seed: int) -> void`
- `static func clip_length(role_name: String, clip: String) -> float`
- `static func far_mesh(role_name: String) -> Mesh`

## prototype/scripts/visuals/valley_rider.gd

- `extends Node3D`
- `func set_mounted(value: bool) -> void`
- `func set_detail(level: int) -> void`
- `func present(state: String, phase: float, _elapsed: float) -> void`
- `func play_state(_state: String) -> void`

## prototype/scripts/visuals/valley_tribal_soldier.gd

- `extends "res://scripts/visuals/soldier_visual.gd"`
- `static func silhouette(family_id: String) -> Mesh`

## prototype/scripts/visuals/village_person.gd

- `extends Node3D`
- `func configure(kind: String, origin: String, years: int) -> void`
- `func configure_appearance(new_appearance: String, variation: int = 0) -> void`
- `func configure_meshy(stable_id: String) -> bool`
- `func configure_meshy_youth(enabled: bool = true, outfit: String = "") -> bool`
- `static func youth_outfit_installed(outfit: String) -> bool`
- `func youth_path(level: int) -> String`
- `func configure_resident(origin: String, years: int, new_appearance: String, variation: int = 0, camera: Camera3D = null, actor_uid: String = "", city_role: String = "", city_wealth: int = -1) -> void`
- `func drive(metres_per_second: float, turn_radians_per_second: float = 0.0) -> void`
- `func set_equipment(sword: bool, shield: bool = false) -> void`
- `func set_service_gear(enabled: bool) -> void`
- `func set_market_gear(pieces: Array) -> void`
- `func sample_service_combat(style: String, normalized: float) -> bool`
- `func sample_combat(technique: String, normalized: float) -> void`
- `func cue_combat(technique: String, duration: float) -> void`
- `func cancel_action() -> void`
- `func strike_contact_seconds() -> float`
- `func cue_strike(seconds_to_contact: float) -> float`
- `func strike_progress() -> Dictionary`
- `func cue(action: String, preferred_style: String = "") -> void`
- `func sample_armed_pose(style: String, normalized: float) -> bool`
- `func cue_unarmed(action: String) -> bool`
- `func set_loaned_gear(enabled: bool) -> void`
- `func reset_motion() -> void`
- `func set_conversation_focus(enabled: bool) -> void`
- `func keep_talking() -> void`
- `func keep_working() -> void`
- `func locomotion_stride(action: String) -> float`
- `func sample_pose(action: String, normalized: float) -> void`
- `func set_jug_carry(enabled: bool) -> void`
- `func set_resident_prop(kind: String) -> void`
- `func apply_water_wrists(left: Vector3, right: Vector3, orientation: Basis) -> void`
- `func set_cinematic_detail(enabled: bool) -> void`
- `func refresh_lod(camera: Camera3D) -> void`
- `func gaze_anchor() -> Vector3`
- `func set_gaze_target(target: Node3D, turn_body: bool = false) -> void`
- `func set_gaze_speaker(target: Node3D) -> void`
- `func clear_gaze_target() -> void`
- `func set_ambient_gaze(enabled: bool) -> void`
- `static func far_foot_contacts(profile_id: String) -> bool`
- `func world_foot_supported(side: String) -> bool`

## prototype/scripts/visuals/workplace_stock.gd

- `extends RefCounted`
- `static func pile_count(quantity: int, capacity: int, slots: int = 3) -> int`
- `static func build(parent: Node3D, workplace: String) -> Array[Node3D]`
- `static func sync(piles: Array, workplace: String, stocks: Dictionary) -> void`

## prototype/scripts/visuals/youth_outfit.gd

- `extends RefCounted`
- `static func for_state(state: Dictionary) -> String`

## prototype/scripts/visuals/youth_sole_contact.gd

- `extends RefCounted`
- `static func motion_report(path: String = MOTION_REPORT) -> Dictionary`
- `func bind(model: Node3D, level: int, report_path: String = MOTION_REPORT) -> void`
- `func clearance(action: String, phase: float) -> float`
- `func measure_lowest() -> float`
- `func apply_to_floor(floor_y: float, action: String, phase: float) -> void`

## prototype/scripts/viva_country/country_field.gd

- `extends Node3D`
- `static func center(z: float) -> float`
- `func build() -> bool`
- `func set_detail(value: String, camera_position: Vector3, force: bool=false) -> void`
- `func set_wind_time(value: float) -> void`

## prototype/scripts/viva_country/country_scenery.gd

- `extends Node3D`
- `func build(soil: ShaderMaterial) -> bool`
- `func set_detail(profile: String, camera_position: Vector3) -> void`
- `func set_wind_time(value: float) -> void`

## prototype/scripts/viva_country/country_sun.gd

- `extends Node3D`
- `func set_daylight(id: String) -> bool`
- `func set_quality(id: String) -> void`

## prototype/scripts/viva_country/country_walk.gd

- `extends Node3D`

## prototype/scripts/viva_roma/closeup_lab.gd

- `extends Node3D`

## prototype/scripts/world/camera_obstruction.gd

- `extends RefCounted`
- `func reset() -> void`
- `func place(space: PhysicsDirectSpaceState3D, anchor: Vector3, wanted: Vector3, previous: Vector3, smoothing: float, excluded: Array[RID] = [], minimum_planar_distance: float = 0.0) -> Vector3`

## prototype/scripts/world/city_ambient_people.gd

- `class_name CityAmbientPeople`
- `extends Node3D`
- `func setup(city: Node3D, camera: Camera3D, requested_profile: String) -> Dictionary`
- `func set_active(value: bool) -> void`

## prototype/scripts/world/city_bakery_display.gd

- `extends Node3D`
- `func install(city: Node3D) -> bool`
- `func set_stock(count: int) -> void`

## prototype/scripts/world/city_exploration.gd

- `extends Node3D`
- `signal leave_requested`
- `signal story_requested`
- `static func tune_forum_mortar(city: Node) -> int`
- `static func prune_future_city_nodes(root: Node, jdn: int, excluded: Dictionary) -> void`
- `static func surface_tile_extra_reach(mesh: MeshInstance3D) -> float`
- `func set_living_city_clock(clock: Dictionary) -> bool`
- `func set_solar_hour(hours: float, season: int = 0, weather_sample: Dictionary = {}) -> void`
- `func perform_action(action: String) -> void`
- `func set_paused(value: bool) -> void`
- `func go_to_colosseum() -> bool`
- `func teleport(point: Vector3) -> void`
- `func snapshot() -> Dictionary`
- `func save_state() -> Error`

## prototype/scripts/world/city_exploration_crowd.gd

- `extends Node3D`
- `func exclude_market_shop(shop: String) -> void`
- `func limit() -> int`
- `func point(index: int) -> Vector3`
- `func tick(observer: Vector3) -> void`
- `func set_paused(value: bool) -> void`

## prototype/scripts/world/city_exploration_state.gd

- `extends RefCounted`
- `static func defaults() -> Dictionary`
- `static func decode(value: Variant) -> Dictionary`
- `static func read(path: String = PATH) -> Dictionary`
- `static func write(state: Dictionary,path: String = PATH) -> Error`

## prototype/scripts/world/city_life_session.gd

- `extends RefCounted`
- `func start(clock: Dictionary, seed: int, scene_nodes: Callable = Callable()) -> bool`
- `func restore(clock: Dictionary, saved: Dictionary, scene_nodes: Callable = Callable()) -> bool`
- `func sync_to(clock: Dictionary, budget_usec: int = MAX_FRAME_BUDGET_USEC) -> Dictionary`
- `func trade_error(shop_id: String, item_id: String, quantity: int, denarii: int, buying: bool) -> String`
- `func book_trade(shop_id: String, item_id: String, quantity: int, denarii: int, buying: bool) -> bool`
- `func save_state() -> Dictionary`
- `func summary() -> Dictionary`
- `func open_campaign(world: Dictionary, scene_nodes: Callable) -> bool`
- `func owns(world: Dictionary) -> bool`
- `func quote(shop_id: String, item_id: String) -> Dictionary`
- `func stage_trade(shop_id: String, item_id: String, quantity: int, denarii: int, buying: bool) -> Dictionary`
- `static func quadrantes_per_denarius() -> int`

## prototype/scripts/world/city_market_bridge.gd

- `extends Node`
- `signal closed`
- `signal message(text: String)`
- `static func verified_sites(city: Node3D) -> Dictionary`
- `func setup(city: Node3D, body: CharacterBody3D, persistent: bool, stable_trader: Marker3D = null, campaign: Model = null, campaign_path := "", scene_nodes := Callable()) -> bool`
- `func attach_living_city(session: LifeSession) -> bool`
- `func campaign_session() -> LifeSession`
- `func sync_campaign() -> Dictionary`
- `func checkpoint_campaign() -> Dictionary`
- `func is_open() -> bool`
- `func nearest() -> Dictionary`
- `func open_shop() -> bool`
- `func open_inventory() -> bool`
- `func close() -> void`
- `func execute(command: String, args: Dictionary, request_id := "") -> Dictionary`

## prototype/scripts/world/city_market_signage.gd

- `class_name CityMarketSignage`
- `extends RefCounted`
- `static func install(city: Node3D, profile: String = "balanced") -> Dictionary`

## prototype/scripts/world/city_party_visit.gd

- `extends RefCounted`
- `func advance(city: Node3D, player: CharacterBody3D, data: Dictionary, delta: float) -> void`
- `func pause() -> void`
- `func return_to_village() -> void`

## prototype/scripts/world/city_resident_view.gd

- `extends Node3D`
- `func setup(source: Life, player: CharacterBody3D, view: Camera3D, quality: String) -> void`

## prototype/scripts/world/city_riding_trial.gd

- `extends Node3D`
- `signal feedback(text: String)`
- `func install(player: CharacterBody3D, figure: Node3D, at: Vector3, heading: float) -> bool`
- `func advance(delta: float, axis: Vector2, camera_yaw: float, faster: bool) -> bool`

## prototype/scripts/world/city_training.gd

- `extends Node3D`
- `func execute_attack(position: Vector3, yaw: float) -> Dictionary`
- `func execute_block() -> Dictionary`
- `func tick(delta: float, observed_position: Vector3 = Vector3.INF) -> Dictionary`
- `func state() -> Dictionary`

## prototype/scripts/world/city_watch_patrol.gd

- `extends Node3D`
- `func setup(host: Node3D, streets: Streets, hud: Control) -> bool`
- `func suspend() -> void`
- `func observation() -> Dictionary`
- `func reply(choice: String) -> bool`
- `func tick(delta: float) -> void`

## prototype/scripts/world/companion_world.gd

- `extends RefCounted`
- `func actor(id: String) -> CharacterBody3D`
- `func home(id: String) -> Vector3`
- `func sync(data: Dictionary) -> void`
- `func reset(data: Dictionary) -> void`
- `func pause() -> void`
- `func advance(delta: float) -> void`
- `func departing_for_market(data: Dictionary, at: Vector3) -> Array[CharacterBody3D]`

## prototype/scripts/world/game_world.gd

- `extends Node3D`
- `signal action_requested(action: String, payload: Dictionary)`
- `func setup(state: Dictionary) -> void`
- `func sync_state(state: Dictionary) -> void`
- `func set_mode(mode: String) -> void`
- `func set_menu_flight(enabled: bool) -> void`
- `func is_menu_flight() -> bool`
- `func set_active(active: bool) -> void`
- `func get_player_position() -> Vector3`
- `func prepare_cinematic_camera() -> void`
- `func get_cinematic_anchor(key: String) -> Vector3`
- `func get_cinematic_figure(actor_id: String) -> Node3D`
- `func set_frontier_time(seconds: float) -> void`
- `func get_frontier_npc_position(id: String) -> Vector3`
- `func get_frontier_npc_info(id: String) -> Dictionary`
- `func focus_frontier_npc(id: String) -> bool`
- `func clear_frontier_focus() -> void`
- `func set_build_mode(enabled: bool) -> void`
- `func is_build_active() -> bool`
- `func set_quality(profile: String) -> void`
- `func set_presentation_time(seconds: float) -> void`
- `func get_quality_profile() -> String`
- `func set_touch_move(axis: Vector2) -> void`
- `func is_running() -> bool`
- `func combat_line_clear(from: Vector2, to: Vector2) -> bool`
- `func perform_unarmed(technique: String) -> void`
- `func cue_unarmed(technique: String) -> void`
- `func select_route(id: String) -> void`
- `func at_waystation() -> bool`
- `func navigation_view() -> Dictionary`
- `func perform_interaction() -> void`
- `func perform_attack(technique := "") -> void`
- `func set_running(value: bool) -> void`
- `func set_selected_technique(technique: String) -> void`
- `func set_touch_camera_managed(value: bool) -> void`
- `func apply_camera_look(relative: Vector2) -> void`
- `func apply_camera_zoom(factor: float) -> void`
- `func sync_combat_state(state: Dictionary) -> void`
- `func set_raid_physics_authority(enabled: bool) -> void`
- `func raid_observations() -> Dictionary`
- `func combat_sight_clear(from: Vector2, to: Vector2) -> bool`
- `func npc_sight_clear(from: Vector3, to: Vector3) -> bool`
- `func combat_safe_motion(from: Vector2, to: Vector2) -> Vector2`
- `func guard_visual_style() -> String`
- `func cue_village_defense(action: String) -> void`
- `func focus_village_npc(id: String) -> void`
- `func focus_companion_gaze() -> void`
- `func npc_observations() -> Dictionary`
- `func show_confirmed_impact(event: Dictionary, age: int, enabled: bool) -> void`
- `func set_political_context(view: Dictionary) -> void`

## prototype/scripts/world/land/far_relief.gd

- `extends Node3D`
- `static func massif_height(p: Vector2) -> float`
- `static func height(p: Vector2) -> float`
- `func follow(position: Vector3, quality: String) -> void`
- `static func level_rect(level: int, centre: Vector2) -> Rect2`
- `class _Grid`
- `_Grid`: `func add(rect: Rect2, wanted_cell: float, offset: float, hole: Rect2, sample: Callable) -> void`
- `_Grid`: `func commit() -> ArrayMesh`

## prototype/scripts/world/land/land_surface.gd

- `extends RefCounted`
- `static func make_terrain() -> ShaderMaterial`
- `static func make_far() -> ShaderMaterial`
- `static func dress_village_ground(material: ShaderMaterial) -> void`
- `static func follow_village_ground(ground: ShaderMaterial, others: Array) -> void`
- `static func apply_season(materials: Array, season: int, tint: Color) -> void`
- `static func sync_haze(materials: Array, environment: Environment, horizon: Color) -> void`

## prototype/scripts/world/mount_controller.gd

- `extends Node3D`
- `signal state_changed(mounted: bool)`
- `signal action_feedback(text: String)`
- `func configure(rider: CharacterBody3D, figure: Node3D, horse: CharacterBody3D, saddle: Node3D, sole_offset := 0.90) -> bool`
- `func is_mounted() -> bool`
- `func riding_speed() -> float`
- `func riding_gait() -> StringName`
- `func camera_exclusions() -> Array[RID]`
- `func interaction_label() -> String`
- `func request_interact() -> bool`
- `func clear_pending() -> void`
- `func advance(delta: float, axis: Vector2, camera_yaw: float, faster: bool) -> bool`

## prototype/scripts/world/mounted_rider_pose.gd

- `extends "res://scripts/visuals/character_motion.gd"`
- `func start(figure: Node3D) -> bool`
- `func seated(lean: float) -> bool`
- `func pelvis_world() -> Vector3`
- `func stop() -> void`

## prototype/scripts/world/player_action_world.gd

- `extends RefCounted`
- `func sync(data: Dictionary) -> void`
- `func reset() -> void`
- `func attack() -> void`
- `func sight_clear(from: Vector2, to: Vector2) -> bool`
- `func safe_actor_motion(from: Vector2, to: Vector2) -> Vector2`
- `func sync_personal_space() -> void`

## prototype/scripts/world/regional_footpath.gd

- `extends RefCounted`
- `static func length_m() -> float`
- `static func map_points() -> Array`
- `static func add_entrance(sector: Node3D, sector_size: float) -> void`
- `static func destination(id: String) -> Vector2`
- `static func route_between(start: Vector2, goal: Vector2) -> PackedVector2Array`
- `static func add_tracks(sector: Node3D, size_m: float, height: Callable) -> void`

## prototype/scripts/world/regional_quarry.gd

- `extends RefCounted`
- `static func approach_direction() -> Vector2`
- `static func site_coordinates() -> Vector2`
- `static func add_site(sector: Node3D, sector_size: float, surface_height: Callable) -> void`
- `static func add_collision(sector: Node3D) -> void`
- `static func remove_collision(sector: Node3D) -> void`

## prototype/scripts/world/regional_terrain.gd

- `extends Node3D`
- `func follow(position: Vector3, quality: String, velocity: Vector3 = Vector3.ZERO) -> void`
- `static func ground_color(global_point: Vector3) -> Color`
- `static func surface_height(position: Vector2) -> float`
- `func report() -> Dictionary`

## prototype/scripts/world/regional_village.gd

- `extends Node3D`
- `func show_origin(id: String) -> void`
- `func set_active(enabled: bool) -> void`
- `func set_quality(profile: String) -> void`

## prototype/scripts/world/regional_waystation.gd

- `extends Node3D`
- `static func at_counter(player: Vector3) -> bool`
- `func setup(height: Callable) -> void`
- `func update_nearby(player: Vector3, receipt: Dictionary, delta := 1.0) -> void`

## prototype/scripts/world/roman_quarter.gd

- `extends Node3D`
- `func install(profile: String, add_imported_colliders: Callable) -> void`
- `func tablet_reachable(player: CharacterBody3D) -> bool`
- `func street_at(at: Vector3) -> String`

## prototype/scripts/world/village/architecture/valdora_house_family.gd

- `extends RefCounted`
- `static func variant_for(home_id: String) -> String`
- `static func manifest() -> Dictionary`
- `static func variant_data(variant_id: String) -> Dictionary`
- `static func navigation_footprints(home: Dictionary) -> Array[Rect2]`
- `static func material(profile: String, tint: Color, age_state: String) -> ShaderMaterial`
- `static func set_wetness(value: float) -> void`
- `static func register_material(material: ShaderMaterial) -> void`
- `static func instantiate(home: Dictionary, profile: String) -> Node3D`
- `static func instantiate_forge_shell(profile: String) -> Node3D`
- `static func is_family_house(model: Node) -> bool`
- `static func apply_quality(model: Node3D, profile: String) -> void`
- `static func build_collision(model: Node3D) -> void`
- `static func imported_stats(model: Node3D) -> Dictionary`

## prototype/scripts/world/village/architecture/valdora_paving.gd

- `extends Node3D`
- `func build(region: Node3D) -> void`
- `func set_quality(next: String) -> void`

## prototype/scripts/world/village/backdrop_hills.gd

- `extends RefCounted`
- `static func step_m() -> float`
- `static func foot_z(x: float) -> float`
- `static func relief(p: Vector2) -> float`
- `static func vertex_position(column: int, row: int) -> Vector3`
- `static func vertex_weights(position: Vector3, height_above_ground: float) -> Color`
- `static func covers(p: Vector2) -> bool`
- `static func surface_height(p: Vector2) -> float`
- `static func build_mesh() -> ArrayMesh`
- `static func material() -> ShaderMaterial`

## prototype/scripts/world/village/breakfast_acting.gd

- `class_name BreakfastActing`
- `extends RefCounted`
- `func advance(world: Node3D, life: Node3D, delta: float, data: Dictionary) -> void`
- `func focus_id() -> String`
- `func owns_gaze(actor_id: String) -> bool`

## prototype/scripts/world/village/brook.gd

- `extends RefCounted`
- `static func replaces_terrain(p: Vector2) -> bool`
- `static func rows(source_z: float) -> PackedFloat32Array`
- `static func columns(z: float, source_z: float) -> PackedFloat32Array`
- `static func ground_height(p: Vector2, source_z: float, rim: bool) -> float`
- `static func walk_height(p: Vector2, source_z: float, rim: bool) -> float`
- `static func ground_mesh(source_z: float) -> ArrayMesh`
- `static func collision_shape(source_z: float) -> ConcavePolygonShape3D`
- `static func water_mesh(source_z: float) -> ArrayMesh`

## prototype/scripts/world/village/frontier_dressing.gd

- `extends Node3D`
- `func build() -> void`
- `func set_quality(profile: String) -> void`
- `func set_wagon_progress(progress: float) -> void`

## prototype/scripts/world/village/house_interiors.gd

- `extends Node3D`
- `static func furnishes(id: String) -> bool`
- `func build(houses: Node3D, dressing: Node = null) -> void`
- `func resolve(items: Array, house_id := "") -> Array`
- `func set_forge_work(work: String) -> void`
- `func set_quality(profile: String) -> void`

## prototype/scripts/world/village/household_designs.gd

- `extends RefCounted`
- `static func shell(id: String) -> Dictionary`
- `static func is_site(id: String) -> bool`
- `static func basics(id: String) -> Array`
- `static func profession(id: String) -> String`
- `static func grime(id: String) -> float`
- `static func contract() -> Dictionary`
- `static func items(id: String) -> Array`
- `static func stations(id: String) -> Array`

## prototype/scripts/world/village/i01_props.gd

- `extends Node3D`
- `func begin_jug_action(action: String) -> void`
- `func jug_in_hand() -> bool`
- `func full_jug_carried() -> bool`
- `func jug_animating() -> bool`
- `func water_interaction_active() -> bool`
- `func begin_film_pour() -> void`
- `func sample_film_pour(seconds: float) -> void`
- `func cinematic_pour_focus() -> Vector3`
- `func settle_film_pour() -> void`
- `static func world_point(local: Vector3) -> Vector3`
- `static func anchor(key: String) -> Vector3`
- `func sync_state(state: Dictionary, figure: Node3D) -> void`
- `func cup_location(owner: String) -> String`
- `func cup_node(owner: String) -> Node3D`
- `func jug_node() -> Node3D`

## prototype/scripts/world/village/i01_water_motion.gd

- `extends RefCounted`
- `func setup(parent: Node3D) -> void`
- `func bind_well() -> bool`
- `func windlass(lift_m: float) -> Vector3`
- `func bucket_base() -> Transform3D`
- `func bucket_at(pose: Transform3D, filled: float, tilt: float = 0.0) -> void`
- `func water_between(start: Vector3, finish: Vector3, strength: float) -> void`
- `func clear_stream() -> void`
- `func finish() -> void`

## prototype/scripts/world/village/i02_props.gd

- `extends Node3D`
- `func sync_state(state: Dictionary, figure: Node3D) -> void`
- `func basket_in_hand() -> bool`
- `func basket_node() -> Node3D`
- `func grip_world() -> Vector3`
- `func hand_world() -> Vector3`
- `func attachment_error_m() -> float`
- `func anchor(key: String) -> Vector3`

## prototype/scripts/world/village/i03_props.gd

- `extends Node3D`
- `func anchor(key: String) -> Vector3`
- `func sync_state(state: Dictionary, figure: Node3D) -> void`
- `func coins_visible() -> bool`
- `func pot_fill() -> String`
- `func jug_in_hand() -> bool`

## prototype/scripts/world/village/i04_props.gd

- `extends Node3D`
- `func anchor(key: String) -> Vector3`
- `func sync_state(state: Dictionary, figure: Node3D, index: int, trial_index: int) -> void`
- `func bundle_armfuls() -> int`
- `func stack_armfuls() -> int`
- `func carrying(what: String) -> bool`
- `func shows(what: String) -> bool`

## prototype/scripts/world/village/interior_kit.gd

- `extends RefCounted`
- `static func ensure() -> void`
- `static func release_meshes() -> void`
- `static func set_profile(profile: String) -> void`
- `static func material_for(surface: Material) -> StandardMaterial3D`
- `static func aabb(prop: String) -> AABB`
- `static func is_detail(prop: String) -> bool`
- `static func hanging(prop: String) -> bool`
- `static func collision(prop: String) -> Array`

## prototype/scripts/world/village/mission_route.gd

- `extends RefCounted`
- `static func local_path(start: Vector2, goal: Vector2) -> PackedVector2Array`
- `func route(start: Vector2, goal: Vector2) -> PackedVector2Array`

## prototype/scripts/world/village/opening_props.gd

- `extends Node3D`
- `func sync_state(state: Dictionary) -> void`

## prototype/scripts/world/village/settlement_dressing.gd

- `extends Node3D`
- `func build(houses: Node3D) -> void`
- `func set_quality(profile: String) -> void`
- `func release_household(id: String) -> void`
- `func release_site(title: String) -> Node3D`

## prototype/scripts/world/village/valdora_land.gd

- `extends RefCounted`
- `static func lane_x(z: float) -> float`
- `static func north_track_x(z: float) -> float`
- `static func south_track_x(z: float) -> float`
- `static func east_track_z(x: float) -> float`
- `static func west_track_z(x: float) -> float`
- `static func track_distance(p: Vector2) -> float`
- `static func in_track(p: Vector2, margin := 0.0) -> bool`
- `static func track_wear(p: Vector2) -> float`
- `static func brook_x(z: float) -> float`
- `static func channel_x(z: float) -> float`
- `static func brook_half_width(z: float) -> float`
- `static func water_half_width(z: float, source_z: float) -> float`
- `static func water_distance(p: Vector2, source_z: float) -> float`
- `static func bed_offset(p: Vector2, source_z: float) -> float`
- `static func water_depth(p: Vector2, source_z: float) -> float`

## prototype/scripts/world/village/village_layout.gd

- `extends RefCounted`
- `static func resident(id: String) -> Dictionary`
- `static func house_footprint(home: Dictionary, margin := 0.0) -> Rect2`
- `static func reserved(p: Vector2, margin := 0.0) -> bool`
- `static func road(p: Vector2) -> bool`
- `static func pose_at(item: Dictionary, seconds: float, index: int) -> Dictionary`

## prototype/scripts/world/village/village_local_navigation.gd

- `extends RefCounted`
- `static func plan(body: CharacterBody3D, target: Vector3) -> Array[Vector3]`
- `static func clear_leg(body: CharacterBody3D, start: Vector3, target: Vector3) -> bool`

## prototype/scripts/world/village/village_population.gd

- `extends Node3D`
- `func sync_behavior(data: Dictionary) -> void`
- `func behavior_observations() -> Dictionary`
- `func show_origin(id: String, time: float, recruited_count: int) -> void`
- `func set_recruited(count: int) -> void`
- `func set_quality(next_profile: String) -> void`
- `func set_active(enabled: bool) -> void`
- `func advance_to(time: float, force := false) -> void`
- `func update_nearby(player_position: Vector3, show_labels: bool) -> void`
- `func nearest_npc(position: Vector3, radius: float) -> String`
- `func actor_position(id: String) -> Vector3`
- `func info(id: String) -> Dictionary`
- `func focus(id: String, viewer: Vector3) -> bool`
- `func clear_focus() -> void`
- `func set_wagon_work(enabled: bool) -> void`
- `func snapshot() -> Array[Dictionary]`

## prototype/scripts/world/village/village_scenery.gd

- `extends Node3D`
- `func set_presentation_time(seconds: float) -> void`
- `func set_origin(id: String) -> void`
- `func set_quality(next_profile: String) -> void`
- `func apply_season(index: int, sun: DirectionalLight3D, environment: Environment) -> void`
- `func set_weather_state(sample: Dictionary) -> void`
- `func create_land() -> void`
- `func register_land(material: ShaderMaterial) -> void`
- `func add_businesses(parent: Node3D) -> void`
- `func palisade_bays(parent: Node3D,poses: Array) -> void`
- `func sow_field(parent: Node3D) -> void`

## prototype/scripts/world/village_art.gd

- `extends RefCounted`
- `static func material(color: Color, roughness: float = 0.88, worn: bool = true) -> StandardMaterial3D`
- `static func transparent_material(color: Color) -> StandardMaterial3D`
- `static func box(parent: Node3D, size: Vector3, location: Vector3, paint: Material, solid: bool = false) -> MeshInstance3D`
- `static func box_collider(parent: Node3D, size: Vector3, location: Vector3 = Vector3.ZERO) -> StaticBody3D`
- `static func cylinder(parent: Node3D, radius: float, height: float, location: Vector3, paint: Material, top_radius: float = -1.0, solid: bool = false) -> MeshInstance3D`
- `static func sphere(parent: Node3D, radius: float, location: Vector3, paint: Material, proportions: Vector3 = Vector3.ONE) -> MeshInstance3D`
- `static func batch_static(root: Node3D, excluded: Array = []) -> Dictionary`
- `static func label(parent: Node3D, words: String, location: Vector3, color: Color = Color(0.94, 0.88, 0.72), font_size: int = 40) -> Label3D`
- `static func roof(parent: Node3D, width: float, depth: float, wall_height: float, rise: float, paint: Material) -> MeshInstance3D`
- `static func hut(parent: Node3D, stone: Material, timber: Material, tiles: Material, solid: bool = true) -> Node3D`
- `static func person(parent: Node3D, role: String, home := "italia", age := 18) -> Node3D`
- `static func tree(parent: Node3D, at: Vector3, height: float, bark: Material, foliage: Material, solid: bool = true) -> Node3D`

## prototype/scripts/world/village_life_world.gd

- `extends Node3D`
- `func raid_observations() -> Dictionary`
- `func sync_raid_state(data: Dictionary) -> void`
- `func behavior_observations() -> Dictionary`
- `func sync_state(data: Dictionary, profile: String) -> void`
- `func at_council_records(point: Vector3) -> bool`
- `func update_south_road(view: Dictionary) -> void`
- `func nearest(position: Vector3, radius := 3.2) -> String`
- `func actor_position(id: String) -> Vector3`
- `func set_active(value: bool) -> void`
- `func focus(id: String, player: Vector3) -> void`
- `func clear_focus() -> void`
- `func hint(position: Vector3) -> String`

## prototype/scripts/world/world_smoke.gd

- `extends SceneTree`

## prototype/scripts/world/world_stream_plan.gd

- `extends RefCounted`
- `static func bounds() -> Dictionary`
- `static func sector_for_position(position: Vector3) -> Vector2i`
- `static func sector_valid(sector: Vector2i) -> bool`
- `static func sector_id(sector: Vector2i) -> String`
- `static func sector_origin(sector: Vector2i) -> Vector3`
- `static func local_coordinates(position: Vector3) -> Dictionary`
- `static func region_at(position: Vector3) -> Dictionary`
- `static func region_label(position: Vector3) -> String`
- `static func terrain_height(position: Vector2) -> float`
- `static func points_of_interest() -> Array`
- `static func roads() -> Array`
- `static func plan(position: Vector3, quality: String = "balanced") -> Dictionary`
- `static func transition(previous: Dictionary, current: Dictionary, create_budget: int = 4) -> Dictionary`
- `static func overview(position: Vector3 = Vector3.ZERO, quality: String = "balanced") -> Dictionary`

## prototype/scripts/world_expansion/asset_library.gd

- `extends RefCounted`
- `func load_manifest_assets(manifest: Dictionary) -> bool`

## prototype/scripts/world_expansion/atlas.gd

- `extends Control`
- `signal settlement_selected(settlement_id: String, region_id: String)`
- `func configure(manifest: Dictionary) -> void`
- `func map_point(at: Vector2) -> Vector2`
- `func route_report() -> Dictionary`

## prototype/scripts/world_expansion/environment_controller.gd

- `extends Node3D`
- `signal presentation_settings_changed`
- `func create_rig() -> void`
- `func advance_presentation(delta: float) -> void`
- `func set_time_of_day(hours: float) -> bool`
- `func set_cycle_duration(seconds: float) -> bool`
- `func set_wind(strength: float, direction: Vector2 = Vector2(2.0, 1.0)) -> bool`
- `func set_wind_time(seconds: float) -> bool`
- `func set_quality(profile: String) -> void`
- `func bind_material(material: ShaderMaterial) -> void`
- `func unbind_materials() -> void`
- `func snapshot() -> Dictionary`

## prototype/scripts/world_expansion/preview.gd

- `extends Node3D`
- `signal return_requested`
- `func select_settlement(id: String, region_id: String = "") -> bool`
- `func set_view_mode(mode: int) -> void`
- `func focus_on_asset(asset_id: String) -> bool`
- `func set_quality(profile: String) -> void`
- `func set_controls_visible(enabled: bool) -> void`
- `func diagnostics() -> Dictionary`

## prototype/scripts/world_expansion/settlement_layout.gd

- `extends RefCounted`
- `static func generate(config: Dictionary, building_assets: Array, vegetation_assets: Array, road_assets: Array = [], services: Array = []) -> Dictionary`

## prototype/scripts/world_expansion/settlement_view.gd

- `extends Node3D`
- `func populate(next_layout: Dictionary, library: RefCounted) -> Dictionary`
- `func clear() -> void`
- `func set_quality(next_profile: String) -> void`
- `func set_overview(enabled: bool, distance: float = 1800.0) -> void`
- `func refresh_budgeted(viewer: Vector3) -> void`
- `func refresh_all(viewer: Vector3) -> void`
- `func report() -> Dictionary`
