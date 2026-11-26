# Stammeswelt am Rhein · Simulationskern

Stand 26.11.2026, Branch `feat/germanic-tribes-ai-20261126`. Dieses Dokument beschreibt, was gebaut und geprüft ist, wie es an das Dorfleben angeschlossen wird und welche Entscheidungen beim Eigentümer liegen. Es ersetzt keinen Spieltest; die Simulation ist eine aggregierte Fernebene ohne eigene Grafik.

## 1. Umfang

| Teil | Datei | Status |
|---|---|---|
| Akteurgenerischer Beziehungs- und Erinnerungskern (Gruppen und Personen) | `prototype/scripts/domain/actor_relations.gd` | gebaut, getestet |
| Wöchentliche Simulation, Ledger, Truppen, Personen, Diplomatie, Kriegszüge, Anker | `prototype/scripts/domain/tribal_world.gd` | gebaut, getestet |
| Szenario 58 v. Chr. am Rhein (Daten, Quellen, Kanonmarker) | `prototype/assets/world/tribes/bc58_rhine.json` | gebaut |
| Speichervertrag v6, Migration v5→v6, Kalenderanschluss | `prototype/scripts/domain/world_model.gd` | gebaut, getestet |
| Strategieatlas: Siedlungen, Stärkeklasse, Haltungen aus denselben Daten | `prototype/scripts/strategy/atlas_screen.gd`, `globe.gd` | gebaut, getestet |
| Tests | `prototype/tests/tribal_world_test.gd`, `tribal_save_test.gd`, `tribal_atlas_test.gd` | Gruppen `tribal_world`, `tribal_save`, `tribal_atlas` |
| Anschluss an `village_life.gd` (Überfälle, I-10) | — | Plan in Abschnitt 8, nicht verdrahtet |
| Germanische Siedlungsgrafik | — | Plan in Abschnitt 11, nicht gebaut |

## 2. Zeitmodell und Takt

Ein Simulationsschritt ist **eine Kalenderwoche**. Das Spieljahr hat 52 Wochen, jede Jahreszeit 13 Wochen und beginnt im März. Es gibt kein Jahr 0: Auf 1 v. Chr. folgt 1 n. Chr. (`TribalWorld.year_of`).

Das Spiel besitzt keine einheitliche Uhr. `world_seconds` mischt Dorfsekunden (ein Kindheitstag dauert 3600 s, ein älterer Dorftag 120 s) mit Strategiesprüngen von `YEAR_SECONDS/4`. Die Stammeswelt liest deshalb nicht `world_seconds`, sondern bildet den Kalendertag aus den vorhandenen, autoritativen Zählern:

```
Kalendertag = village.economy.day + progress.years_elapsed · 364 + (strategy.turn mod 4) · 91 + tribes.extra_days
```

`extra_days` nehmen Reise, Schlaf oder Warten außerhalb der Dorfuhr auf (`WorldModel.pass_calendar_days(days, reason)`). Begründung der Woche gegenüber Alternativen:

- Eine Jahreszeit der Strategiekarte entspricht genau 13 Schritten; Karte und Welt bleiben deckungsgleich.
- Bauvorhaben (2–6 Wochen), Ernte (Wochen 22–31), Fristen (Waffenruhe 26, Tribut alle 13 Wochen) und Kriegszüge (Reise 1–2 Wochen) lassen sich ohne künstliche Stückelung abbilden.
- 400 Schritte umfassen 58–51 v. Chr., also Band I samt Übergang zu Band II.
- Tages- oder Bildschritte hätten bei gleicher Aussage die siebenfache bzw. geräteabhängige Last erzeugt.

Der Kalendertag steht im Weltmodell hinter genau einer Funktion, `WorldModel.calendar_day(state)` (D-045). Der gemeinsame Weltkalender aus #98 ersetzt nur deren Inhalt.

### Bildbudget (D-046)

Eine Woche wird nicht mehr in einem Bild gerechnet. `WorldModel._pump_tribes` arbeitet je Bild höchstens `TRIBE_UNITS_PER_FRAME = 6` Arbeitseinheiten ab:

1. Kopie des angenommenen Stammeszustands in Scheiben (Grundteil, Personen, Chronik, Ledger, Beziehungen zu je 48 Kanten).
2. Die Woche in der Reihenfolge des bisherigen Ticks: Anker, Kriegszüge, Wirtschaft je eine Gruppe, Vereinbarungen, Führung, Nachrichten, Entscheidungsgrundlage, Entscheidung je eine Gemeinschaft, Abklingen je 96 Kanten, Abschluss.
3. Vollständige Validierung in Scheiben (Kopf, Kriegszüge, je Gruppe, Personen, Ziele, Beziehungen zu je 24 Kanten, Vereinbarungen, Chronik, Streitfälle).
4. Erst dann wird der neue Zustand atomar übernommen und als geprüft vermerkt; es folgt keine zweite Vollprüfung im selben Bild.

Jede Scheibe hat feste Kosten (`TribalWorld.UNITS`, kalibriert auf etwa 0,25 ms je Einheit beim 95. Perzentil der Scheibe auf dem Entwicklungsrechner); keine Scheibe kostet mehr als das Bildbudget. Eine Woche kostet 118–132 Einheiten, also etwa 20 Bilder. `tick()` selbst läuft über dieselben Scheiben, daher sind gescheibte und durchgerechnete Wochen bitgleich (Test).

Speichern während einer laufenden Woche: Gespeichert wird immer die zuletzt übernommene Woche. Die halbfertige Woche wird verworfen und nach dem Laden deterministisch neu gerechnet; das Ergebnis ist bitgleich mit einem ununterbrochenen Lauf (Test `tribal_save`). Ändert sich der angenommene Stammeszustand während eines Auftrags (Raidergebnis, Reisetage), beginnt die Woche neu. `pump_tribes()` dient Menüs, die die Welt anhalten (Atlas über `tribes_pump`); `finish_tribes()` dient Tests und Ladebildschirmen.

## 3. Zustand (`data.tribes`)

`version, scenario, seed, rng, tick, extra_days, next_id, groups, persons, targets, relations, agreements, expeditions, events, ledger, flows, opening, intel, anchors, raid_windows, story, stats, visits`

- **Gruppe** (`groups[actor_id]`, Art `tribe`, `band` oder `market`): Kanonmarker, Quelle, Status (`active`, `departed`, `left_area`, `dispersed`), Anführer (Personen-ID), Herrschaftsform und gegebenenfalls Heerführer, Familien, Grundeigenschaften (Kühnheit, Vorsicht, Stolz, Handel, Treue), Ziele, Reichweite, bis zu drei Siedlungen (Lage, Bevölkerung, Felder, Raseneisenerz, Gebäude, Schaden), freie Siedlungsplätze, Bestand (`stock`), getragene Ausrüstung (`held`), Truppen, Moral, Bauvorhaben, Restbeträge, Geschichte.
- **Truppen** je Typ: `count`, `xp`, `gear`. Typen (Kulturbaum `germanic_rhine`): Aufgebot der Höfe mit gemischter Ausrüstung (Speer, Wurfspeere, Axt oder unbewaffnet; je Mann höchstens eine Waffe), Speerkrieger (framea und Schild), Plänkler, seltene erfahrene Schwertkämpfer (höchstens 5 %), Axtkämpfer als rekonstruierte Variante (höchstens 3 %), Reiter, Gefolgsleute. Aufwertungen verlangen Erfahrung, Ausrüstung aus dem Bestand und für die Gefolgschaft eine Halle; der Mann behält passende Teile und gibt übrige zurück.
- **Personen** (`persons`): Anführer, Erbe, Rivale je Gruppe sowie **jeder Gefolgsmann einzeln** (Name, Familie, Geburtswoche, Eigenschaften, Ansehen, Aufenthalt `with`, Taten, Schicksal). Gefallene werden nicht ersetzt; neue Gefolgsleute sind neue Personen. Tote und Fortgezogene bleiben zwei Jahre erhalten und werden dann samt Beziehungen entfernt.
- **Ziele** (`targets`): Valdora, Spielfigur, Rom, Handelshaus mit dem roten Siegel. Ihre Güter gehören nicht in dieses Ledger.
- **Beziehungen** (`relations`, Abschnitt 5), **Vereinbarungen** (Abschnitt 6), **Kriegszüge** (`expeditions` mit Truppen, Beute als `cargo`, Status `outbound`/`arrived`/`returning`).
- **Wissen** (`intel`): Was eine Gruppe zuletzt über eine andere beobachtet oder erzählt bekommen hat (Stärke, Verteidigung, Vorräte, Zeitpunkt). Entscheidungen lesen dieses Wissen, nicht die Wahrheit.

## 4. Ledger und Wirtschaft

Jede Mengenänderung läuft über `_book` mit Transaktions-ID, Konto (`stock`, `held`, `cargo`), Kategorie (`produce`, `consume`, `destroy`, `transfer_in/out`, `external_in/out`, interne Umbuchung `move`), Grund und Gegenpartei. Transfers zwischen Gruppen haben eine gemeinsame Transaktions-ID. Validierung je Gruppe und Gut:

```
stock + held + cargo = Eröffnung + Zuflüsse − Abflüsse,  held = Ausrüstung aller Truppen,  Bevölkerung = Eröffnung + Geburten/Zuzug − Tod/Abzug
```

Wirtschaft je Woche: Feldarbeit nach Jahreszeit (Anteil und Ertrag datengetrieben), Milch, Kalben, Herbstschlachtung, Notschlachtung, Holz und Raseneisenerz bis zu Arbeitsbeständen, Rennofen und Schmiede (Eisen, Speere, Wurfspeere, Äxte, Klingen), Schilde, Fohlen, Rationen, Verderb (mit Speicherbau weniger), Geburten, Sterbefälle, Hunger, Abwanderung bei Wohnungsmangel. Krieger kommen aus der Bevölkerung, arbeiten zu Hause halb, auswärts gar nicht. Die Gefolgschaft erhält Geschenke in Wertgütern oder Rindern; ohne Geschenke sinkt die Moral und Gefolgsleute gehen. Händler aus Gallien bringen je Jahreszeit begrenzte Waren und nehmen Gekauftes mit (keine unendlichen Bestände).

Bauvorhaben verbrauchen Arbeit und Material anteilig über mehrere Wochen und wirken erst nach Fertigstellung (Wohnraum, Lager, Schmiedekapazität, Verteidigung, Gefolgschaftsraum, Frühwarnung, neue Siedlung, Reparatur). Ein Vorhaben ohne Fortschritt über 26 Wochen wird aufgegeben.

## 5. Beziehungen und Wissen (akteurgenerisch)

`actor_relations.gd` ist unabhängig von Stämmen. Eine Kante `beobachter>subjekt` existiert nur, wenn der Beobachter den anderen kennt. Dimensionen: Vertrauen, Furcht, Groll, Verpflichtung, Respekt, Loyalität, Neid, je mit Grenzen, wöchentlichem Abklingen zur Basis und bis zu acht Erinnerungen mit Ereignis-ID. Änderungen nur über `apply()` mit Ereignis-ID. Dieselbe API trägt Gruppen, Anführer, Gefolgsleute und später Marcus und andere NPCs.

Wissen breitet sich aus: Verbreitbare Ereignisse (Überfall, gebrochener Eid, Einigung, Anführerwechsel, Anker) erreichen Nachbarn nur über Gruppen, denen der Erzähler vertraut, eine Woche je Station. Dritte reagieren erst beim Erfahren (Freund des Opfers grollt dem Angreifer, Eidbruch kostet Vertrauen). Neue Gruppen werden über Partner bekannt. Die Rheingruppen kennen Valdora und die Reiter bei Aquileia nicht; Beweise führen erst über `reveal()` zu Wissen.

## 6. Vereinbarungen

Waffenruhe (26 Wochen), Bündnis (52), Tribut (52, Fälligkeit alle 13 Wochen), Handelsbund (52), Gastfreundschaft (156), Auftrag (Storybindung), Freundschaft mit Rom (Anker). Jede Vereinbarung ist ein Datensatz mit Frist, Bedingungen, Zahlungsstand und Ausgang (`kept`, `broken`, `expired`, `void`, `fulfilled`).

- Eingehalten bis zur Frist: Vertrauen und Respekt steigen, freundliche Partner erneuern.
- Gebrochen (Überfall unter Frieden, unbezahlter Tribut, ausbleibende Bündnishilfe): Vertrauen und Groll ändern sich beim Opfer, die Nachricht verbreitet sich, der Preis beim Handel steigt (`trade_terms`), der Zugang kann wegfallen. Ein Strafzug folgt nur, wenn schon ein Streit mit erlaubtem Anlass besteht (D-048). Einen Tribut nimmt nur an, wer ihn aus dem eigenen Bestand zweimal zahlen kann.
- Ein Kriegszug, der zwischen frisch Geeinten unterwegs ist, kehrt um.

## 6a. Konfliktanlässe (D-048, D-049)

Kein Überfall, keine Fehde und kein Feldzug ohne gebuchten Anlass. Das Streitregister (`disputes`) hält Anlass, Quelle, Beginn, Ende und Richtung:

| Anlass | Entsteht durch |
|---|---|
| `quest_dispute` | Mission oder Quest über `open_dispute()`; I-10 trägt `mission:I-10` |
| `natural_enemy` | Roster: Sueben ↔ Ubier (BG 4,3; 4,16), Sueben ↔ Usipeter/Tenkterer (BG 4,1), Eichenhang ↔ Ravensteg (Design, fiktiv) |
| `alliance_call` | Bündnispartner angegriffen oder in der Verteidigung |
| `retaliation` | Antwort auf einen solchen Konflikt; ein gebrochener Tribut verlängert nur einen bestehenden Streit |
| `conquest` | klarer Sieg innerhalb eines Streits; endet mit vereinbartem Tribut |
| `need` | Hunger, Mangel oder strategische Not beim Ausbau, gebucht mit Anlass (Hungerstufe, Vorratswochen, fehlende Güter, Charakter des Anführers, Vertrauen zum Ziel) |

Ob Not zu Handel, Abwanderung, Verhandlung oder Überfall führt, entscheidet der Nutzenvergleich nach Lage, Charakter und Beziehung; Freunde auszurauben kostet Vertrauen. Überlegenheit allein ist kein Anlass. Jeder Kriegszug und jedes Konfliktereignis speichert Anlass, Streit-ID und Quelle; die Validierung lehnt Konfliktereignisse ohne erlaubten Anlass ab. Eine eingehaltene Waffenruhe beendet Fehden zwischen den Partnern; die natürliche Feindschaft bleibt.

## 6b. Herrschaftsformen (D-044)

| Form | Gruppen | Wirkung |
|---|---|---|
| Versammlung | Ubier, Händler, Reiter | Ansehen und Herkunft entscheiden; Rivale kann gewinnen |
| Erbliches Häuptlingtum | Sugambrer, Ravensteg (Erbin Swanahild) | Erbe der Familie folgt; Herausforderungen schwerer |
| Ältestenrat | Eichenhang | Alter und Besonnenheit zählen; der Rat mäßigt den Anführer |
| Gewählter Heerführer | Sueben, Usipeter/Tenkterer | im Krieg Wahl eines Heerführers für 26 Wochen (Caesar BG 6,23), dessen Charakter wiegt dann schwerer; ein siegreicher Heerführer kann die Führung anstreben |

Nur die Heerführerregel stützt sich auf eine Quelle; die anderen Zuordnungen sind Spielannahmen. Langfristig wachsen Gruppen über Siedlungsgröße (Weiler, Dorf, Großsiedlung), Handelsbünde, Bündnisse und Tributnehmer zu Handelsgemeinschaften oder Machtzentren; der Atlas zeigt dieses Profil.

## 6c. Verborgene Wahrheit (D-040)

Die etwa dreißig Reiter für I-10 sind keinem Volk und keinem Stamm zugeordnet. Ihr Auftraggeber steht nur im Zustand (verdeckter Auftrag, `hidden`). `observed_facts(state, akteur)` und `chronicle(state, n, akteur)` liefern nur, was der Akteur gesehen oder erzählt bekommen hat. `planned_raids` zeigt für die Reiter weder Auftrag noch Auftraggeber. Erst `reveal()` (Beweis, Zeuge) schafft Wissen; das Ermittlungs- und Zeugensystem baut der Agent auf `feat/raid-conspiracy-investigation-20261126`.

## 6d. Regionale Völker um Aquileia (Vorbereitung)

`prototype/assets/world/tribes/regional_candidates_aquileia.json` enthält Karner, Histrer, Taurisker/Noriker, Iapyden und Veneter als **ungeprüfte Kandidaten**. Jeder Eintrag hat Prüfaufträge (Quellenstellen) und offene Fragen, aber keine Zahlen und keine behaupteten Ereignisse; nichts davon wird simuliert, bevor es geprüft und freigegeben ist. Kulturen, Kriegerbäume und Namen sind im Szenarioformat bereits je Kultur angelegt.

## 7. Entscheidungen

Jede aktive Gemeinschaft wählt pro Woche eine Hauptentscheidung (Reihenfolge rotiert, alle lesen die Lage vom Wochenbeginn): bauen oder gründen oder reparieren, handeln, überfallen, verteidigen/üben, verhandeln (Waffenruhe, Bündnis, Tribut, Handelsbund, Gastfreundschaft), schenken, Fest (mit Gast), Rückzug (Zuflucht, Rückruf, Flucht aus zerstörter Siedlung) oder gewöhnliche Arbeitswoche. Der Nutzen folgt aus Bedürfnissen (Hunger, Wohnraum, Land, Wertgüter), Gelegenheit (geschätzte Beute, Kräfteverhältnis aus Wissen), Beziehungen (Groll, Furcht, Vereinbarungen), Erfahrung (Kriegszüge ohne Beute im letzten Jahr schwächen den nächsten Entschluss), Jahreszeit und Charakter (Gruppe 60 %, Anführer 40 %). Ein kleiner geseedeter Zufallsanteil bricht Gleichstände. Eigenschaften verschieben sich langsam durch Erfahrungen. Anführer altern, sterben, werden von der Versammlung gewählt oder von einem ehrgeizigen Rivalen bei Unruhe abgelöst.

## 8. Überfall-API und Integrationsplan für `village_life.gd`

Funktionen (alle in `TribalWorld`, Zustand = `data.tribes`):

| Funktion | Wirkung |
|---|---|
| `planned_raids(tribes, "valdora")` | rein lesend: je Gruppe Status (`planned`, `no_intent`, `blocked`, `en_route`, `arrived`, `returning`, `commissioned`), Grund, tatsächlich verfügbare Krieger nach Typ, Stärke, Motiv, Nutzen, frühester Tick und Kalendertag, Entfernung |
| `raid_allowed(tribes, target)` | Erholungs- oder Storysperre mit Ende |
| `commit_raid(tribes, gid, target)` | startet einen geplanten Zug mit echten Männern |
| `arrived_raids(tribes, target)` | angekommene Züge, die auf die lokale Szene warten |
| `story_raid(tribes, "I-10")`, `commit_story_raid(tribes, "I-10")` | geschützter Storyüberfall der 30 Reiter |
| `apply_raid_result(tribes, expedition_id, {outcome, attacker_losses, loot, defender_casualties, damage})` | Verluste, Beute, Auftragszahlung, Beziehungen, Erholungsfenster |
| `report_target_state(tribes, target, defenders, rebuilt)` | Verteidigung und Wiederaufbau des Dorfes melden |
| `set_story_lock(tribes, target, until_tick, reason)` | Schutzfenster für Storyabschnitte |
| `writable(world)` | Kopie vor jeder Änderung innerhalb einer Weltmodell-Transaktion |

Anschlussstellen in `prototype/scripts/story/village_life.gd` (Stand Basis `ffbe3ad`; der Raid-Agent ändert die Datei parallel, Zeilen daher nach dessen Merge prüfen):

1. **Zeitgeber ersetzen** (`_tick`, Z. 344): statt `social.seconds >= raid.next_at` → `var waiting := TribalWorld.arrived_raids(data.tribes, "valdora")`; nur wenn ein nicht geschützter Zug wartet und `raid_allowed` frei ist, `_begin_warning(data)` und die Expeditions-ID in `raid` vermerken (neues Feld, Validierung Z. 696 anpassen). `RAID_INTERVAL` entfällt.
2. **Angreiferzahl** (`_begin_raid`, Z. 528): `_enemy_count(raid.number)` ersetzen durch `mini(6, warriors_total)` volle Kampf-KIs; der Rest ist sichtbare Masse wie heute.
3. **Ergebnis zurückmelden** (`_finish_raid`, Z. 554, und `_resolve_hidden_childhood_raid`, Z. 533): `TribalWorld.apply_raid_result(TribalWorld.writable(data), id, {"outcome": outcome, "attacker_losses": gefallene volle KIs, "loot": {"grain": raid.stolen}, "defender_casualties": …, "damage": …})`. Getreide wird mit 10 Rationen je Dorfeinheit gebucht (`EXTERNAL_GOODS`), Denare mit 0,25 Wertgütern; der Dorfledger bleibt führend.
4. **I-10** (`_apply`, Z. 120–135, Befehle `village_childhood_begin_raid`, `i10_defend`, `i10_hide`): vor `_begin_warning(data, true)` → `TribalWorld.commit_story_raid(TribalWorld.writable(data), "I-10")`. Das Drehbuch bestimmt Ablauf, Opfer und Familienpfade; die Simulation liefert nur die konsistente Gruppe (30 Reiter mit Pferden, Speer, Schild) und bucht das gemeldete Ergebnis. Danach sperrt sie Valdora 26 Wochen für jeden weiteren Zug (Wiederaufbau I-13 bis I-16).
5. **Verteidigung melden**: am Ende jedes Dorftags oder nach `_finish_raid` → `report_target_state(writable(data), "valdora", VillageLife.defense_strength(data), rebuilt)`.
6. **Atlas** (`main.gd` `_open_atlas`, nach `atlas.data = …`): `atlas.tribes = model.data.tribes if not demo else {}` und `atlas.tribes_pump = func(): return model.pump_tribes()` (nicht im Demo). Solange der Atlas die Welt anhält, rechnet er so die Wochen einer Jahreszeit im Bildbudget nach und zeigt „noch N Wochen werden berechnet“.
7. **Streit aus Quests** (D-048): Missionen melden Streitigkeiten mit `TribalWorld.open_dispute(writable(data), a, b, "quest_dispute", "quest:<id>", Notiz, Wochen)` und beenden sie mit `close_dispute`.

Endlose Überfallserien verhindert das Modell selbst: eigene Abklingzeit des Angreifers (6 Wochen), Erholungsfenster des Ziels (6–26 Wochen je nach Schaden und Verlusten, beim Storyüberfall 26), Umkehr vor einem gerade geplünderten Ziel, Lerneffekt nach erfolglosen Zügen, Kosten (Proviant, Arbeitskraft, Gefallene), Abschwächung bei Frieden.

Ein angekommener Zug wartet zwei Wochen auf die lokale Szene. Ist der Spieler nicht im Dorf, kehrt er ohne Zusammenstoß um; das Modell erfindet keine Dorfverluste.

## 9. Epochen und Anker

Inhalte tragen `from_year`/`to_year`. Datierte Anker mit Quelle und Größenmarker (`documented` oder `game_interpretation`) laufen zu ihrer Woche, wenn ihre Voraussetzungen erfüllt sind, sonst wird `divergent` vermerkt: Ariovists Niederlage (Herbst 58), Übergang der Usipeter und Tenkterer (Winter 56/55), deren Reiterei zu den Sugambrern (55), Rheinbrücke, Freundschaft Ubier–Rom, Verwüstung bei den Sugambrern (55), zweiter Rheinübergang (53), Ansiedlung der Ubier links des Rheins (38). Bandzeiträume I 58–52, II 51–47, III 47–44, IV 44–27 v. Chr. (`band_of`).

## 10. Gemessene Ergebnisse (dieser Rechner, headless)

Die Zahlen stammen aus den Testläufen dieses Branches; sie sind keine Gerätemessung.

- `tribal_world`: 147 Prüfungen bestanden, `tribal_save`: 24, `tribal_atlas`: 29.
- Determinismus: gleicher Seed → identischer Zustand nach 200 Wochen; Speichern und Laden nach Woche 100 → bitgleiche Fortsetzung. Godots JSON überträgt nur korrekt gerundete Dezimalzahlen exakt; alle gespeicherten Bruchwerte werden deshalb auf vier Dezimalen gerundet.
- Ledger: vollständige Wiederholung aller Buchungen über 200 Wochen ergibt jeden Bestand, jede getragene Ausrüstung und jede Bevölkerungszahl; jeder Transfer hat genau Sender und Empfänger.
- 400 Wochen, Seeds 1, 2026, 58: gültig, keine Gemeinschaft unter 30 % oder über 200 % der Anfangsbevölkerung, keine gegenseitige Feindschaft länger als drei Jahre, höchstens 12 Überfälle je Gruppe und Jahr (gemessen: 7–16 Überfälle der ganzen Region in 400 Wochen, Seeds 1/2026/58), Erholungsfrist eingehalten, Frieden, Handel und Bau finden statt.
- Kosten einer ganzen Woche: 6–15 ms Rechnen und 6–16 ms Vollvalidierung, stark abhängig von der Last der parallel laufenden Agenten. Seit D-046 werden beide in Scheiben über etwa 20 Bilder verteilt.
- Bildbudget (Entwicklungsrechner, headless, 4 Kerne bei Last 6–8, nur relativ, keine Gerätemessung): je Bild höchstens 6 Einheiten (Test, keine Uhrzeit). Gemessene Bildzeiten über 52 Wochen Aufholen: p50 0,58–0,79 ms, p95 1,8–2,7 ms, p99 2,7–5,5 ms, Maximum 3,6–7,4 ms. Die Ausreißer entstehen durch Verdrängung auf dem überlasteten Rechner. Minimum je Scheibe aus drei gleichen Läufen: p95 1,36 ms je Bild. Die größten regulären Scheiben sind Nachrichten (bis 1,9 ms), Entscheidung und Führung (bis 1,3 ms). Ein Maximum von 2 ms ist auf diesem Rechner nicht belegbar; die Messung auf einem ruhigen Rechner und auf dem Fold7 steht aus.
- Konfliktanlässe: 3 × 400 Wochen ohne Konfliktereignis ohne erlaubten Anlass (40 Konfliktereignisse); eine satte Welt ohne Streit bleibt ein halbes Jahr ohne Kriegszug; ein Hungerzug bucht `need` mit Anlass.

## 11. Germanische Siedlungen · Grafik- und LOD-Plan (späteres Paket)

Qualitätsmaßstab ist die Lesbarkeit und Dichte, die der Eigentümer mit Assassin's Creed Valhalla verbindet; keine Übernahme von Modellen, Texturen, Layouts oder Namen.

1. **Baukasten aus den Simulationsdaten**: Wohnstallhaus (dreischiffig, Pfostenreihen, Wohn- und Stallteil, Lehm-Flechtwerk, Reet), Speicherbau (Pfostenspeicher), Grubenhaus für Handwerk, Schmiede mit Rennofen, Halle, Palisade mit Graben, Warte. Jede Instanz entspricht einem Gebäudezähler; Schaden steuert verkohlte und reparierte Varianten.
2. **Siedlungsplan**: Hofgruppen mit Zäunen, Wegen, Feldern und Weiden; Anzahl der Höfe aus `longhouse`, Felder aus `fields`, Herdengröße aus Rindern; neue Siedlungen erscheinen an den Plätzen aus den Daten.
3. **LOD**: L0 begehbar (≤ 150 m, echte Kollision, Innenräume nur für Halle, Schmiede, ein Wohnhaus), L1 vereinfachte Hüllen und Instanzen (150–600 m), L2 Atlas-/Impostor-Silhouetten mit Rauchsäulen (600 m–3 km), L3 Kartenpin. Personen: Gefolgsleute und Anführer als benannte Akteure, Aufgebot als Gruppen mit Ausrüstung aus `gear`.
4. **Fold7-Budget**: messen, nicht versprechen; Zielwerte für eine Siedlung im Bild (Draw Calls, Dreiecke, Texturspeicher) werden mit dem vorhandenen `fold7_quality_policy.gd`-Rahmen festgelegt.
5. **Quellen und Prüfung**: Rekonstruktionen eisenzeitlicher Höfe (z. B. Freilichtmuseen) als Referenz mit Herkunftsnachweis; Fachprüfung vor Produktion.

## 12. Drei Zeithorizonte (Beispiele)

| Ereignis | Sofort | Später | Langfristig |
|---|---|---|---|
| Sugambrer plündern Ravensteg | Beute, Gefallene, Schaden, Moral | Erholungsfenster, Groll des Opfers, Nachricht an Freunde | Tribut oder Bündnis mit den Ubiern, Charakter wird vorsichtiger |
| Tribut nicht bezahlt | Bruch, Vertrauensverlust | Strafzug, höhere Preise | Abhängigkeit oder Loslösung, neue Allianzen |
| Anführer stirbt | Versammlung wählt | Erbe oder Rivale prägt Entscheidungen | anderer Wirtschafts- und Kriegspfad |
| I-10 | 30 Reiter greifen an, Ergebnis aus der Szene | Sperre bis zum Wiederaufbau, Valdora erinnert die Täter | Beweise (I-15) führen zum Auftraggeber |
| Spieler hilft einer Gruppe | Vertrauen dieser Gruppe | Nachricht an deren Partner | Zugang, Vermittlung, Beitritt |

## 13. Datenmodell und Plan für noch nicht gebaute Erweiterungen

- **NPC-Persönlichkeiten (nächstes Paket)**: Marcus und andere als `persons` mit `traits` (Ehrgeiz, Loyalität, Neid, Furcht), Kanten im selben Graphen, Tagesentscheidungen außerhalb der Szene über denselben Nutzenrahmen; der Dorf-Personenkatalog (`npc_behavior.gd`) bleibt die Quelle der IDs.
- **Dynastien (später)**: Personen besitzen bereits Familie, Geburtswoche, Rolle und Nachfolge. Ergänzung: `parents`, `spouse`, `lineage`; keine Schemaänderung der übrigen Felder nötig.
- **Rom als handelnder Akteur**: derzeit nur Anker. Plan: Legionen und Lager als Gruppen der Art `power` mit eigenem Ledger.
- **Gallische Gemeinschaften links des Rheins** (Treverer u. a.) als weitere Akteure; Ethnie bestimmt dabei keine Loyalität.
- **Begehbare Materialisierung**: `visit_report`/`mark_visited` liefern bereits die Ledger-Deltas seit dem letzten Besuch.
- **Schlacht- und Befehlssystem**: verbraucht dieselben Truppenstapel (`count`, `xp`, `gear`, Gefolgsleute als Personen).

## 14. Offene Eigentümerentscheidungen

1. **Valdora liegt laut Drehbuch bei Aquileia** (`campaign_arc.json`), rund 600–700 km vom Rhein. Die Rheingruppen erreichen Valdora deshalb nicht (`out_of_reach`). Wer Valdora überfällt, legt das Drehbuch fest; I-08 verbietet, vorschnell ein Volk zu benennen. Umgesetzt ist eine fiktive Reitergruppe ohne Herkunft mit einem verborgenen Auftrag des Handelshauses mit dem roten Siegel (I-15/I-20), ohne Personen oder Schuld festzulegen. Bitte bestätigen oder ändern.
2. **Kalenderanzeige**: `season_campaign.gd` schreibt fest `100 + turn/4` n. Chr.; der Atlas zeigt in einer Kindheitspartie deshalb oben ein anderes Jahr als die Stammeslage (58 v. Chr.). Die Strategiekarte gehört nicht zu diesem Paket.
3. **Ältere Laufbahnen um 100 n. Chr.** erhalten keine Gruppenaufstellung (`scenario: none`). Für eine Rheingrenze um 100 n. Chr. wären andere Gruppen zu belegen (die Ubier lebten dann links des Rheins).
4. **Wirkungsgrößen der Anker** (Schaden, Furcht) sind Spielannahmen; die Ereignisse selbst sind belegt.
5. **Weibliche Erbin** in Ravensteg ist eine fiktive Entscheidung für eine fiktive Gemeinschaft; für belegte Völker sind Anführer männlich angelegt.
6. **Kriegslast**: Nach D-048/D-049 erzeugt die Region in 400 Wochen 6–7 Überfälle (Plünderung, Abwehr und Gefecht gemischt), dazu 55–75 Tauschgeschäfte und 41–57 eingehaltene Vereinbarungen (Seeds 1/2026/58). Es gibt keine erzwungene Zahl; Missionen und Quests sollen Konflikte anstoßen. Die Dichte bewertet der Spieltest.

## 15. Risiken

- Schema v6 berührt Tests anderer Pakete (sechs Prüfungen auf `schema_version == 5` wurden auf `SCHEMA_VERSION` umgestellt); ein paralleler Branch mit eigener Schemaanhebung muss die Migrationskette zusammenführen.
- Leistung auf dem Fold7 ist nicht gemessen; der Catch-up ist auf 2 Wochen je Bild begrenzt.
- Die Balance (Ertrag, Geburten, Überfallnutzen) ist nur gegen Stabilitätskriterien geprüft, nicht gegen Spielspaß.
- Die fixen Bezugstexte in `village_life.gd` ändern sich parallel; die Zeilenangaben in Abschnitt 8 sind vor dem Anschluss zu prüfen.
- Stammeszustand v2 (Herrschaftsformen, Streitregister): `TribalWorld.migrate()` hebt Stände des ersten #99-Builds an. Dabei kehren Kriegszüge ohne gebuchten Anlass heim, und alte Konfliktereignisse werden als `legacy` (vor D-048) markiert.
- `writable()` für Raidergebnisse kopiert den ganzen Zustand in einem Bild (etwa 5 ms auf dem Entwicklungsrechner). Das geschieht einmal je gemeldetem Überfall und lässt sich später auf denselben Scheibenmechanismus umstellen.
