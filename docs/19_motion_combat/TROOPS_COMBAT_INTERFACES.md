# Truppen, Kampfwert und Soldatenleben: Schnittstellen

Stand: 26. November 2026, Branch `feat/troops-command-core-20261126` (PR #100). Setzt D-041, D-042 und D-043 um. Alle Zahlen sind Designwerte und stehen in den genannten Datendateien, nicht im Code.

Was hier „geprüft“ heißt, ist durch die Headless-Tests `troop_catalog`, `combat_formula`, `battle_command` und `battle_rules` belegt. Nichts davon ist auf einem Gerät gemessen.

## 1. Militärische Möglichkeiten einer Gemeinschaft (D-041)

Germanische Gruppen sind nicht pauschal gleich. Was eine Gemeinschaft aufstellen kann, folgt aus ihrem Wohlstand, ihrem Handel, ihren Rohstoffen und ihrer Entwicklung.

```gdscript
const Catalog := preload("res://scripts/battle/troop_catalog.gd")
var options := Catalog.military_options(Catalog.load_default(), profile)
```

Die Funktion ist rein: Sie liest nur den Katalog und das übergebene Profil. Sie kennt die Stammeswelt nicht, und `tribal_world.gd` wurde nicht geändert.

### Profil (Eingabe)

| Feld | Typ | Bedeutung | Quelle in der Stammeswelt (`bc58_rhine`) |
|---|---|---|---|
| `culture` | Text | Katalogkultur, oder mit `system` die Kennung des fremden Systems | `group.culture`, z. B. `germanic_rhine` |
| `system` | Text, optional | `"tribal_world"`: `culture` wird über `military_options.cultures` übersetzt | fest |
| `year` | ganze Zahl, kein Jahr 0 | Jahr der Aufstellung | Weltzeit |
| `wealth` | Zahl ≥ 0 | Wohlstand | `group.stock.wealth` |
| `trade` | 0–1 | Handelsneigung | `traits(state, gid).trade` |
| `trade_partners` | Zahl ≥ 0 | laufende Handelsbeziehungen | aktive Abkommen `trade_pact`, `guest_friendship`, `amicitia` |
| `population` | Zahl ≥ 0 | Einwohner | Summe der `settlements[].population` |
| `materials` | `{id: Menge}` | Rohstoffe | `group.stock` (`iron`, `wood`, `horse`, `ore` …) |
| `development` | `{id: Anzahl}` | Bauten als Maß der Entwicklung | Summe der `settlements[].buildings` (`smithy`, `hall` …) |

Fehlende Felder zählen als 0. Unbekannte Felder, negative oder nicht endliche Werte, eine unbekannte Kultur oder ein Jahr ohne Truppen ergeben `{ok: false, error, troops: {}}`.

### Ergebnis

```
{ok, culture, year,
 equipment_cap, training_cap,        # höchste erreichbare Stufe (ids aus tiers)
 next: {equipment: [...], training: [...]},   # was zur nächsten Stufe fehlt
 troops: {troop_id: {available, missing: [...], max_share, rarity, external_ids}}}
```

- Angeboten werden nur eigene Truppen der Kultur (`service: own`), keine Verbände in römischem Dienst.
- `missing` nennt je Truppe die unerfüllten Voraussetzungen im Klartext, z. B. `materials.iron 2/10`.
- `max_share` ist der höchste Anteil am Aufgebot. Die Funktion nennt ihn nur; einhalten muss ihn, wer das Aufgebot zusammenstellt. Bogenschützen bleiben bei 5 % und tragen `rarity: rare`; Speerwerfer sind regulär (35 %).
- `external_ids.tribal_world` nennt die Truppenarten der Stammeswelt: `aufgebot` → `germanic_civil_levy`, `plaenkler` → `germanic_skirmisher`, `speerkrieger` → `germanic_levy`, `axtkrieger` → `germanic_axe_shield`, `schwertkaempfer` und `gefolgsmann` → `germanic_retainer`, `reiter` → `germanic_rider`. `band_rider` (Reiter offener Herkunft, D-040) hat bewusst keine Zuordnung.
- `Catalog.capped_tiers(catalog, options, troop_id, choice)` begrenzt die Stufen eines Verbands auf die Obergrenzen der Gemeinschaft.

Die Voraussetzungen stehen in `prototype/assets/troops/troops.json`: je Truppe `requires` und `max_share`, die Obergrenzen unter `military_options.equipment_caps` und `training_caps`.

### Stufen eines Verbands

Drei unabhängige Stufen (`tiers` in `troops.json`), im Szenario je Kompanie wählbar:

| Schlüssel | Stufen | Wirkung |
|---|---|---|
| `experience` | rekrut, ausgebildet, erfahren, veteran, elite | Fertigkeit und Erfahrungspunkte neuer Soldaten |
| `equipment` | aermlich (Q0) bis meisterlich (Q4) | Qualität der ausgegebenen Gegenstände |
| `training` | ungeuebt, geuebt, gedrillt | verschiebt die Drillstufen um −1, 0, +1 |

Ohne Angabe gelten die Vorgaben der Truppe. `kit_quality` (Qualität echter Gegenstände) hat Vorrang vor der Ausrüstungsstufe.

### Speerwerfer als Gefechtsart

`battle_kind: "skirmisher"` wirft Wurfspeersalven: Reichweite 9 m, Takt 7 Schritte (`ranged.throw_javelin` in `combat_balance.json`), drei Speere je Mann (`loadout.missile.count`). Danach kämpft der Verband mit Speer und Schild. Die Kompanie `ridge_bows` des Prüfstands ist jetzt ein Speerwerferverband (Szenario `valley_58bc_v2`); Spielstände des ersten Prüfstands behalten ihre Bogner.

Offen für die Formationsseite: `troop_motion.gd` und `formation_agents.gd` (`_role()`) kennen `skirmisher` noch nicht und fallen auf schwere Infanterie zurück. `valley_scene.gd` zeigt Speerwerfer vorläufig mit der Rolle `spear`; ein eigener Wurfclip fehlt, der Wurf nutzt die Angriffspose.

## 2. Kampfwertformel (D-042, Handbuch S. 79)

```
Schaden = Waffenbasis × Qualität × Kompetenz × Trefferzone × Schutzfaktor × Kontakt
```

- Code: `prototype/scripts/battle/combat_formula.gd`. Parameter: `prototype/assets/balance/combat_balance.json`.
- Ebene A (Nahkampf, `feat/melee-combat-core-20261126`) ruft `Formula.resolve_hit(hit)` je Schlag auf, Ebenen B und C (`battle_model.gd`) `Formula.unit_strike(strike)` je Schlagintervall eines Verbands.
- Jeder Faktor entsteht an genau einer Stelle und wird auf `clamps` begrenzt. Ausdauer und Verletzungen wirken nur in der Kompetenz, Waffenverschleiß nur in der Qualität, Rüstung, Schild, Schildstellung und Schildfertigkeit nur im Schutz, der tatsächliche Kontaktzeitpunkt nur im Kontakt.
- `Formula.INPUT_FACTORS` und `UNIT_INPUT_FACTORS` zählen auf, welche Eingabe welchen Faktor bewegen darf. Der Test verändert jede Eingabe einzeln und prüft, dass sich nur die genannten Faktoren ändern und der Schaden exakt das Produkt der ausgewiesenen Faktoren ist.
- Geprüft: Ein Veteran mit gewöhnlicher Ausrüstung (Q1) schlägt einen Neuling mit guter Ausrüstung (Q4) in 48 von 48 Zweikämpfen; als Verbände gewinnen Veteranen Q1 gegen Rekruten Q4 in 6 von 6 Gefechten. Zwischen gleich Ausgebildeten gewinnt die bessere Ausrüstung.

### Anschlüsse

Kein System darf einen eigenen Multiplikator auf den Schaden legen. Jedes liefert Eingaben der Formel:

| System | Liefert | Feld | Faktor |
|---|---|---|---|
| Shops, Handwerk | Qualität eines Gegenstands (0–4) | `weapon.quality`, `armor[zone].quality`, `shield.quality`; für Verbände `kit_quality` oder Stufe `equipment` | Qualität, Schutz |
| Inventar | Gegenstandsfamilie und Zustand | `weapon.family`, `weapon.wear`, `armor[zone].wear`, `shield.wear` | Waffenbasis, Qualität, Schutz |
| Handwerk (Reparatur) | setzt `wear` zurück | wie oben; die Formel gibt den neuen Verschleiß in `wear{weapon, shield, armor}` zurück, der Aufrufer bucht ihn | Qualität, Schutz |
| Fähigkeiten, Ausbildung | Fertigkeit 0–100 | `attacker.skill`, `defender.skill`; für Verbände die Fertigkeiten der Soldaten | Kompetenz, Schutz |
| Ernennungen | Befehlsrechte und Aufstieg, keine Schadenswerte | `commandable_by`, `Catalog.plan_upgrade()` / `apply_upgrade()` mit `authorities` und `inventory` | – |
| Zustand der Person | Ausdauer, Verletzungen | `attacker.stamina`, `attacker.injuries` | Kompetenz |

Aufstiege verbrauchen Gegenstände aus dem Inventar: `apply_upgrade()` gibt `inventory` (Rest) und `consumed` zurück. Eine Ernennung wirkt nur über die Befehlsberechtigung und über die Truppe, zu der sie aufsteigen lässt.

## 3. Soldatenleben (D-043)

Jeder Soldat ist eine Person (`soldier_roster.gd`). Neu im Datensatz, Speicherschema 4:

| Feld | Inhalt | Im Gefecht |
|---|---|---|
| `rank` | `miles`, `signifer`, `deputy`, `commander` | unveränderlich |
| `trust` | Vertrauen in die Führung, 0–100 | ändert sich |
| `family` | `{household, dependants, standing, craft}` | unveränderlich |
| `campaigns` | Kennungen gemeinsamer Feldzüge | unveränderlich |

Spielstände bis Schema 3 erhalten die Felder beim Laden aus der Musterung desselben Soldaten. Ein Spielstand kann Rang, Familie und Herkunft nicht umschreiben.

Im Gefecht (`battle_model.gd`):

- Rettung: Fällt ein Soldat verwundet aus, trägt ihn sein engster Kamerad in den Reihen (Bindung ≥ 50) mit 60 % heraus. Beide Datensätze erhalten einen Diensteintrag (`rescued`, `rescued_comrade`), die Bindung steigt beidseitig um 15, die Genesung verkürzt sich um ein Fünftel.
- Vertrauen: gerettet +5, Retter +2, verlorener Kamerad −2, Flucht des Verbands −8.

Zwischen den Gefechten (`soldier_life.gd`, reine Funktionen auf Kopien):

| Funktion | Wirkung |
|---|---|
| `Life.close_campaign(records, {id, year, outcome})` | Überlebende merken sich den Feldzug, rücken zusammen (+5, Fremde ab 20), Vertrauen ±6 nach Ausgang |
| `Life.friends(record)` | Kameraden mit Bindung ≥ 60 |
| `Life.shared_campaigns(a, b)` | gemeinsame Feldzüge |
| `Life.leave_reason(record)`, `Life.leave(record, year)` | Vertrauen unter 20: der Soldat verlässt das Heer (Status `left`) |
| `Life.promote(record, to_rank, year)` | Beförderung in den nächsten Rang, verlangt Erfahrung, Disziplin und Vertrauen |
| `Roster.recover(record, days, year)` | Genesung, unverändert |

### Ereignisse für die Siedlungen

```gdscript
var events := Life.settlement_events(before, after, {"year": year, "stamp": stamp})
var battle := model.settlement_events()        # Verwundete und Tote dieses Gefechts
var muster := model.settlement_events(true)    # Rekrutierung
```

`settlement_events` vergleicht zwei Datensatzlisten und meldet je Zustandswechsel genau ein Ereignis. `stamp` benennt den Zeitpunkt (Gefechtsschritt, Welttag).

```
{id, type, uid, name, year, stamp, group_id, place,
 household, dependants, standing, craft, troop_id, rank, detail, effects}
```

| `type` | Auslöser | `effects` (Vorschlag) |
|---|---|---|
| `recruited` | neu im Heer | `workers −1, away +1` |
| `wounded` | aktiv → verwundet | `wounded +1` |
| `recovered` | verwundet → aktiv | `wounded −1` |
| `died` | → tot | `population −1, away −1, bereaved_households +1, dependants_without_provider n` (nach Verwundung zusätzlich `wounded −1`) |
| `retired` | verwundet → ausgeschieden | `workers +1, away −1, impaired +1, wounded −1` |
| `left` | → Austritt | `workers +1, away −1` |
| `promoted` | höherer Rang | – |

Vertrag für den gemeinsamen Weltzustand (D-045):

- Das Modul hält keinen Zustand und bucht nichts. Die Wirkung auf die Siedlung bucht der Weltzustand.
- `id` ist `uid:type:stamp`. Wer die verbuchten Kennungen behält, bucht bei wiederholtem Aufruf nichts doppelt.
- `effects` zählt Personen, keine Güter. Über Rekrutierung, Verwundung und Ausscheiden summieren sich `workers`, `away` und `wounded` zu null (geprüft).
- Tote bleiben tot: `recover()`, `leave()` und `promote()` ändern sie nicht.
- Noch nicht verdrahtet: Der Weltzustand ruft diese Ereignisse bisher nicht ab. Die Siedlungen reagieren also noch nicht sichtbar.

## 4. `soldiers(id)` für die Darstellung

Jeder Eintrag: `{id, x, z, facing, pose, rank, slot, appearance_seed, military_rank}`.

- `slot` ist der Platz in der Formation: `{index, rank, file}`. `index` ist die Position im Layout von `FormationSlots.layout()` und zugleich in `uids` und `members`. `rank` zählt von vorn (0 = vorderste Reihe, im Orbis der äußere Ring), `file` von links in Blickrichtung des Verbands. `rank` auf oberster Ebene wiederholt `slot.rank`.
- Das Modell ordnet die Soldaten beim Ausrichten laufend den Plätzen neu zu. Verluste wählt es nach der Tiefe aus Sicht des Angreifers. Eine Darstellung, die einen Mann in einer anderen Reihe zeigt als `slot.rank`, zeigt deshalb Verluste an der falschen Stelle. Die Formationsseite verteilt Positionen nur innerhalb der gemeldeten Reihe.
- `military_rank` ist der Dienstrang der Person, nicht die Reihe.
- Erscheinung: `Roster.visual_variant(appearance_seed, military_rank, n)` wählt eine von `n` Varianten. Ranginhaber erhalten Variante 0, die Mannschaft verteilt sich nach `appearance_seed`. Ein Soldat behält sein Aussehen, wenn die Reihen aufrücken. `valley_scene.gd` nutzt das statt `i % 3`. Derzeit gibt es nur drei Farbtöne; eigene Modelle je Rang liefert das Kriegerfamilien-Paket.
