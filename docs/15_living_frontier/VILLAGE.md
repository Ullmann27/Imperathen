# Valdora – Wohnviertel, Arbeitswege und Begegnungen

**23. November 2026 · Arbeitszweig `feature/living-frontier-20261123`**

Das italienische Grenzdorf erhält einen nördlichen Wohnbereich, eine östliche
Handelsstraße und einen südlichen Fuhrhof. Der bisherige Spielweg mit Marcus,
Holzvorräten, Werkstatt, Übungsplatz und eigener Baufläche bleibt erreichbar.
Die Erweiterung verwendet die vorhandenen echten Architektur-GLBs und neue
in Godot erzeugte, maßstäbliche Ausstattungsgeometrie. Sie behauptet keine neue
fotorealistische Gebäudeproduktion und keine gemessene Android-Leistung.

## Tatsächlich implementierte Umgebung

- **13 Wohnhäuser** statt vier im italienischen Einstieg, zusätzlich zum
  bestehenden Atrium, Markt, Brunnen, Lager und der Werkstatt. Die Häuser
  besitzen einzelne Haushaltskennungen, unterschiedliche Putzfarben und
  orientierte Türen. Die Texturen, Normalkarten und Wandkollisionen bleiben
  erhalten; gemeinsam genutzte Originalmaterialien werden nicht verändert.
- Ein durchgehender Straßenbelag verbindet Nordviertel, Oststraße und Fuhrhof.
  Das Terrain verwendet weiterhin eine einzige zusammenhängende Oberfläche.
  Häuser und neue Straßen werden bei der Platzierung von Bäumen, Steinen und
  Zierpflanzen freigehalten.
- Die alte nördliche Palisade ist für die Dorferweiterung geöffnet. Eine äußere
  Schutzlinie besitzt offene Nord-, Süd-, West- und Ostzugänge. Die bisherige
  südliche Einfriedung der persönlichen Baufläche bleibt erhalten.
- Ein Vorratswagen mit vier Rädern, Speichen, Achsen, Ladung und Deichseln
  steht bei Titus. Ein Schreibtisch mit Rollen und Schreibtafel gehört zu
  Cassian. Ergänzt sind ein östlicher Marktstand, Töpferwaren, Bänke,
  Küchenbeete, trocknende Tücher und ein südlicher Straßenstein.
- Die Stadtansicht lässt sich bis in die neuen Viertel verschieben. Die
  öffentlichen Wege und Einrichtungen verbrauchen keine Spielerressourcen
  und erzeugen keine heimliche Wirtschaftsproduktion.

Die Baufläche `x=5..24, z=-4..13`, bestehende Hüttenkosten und Bauzeiten,
Marcus bei `(-3,4)` sowie der Übungsplatz bei `(0,-7)` sind unverändert.
Die 13 neuen Hausinstanzen gehören zur bestehenden Siedlung, nicht zum
Eigentum des Spielers. Andere Herkünfte behalten ihre vier regionalen Häuser
und erhalten keine römischen Bewohner oder römischen Handlungsfiguren.

## Bewohner und Verhaltensumfang

**18 namentliche Bewohner** ergänzen die bestehenden Haupt- und
Gefährtenfiguren. Vier bleiben an ihren jeweiligen Gesprächs- und Arbeitsorten;
14 nutzen feste, geprüfte Wege mit Arbeits-, Geh- und Ruhephasen. Reihenfolge,
Geschwindigkeit, Pausen und Aussehen sind an stabile Kennungen gebunden.
Es gibt keine bei jedem Laden neu gewürfelten Personen.

| Kennung | Name | Tätigkeit | Verhalten |
| --- | --- | --- | --- |
| `livia` | Livia | Händlerin | Stationär bei `(-14,4)` |
| `cassian` | Cassian | Schreiber | Stationär bei `(14,-22)` |
| `aulus` | Aulus | Veteran | Stationär bei `(4,-25)` |
| `titus` | Titus | Wagenführer | Stationär bei `(3,24)` |
| `flavia` | Flavia | Bäckerin | Haus und alter Markt |
| `marius` | Marius | Zimmermann | Werkstatt und Marktbereich |
| `sabina` | Sabina | Tuchhändlerin | Östlicher Markt |
| `gaius` | Gaius | Töpfer | Nördlicher Handwerksbereich |
| `nerva` | Nerva | Schmied | Oststraße |
| `priscilla` | Priscilla | Heilerin | Nördliche Gasse und Veteran |
| `octavia` | Octavia | Weinbäuerin | Nordviertel und Oststraße |
| `publius` | Publius | Bote | Hauptstraße, am Übungsziel vorbei |
| `lucius` | Lucius | Straßenwache | Nordzugang |
| `sergius` | Sergius | Torwache | Südöstlicher Zugang |
| `rufina` | Rufina | Korbmacherin | Südlicher Außenbereich |
| `marcellus` | Marcellus | Lagerarbeiter | Nordöstlicher Versorgungsweg |
| `tullia` | Tullia | Weberin | Oststraße |
| `domitius` | Domitius | Feldarbeiter | Feldrand |

Die Figuren nutzen `VillagePerson.configure_appearance(id, variation)` aus der
parallelen Figurenlieferung: `civilian_man`, `civilian_woman`, `elder`,
`legionary` und `officer`. Ohne diese optionale Methode bleibt die vorhandene
Figurenroute verwendbar. Die endgültige Modell- und Materialqualität muss
anhand der zugehörigen tatsächlichen Exporte und Aufnahmen bewertet werden.

Die Einwohner sind eine begrenzte Ortsdarstellung, keine vollständige
Bevölkerungs- oder Tagesablaufsimulation. Ihr Ablauf verwendet gespeicherte
`world_seconds`; die kurze Wiederholung ist nicht als realer Tag ausgegeben.
Der vorhandene Personalbestand des Regelkerns bleibt maßgeblich. Bei
Rekrutierung verschwinden Marius, Marcellus und Domitius der Reihe nach aus
ihren Zivilrollen. Damit erscheinen diese Arbeitskräfte nicht gleichzeitig
im Wachtrupp und bei der Dorfarbeit. Verlustzahlen bleiben im bestehenden
Regelkern; es wird kein zweites Personenkonto geführt.

## Gespräche, Kamera und Pause

In der Nähe erscheint höchstens ein Bewohnername. Interaktion benötigt
höchstens drei Meter Entfernung und eine freie Sichtlinie. Ein Passant
übernimmt nicht allein wegen einer minimalen Abstandsdifferenz ein Gespräch
mit einer stationären Person. Nahe gewöhnliche Bewohner bleiben ansprechbar.
Ihre Begrüßungen geben keine Ressourcen oder Erfolge.

`focus_frontier_npc(id)` richtet eine nähere Kamera auf den Bewohner und lässt
rechts Platz für die Gesprächsfläche. Ein Kollisionsstrahl verhindert eine
Kameraposition hinter der nächsten Wand. `clear_frontier_focus()` gibt die
normale Kamera wieder frei. Auf der Dialogkamera kann ein Standbild gleiten,
ohne Weltzeit, Ressourcen oder Bewohnerwege fortzusetzen.

Die Arbeit am Wagen wird nur als Animation gezeigt, wenn der vorhandene
Regelkern `frontier.step == 2`, `preparation == "work"`, noch nicht zwölf
Arbeitssekunden und die Nähe zu Titus meldet. Die Dorfansicht erhöht weder
den Fortschritt noch die Vorräte. Erst die Domain entscheidet darüber.

## Reproduktion

Die normalen Godot-Importe müssen zuvor abgeschlossen sein. Danach:

```sh
godot --headless --path prototype --script res://scripts/world/world_smoke.gd
godot --headless --path prototype --script res://tests/frontier_population_test.gd
```

Am 23. November wurden im lokalen Godot 4.7.2 tatsächlich ausgeführt:

- `WORLD_SMOKE_PASS`: vorhandene Tastatur-/Touchbewegung, Bauplatz,
  Wandkollisionen, Kamerawechsel, Pause und Interaktionsabläufe bestanden.
- `FRONTIER_POPULATION_OK: 659 checks`: reale Szeneninstanzen,
  eindeutige Bewohner, freie Baufläche, alle vier Qualitätsprofile,
  Wiederherstellung aus der gemeinsamen Zeit, Pause, vier erreichbare
  Storypersonen, links eingerahmte Gesprächspartner, Rekrutendarstellung und
  Erhalt anderer Herkünfte bestanden.
- Ein erheblicher Teil der neuen Prüfung bewegt einen echten
  `CapsuleShape3D`-Prüfkörper in höchstens 45-cm-Schritten entlang aller
  Bewohnerwege durch die tatsächliche Physikwelt. Eine zunächst die alte
  südliche Palisade berührende Route von Rufina wurde vor dem grünen Lauf
  verlegt.

Die genannten Prüfungen sind echte Engine- und Kollisionsprüfungen mit
Headless-Ausgabe. Sie ersetzen keine visuelle Abnahme, keine Android-Ausführung
und keinen Lauf auf einem physischen Fold7. Die gemeinsame Integration liefert
dafür jeweils gesonderte Nachweise.

## Dateien und Herkunft

- `prototype/scripts/world/village/village_layout.gd`: Haushalte, Bewohner,
  Wege und gemeinsame räumliche Hilfsfunktionen.
- `prototype/scripts/world/village/village_population.gd`: Darstellung,
  Routinen, Nähe, Gesprächsfokus und Rekrutendarstellung.
- `prototype/scripts/world/village/frontier_dressing.gd`: eigene geometrische
  Ausstattungen. Keine zusätzlichen Fremdmodelle oder kostenpflichtigen Dienste.
- `prototype/scripts/world/regional_village.gd`: Architekturinstanzen und
  Materialvarianten; bestehende Architekturquelle in `art/architecture`.
- `prototype/scripts/world/village/ground.gdshader` und
  `village_scenery.gd`: durchgehende Wege und freigehaltene Vegetation.
- `prototype/scripts/world/game_world.gd`: Spielwelt-, Eingabe-, Kamera- und
  Animationsintegration.
- `prototype/tests/frontier_population_test.gd`: ausführbare Prüfsuite.
