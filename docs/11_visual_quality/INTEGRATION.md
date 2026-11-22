# Grafikpaket: Importvertrag

Stand: 22. November 2026. Eigener Grafikbeitrag zum aktuellen Entwicklungsauftrag;
Koordination in [Issue #18](https://github.com/Ullmann27/Imperathen/issues/18),
angeschlossen an [Team #16](https://github.com/Ullmann27/Imperathen/issues/16) und
[Team #17](https://github.com/Ullmann27/Imperathen/issues/17).

## Zweck und Abgrenzung

Das Paket stellt wiederverwendbare Architektur und Figuren sowie eine visuelle
Prüfszene bereit. Der Godot-Funktionsprototyp und die separate Einstiegsvorschau
behalten ihre vorhandenen Zustands-, Interaktions- und Speicherschnittstellen.
**Android ist die Hauptplattform.** Eine PC-Fassung wird lediglich vorbereitet;
der Wunsch nach dem Erscheinungsbild eines modernen PC-Spiels ist ein
Grafikziel für das Android-Spiel. Die endgültige Produktionsengine ist durch
diesen Beitrag nicht festgelegt.

Die Exportdateien liegen unter `art/visual_benchmark/assets/`, die reproduzierbare
Erzeugung und statische Prüfung unter `tools/art/`. Tatsächliche Aufnahmen der
Prüfszene werden unter `art/visual_benchmark/evidence/` abgelegt. Eine Aufnahme
eines Modells beweist noch keine Integration in die Spielschleife.

## Modelle und Koordinaten

| Stabile ID | Rolle | Bezug |
| --- | --- | --- |
| `frontier_house` | Unterkunft als detaillierter Architekturbaustein | B03, B04 |
| `house_foundation` | Früher sichtbarer Bauzustand der Unterkunft | B04 |
| `village_well` | Orientierungs- und Detailobjekt im Dorf | B03 |
| `civilian_youth` | Junge Zivilfigur für Größen-, Silhouetten- und Materialprüfung | B03 |
| `frontier_guard` | Erwachsene Wachfigur als zweite erkennbare Rolle | B03 |

Ein Meter im Modell entspricht einem Meter in der Szene. In Blender ist Z oben
und die definierte Vorderseite zeigt nach −Y. Der glTF-Export konvertiert zu
Y oben und Vorderseite +Z. Der Ursprung liegt am Boden des Modells. Die in den
GLB-Dateien gespeicherten Transformationen sind zu erhalten; eine zusätzliche
Achsenkorrektur beim Import darf nicht blind aufgeschlagen werden.

`dimensions_m_xyz` im Prüfbericht bezeichnet die aus tatsächlich decodierten,
transformierten Vertices ermittelte Ausdehnung der Standardszene. Y ist dort die
Höhe. Die Maße sind keine behaupteten historischen Originalmaße. Ein sichtbarer
Bauzustand allein implementiert weder Ressourcenabbuchung noch Baufortschritt.

## Materialien und Daten

- GLB-Dateien müssen ohne Nachladen externer Pfade importierbar sein. Bilder und
  Meshdaten werden eingebettet, nicht über lokale Absolute-Pfade referenziert.
- glTF-Materialien verwenden Metallic/Roughness-PBR. Konstante Materialien sind
  für geeignete Teile zulässig. Holz, Stein, Putz und Stoff werden visuell auf
  erkennbare Oberflächenstruktur und sinnvollen Maßstab geprüft.
- Ein texturiertes Material benötigt die von seinen Textur-Slots referenzierten
  UV-Kanäle, normalerweise `TEXCOORD_0`. Das bloße Vorhandensein eines Bildes
  beweist keine erfolgreiche Materialzuweisung.
- Jede primitive Geometrie benötigt Normalen und eine positive Anzahl gültiger
  Dreiecke. Exportiert wird unkomprimierte Dreiecksgeometrie. Draco/Meshopt und
  weitere erforderliche, im Prüfer nicht unterstützte Erweiterungen gehören
  nicht zu diesem Importvertrag.
- Exportdateien werden über SHA-256 identifiziert. Die statische Prüfung ersetzt
  keine Bildprüfung im Zielrenderer und keinen vollständigen Khronos-Validator.

Für `frontier_house` und `village_well` gehört mindestens ein wirklich zugewiesenes
PBR-Material mit Basecolor- und Normaltextur zur visuellen Zielabnahme. Das ist
eine Anforderung an diese Architekturassets, keine Pflicht für jede Primitive
oder für reine Metall-/Hautmaterialien. Der allgemeine GLB-Prüfer meldet fehlende
Texturverwendung als Warnung; ein separater Assetmanifest-Abgleich muss die
rollenspezifische Anforderung ergänzen.

## Android-Qualitätsstufen und Budgets

Alle Stufen erhalten dieselben Gebäude, Figurenrollen, Bau-/Interaktionsregeln,
Speicherstände und sichtbaren Spielinformationen. Zuerst sinken rein kosmetische
Details: Dekorationsdichte, ferne Geometriedetails, Schatten und zusätzliche
Effekte. Ein Qualitätswechsel darf das Kernerlebnis nicht ändern.

Die ausführbare Quelle ist
[`quality_profiles.json`](../../art/visual_benchmark/quality_profiles.json).
Der aktuelle Stand schaltet folgende Werte:

| Parameter | Niedrig | Ausgewogen, Standard | Hoch |
| --- | ---: | ---: | ---: |
| Zielbudget für interne 3D-Pixel | 921.600 | 2.073.600 | 3.686.400 |
| Entsprechung bei 16:9 | 1280×720 | 1920×1080 | 2560×1440 |
| MSAA | aus | 2× | 4× |
| Schattenatlas | 1024 | 2048 | 4096 |
| Schattenentfernung | 24 m | 48 m | 85 m |
| Mesh-LOD-Schwelle | 3,0 | 1,5 | 0,65 |
| Sichtbarer Anteil der Grasdekoration | 22 % | 60 % | 100 % |
| Glow im Mobile-Renderer | aus | aus | ein |

Die Pixelzahl wird anhand der tatsächlichen Ausgabefläche unter Beibehaltung
ihres Seitenverhältnisses berechnet. Kleinere Ausgaben werden nicht künstlich
hochgerechnet. Auf einem Fold bleibt das ausgewogene Zielbudget ebenfalls bei
ungefähr **2,07 Millionen 3D-Pixeln**; es gibt keine starre Vorschrift, dass eine
Seite immer 1080 Pixel haben muss. Beispielsweise entspricht dieses Budget bei
quadratischem Seitenverhältnis 1440×1440. UI und Schrift werden separat in der
Ausgabeauflösung dargestellt.

Die Profile wechseln derzeit keine Texturdateien und erzwingen keine festen
Dreiecks-, Drawcall- oder Speichergrenzen. Sie verändern die LOD-Schwelle der
importierten Meshes und den sichtbaren Anteil dekorativer Grasinstanzen.
Die Importkonfiguration aktiviert die Erzeugung von Mesh-LODs. Wie viele
Dreiecke und Renderdurchgänge dadurch tatsächlich entfallen, ist im Renderer
und später auf Android zu messen. Der allgemeine Dateiprüfer liefert dafür
die Ausgangsgeometrie und Quellenbildgrößen.

Primitiveinstanzen sind ausdrücklich keine gemessenen Drawcalls. Batching,
Instancing, Schatten und zusätzliche Renderdurchgänge verändern die tatsächlichen
Einreichungen. Die Textursumme berücksichtigt noch keine GPU-Kompression,
Mipmap-Ketten, Renderziele oder Treiberbelegung. Aus diesen Ausgangswerten allein
folgt weder Ruckeln noch Spielbarkeit. Auf Android zusätzlich CPU/GPU-Zeit,
belegten Speicher und längere thermische Belastung messen, bevor eine Stufe als
gerätegeeignet bezeichnet wird.

Das Projekt fordert zunächst Godots Mobile-Renderer an und erlaubt einen
OpenGL-Kompatibilitätsfallback. Im aktuellen Controller bleibt Glow im
Kompatibilitätsrenderer ausgeschaltet. Unterschiede zwischen Renderern sind
zu dokumentieren; ein Kompatibilitätsbild beweist nicht die vollständige
Mobile-Darstellung. Profilwerte sind keine Zusage für Bildrate, Energieaufnahme
oder Temperatur eines bestimmten Chips.

## Anschluss an Team #17: Godot

Die Modelle zunächst in einen eigenen Asset-Unterordner des Prototyps übernehmen
und den tatsächlichen Import dokumentieren. Die vorhandenen Nodes für Bewegung,
Interaktion, Auswahl, Kollision und Spielstand bleiben die funktionalen Eigentümer.
Das Grafikmodell wird als sichtbares Kind eines solchen Nodes eingebunden.

Bei der Unterkunft Eingang, Bodenhöhe und Laufwege mit der aktuellen
Spielerkollision abgleichen. Ein detailliertes sichtbares Mesh ist keine geeignete
automatische Komplettkollision. Vereinfachte Körper und tatsächlich freie Zugänge
sind im Funktionsprototyp zu prüfen. `house_foundation` und `frontier_house` müssen
am selben vom Spielzustand verwalteten Bauplatz umgeschaltet werden.

Bei Figuren sind Modell, Bewegungscontroller und Animationssystem getrennte
Lieferbestandteile. Vorhandene sichtbare Körperteile oder Posen belegen kein
fertiges Rig. Animationen, Gewichtung, Gang, Interaktionsposen und Clipping werden
erst nach einem tatsächlichen Test als geprüft markiert.

## Anschluss an Team #16: Einstieg und spätere PC-Vorbereitung

Die Einstiegsvorschau darf geprüfte Aufnahmen des Grafikpakets verwenden. Als
Bild verwendete Szenen sind entsprechend zu bezeichnen; sie belegen keine
interaktive 3D-Darstellung im Browser. Vorhandene Menü-, Fokus- und
Speicherschnittstellen bleiben unberührt.

Ein späterer Unreal-Import benötigt einen tatsächlichen Lauf in der vorgesehenen
Unreal-Version. Materialübersetzung, Maße, Schatten, LOD, Kollisionen und der
Animationspfad sind dabei erneut zu prüfen. Solange diese Prüfung fehlt, lautet
der Status ausdrücklich **Unreal-Import nicht nachgewiesen**. Die separate
PC-Vorbereitung darf den Android-Hauptpfad nicht blockieren oder stillschweigend
ersetzen.

## Bildreferenzen und Abnahme

Die IDs beziehen sich auf den vorhandenen
[Referenzindex](../09_sources/VISUAL_REFERENCE_INDEX.md):

| Referenz | Zu prüfender Zweck | Sichtbare Mindestmerkmale |
| --- | --- | --- |
| B02, Hauptmenü | Lesbarer Einstieg mit räumlichem Hintergrund | Titel und Bedienflächen bleiben lesbar; Licht lenkt den Blick; Kulisse überdeckt keine Eingaben |
| B03, Junge und Dorf | Glaubwürdiger menschlicher Maßstab | Erkennbare Hände/Füße/Kopf, klare Figurenrollen, begehbar wirkender Eingang, erkennbare Konstruktion, Bodenkontakt |
| B04, freier Städtebau | Lesbare Architektur aus Nah- und Fernsicht | Dach/Wand/Fundament unterscheidbar; Bauzustände erkennbar; Weganschluss frei; Details brechen in mittlerer Distanz nicht vollständig weg |

Die gesamte Szene wird zusätzlich auf Silhouette, Materialunterschiede,
Kontaktschatten, überstrahlte Flächen, Wiederholungsmuster, schwebende Objekte und
Schnittflächen geprüft. Verbindliche visuelle Abnahme erfordert echte Bilder aus
dem verwendeten Renderer. Ein Konzeptbild oder erfolgreicher Dateiexport reicht
dafür nicht.

## Herkunft und offene Punkte

Die neuen Modelle entstehen als originale prozedurale Geometrie dieses
Projektbeitrags. Verwendete Bild-/Materialquellen und Erzeugungsschritte werden bei
den tatsächlichen Dateien dokumentiert. B02/B03/B04 dienen als vom Nutzer
bereitgestellte Bildreferenzen; ihre Produktionsrechte werden dadurch nicht
pauschal bestätigt. Die Projektlizenz ist weiterhin nicht festgelegt. Es wird
keine neue Open-Source-Lizenz oder fremde Rechtefreigabe behauptet.

Die Übergabe muss tatsächliche Prüfläufe von offenen Aufgaben trennen. Ohne
gesonderten Lauf bleiben insbesondere vollständige Rig-/Animationsabnahme,
Spielintegration, Android-Geräteprüfung, Unreal-Import, GPU-Speicherbedarf und FPS offen. Ein statischer
GLB-Pass ist nur der Nachweis des beschriebenen Dateivertrags.
