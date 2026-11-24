# Bewohnerentscheidungen und beobachtete Bewegung

Stand: 24. November 2026. Dieser Abschnitt beschreibt die implementierte,
begrenzte Offline-Simulation. Er behauptet weder menschliches Bewusstsein noch
eine fertige, frei navigierende Großstadt-KI.

## Was im Spiel tatsächlich geschieht

Für die **42 bestehenden Identitäten** werden Bedürfnisse und Absichten gespeichert:
26 Hintergrundbewohner, die 14 Personen der Dorfwirtschaft, Decimus und Marcus.
Die Darstellung erzeugt dafür keine zusätzlichen Einwohner oder Arbeitskräfte.
Interessen und Charakterzüge sind anhand der stabilen ID reproduzierbar; Julia
interessiert sich für Familie, Sextus für Handwerk und Marcus für Lernen und
Erkundung. Die tatsächlichen kanonischen Beziehungen bleiben im vorhandenen
Kindheits- und Gesprächsvertrag.

Alle 0,5 Simulationssekunden werden Erschöpfung, Gesellschaftsbedarf und Anspannung
fortgeschrieben. Gewöhnliche Entscheidungen werden individuell gestaffelt alle
3 bis 5 Sekunden überprüft. Unterschiedliche Gewichtungen und eine kleine
Wechselschwelle verhindern ein gleichförmiges Umschalten aller Figuren.

- Arbeit führt zu Ermüdung. Eine gewählte Pause verringert sie und beendet die
  Arbeitsanimation. Bei Wirtschaftsfiguren zählt eine Pause auch als tatsächliche
  Abwesenheit aus der Produktion; der vorhandene Arbeitsplatz bleibt zugeteilt.
- Bewegliche Bewohner gehen bei Arbeit zurück zum Ursprung ihres Wegs und bei
  Erkundung beziehungsweise Gesellschaft zu einem passenden Punkt auf ihrer
  vorhandenen Route. Wachen pendeln auf ihren Wegen.
- Gesellschaftsbedarf sinkt nur, wenn der Gesprächspartner tatsächlich beobachtet,
  nahe und ebenfalls gesprächsbereit ist. Ein entfernter Name im Zustand genügt
  nicht. Gemeinsame Interessen beeinflussen die Auswahl eines nahen Nachbarn.
- Ein naher Spieler kann einen kurzen Gruß auslösen. Positive oder negative
  Beziehungen beeinflussen Ton und Zurückhaltung. Ein Gespräch bekommt eine
  Wiederholungspause. Sehr enge Nähe veranlasst mobile Bewohner zu einem kleinen,
  kollisionsgeprüften Ausweichschritt.
- Ein lebender naher Angreifer löst bei beweglichen Zivilisten Flucht entlang
  ihrer vorhandenen Wege aus; Wachen beobachten die Gefahr. Ein besiegter Gegner
  wird dabei nicht weiter als Gefahr gezählt. Versorgungsfiguren können Hilfe
  bereithalten, ohne dadurch automatisch jemanden zu heilen oder eine Rettung
  abzuschließen.
- Die gleiche Herbst-Saison, die den Dorfregen steuert, unterbricht passende
  Tätigkeiten im Freien. Es entsteht dadurch kein zweites Wettersystem.

## Physik und Spielregeln

Die Hintergrundkörper benutzen weiterhin `CharacterBody3D.move_and_collide`.
Ihre Routen liegen auf den bestehenden, vorgegebenen Wegen; sie schneiden keine
Hauswände durch eine neue direkte Zielgerade. Bei Personen kann ein kurzer
geprüfter Seitenschritt helfen. Bei einer Wand warten sie. Fahrtstrecke und
Gehanimation folgen der tatsächlich erreichten Position.

Die Eltern, Sextus und andere feste Gesprächs-/Dienstorte werden nicht durch
die neue Simulation versetzt. `VillageLife.actor_position` und die sichtbaren
Körper behalten dadurch denselben Ort und dieselbe Interaktionsreichweite.
Diese Personen können Arbeit unterbrechen, sich zu einem Gespräch oder zur
Gefahr drehen und um Abstand bitten. Ihre Anzeige behauptet keine Flucht,
solange sie am festen Anker bleiben.

Der neue Vertrag besitzt keine Befehle für Geld, Gegenstände, Gesundheit,
Questfortschritt oder Schaden. Er benutzt die vorhandene Beziehung als Quelle;
Bedürfnisse erzeugen keine zusätzlichen Belohnungen. Pausen ändern die
Verfügbarkeit vorhandener Arbeiter, nicht deren Zahl oder Besitz.

## Persistenz und Anbindung

`prototype/scripts/domain/npc_behavior.gd` besitzt `village.behavior`, Version 1.
Gespeichert werden Bedürfnisse, aktuelle Absicht samt Grund, Entscheidungszeiten,
letzter Gruß, zuletzt beobachtetes Vertrauen, Gesprächspartner, tatsächliche
Position, Routenfortschritt und -richtung sowie höchstens vier belegte Erinnerungen.
Die Profile und der ID-Katalog werden unveränderlich zwischengespeichert.

`WorldModel.npc_observations` liest vor Simulation und Speicherung die vorhandenen
Weltkörper aus. `village_population.gd` und `village_life_world.gd` liefern nur
Beobachtungen ihrer sichtbaren Personen. Fehlende, unbekannte oder ungültige
Beobachtungen erzeugen keine neuen Figuren. Beim Laden wird eine vorhandene
physische Position wiederhergestellt; nur eine tatsächliche Belegung kann einen
kleinen sicheren Ausgleich beim Platzieren verlangen.

Neue römische Kindheitsspiele aktivieren den Vertrag. Bestehende Kindheitssaves
ohne diesen Bereich werden beim Laden ergänzt, ohne Alter, Aufgaben, Familie,
Vorräte oder Weltzeit zurückzusetzen. Ein vorhandener beschädigter Bereich wird
streng abgewiesen. Ältere Lebensläufe ohne Kindheitsabschnitt behalten ihre
bisherige Simulation. Die äußere Save-Version bleibt fünf.

`view(data, id)` liefert die sichtbaren Felder `activity_label`, `reason`,
`interest_label`, `mood_label` und `greeting`. Der UI-Anschluss bewahrt die
vorhandenen Storytexte, Entscheidungen und Verfügbarkeitsregeln.

## Tatsächlich geprüfter Umfang

| Prüfung | Ergebnis |
| --- | --- |
| `npc_behavior_test.gd` | 77 Prüfungen bestanden: Bedürfnisse, echte Arbeitsabwesenheit und Rückkehr, Nähe, Gesellschaft, Gefahr, Wetter, deterministische Tickteilung, Speichern/Laden, Migration und Ablehnung beschädigter Daten. |
| `npc_behavior_world_test.gd` | 30 Prüfungen bestanden: Raider-Anschluss mit tatsächlichem Meshy-Rig und animiertem Fuß, echte Wege, Rückkehr zur Arbeit, Stillstand, Platzmachen, feste Questorte, Beobachtungen, Positions-/Routenwiederherstellung, Wandblockierung und Pause. |
| Vorhandenes `village_economy_test.gd` | 189 Prüfungen bestanden. |
| Vorhandenes `village_model_test.gd` | 227 Prüfungen bestanden. |

Die Prüfungen wurden mit der vorhandenen Godot-4.7.2-Engine ausgeführt. Die
Positionsprüfung benutzt die produktiven Weltkörper und Kollisionen unter
Headless-Betrieb. Sie ist kein grafischer Qualitäts-, Android-FPS- oder
Temperaturnachweis. Save-Vergleiche prüfen jeden Zustand, bei JSON-Fließkommazahlen
mit einer Toleranz kleiner als 10⁻⁹.

## Konkrete Grenzen

Die Wege sind noch vorgegeben; freie Navigation durch beliebige neue Innenräume
oder eine große Stadt ist damit nicht implementiert. Feste Storypersonen bleiben
an ihren notwendigen Ankern. Ihre Entscheidungen betreffen Tätigkeit und
Aufmerksamkeit. Die Dialogreaktionen sind verfasste, zustandsabhängige Texte.
Die Figuren führen keine beliebigen sprachlichen Planungen aus und besitzen
keine unabhängige persönliche Geldbörse. Die vier Erinnerungen sind beobachtete
Gefahren- und Vertrauensänderungen, keine vollständige Lebensbiografie.
