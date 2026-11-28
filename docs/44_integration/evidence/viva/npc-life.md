# B1 — Reproduzierbare NPC-Lebensbeobachtungen

Stand: 2026-11-28

Basis: `4d14cd50e3b9e5c7faebcdeab04c6ef41ad961be` auf `hoplite/kolophon-ac55f0d6--viva-imperium`
Umfang: Beobachtung und Dokumentation; keine Änderungen an NPC-, Welt- oder Simulationskern.

## Reproduktion

Godot `4.7.2.stable.official.ed1daf0bf`, headless, nacheinander aus dem Repository-Root:

```sh
for test in npc_behavior_test npc_behavior_world_test npc_social_memory_test resident_activity_test city_life_test; do
  ../../Godot_v4.7.2-stable_linux.x86_64 --headless --path prototype --script "res://tests/${test}.gd"
done
```

Der vorhandene Import war abgeschlossen; während dieses Laufs war kein Godot-/City-Life-Prozess aktiv. Es wurden keine Performance-Tests ausgeführt. Die vollständigen, ignorierten Einzellogs liegen unter `docs/44_integration/evidence/viva/npc/`.

## Ergebnisse

| Test | Ergebnis | Beobachteter Umfang |
|---|---:|---|
| `prototype/tests/npc_behavior_test.gd` | 86 Checks bestanden | Neues Kindheitsmodell mit 42 gespeicherten Bewohnerentscheidungen, individuellen Profilen, mehreren Routinen, Motiven und Stimmungen; Bedürfnisse und Arbeitsruhe; Beobachtungs- und Speicherregeln. Der Legacy-Spielstand bleibt ohne diese optionale Simulation. |
| `prototype/tests/npc_behavior_world_test.gd` | 63 Checks bestanden | Bewohnerkörper und kollisionsgeprüfte Bewegung auf dem Dorfweg; zusätzlich soziale Navigation. Das belegt Bewegung im Weltpfad, nicht einen vollständigen unbeaufsichtigten Tagesablauf. |
| `prototype/tests/npc_social_memory_test.gd` | 106 Checks bestanden | Nur beobachtete, gegenseitige Gespräche erzeugen soziale Erinnerung. Acht Sekunden begründen Vertrautheit; Freundschaft erfordert mindestens drei getrennte abgeschlossene Begegnungen und 45 kumulierte Gesprächssekunden. Ein Gruß genügt nicht. Das ist keine Spieler-Vertrauenswertung und gewährt keine Belohnungen. |
| `prototype/tests/resident_activity_test.gd` | `RESIDENT_ACTIVITY_PASS` | Aktivitäts-/Arbeitsdarstellung, Tagesfenster, Mahlzeiten und Schutz der Ressourcenbilanz. |
| `prototype/tests/city_life_test.gd` | 122 Checks bestanden | Deterministischer, nicht gerenderter Stadt-Domänenlauf mit Seed `20261126`, Speicher-/Ladefortsetzung, Handel, Gesprächen, Tagesrhythmus und Wetterfällen. |

### Stadt-Simulation: gemessene Zustände

Der Stadt-Test startete im Kampagnenjahr 58 v. Chr. und simulierte 36 Stunden. Er erzeugte 2.095 Bewohner, 480 Haushalte und 120 Betriebe. Alle Bewohner hatten eine gültige Wohnung; Anbieter und Handwerker hatten gültige Arbeitsorte. Die Rollen waren vielfältig: Bettler 4, Kinder 631, Handwerker 127, Ältere 126, Wachen 22, Hausleute 228, Arbeiter 218, Matronen 132, Patrone 134, Träger 26, Diener 384 und Händler 63.

Im 11:30-Snapshot waren 639 Personen draußen; die Aktivitäten umfassten unter anderem Zuhause 1.226, Arbeit 118, Verkauf 63, Abwesenheit 218, Spiel 172 und Gossip 126. Das Wetter war dort klar. Für 02:30 prüft der Test, dass über 80 % schlafen und kein Marktstand mehr besetzt ist; zusätzlich bestehen der Dienstzeit-Grenzfall eines Händlers und die Reaktion, bei Regen Schutz zu suchen.

Nach 36 Stunden meldete der Lauf 7.776 Gespräche, 1.779 Käufe, 63 Lieferungen und null hungrige Haushalte. In diesem Seed-Zeitfenster gab es keine Jobwechsel, Heiraten oder Umzüge. Der Einwohnerbestand blieb erhalten. Ein JSON-Speicher aus der Tagesmitte wurde exakt wiederhergestellt; die Fortsetzung erreichte denselben Endzustand wie der ununterbrochene Lauf (`16da1cd6003562791f5b16176c9026cb1a81c42e9f717b7cb7c342703534b2ca`). Der vollständige Metrikdatensatz steht im Log `docs/44_integration/evidence/viva/npc/city_life_test.txt`.

## Kindheit und Stadt: Verbindung und Grenzen

- **Valdora/Kindheit:** `WorldModel` startet `NpcBehavior` nur im dafür aktivierten neuen Kindheitsmodell; die Dorfwelt nutzt die Daten für Aufmerksamkeit, Sozialkontakt und Bewohnerbewegung. Die 42er-Prüfung belegt individuelle, bedürfnisgesteuerte Entscheidungen und Arbeitsruhe auf Domänenebene; der Welt-Test deckt zusätzlich physische Bewegung ab.
- **Stadt:** `CityExploration` erzeugt eine `CityLifeSession`; `WorldModel` enthält den Stadt-Session-Pfad. `CityLife` simuliert über Stadtanker Haushalte, Berufe, Bedürfnisse, Zeitplan, Handel, soziale Ereignisse und Wetter. Der verwendete Test lädt weder eine 3D-Szene noch ein GLB und ruft die Simulation direkt auf.
- **Nicht belegt:** Die Läufe beweisen weder die automatische Weiterführung bei Abwesenheit des Spielers noch den Übergang persönlicher Kinder-Identitäten und Beziehungen in die 2.095-Personen-Stadtpopulation. Die Kindheits-, Social-Memory- und Stadtprüfungen laufen als getrennte Testpfade. Gespräche in der Stadt sind kein Nachweis für wachsende Freundschaften oder Vertrauen; im 36-Stunden-Lauf änderten sich weder Jobs noch Haushalte. `docs/GENESIS/KNOWN_LIMITATIONS.md` führt AP23 (autonome Siedlungsplanung und Entscheidungen außerhalb des Spielerbereichs) weiterhin als Lücke.
- **Sicht-/Hörqualität:** Der Stadt-Test ist funktional und headless, kein Spielerlebnis- oder Performance-Nachweis. Seine Metriken meldeten `spoken_lines=6`, `voiced_lines=0` und `audio_status=text_only_until_voice_pool_recordings_land`; die Stadtreaktionen sind hier also nicht als vertonte Gespräche belegt.

**Fazit:** Die vorhandenen Tests belegen differenzierte Dorfentscheidungen, soziale Erinnerung, räumliche Bewohnerbewegung und einen reichhaltigen, speicherstabilen Stadt-Domänenlauf. Eine durchgängig autonome, spielerseitig erlebbare Lebenssimulation über Abwesenheit, Alter/Übergang und persistierende Beziehungen hinweg ist damit noch nicht nachgewiesen.
