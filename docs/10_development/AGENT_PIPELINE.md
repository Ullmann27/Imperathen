# Aktiver Aufbau – drei Arbeitsagenten

Stand 22.11.2026. Der neueste Nutzerauftrag gibt den Beginn der Spielentwicklung frei. Der frühere Planungsstopp ist für diesen Block aufgehoben. Öffentliches Repository; keine eigenmächtige Änderung der Sichtbarkeit, keine neuen kostenpflichtigen Dienste und kein Merge nach main.

Die anschließende ausdrückliche Plattformkorrektur verlangt eine auf Android installierbare Fassung. Nutzerstart, APK-Datei und konkrete Nachweise stehen in [ANDROID_INSTALL.md](ANDROID_INSTALL.md). Desktop-Editor und Headless-Lauf dienen der Entwicklung. Für diesen Android-Block übernahmen die drei Agenten Export/Bauanleitung, Touch-/Back-Integration und unabhängige APK-/Laufzeitprüfung; die gemeinsame Integration führt ihre tatsächlichen Ergebnisse zusammen.

## Arbeitszweig

`feature/prototype-foundation-20261122`, aus dem geprüften Dokumentationsstand `a3e036ba24b99416b016337d81ab2b4067350fa3`. Die erste Bestandsprüfung fand nur diesen Dokumentationsstand und main; weitere Arbeiten dürfen bei späteren Prüfungen nicht überschrieben werden.

## Verantwortlichkeiten

| Rolle | Eigene Dateien | Lieferung |
| --- | --- | --- |
| Agent 1 – Zustand und Persistenz | `prototype/scripts/domain/`, `prototype/tests/domain_test.gd` | Spielregeln, Ressourcen, Bau, Gefährte, Ausbildungs-/Konfliktfortschritt, Speicherung und sinnvolle Tests |
| Agent 2 – Oberfläche | `prototype/scripts/ui/` | Überspringbarer Vorspann, Hauptmenü, Einstellungen, lesbares HUD, Dialoge und Rückwege |
| Agent 3 – Spielwelt | `prototype/scripts/world/` | Begehbares 3D-Dorf, Bewegung, Kamera, Sammeln, Bauvorschau, Training und kleiner Kampf |
| Integration | Einstieg, Projektdatei, Assets, Integrationstests und GitHub | Durchgängiger Ablauf und tatsächliche Ausführungsnachweise |

Godot 4.7.2 und Blender 4.3.2 wurden lokal als ausführbar festgestellt. Godot ist die Engine dieses isolierten Prototyps, keine endgültige Produktionsentscheidung für das gesamte Spiel. Vor dem Abschluss erneut Branches und offene PRs lesen; keine parallel eingetroffenen Änderungen überschreiben.

## Parallel laufende Arbeit

Nach der ersten Bestandsprüfung wurde Koordinationsissue #16 sichtbar: Ein weiterer Arbeitsblock erstellt `preview/` (Web-Einstieg), `game/` (Unreal-Basis), `coordination/` und `tools/agent_pipeline.py`. Diese Pfade werden hier nicht bearbeitet. Die eigene Lieferung unter `prototype/` ist ein tatsächlich ausführbarer 3D-Funktionsnachweis. Eine Koordinationsnachricht wurde in #16 hinterlegt. Beide Linien behalten getrennte Branches und werden beim späteren Gesamtcheck bewusst abgeglichen; es wird keine endgültige Mehr-Engine-Produktstrategie daraus abgeleitet.

## Gemeinsamer Schnittstellenvertrag

Die Welt ist in `prototype/scripts/domain/world_model.gd` als `extends RefCounted` implementiert. Keine Autoload-Abhängigkeit. Einstieg lädt das Skript explizit und erstellt eine Instanz. API:

- Signal `changed` ohne Argumente.
- `data: Dictionary`: JSON-fähiger Zustand; keine Node-/Resource-/Vector-Objekte speichern.
- `new_game()`; `execute(command: String, args: Dictionary = {}, command_id: String = "") -> Dictionary` mit `ok` und `message`.
- `advance(delta: float)` für laufende Arbeiten; Pausen führen im Einstieg zu keinem Aufruf.
- `set_player_position(position: Vector3)` für die tatsächlich beobachtete Position.
- `save_game(path: String) -> Dictionary`; `load_game(path: String) -> Dictionary`, Ergebnis mit `ok` und `message`.

Mindestens diese Daten: `schema_version`, `revision`, `world_seconds`, `resources` (`wood`, `grain`, `denarii`), `player` (`position` als [x,y,z], `health`, `age`), `companion` (`met`, `choice`, `trust`), `progress` (`stage`, `training_hits`, `training_complete`, `skirmish_won`), `buildings` (ID, x, z, progress 0..1, completed), `resource_nodes` (ID, x, z, amount), `squad` (`recruits`, `alive`, `morale`), `encounter` (`active`, `enemies` mit ID/x/z/health), `chronicle` (Zeit und Text), `story` (Titel, Text, Auswahl).

Startposition [0,1,8]. Holzstellen `timber_0` bei [-8,2], `timber_1` bei [-11,-3], `timber_2` bei [-5,-7], je 16 Holz. Gefährte bei [-3,4], Trainingsplatz bei [0,-7]. Freie Baufläche: x 5..24, z -4..13; Mindestabstand zwischen Hütten 5 Meter. Erster Bau kostet 8 Holz; Arbeit dauert im Funktionsprototyp 12 Sekunden bei anwesender Figur in Baustellennähe. Diese Zahlen sind Prototypwerte, keine endgültige Spielbalance.

Unterstützte Befehle: `gather` (`node_id`, 4 Holz je Aktion, Reichweite prüfen), `choose_companion` (`choice`: help/decline, einmalig), `build` (`x`,`z`), `train` (Übergang zur erwachsenen Trainingsphase, Voraussetzungen Hütte+Begegnung), `training_hit` (3 gültige Treffer), `recruit` (höchstens 3, Kosten), `start_skirmish`, `strike_enemy` (`enemy_id`, konsistente Trefferfolgen), `receive_damage` (`amount`), `resolve_skirmish` (nur bei tatsächlicher Erfüllung), `choose_story` (`choice`). Fehlende Voraussetzungen verständlich ablehnen. Neue Befehle nur nach Mitteilung an die Integration.

Die UI ist `prototype/scripts/ui/game_ui.gd`, `extends CanvasLayer`: Signal `action_requested(action: String, payload: Dictionary)`; Methoden `show_intro()`, `show_menu(can_continue: bool)`, `show_game(state: Dictionary)`, `update_state(state: Dictionary)`, `show_pause()`, `show_dialog(title: String, text: String, choices: Array)`, `notify(message: String)`, `set_mode(mode: String)`. Aktionen: new_game, continue, resume, save, menu, quit, mode_person, mode_city, mode_map, build, companion_help, companion_decline, train, recruit, skirmish, story_choice. Auswahl darf Payload `choice` tragen. Intro beendet mit Aktion intro_finished. Menüs dürfen Fokus und Weltinput nicht vermischen.

Die Welt ist `prototype/scripts/world/game_world.gd`, `extends Node3D`: Signal `action_requested(action: String, payload: Dictionary)`; Methoden `setup(state: Dictionary)`, `sync_state(state: Dictionary)`, `set_mode(mode: String)`, `set_active(active: bool)`, `get_player_position() -> Vector3`, `set_build_mode(enabled: bool)`. Modi person/city/map. Der Einstieg verarbeitet Weltaktionen über denselben Modellbefehlspfad. Bewegung WASD/Pfeile, Interaktion E, Angriff linke Maustaste/Leertaste, Bauen B, Moduswechsel Tab/M; Touch-Schaltflächen auf HUD soweit praktikabel. Der persönliche Ort bleibt bei Kameramoduswechsel erhalten. Gameplay-Eingaben pausieren in Menüs und Dialogen.

Die erste Lieferung muss einen tatsächlichen Start-/Menü-/Dorfablauf besitzen. Stil: glaubwürdiges römisches Grenzdorf, warmes Stein-/Holzmaterial, gedecktes Rot, Atmosphäre und klare Lesbarkeit. Eigenes Blockout statt kopierter Fremdassets. Kein fotorealistischer Fertigzustand behaupten. Keine Cloud-KI oder beliebiger generierter Code; erste Ereignisfolge arbeitet kontrolliert und offline.

## Während der Integration ergänzter Vertrag

Die gemeinsame Koordination in #17/#18 hat Android zum Hauptziel und PC zur späteren Erweiterung erklärt. Die frühere PC-Arbeitsannahme gilt deshalb nicht als aktuelle Produktfestlegung. Touchbedienung und drei reale Grafikprofile wurden in dieser Lieferung ergänzt.

- UI-Aktionen: `pause`, `intro_finished`, `move_axis` mit x/y, `interact`, `attack`, `cancel_build`, `quality_changed` mit profile low/balanced/high. UI bietet `set_build_active(bool)` und `get_quality()`.
- Weltmethoden: `set_touch_move(Vector2)`, `perform_interaction()`, `perform_attack()`, `is_build_active()`, `set_quality(String)`, `get_quality_profile()`. Aktionssignal `build_mode_changed` mit active synchronisiert den Bauabbruch.
- Native ScreenTouch/ScreenDrag-Ereignisse und Tastatureingaben gelangen zu denselben geprüften Domainbefehlen. Mehrfingerbedienung hat eigene Indexerfassung und löst keine zweite emulierte Mausaktion aus.
- Der Storyzustand enthält aktuell title/text/choices/choice. Eine separate story.id gehört nicht zum strengen Saveschema; Main erkennt eine anstehende Auswahl über einen stabilen Hash aus Titel, Inhalt und Optionen. Fehlgeschlagene Auswahl darf keinen Dialog dauerhaft schließen.
- Sieg durch den letzten tatsächlichen Treffer erzeugt direkt die Folgeentscheidung. Ein reiner Aufruf von resolve_skirmish ohne besiegte Gegner erzeugt keinen Erfolg.
- Das Anzeigen eines Todesdialogs schreibt keinen Spielstand. Speichern erfolgt einmal über den erfolgreichen Befehlsabschluss. App-Pausierung pausiert die Simulation und speichert vor dem Hintergrundwechsel.
- Audio ist in Headless-Prüfläufen absichtlich stumm. Der reale Audio- und Grafikausgang benötigt einen gesonderten Gerätedurchlauf.

## Lieferung und Prüfnachweis

Alle drei Agenten haben ihre Implementierungsbereiche geliefert. Der abschließende Prüfläufer ist `python tools/check_prototype.py`. Seine tatsächlichen Ergebnisse, behobenen Integrationsfehler und verbleibenden Grenzen stehen in [VALIDATION.md](VALIDATION.md). Diese Prüfungen verwenden echte Godot-Szenen und Eingaben, aber einen Renderer ohne grafische Ausgabe. Das ist kein Android-Hardware- oder Leistungsnachweis.

## Android-Lieferabschluss

Die drei Arbeitsbereiche wurden in den tatsächlich erfolgreichen [Android-Lauf 45038377950](https://github.com/Ullmann27/Imperathen/actions/runs/45038377950) integriert. ARM64-APK und separate x86_64-Prüffassung stammen aus Commit `b3d8e01e64663480d228777a7244a2a882bcac18`. Installationsweg, statische Berichte, tatsächliche Menü-/Dorf-/Pausebilder und Android-Laufzeitbericht stehen in [ANDROID_INSTALL.md](ANDROID_INSTALL.md). Ein physischer ARM64-Test und eine vollständige mobile Kampagne bleiben offene Folgearbeit.
