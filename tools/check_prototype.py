"""Run actual Godot prototype checks with disposable settings and save directories.

No packages or network services are required. The runner validates engine exits,
script errors, and success markers; Godot can log script errors with a zero exit.
Usage: python tools/check_prototype.py --godot godot --report docs/10_development/evidence
"""

from concurrent.futures import ThreadPoolExecutor
from itertools import groupby

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

from motion_quality_gate import source_fingerprint as motion_fingerprint, source_commit

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "prototype"
FAILURE = re.compile(r"SCRIPT ERROR:|Parse Error:|^ERROR:|^USER ERROR:", re.MULTILINE)


def run_check(engine, name, arguments, marker, environment, report):
    started = time.monotonic()
    timeout = {"import": 600, "vegetation_safe": 360, "motion_measurement": 2400, "formation_agents": 600, "formation_levels": 600, "character_phase1": 420, "character_phase2": 420, "world_workshop_entry": 240, "world_expansion": 240, "waystation_workshop_assets": 240, "waystation_journey": 240}.get(name, 120)
    try:
        result = subprocess.run([engine, "--headless", "--path", str(PROJECT), *arguments],
                                cwd=ROOT, env=environment, text=True, encoding="utf-8",
                                errors="replace", capture_output=True, timeout=timeout)
        combined = result.stdout + result.stderr
        success = result.returncode == 0 and FAILURE.search(combined) is None and (marker is None or marker in combined)
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        stdout = (exc.stdout or b"").decode("utf-8", errors="replace")
        stderr = (exc.stderr or b"").decode("utf-8", errors="replace")
        combined = f"TIMEOUT during {name}: {exc}\n{stdout}{stderr}"
        success = False
        code = None
    report.mkdir(parents=True, exist_ok=True)
    (report / f"{name}.log").write_text(combined, encoding="utf-8")
    record = {"check": name, "passed": success, "exit_code": code,
              "elapsed_seconds": round(time.monotonic() - started, 3),
              "expected_marker": marker, "log": f"{name}.log",
              "warnings": [line for line in combined.splitlines() if "WARNING:" in line]}
    print(f"{'PASS' if success else 'FAIL'} {name}: exit={code}", flush=True)
    if not success:
        print(combined[-6000:], flush=True)
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--keep-going", action="store_true", help="Collect every check result; any failed check still fails the run.")
    parser.add_argument("--only", nargs="+", help="Run only these named check groups; omitted means the complete suite.")
    parser.add_argument("--report", type=Path, default=ROOT / "docs/10_development/evidence")
    parser.add_argument("--jobs", type=int, default=1,
                        help="Parallel independent engine groups in keep-going mode (default: 1).")
    args = parser.parse_args()
    if args.jobs < 1 or args.jobs > 1 and not args.keep_going:
        parser.error("--jobs must be positive; parallel checks require --keep-going")
    engine = shutil.which(args.godot)
    if engine is None:
        raise SystemExit(f"Godot not found: {args.godot}")
    report = args.report.resolve()
    version = subprocess.run([engine, "--version"], text=True, capture_output=True, check=True).stdout.strip()
    records = []
    measured_fingerprint = None
    checked_fingerprint = None
    checked_commit = source_commit(ROOT)
    start_fingerprint = motion_fingerprint(ROOT)
    report.mkdir(parents=True, exist_ok=True)
    (report / "motion-measurements.json").unlink(missing_ok=True)
    (report / "motion-gate.json").unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix="imperathen-check-") as temporary:
        environment = os.environ.copy()
        environment["IMPERATHEN_ISOLATED_TEST"] = "1"
        environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
        checks = [
            ("import", ["--import"], None),
            ("domain", ["--script", "res://tests/domain_test.gd"], "DOMAIN_TEST_PASS"),
            ("combat_actions", ["--script", "res://tests/combat_actions_test.gd"], "COMBAT_ACTIONS_PASS"),
            ("combat_model", ["--script", "res://tests/combat_model_integration_test.gd"], "COMBAT_MODEL_PASS"),
            ("melee_tracks", ["--fixed-fps", "60", "--script", "res://tests/melee_strike_bake.gd"], "MELEE_TRACKS_PASS"),
            ("melee_core", ["--script", "res://tests/melee_core_test.gd"], "MELEE_CORE_PASS"),
            ("melee_visual_contact", ["--fixed-fps", "60", "--script", "res://tests/melee_visual_contact_test.gd"], "MELEE_VISUAL_CONTACT_PASS"),
            ("melee_feedback", ["--script", "res://tests/melee_feedback_test.gd"], "MELEE_FEEDBACK_PASS"),
            ("melee_camera", ["--script", "res://tests/melee_camera_test.gd"], "MELEE_CAMERA_PASS"),
            ("melee_weapons", ["--script", "res://tests/melee_weapons_test.gd"], "MELEE_WEAPONS_PASS"),
            ("village_economy", ["--script", "res://tests/village_economy_test.gd"], "VILLAGE_ECONOMY_PASS"),
            ("commerce_transaction", ["--script", "res://tests/commerce_transaction_test.gd"], "COMMERCE_TRANSACTION_PASS"),
            ("city_trade", ["--script", "res://tests/city_trade_test.gd"], "CITY_TRADE_PASS"),
            ("horse_commerce", ["--script", "res://tests/horse_commerce_test.gd"], "HORSE_COMMERCE_PASS"),
            ("horse_rig", ["--script", "res://tests/horse_rig_test.gd"], "HORSE_RIG_PASS"),
            ("mount_controller", ["--fixed-fps", "60", "--script", "res://tests/mount_controller_test.gd"], "MOUNT_CONTROLLER_PASS"),
            ("valdora_politics", ["--script", "res://tests/valdora_politics_test.gd"], "VALDORA_POLITICS_PASS"),
            ("political_offices", ["--script", "res://tests/political_offices_test.gd"], "POLITICAL_OFFICES"),
            ("political_persons", ["--script", "res://tests/political_persons_test.gd"], "POLITICAL_PERSONS_PASS"),
            ("political_reference_playthrough", ["--fixed-fps", "60", "--script", "res://tests/political_reference_playthrough.gd"], "POLITICAL_REFERENCE_PLAYTHROUGH"),
            ("city_market_bridge", ["--fixed-fps", "60", "--script", "res://tests/city_market_bridge_test.gd"], "CITY_MARKET_BRIDGE_PASS"),
            ("city_campaign_trade", ["--script", "res://tests/city_campaign_trade_test.gd"], "CITY_CAMPAIGN_TRADE_PASS"),
            ("campaign_market_visit", ["--fixed-fps", "60", "--script", "res://tests/campaign_market_visit_test.gd"], "CAMPAIGN_MARKET_VISIT_PASS"),
            ("quarter_street_walk", ["--fixed-fps", "60", "--script", "res://tests/quarter_street_walk_test.gd"], "QUARTER_STREET_WALK_PASS"),
            ("resident_footwear", ["--script", "res://tests/resident_footwear_test.gd"], "RESIDENT_FOOTWEAR_PASS"),
            ("city_life", ["--script", "res://tests/city_life_test.gd"], "CITY_LIFE_PASS"),
            ("city_inventory_ui", ["--fixed-fps", "60", "--script", "res://tests/city_inventory_ui_test.gd"], "CITY_INVENTORY_UI_PASS"),
            ("city_character_detail", ["--fixed-fps", "60", "--script", "res://tests/city_character_detail_test.gd"], "0 failures"),
            ("city_support", ["--fixed-fps", "60", "--script", "res://tests/city_support_integration_test.gd"], "CITY_SUPPORT_PASS"),
            ("city_exploration_detail", ["--fixed-fps", "60", "--script", "res://tests/city_exploration_detail_adapter_test.gd"], "CITY_EXPLORATION_DETAIL_PASS"),
            ("city_viva_props", ["--fixed-fps", "60", "--script", "res://tests/city_viva_props_test.gd"], "CITY_VIVA_PROPS_PASS"),
            ("village_life", ["--script", "res://tests/village_life_test.gd"], "VILLAGE_LIFE_PASS"),
            ("village_model", ["--script", "res://tests/village_model_test.gd"], "VILLAGE_MODEL_PASS"),
            ("village_childhood", ["--script", "res://tests/village_childhood_test.gd"], "VILLAGE_CHILDHOOD_PASS"),
            ("npc_behavior", ["--script", "res://tests/npc_behavior_test.gd"], "checks passed"),
            ("npc_social_memory", ["--script", "res://tests/npc_social_memory_test.gd"], "checks passed"),
            ("npc_physical_conversation", ["--fixed-fps", "60", "--script", "res://tests/npc_physical_conversation_test.gd"], "NPC_PHYSICAL_CONVERSATION_PASS"),
            ("team_b_integration", ["--fixed-fps", "60", "--script", "res://tests/team_b_integration_test.gd"], "TEAM_B_INTEGRATION_PASS"),
            ("npc_behavior_world", ["--fixed-fps", "60", "--script", "res://tests/npc_behavior_world_test.gd"], "checks passed"),
            ("raid_route_world_a", ["--fixed-fps", "60", "--script", "res://tests/raid_route_world_test.gd", "--", "part=a"], "checks, 0 failed"),
            ("raid_route_world_b", ["--fixed-fps", "60", "--script", "res://tests/raid_route_world_test.gd", "--", "part=b"], "checks, 0 failed"),
            ("raid_route_world_c", ["--fixed-fps", "60", "--script", "res://tests/raid_route_world_test.gd", "--", "part=c"], "checks, 0 failed"),
            ("raid_route_world_d", ["--fixed-fps", "60", "--script", "res://tests/raid_route_world_test.gd", "--", "part=d"], "checks, 0 failed"),
            ("raid_strike_timing", ["--fixed-fps", "60", "--script", "res://tests/raid_strike_timing_test.gd"], "checks, 0 failed"),
            ("unarmed_combat", ["--script", "res://tests/unarmed_combat_test.gd"], "UNARMED_COMBAT_PASS"),
            ("childhood_integration", ["--fixed-fps", "60", "--script", "res://tests/childhood_integration_test.gd"], "CHILDHOOD_INTEGRATION_PASS"),
            ("locomotion_regression", ["--fixed-fps", "60", "--script", "res://tests/locomotion_regression_test.gd"], "LOCOMOTION_PASS"),
            ("npc_behavior_ui", ["--fixed-fps", "60", "--script", "res://tests/npc_behavior_ui_test.gd"], "NPC_BEHAVIOR_UI_PASS"),
            ("world_stream_plan", ["--script", "res://tests/world_stream_plan_test.gd"], "failures=0"),
            ("regional_terrain", ["--fixed-fps", "60", "--script", "res://tests/regional_terrain_test.gd"], "failures=0"),
            ("frontier_story", ["--script", "res://tests/frontier_story_test.gd"], "FRONTIER_STORY_PASS"),
            ("frontier_people", ["--fixed-fps", "60", "--script", "res://tests/frontier_people_test.gd"], "FRONTIER_PEOPLE_PASS"),
            ("resident_catalog_bridge", ["--fixed-fps", "60", "--script", "res://tests/resident_catalog_bridge_test.gd"], "RESIDENT_CATALOG_BRIDGE_PASS"),
            ("owner_story", ["--fixed-fps", "60", "--script", "res://tests/meshy_owner_story_test.gd"], "MESHY_OWNER_STORY_PASS"),
            ("recovered_population_perf", ["--script", "res://tests/recovered_population_perf_test.gd"], "RECOVERED_POPULATION_PERF_PASS"),
            ("frontier_population", ["--fixed-fps", "60", "--script", "res://tests/frontier_population_test.gd"], "FRONTIER_POPULATION_OK"),
            ("settlement_geometry", ["--fixed-fps", "60", "--script", "res://tests/settlement_geometry_test.gd"], "SETTLEMENT_GEOMETRY_PASS"),
            ("village_collision", ["--fixed-fps", "60", "--script", "res://tests/village_collision_test.gd"], "VILLAGE_COLLISION_PASS"),
            ("village_backdrop", ["--fixed-fps", "60", "--script", "res://tests/village_backdrop_test.gd"], "VILLAGE_BACKDROP_PASS"),
            ("house_interiors", ["--fixed-fps", "60", "--script", "res://tests/house_interiors_test.gd"], "HOUSE_INTERIORS_PASS"),
            ("operation_prima_art", ["--fixed-fps", "60", "--script", "res://tests/operation_prima_art_test.gd"], "OPERATION_PRIMA_ART_PASS"),
            ("genesis_mission_event_batch", ["--script", "res://tests/genesis_mission_event_batch_test.gd"], "GENESIS_MISSION_BATCH_PASS"),
            ("character_phase1", ["--fixed-fps", "60", "--script", "res://tests/character_core_phase1_test.gd"], "CHARACTER_PHASE1_PASS"),
            ("character_phase2", ["--fixed-fps", "60", "--script", "res://tests/character_equipment_phase2_test.gd"], "CHARACTER_PHASE2_PASS"),
            ("frontier_integration", ["--fixed-fps", "60", "--script", "res://tests/frontier_integration_test.gd"], "FRONTIER_INTEGRATION_PASS"),
            ("village_experience", ["--fixed-fps", "60", "--script", "res://tests/village_experience_test.gd"], "VILLAGE_EXPERIENCE_PASS"),
            ("village_panels", ["--fixed-fps", "60", "--script", "res://tests/village_panel_test.gd"], "VILLAGE_PANEL_PASS"),
            ("village_nameplates", ["--fixed-fps", "60", "--script", "res://tests/village_nameplates_test.gd"], "VILLAGE_NAMEPLATES_PASS"),
            ("opening_story", ["--script", "res://tests/opening_story_test.gd"], "OPENING_STORY_PASS"),
            ("combat_sfx", ["--fixed-fps", "60", "--script", "res://tests/combat_sfx_test.gd"], "COMBAT_SFX_PASS"),
            ("opening_voice", ["--fixed-fps", "60", "--script", "res://tests/opening_voice_test.gd"], "OPENING_VOICE_PASS"),
            ("live_npc_voice", ["--fixed-fps", "60", "--script", "res://tests/live_npc_voice_test.gd"], "LIVE_NPC_VOICE_PASS"),
            ("dialogue_lipsync", ["--fixed-fps", "60", "--script", "res://tests/dialogue_lipsync_test.gd"], "DIALOGUE_LIPSYNC_PASS"),
            ("i00_stage", ["--script", "res://tests/i00_stage_test.gd"], "I00_STAGE_PASS"),
            ("campaign_bible", ["--script", "res://tests/campaign_bible_test.gd"], "CAMPAIGN_BIBLE_TEST"),
            ("band1_alignment", ["--script", "res://tests/band1_alignment_test.gd"], "BAND1_ALIGNMENT_PASS"),
            ("i01_slice", ["--script", "res://tests/i01_slice_test.gd"], "I01_SLICE_PASS"),
            ("i01_flow", ["--fixed-fps", "60", "--script", "res://tests/i01_flow_test.gd"], "I01_FLOW_PASS"),
            ("i03_slice", ["--script", "res://tests/i03_slice_test.gd"], "I03_SLICE_PASS"),
            ("i03_flow", ["--fixed-fps", "60", "--script", "res://tests/i03_flow_test.gd"], "I03_FLOW_PASS"),
            ("i04_slice", ["--script", "res://tests/i04_slice_test.gd"], "I04_SLICE_PASS"),
            ("i04_flow", ["--fixed-fps", "60", "--script", "res://tests/i04_flow_test.gd"], "I04_FLOW_PASS"),
            ("mission_bridge_data", ["--script", "res://tests/mission_bridge_data_test.gd"], "MISSION_BRIDGE_DATA_PASS"),
            ("companion_navigation", ["--fixed-fps", "60", "--script", "res://tests/companion_navigation_test.gd"], "COMPANION_NAVIGATION_PASS"),
            ("companion_turn_motion", ["--fixed-fps", "60", "--script", "res://tests/companion_turn_motion_test.gd"], "COMPANION_TURN_MOTION_PASS"),
            ("companion_follow", ["--fixed-fps", "60", "--script", "res://tests/companion_follow_test.gd"], "COMPANION_FOLLOW_PASS"),
            ("chapter_abilities", ["--script", "res://tests/chapter_abilities_test.gd"], "CHAPTER_ABILITIES_PASS"),
            ("band1_expansion", ["--script", "res://tests/band1_expansion_test.gd"], "BAND1_EXPANSION_PASS"),
            ("opening_props", ["--script", "res://tests/opening_props_test.gd"], "failures=0"),
            ("opening_director", ["--script", "res://tests/opening_director_test.gd"], "checks []"),
            ("opening_overlay", ["--fixed-fps", "60", "--script", "res://tests/opening_overlay_test.gd"], "failures=0"),
            ("opening_flow", ["--fixed-fps", "60", "--script", "res://tests/opening_flow_test.gd"], "OPENING_FLOW_PASS"),
            ("ui", ["--fixed-fps", "60", "--script", "res://scripts/ui/ui_smoke.gd"], "UI_SMOKE_PASS"),
            ("roman_menu", ["--fixed-fps", "60", "--script", "res://tests/roman_menu_test.gd"], "ROMAN_MENU_PASS"),
            ("world_workshop_entry", ["--fixed-fps", "60", "--script", "res://tests/world_workshop_entry_test.gd"], "WORLD_WORKSHOP_ENTRY_PASS"),
            ("world_expansion", ["--fixed-fps", "60", "--script", "res://tests/world_expansion_environment_test.gd"], "WORLD_EXPANSION_TESTS"),
            ("roman_hud", ["--fixed-fps", "60", "--script", "res://tests/roman_hud_test.gd"], "ROMAN_HUD_PASS"),
            ("camera_collision", ["--fixed-fps", "60", "--script", "res://tests/camera_collision_test.gd"], "CAMERA_COLLISION_PASS"),
            ("runtime_display_lifecycle", ["--fixed-fps", "60", "--script", "res://tests/runtime_display_lifecycle_test.gd"], "RUNTIME_DISPLAY_LIFECYCLE_PASS"),
            ("fold7_graphics_policy", ["--fixed-fps", "60", "--script", "res://tests/fold7_graphics_policy_test.gd"], "FOLD7_GRAPHICS_POLICY_PASS"),
            ("render_profile", ["--fixed-fps", "60", "--script", "res://tests/render_profile_test.gd"], "RENDER_PROFILE_PASS"),
            ("render_bench_views", ["--fixed-fps", "60", "--script", "res://tests/render_bench_views_test.gd"], "RENDER_BENCH_VIEWS_PASS"),
            ("touch_controls", ["--fixed-fps", "60", "--script", "res://tests/touch_controls_test.gd"], "TOUCH_CONTROLS_PASS"),
            ("action_adapter", ["--fixed-fps", "60", "--script", "res://tests/action_adapter_test.gd"], "ACTION_ADAPTER_PASS"),
            ("action_world", ["--fixed-fps", "60", "--script", "res://tests/action_world_test.gd"], "ACTION_WORLD_PASS"),
            ("world", ["--fixed-fps", "60", "--script", "res://scripts/world/world_smoke.gd"], "WORLD_SMOKE_PASS"),
            ("integration", ["--fixed-fps", "60", "--script", "res://tests/integration_test.gd"], "INTEGRATION_PASS"),
            ("battle_rules", ["--script", "res://tests/battle_rules_test.gd"], "failures=0"),
            ("troop_catalog", ["--script", "res://tests/troop_catalog_test.gd"], "failures=0 troops="),
            ("battle_command", ["--script", "res://tests/battle_command_test.gd"], "failures=0 metrics="),
            ("gear_market", ["--script", "res://tests/gear_market_test.gd"], "GEAR_MARKET_PASS"),
            ("gear_visuals", ["--fixed-fps", "60", "--script", "res://tests/gear_visual_test.gd"], "GEAR_VISUALS_PASS"),
            ("combat_formula", ["--script", "res://tests/combat_formula_test.gd"], "failures=0 metrics="),
            ("valley_orders", ["--fixed-fps", "60", "--script", "res://tests/valley_orders_test.gd"], "failures=0 smallest_row_px="),
            ("soldier_visuals", ["--script", "res://tests/soldier_visual_test.gd"], "0 failed"),
            ("soldier_gait", ["--fixed-fps", "60", "--script", "res://tests/soldier_gait_test.gd"], "failures=0"),
            ("formation_agents", ["--fixed-fps", "60", "--script", "res://tests/formation_agents_test.gd"], "FORMATION_AGENTS_PASS"),
            ("formation_levels", ["--fixed-fps", "60", "--script", "res://tests/formation_agents_test.gd", "++", "large"], "FORMATION_AGENTS_PASS"),
            ("village_people", ["--fixed-fps", "60", "--script", "res://tests/village_person_test.gd"], "checks, 0 failed"),
            ("youth_outfit_skin", ["--script", "res://tests/youth_outfit_skin_test.gd"], "YOUTH_OUTFIT_SKIN_PASS"),
            ("youth_outfit", ["--script", "res://tests/youth_outfit_test.gd"], "YOUTH_OUTFIT_PASS"),
            ("meshy_registry", ["--script", "res://tests/meshy_asset_registry_test.gd"], "MESHY_ASSET_REGISTRY"),
            ("meshy_characters", ["--fixed-fps", "60", "--script", "res://tests/meshy_character_test.gd"], "MESHY_CHARACTERS_PASS"),
            ("meshy_equipment", ["--fixed-fps", "60", "--script", "res://tests/meshy_equipment_test.gd"], "MESHY_EQUIPMENT_PASS"),
            ("character_motion", ["--fixed-fps", "60", "--script", "res://tests/character_motion_test.gd"], "checks; 0 failed;"),
            ("lod_contact_history", ["--fixed-fps", "60", "--script", "res://tests/lod_contact_history_test.gd"], "LOD_CONTACT_HISTORY_PASS"),
            ("service_gear", ["--fixed-fps", "60", "--script", "res://tests/service_gear_test.gd"], "SERVICE_GEAR_PASS"),
            ("natural_motion", ["--fixed-fps", "60", "--script", "res://tests/natural_motion_test.gd"], "checks, 0 failed"),
            ("cc0_runtime_gestures", ["--fixed-fps", "60", "--script", "res://tests/cc0_runtime_gestures_test.gd"], "CC0_GESTURES_PASS"),
            ("village_static_art", ["--script", "res://tests/village_static_art_test.gd"], "checks, 0 failed"),
            ("hero_faces", ["--fixed-fps", "60", "--script", "res://tests/hero_face_test.gd"], "checks, 0 failed"),
            ("facial_lifecycle", ["--fixed-fps", "60", "--script", "res://tests/facial_motion_lifecycle_test.gd"], "FACIAL_LOD_PASS"),
            ("hero_cloth_grounding", ["--fixed-fps", "60", "--script", "res://tests/hero_cloth_grounding_test.gd"], "checks; 0 failed"),
            ("village_scenery", ["--script", str(ROOT / "art/village/verify.gd")], "VILLAGE_SCENERY errors []"),
            ("village_look", ["--script", "res://tests/village_look_test.gd"], "VILLAGE_LOOK_PASS"),
            ("route_fire", ["--script", "res://tests/route_fire_test.gd"], "ROUTE_FIRE_PASS"),
            ("resident_activity", ["--script", "res://tests/resident_activity_test.gd"], "RESIDENT_ACTIVITY_PASS"),
            ("atrium", ["--script", str(ROOT / "art/architecture/verify_atrium.gd")], "ATR_VISUAL errors []"),
            ("seasons", ["--script", "res://tests/season_campaign_test.gd"], "failures=0"),
            ("world_calendar", ["--script", "res://tests/world_calendar_test.gd"], "WORLD_CALENDAR_PASS"),
            ("era_registry", ["--script", "res://tests/era_registry_test.gd"], "ERA_REGISTRY_PASS"),
            ("colosseum_era_gate", ["--script", "res://tests/colosseum_era_gate_test.gd"], "COLOSSEUM_ERA_GATE_PASS"),
            ("colosseum_walkthrough", ["--fixed-fps", "60", "--script", "res://tests/colosseum_walkthrough_test.gd"], "COLOSSEUM_WALKTHROUGH_PASS"),
            ("colosseum_city_integration", ["--fixed-fps", "60", "--script", "res://tests/colosseum_city_integration_test.gd"], "COLOSSEUM_CITY_INTEGRATION_PASS"),
            ("mission_timeline", ["--script", "res://tests/mission_timeline_test.gd"], "MISSION_TIMELINE_PASS"),
            ("time_jump_contract", ["--script", "res://tests/time_jump_contract_test.gd"], "TIME_JUMP_CONTRACT_PASS"),
            ("tribal_world", ["--script", "res://tests/tribal_world_test.gd"], "TRIBAL_WORLD_PASS"),
            ("tribal_save", ["--script", "res://tests/tribal_save_test.gd"], "TRIBAL_SAVE_PASS"),
            ("tribal_atlas", ["--fixed-fps", "60", "--script", "res://tests/tribal_atlas_test.gd"], "TRIBAL_ATLAS_PASS"),
            ("party_transactions", ["--fixed-fps", "60", "--script", "res://tests/party_transactions_test.gd"], "PARTY_TRANSACTIONS_PASS"),
            ("party_world", ["--fixed-fps", "60", "--script", "res://tests/party_world_test.gd"], "PARTY_WORLD_PASS"),
            ("party_city", ["--fixed-fps", "60", "--script", "res://tests/party_city_test.gd"], "PARTY_CITY_PASS"),
            ("party_ui", ["--fixed-fps", "60", "--script", "res://tests/party_ui_test.gd"], "PARTY_UI_PASS"),
            ("adult_path", ["--fixed-fps", "60", "--script", "res://tests/adult_path_test.gd"], "failures=0"),
            ("valley_muster", ["--fixed-fps", "60", "--script", "res://tests/valley_muster_test.gd"], "VALLEY_MUSTER_PASS"),
            ("legio_objects", ["--fixed-fps", "60", "--script", "res://tests/legio_objects_test.gd"], "failures=0"),
            ("party_reconciliation", ["--fixed-fps", "60", "--script", "res://tests/party_reconciliation_test.gd"], "failures=0"),
            ("regional_freight", ["--fixed-fps", "60", "--script", "res://tests/regional_freight_test.gd"], "REGIONAL_FREIGHT"),
            ("waystation_workshop_assets", ["--fixed-fps", "60", "--script", "res://tests/waystation_workshop_assets_test.gd"], "WAYSTATION_WORKSHOP_ASSETS_PASS"),
            ("legio_art", ["--fixed-fps", "60", "--script", "res://tests/legio_art_test.gd"], "failures=0"),
            ("city_watch", ["--fixed-fps", "60", "--script", "res://tests/city_watch_test.gd"], "\"failures\":[]"),
            ("waystation_journey", ["--fixed-fps", "60", "--script", "res://tests/waystation_journey_test.gd"], "CAMPAIGN_MARKET_VISIT_PASS"),
            ("party_aftermath", ["--fixed-fps", "60", "--script", "res://tests/party_aftermath_test.gd"], "failures=0"),
            ("party_conversations", ["--fixed-fps", "60", "--script", "res://tests/party_conversations_test.gd"], '"failures":[]'),
            ("campaign_allegiance", ["--fixed-fps", "60", "--script", "res://tests/campaign_allegiance_test.gd"], "CAMPAIGN_ALLEGIANCE_PASS"),
            ("world_state", ["--script", "res://tests/world_state_test.gd"], "WORLD_STATE_PASS"),
            ("figure_gallery", ["--fixed-fps", "60", "--script", "res://tests/figure_gallery_test.gd"], "failures=0 real_textures=true"),
            ("landscape", ["--script", str(ROOT / "art/landscape/verify.gd")], None),
            ("village_landscape", ["--fixed-fps", "60", "--script", "res://tests/village_landscape_test.gd"], "VILLAGE_LANDSCAPE_PASS"),
            ("vegetation", ["--script", "res://tests/vegetation_test.gd"], "VEGETATION_PASS"),
            ("vegetation_safe", ["--fixed-fps", "60", "--script", "res://tests/vegetation_safe_test.gd"], "VEGETATION_SAFE_PASS"),
            ("valdora_house_family", ["--script", str(ROOT / "art/architecture/valdora_family/verify_family.gd")], "VALDORA_FAMILY errors []"),
            ("regional_workers", ["--fixed-fps", "60", "--script", "res://tests/regional_worker_test.gd"], "REGIONAL_WORKERS_PASS"),
            ("motion_skin_measurement", ["--fixed-fps", "60", "--script", "res://tests/motion_skin_measurement_test.gd"], "checks; 0 failed"),
            ("motion_mesh_clearance", ["--script", "res://tests/motion_mesh_clearance_test.gd"], "checks; 0 failed"),
            ("main_scene", ["--fixed-fps", "60", "--quit-after", "420"], "IMPERATHEN_READY"),
            ("motion_measurement", ["--fixed-fps", "60", "--script", "res://tests/motion_quality_measurement.gd"], "MOTION_MEASURED"),
        ]
        original_motion_manifest = PROJECT / "assets/animations/accad_youth_motion.json"
        if (PROJECT / "assets/characters/marcus_quality_0.glb").is_file() or (args.only and "marcus_character" in args.only):
            checks.append(("marcus_character", ["--fixed-fps", "60", "--script", "res://tests/marcus_character_test.gd"], "MARCUS_CHARACTER_PASS"))
        if original_motion_manifest.is_file() or (args.only and "youth_mocap" in args.only):
            checks.insert(-1, ("youth_mocap", ["--fixed-fps", "60", "--script",
                                             "res://tests/youth_mocap_test.gd"], "YOUTH_MOCAP_RUNTIME_PASS"))
        if args.only:
            unknown = set(args.only) - {entry[0] for entry in checks}
            if unknown:
                parser.error("Unknown check groups: " + ", ".join(sorted(unknown)))
            checks = [entry for entry in checks if entry[0] in args.only]
        def execute(check):
            nonlocal checked_fingerprint, measured_fingerprint
            name, arguments, marker = check
            isolated = environment.copy()
            # Each executable scenario starts with its own account state. A
            # completed opening test must not become another test's Continue.
            for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                location = Path(temporary) / name / variable.lower()
                location.mkdir(parents=True)
                isolated[variable] = str(location)
            if name == "motion_measurement":
                measured_fingerprint = motion_fingerprint(ROOT)
                isolated["IMPERATHEN_MOTION_CONTRACT"] = str(ROOT / "quality/motion_contract.json")
                isolated["IMPERATHEN_MOTION_REPORT"] = str(report / "motion-measurements.json")
                isolated["IMPERATHEN_MOTION_SOURCE"] = measured_fingerprint
            record = run_check(engine, name, arguments, marker, isolated, report)
            if name == "import":
                # Import may create deterministic metadata on a fresh checkout.
                # Every actual regression afterwards must inspect these same bytes.
                checked_fingerprint = motion_fingerprint(ROOT)
            return record

        if args.jobs == 1:
            for check in checks:
                record = execute(check)
                records.append(record)
                if not record["passed"] and not args.keep_going:
                    break
        else:
            # Import and motion fingerprint the entire project. The landscape
            # probe also has a wall-clock deadline measured on an idle host.
            # CityLife also checks a wall-clock budget for individual simulation
            # slices; a competing Godot test changes that measurement.
            exclusive = {"import", "landscape", "motion_measurement", "city_life"}
            with ThreadPoolExecutor(max_workers=args.jobs) as pool:
                for solo, batch in groupby(checks, key=lambda check: check[0] in exclusive):
                    results = map(execute, batch) if solo else pool.map(execute, batch)
                    records.extend(results)
    source_hashes = {}
    for path in sorted(PROJECT.rglob("*")):
        if path.is_file() and ".godot" not in path.parts and path.suffix in {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".godot", ".glb", ".res", ".wav", ".ogg", ".svg", ".ttf", ".json", ".webp", ".jpg", ".png", ".import"}:
            source_hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    final_fingerprint = motion_fingerprint(ROOT)
    # The complete suite ALWAYS requires the measured Motion Quality Gate
    # with identical import, measurement and final source fingerprints.
    # A deliberately selected graphics-only subset does not run motion;
    # it must still verify that source/commit did not change and must clearly
    # report that the independent motion approval was NOT performed.
    selected_motion = not args.only or "motion_measurement" in args.only
    if selected_motion:
        source_unchanged = (checked_fingerprint == measured_fingerprint == final_fingerprint
                            and checked_commit == source_commit(ROOT))
    else:
        # A fresh --import may generate deterministic .uid/.import sidecars.
        # Compare the post-import source fingerprint when import was selected.
        # In a subset without import, compare against the original checkout.
        baseline = checked_fingerprint if "import" in [entry["check"] for entry in records] else start_fingerprint
        source_unchanged = (baseline == final_fingerprint
                            and checked_commit == source_commit(ROOT))
    result = {"engine": version, "parallel_jobs": args.jobs,
              "passed": len(records) == len(checks) and all(item["passed"] for item in records) and source_unchanged,
              "motion_quality_measurement": "required_same_source" if selected_motion else "not_run_selected_subset",
              "motion_source_fingerprint": final_fingerprint, "source_commit": checked_commit,
              "source_unchanged_during_checks": source_unchanged,
              "scope": "selected check groups" if args.only else "complete suite", "selected_checks": [entry[0] for entry in checks],
              "renderer": "headless/dummy; no graphical FPS or screenshot claim",
              "save_isolation": "Separate disposable XDG data/config/cache directories for every check",
              "checks": records, "source_sha256": source_hashes}
    (report / "validation_report.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    raise SystemExit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()
