# Übergabe: Kindheit, bewohntes Dorf und erste Nahkampfgrundlage

> Historischer Lieferstand des Koordinatorzweigs bis `e5735509622c9a94564dc5fe21257c07074f9df5`. Die aktuelle zusammengeführte Fassung und die spätere Nutzervorgabe stehen in [CHAT_B_DELIVERY.md](CHAT_B_DELIVERY.md) und [STORY_TIME_CONTRACT.md](STORY_TIME_CONTRACT.md). Neue Partien verwenden Julia, Silvanus und Sextus sowie beide endgültigen Nachtfolgen. Der hier beschriebene frühere Familienbogen bleibt für tatsächlich vorhandene Spielstände erhalten. Die folgenden Zahlen, Bild- und Androidgrenzen beziehen sich ausschließlich auf diesen früheren Stand.

Stand: 23. November 2026. Arbeitszweig: `feature/childhood-village-20261123`. Ausgangspunkt des Codes: `f2900eb86b90b185627dcd490fef550fd0cbed11`. Die zwei Zusatzchat-Aufträge wurden zuerst in `2909040deeb33b99ad4180b884b38921f28233a9` gesichert. Für die Weiterarbeit den **aktuellen Remote-Stand dieses Zweigs** und dessen tatsächlichen Änderungsumfang lesen; die zuvor veröffentlichte APK enthält diesen Kindheitsumbau noch nicht.

## Was dieser Stand verändert

Ein neues römisches Spiel beginnt im vorhandenen Familienhaus mit zwölf Jahren. Mutter Antonia, Vater Sextus und Schmied Quintus stammen aus dem vorhandenen gemeinsamen Einwohnerroster. Die Geschichte umfasst 35 geordnete Handlungen mit Gegenständen, Wegen, angeleiteter Arbeit, unterschiedlicher Marktentscheidung, beaufsichtigter Dorfrunde und zeitweiser Wachhilfe. Drei bewusste Ruhehandlungen führen durch vier erzählte Tage; der abschließende Schlaf bereitet das nächste Nachtereignis vor. Ein Timer erledigt weder die Kindheit noch den Sprung zum Erwachsenen. Siehe [STORY.md](STORY.md).

Die gebaute Siedlung umfasst 20 betretbare Wohnhäuser, die vorhandene Domus, Geschäftsgebäude und 26 benannte Hintergrundbewohner zusätzlich zu den 15 Figuren des Dorfmodells. Böden, Schwellen, Zugänge, Möbel und die offene Haustür besitzen passende Kollisionen. Personen blockieren die Spielfigur; Hintergrundbewohner bewegen sich mit geprüften Physikschritten. Die frühere störende innere Palisade ist im bewohnten Dorf deaktiviert. Siehe [GEOMETRY_AND_PEOPLE.md](GEOMETRY_AND_PEOPLE.md).

Für den neuen Anfang gelten ein eigener Geh- und Laufmodus mit vorläufigen Höchstwerten von 1,5 beziehungsweise 3,6 m/s, eine korrigierte unbewaffnete Ruhehaltung und gegensinniger Armschwung. Zehn Übungstechniken besitzen getrennte Bewegungsclips und eine bestätigte Trefferverarbeitung. Helm und Holzschild der Wachhilfe werden an echten Knochen dargestellt und bei Rückgabe entfernt. Die Leihdarstellung ist noch kein neues Schwert-/Schildkampfsystem. Siehe [PERFORMANCE.md](PERFORMANCE.md).

Die Touchoberfläche enthält ein höheres, größeres Steuerfeld, Gehen/Laufen, beschriftete Kampficons, eine Technikauswahl sowie eine kleine Nordkarte mit tatsächlichem aktuellem Auftragsziel. Ein reproduzierter Fehler bei nachlaufenden emulierten Mausereignissen ließ den Bewegungsvektor nach dem Loslassen stehen; die Ereigniskennung verhindert diesen Doppelpfad nun ausdrücklich.

## So wird der neue Abschnitt gestartet

Im laufenden Spiel eine **neue römische Partie** beginnen. Auf Codeebene lautet der ausdrückliche Einstieg `WorldModel.new_game("italia", true, true)`. Das Familienintro verwendet die Kennung `childhood_home`. Bestehende Spielstände werden weiterhin über „Fortsetzen“ geöffnet und behalten ihren bisherigen Weg.

Der bisherige zweiparametrige Aufruf `new_game("italia", true)` aktiviert den neuen Abschnitt nicht. Das ist beabsichtigte Rückwärtskompatibilität. Alte Integrationsszenarien laden ihre ausdrücklich erzeugte Legacy-Partie über die tatsächliche Fortsetzen-Funktion. Die neue UI-Prüfung startet dagegen den neuen Weg über das reguläre Menü. Diese Unterscheidung darf bei weiteren Änderungen nicht verloren gehen.

## Verträge zwischen den Arbeitsbereichen

| Bereich | Maßgebliche Dateien und Vertrag |
| --- | --- |
| Kindheit | `story/village_childhood.gd`; optionaler Vertrag `village.childhood`, Version 1. Reihenfolge, Auftragsinventar, Beziehungen, Arbeit, Ausfall der Wache, Leihstatus und Nachtereignis. |
| Gemeinsame Figuren | `story/village_life.gd`; `npc_catalog(data)`, `has_npc`, `relationship`, `actor_position` berücksichtigen die tatsächlichen Eltern und den Schmied. Keine zweite Figur für dieselbe Einwohner-ID erzeugen. |
| Spieltransaktion | `domain/world_model.gd`; neue Befehle werden in einer Weltkopie verarbeitet, vollständig validiert und erst danach übernommen. JSON-Zahlen der neuen Verträge werden beim Laden korrekt wiederhergestellt. |
| Nahkampf | `domain/unarmed_combat.gd`; optionaler Vertrag `village.unarmed`, Version 1. Annahme, Kosten, Richtung, Trefferzeitpunkt, Zielzustand und Erholung gehören ins Modell. |
| Figurendarstellung | `visuals/village_person.gd`, `natural_motion.gd`, `practice_gear.gd`; `cue_unarmed(id)` darf keine Belohnung vergeben. `configure_resident(...)` lädt Identität und anfängliche Detailstufe gemeinsam. |
| Dorfgeometrie | `world/village/village_layout.gd`, `settlement_dressing.gd`, `regional_village.gd`; sichtbarer Boden und physische Oberkante müssen übereinstimmen. Änderungen am Straßenverlauf auch im Bodenshader abgleichen. |
| Bewohnerbewegung | `world/village/village_population.gd`, `village_life_world.gd`; Kollisionsschicht 8 für zivile Personen. Tote oder nicht dargestellte Zivilfiguren dürfen keine unsichtbaren Blocker behalten. |
| Steuerung | `ui/game_ui.gd`, `touch_pad.gd`, `touch_action.gd`, `combat_action.gd`, `village_navigation.gd`; Weltbewegung, Zielwahl und Darstellung über `main.gd` und `game_world.gd` verbinden. |

Pfade in dieser Tabelle sind relativ zu `prototype/scripts/`.

### Befehle

- `village_childhood_action`: genau `action_id`. Beträge, Vertrauensgewinn und Fortschritt kommen aus dem Spielvertrag, nicht vom aufrufenden Knopf.
- `village_childhood_begin_raid`: keine Argumente; nur nach vollständiger Kindheit und noch offenem Nachtereignis genau einmal zulässig.
- `village_unarmed_attack`: `technique`, `target_id`, `facing_x`, `facing_z`. Eine angenommene Bewegung ist noch kein Treffer. Am vereinbarten Zeitpunkt werden tatsächliche Entfernung, Richtung, Sichtprüfung und Ziel erneut geprüft.
- `village_unarmed_guard`, `village_unarmed_dodge`: keine Argumente. Ausdauer und begrenztes Schutzfenster werden im Modell geführt; Darstellung folgt nur erfolgreicher Annahme.

Der Übungspfahl liegt bei Welt-X/Z `(0,-7)`. Die ersten beiden geraden Schläge stehen sofort zur Verfügung. Bestätigte Übungstreffer eröffnen weitere Techniken. Luftschläge bringen keinen Übungsfortschritt. Der aktuelle Schwellenwert bis zum hohen Tritt ist ein vorläufiger Prototypwert und keine Behauptung realistischer Ausbildungsdauer.

`WorldModel.combat_sight_check` ist die Weltanbindung für Hindernisse. Das produktive `Main` verbindet sie mit `GameWorld.combat_line_clear`. Reine Domainprüfungen dürfen einen eigenen prüfbaren Callback verwenden; eine nicht angeschlossene Sichtprüfung darf nicht als Wandtest ausgegeben werden.

### Zeit und Speicher

Der neue Abschnitt bewahrt das Alter zwölf. Erzählte Dorftage entstehen durch vereinbarte Ruhehandlungen, nicht durch Lesegeschwindigkeit oder Offlinezeit. Die Dorfwirtschaft verwendet hier einen 3.600-Sekunden-Zyklus; alte Spielstände behalten ihren 120-Sekunden-Zyklus. Produktion läuft weiterhin nach den vorhandenen kurzen Arbeitsintervallen. Diese dokumentierte Zwischenlösung ist noch kein einheitlicher Lebenskalender.

Die Hauptansicht verarbeitet die Kindheitssimulation gesammelt ungefähr zehnmal pro Sekunde und erhält dabei die tatsächlich vergangene Spielzeit. Pause und Dialoge erzeugen keine nachgeholte Offlinearbeit. Ein vollständiger Nachweis der Gleichheit beliebig langer Kampf-Zeitsprünge zu vielen kleinen Schritten liegt nicht vor. Der normale Framepfad und tatsächliche kurze Treffer-/Abwehrfolgen sind eigene Prüffälle.

Die äußere Save-Version bleibt fünf. Neue Abschnitte haben eigene Versionsfelder. Alte Saves bekommen keine rückwirkend erfundene Kindheit. Ein beschädigter oder widersprüchlicher neuer Vertrag wird abgelehnt, ohne den aktiven Spielstand zu überschreiben.

## Prüfung und Bilder

Der zentrale Aufruf `python tools/check_prototype.py --report docs/18_childhood/evidence/engine` registriert 40 Gruppen einschließlich Import, alter Spielpfade und sieben neuer Prüfgruppen. Jeder Lauf verwendet eigene leere Daten-, Konfigurations- und Cacheverzeichnisse. Exitcode, Skriptfehler und erwartete Erfolgsmeldung werden gemeinsam geprüft. Maßgeblich für einen tatsächlich abgeschlossenen Lauf sind `evidence/engine/validation_report.json` und dessen Einzelprotokolle.

Die neue Kindheits-Domainprüfung durchläuft alle 35 Schritte sowie beide Marktfolgen, Speichern mitten in Arbeit, Wachablösung, Leihstatus, strikte Nachtfreigabe und tatsächliche Treffer/Abwehr gegen regulär freigegebene Angreifer. Sie positioniert die Testfigur ausdrücklich an benötigten Orten; sie misst keine menschliche Spielzeit.

`childhood_integration_test.gd` verwendet die wirklichen Main-, UI- und Weltobjekte. Geprüft werden neuer Einstieg, ein tatsächliches Muttergespräch per Touchereignis, Auftragsgegenstand, Kartenfortschritt, Speichern/Fortsetzen, drei Displaygrößen und getrennte Bewegung-/Angriffsfinger mit sauberem Loslassen. Der grafische Modus speichert zusätzlich echte Bilder. Auch hier ist die gezielte Platzierung für Gesprächsprüfungen eine Testhilfe und kein aufgezeichneter durchgängiger Fußweg.

Die sechs [Dorfaufnahmen](evidence/world/settlement-review.json) zeigen die tatsächliche Produktionswelt mit festen Prüfansichten. Der [Requisitenvergleich](evidence/performance/) verwendet identische kleine Vorher-/Nachher-Szenen. Beides wurde mit Mesa/llvmpipe gerendert. Software-Rendering ist kein Nachweis einer Android-Bildrate. Es wurden weder Bildschirmbilder erfunden noch Konzeptbilder als Spielausgabe ausgegeben.

Die vollständige abschließende Engine-Regressionsfolge hat alle 40 Gruppen ohne Fehler und Warnungen bestanden; die neue Headless-UI-Gruppe enthält 62 erfolgreiche Prüfungen. Für die Bilder gilt eine engere Aussage: Ein vorheriger grafischer UI-Lauf bestand 69 Prüfungen mit vier Bildern. Nach der abschließenden Korrektur des zu großen Interaktionstexts entstanden drei aktuelle Bilder; der weitere grafische Lauf endete mit Code −9. [Der genaue Bildumfang](evidence/ui/review-scope.json) und [der Lieferbericht](DELIVERY.md) halten diese Grenze fest. Eine vollständige grafische oder Android-Abnahme des letzten Stands darf daraus nicht abgeleitet werden.

## Offene Arbeiten für die weiteren Chats

1. **Neuen Stand auf Android liefern und dort prüfen.** Dieser Umbau hat noch keine neue APK-Laufzeitabnahme. Der bisherige Android-Testweg setzt den alten Dorfanfang voraus und muss anhand des neuen echten Spielerwegs ergänzt werden. Alte 50 Android-Checks oder die alte e1b1c1fb-APK belegen diese Änderung nicht. Keine Veröffentlichung als neue getestete Fassung ohne passenden Bau- und Laufzeitnachweis.
2. **Nacht mit Reitern inszenieren.** Der letzte Schlaf hinterlässt `night_event = "pending"`. Es gibt bisher keinen produktiven Aufruf der Freigabe durch eine neue Nachtfilmsequenz. Dreißig berittene Angreifer, Pferde, individuelle Reiter, Abstand, Schnitt, Audio und Übergang bleiben auszuarbeiten. Quelle und Fiktion sind in [REFERENZEN_UND_RICHTUNG.md](REFERENZEN_UND_RICHTUNG.md) getrennt.
3. **Kindheit inhaltlich vertiefen.** Der geordnete erste Bogen ist noch keine lange Lebensgeschichte. Wiederkehrende Begegnungen, Freundschaften, verschiedene Misserfolge, freiwillige Tätigkeiten und nachvollziehbare spätere Geburtstage müssen eigene gespeicherte Folgen erhalten. Die bewussten vier Tage dürfen nicht als Beleg langer Spielzeit bezeichnet werden.
4. **Bewegung weiter ausarbeiten.** Arme und Grundtechnik sind verbessert, doch Hände, Körpergewicht, Fußkontakt in wechselndem Gelände, unterschiedliche Körperproportionen, Übergänge und Kampfreaktionen bleiben sichtbar prototypisch. Schwert-/Schildkampf benötigt echte Ausrüstung und eigene Regeln.
5. **Persönliches Leben und Wirtschaft erweitern.** Auftragslohn wird getrennt protokolliert, aber die bisherige Geldanzeige bleibt ein gemeinsamer Bestand. Trinkkrug und Wasserauftrag sind vorhanden; eine vollständige Animation aller Alltagshandlungen, freie Innenrauminteraktion und eine fertige Handelsökonomie sind damit nicht belegt.
6. **Lange Partien tragfähig machen.** Die bestehende Befehls-ID-Sicherung ist auf 1.024 Einträge begrenzt. Für eine langfristige Kampagne braucht sie ein begründetes Verfahren zum Kompaktieren beziehungsweise Fortsetzen ohne doppelte Befehlsausführung. Nicht einfach das Wiederholungsschutz-Limit entfernen. Auch die fest verfassten Bewohnerwege ersetzen keine Navigation einer beliebig großen Stadt.
7. **Leistung auf dem Zielgerät messen.** Der Requisitenvergleich reduziert tatsächlich Zeichenaufrufe; die Wirkung der größeren gesamten Siedlung auf Speicher, dauerhaftes FPS-Niveau, Akku und Wärme ist getrennt zu messen. Keine Cloudkosten oder neue Dienstabhängigkeit stillschweigend einführen.

## Die zwei Folgeaufträge

- [Chat A: Bewegung, Kampf und Steuerung](CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md) – drei Agenten für Anatomie/Fortbewegung, Kampf/Treffer und Touch/Kamera/Prüfung.
- [Chat B: Dorf, Geschichte und Welt](CHAT_B_DORF_GESCHICHTE_WELT.md) – drei Agenten für Geschichte/Zeit, Dorf/Bewohner/Innenräume und historische Welt/Wirtschaft/Reiter/Leistung.

Jeder Chat arbeitet auf einem eigenen Branch und bewahrt fremde Arbeit. Gemeinsame Integrationsdateien nur anhand dieser Verträge in kleinen überprüfbaren Änderungen anfassen. Für einen gemeinsamen Stand tatsächliche Commits, Tests, Bilder und offene Punkte zurückmelden. Schwere Render- und Engine-Läufe bei gemeinsamem begrenztem Arbeitsspeicher nacheinander koordinieren. Keine Behauptung dauerhaft arbeitender Chats oder bereits ausgeführter Tests ohne entsprechenden Lauf.
