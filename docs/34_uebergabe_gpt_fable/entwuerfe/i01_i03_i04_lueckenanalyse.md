# Gap analysis I-01 / I-03 / I-04 (read-only audit of df15a2e; base ffbe3ad differs only in character assets)

P = prototype/, M = P/assets/story/missions/band1/, HB = page of the handbook PDF
(/root/.claude/uploads/2f57f86d-fea5-54ec-a5ed-a114ab86238f/cc1cc149-IMPERATHEN_Operation_Aeterna_Masterhandbuch_3_0.pdf,
Textauszug lokal mit `pdftotext -layout` erzeugt).
I-01 beat sheet = HB 13, original I-01 sheet = HB 126, quest contract = HB 10, consequence contract = HB 12,
film production = HB 22-31, first-60-minutes usability = HB 44, test matrix = HB 46, evidence schema = HB 48.

Reachability: all three missions reachable from the main menu without debug: "Neues Leben" starts childhood
(P/scripts/main.gd:280; P/scripts/domain/world_model.gd:87-99), then I-00 prologue + family scene (main.gd:290, 876-877),
then linear I-01 → I-02 → I-03 → I-04 (P/scripts/story/village_childhood.gd:807-881). The integration test
(P/tests/childhood_integration_test.gd:51-125) teleports the player to targets via fixture instead of walking.
Each mission is a few-minute errand with one-button dialogues (docs/22_band1_alignment/FAEHIGKEITEN_UND_SPIELZEIT.md:49,64).

## I-01 (HB 13), by phase
- 00–06 VID-A: exists: I-00 + 3 text cards, camera setups `player` and `market` (P/scripts/story/opening_story.gd:100-111);
  exact handover to the play camera (P/scripts/cinematic/opening_director.gd:299-306, 335-338).
  Missing: shots over bread/cups/hands; Silvanus' joke; getting up at the bed — the player starts at the water table
  (world_model.gd:99), not at the bed (P/scripts/world/village/settlement_dressing.gd:112). No choice talk/help/yard.
  The child sees fist combat buttons (P/scripts/ui/game_ui.gd:1371; world_model.gd:105) although HB 13 says
  "Keine Waffe und kein Militärmenü".
- 06–14 play: exists: steps `mother_morning`, `fill_water` (a point inside the house), `father_morning`, one option each
  (M/I-01.json:10-44). Shelf, table, bread and cups are static batched meshes (settlement_dressing.gd:42, 75-89).
  Missing: take/carry/put cups, well action, refusal path, meal. BUG (invented success): result text says three cups
  stand filled (I-01.json:29) while the world shows two unchanged cups.
- 14–18 VID-B: only the generic transition scene at the I-01/I-02 border repeating the father's text
  (P/scripts/story/mission_cinematics.gd:21-41). Missing: table talk about Sextus, topic choice, Julia's reaction.
- 18–30: neighbours with default lines (village_childhood.gd:31-39); the beat is missing. BUG: talking to Marcus before
  I-03 shows the old hut dialogue "4 Holz teilen" (main.gd:700-703; opening_story.gd:18) whose click fails
  (world_model.gd:491-493).
- 30–34 VID-C: I-02 objective follows; no variants. No time of day; the sun is fixed (P/scripts/world/game_world.gd:683).
- Tests: only title/text checks (P/tests/band1_alignment_test.gd:91,100); all five I-01 tests missing
  (no weapons, film aborted, NPC at the well absent, help refused, save at the table).

## Cross-cutting
- Film system exists: in-engine films with pause, skip, reading mode, checkpoint, suspend (main.gd:188, 794-866),
  tested in P/tests/opening_flow_test.gd:46-84. Missing: choice inside a film, shot-list data, VID-A/B/C per mission.
- Consequence contract fields (immediate_effect, delayed_hook, long_term_effect, line_id, speaker_id) do not exist.
- Props: only jug and one cup are separate (settlement_dressing.gd:92-96); no carry/hand attachment for the child.
- NPCs: story figures fixed to points (village_childhood.gd:220-221); no day schedule (P/scripts/domain/npc_behavior.gd:14).
- Voices: none; no espeak/piper locally; paid voice services excluded (AGENTS.md:55) → BLOCKED.
- Journal shows the child "Truppe/Moral" (game_ui.gd:630, 1701).
- Save: atomic with .bak and SHA (world_model.gd:320-372).
- Youth rig: 35 joints incl. Palm, FingerCurl, Thumb, Jaw; no sit/stand-up/carry clips. Adults: 15 joints, no fingers.

## Plan for an I-01 slice (~5 h)
- WP1 state: screenplay version 3 → 4 with migration like `migrate_screenplay` (village_childhood.gd:160-173). New fields
  `i01_path`, `i01_cups` (per cup), `i01_table_by`, `i01_contact`, `i01_meal`. New bridge steps between `mother_morning`
  and `fill_water` following the I-07 pattern (:824-834), existing step indices unchanged. Consequence objects in data,
  unique `event_id` in `_record` (:1024); result texts depend on state. Acceptance: model test help/yard/refuse; a v3 save
  migrates without retroactively completing anything.
- WP2 props: three named cups, not batched, following saved state; carrying via BoneAttachment3D to Hand_R (labelled greybox);
  move `fill_water` to the well (-7,6); Julia at the table. Acceptance: positions correct after load; xvfb image with
  three cups on the table.
- WP3 film: new setups `home_table`, `home_bed` (opening_director.gd:9; anchor in game_world.gd:308). VID-A ends with a
  choice beat (talk/help/yard) committed through the childhood command; VID-B table talk, Silvanus joins via companion
  direction (add I-01 to companion_story.gd:6), contact topic only if a contact happened; VID-C variants; register new
  sequence IDs in `_restore_opening` (main.gd:845-866).
- WP4: Marcus greeting before I-03 without setting `companion.met` (validator :702-703); remove "Truppe" from the child's
  HUD and journal.
- WP5: new test P/tests/i01_slice_test.gd; extend opening_flow and childhood_integration; xvfb renders 1280×720 and
  1384×1536 (capture option childhood_integration_test.gd:20-23), labelled engine image/greybox.
- Handbook test mapping: T01 "no weapons" (no service gear P/scripts/domain/combat_actions.gd:53-59, no military commands,
  no money cheat); T19 film starts, reaches the choice and hands over exactly to the play camera; T20 skip lands on the
  choice beat and state is unchanged until the player chooses; T21 back key, suspend and resume return to the same beat
  without duplicate events; "film aborted": skipping or interrupting VID-B gives the same result; "NPC at the well absent":
  Marcus hidden → no contact, no substitute line; "help refused": Julia sets the table, meal happens, no trust gain;
  "save at the table": cups in hand / on the table identical after resume.
- BLOCKED: voices and lip sync; Julia's fingers (15-joint rig); youth stand-up clip; Fold7 device; real clock (no day/night).
- Expected slice play time ~8–12 min, not the handbook's 34 min.

## Owner decisions (do not decide silently; implement the handbook where it is explicit and newer)
Calendar (100 AD in AGENTS.md vs 58 BC in HB/campaign_arc.json); AGENTS.md self-contradictions; combat buttons from
minute 0 vs HB 13 "kein Militärmenü"; Marcus friend/rival flag in I-03 vs HB 128/HB 14; save migration; Julia in I-10;
double roles (Nerva/Livia/Priscilla vs Sextus/Cassia/Aurelia); voices; 30 starting denarii vs T01 "no money cheat".
