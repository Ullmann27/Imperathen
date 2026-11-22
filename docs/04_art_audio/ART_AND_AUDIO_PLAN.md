# Grafik-, Asset- und Audioplan

**Status: Produktionsvorbereitung, keine neu erstellten Modelle oder Renderings.**

## Bildsprache

Glaubwürdige menschliche Maßstäbe, handwerklich nachvollziehbare Gebäude, erkennbare Wege und realistische Gebrauchsspuren bilden das Ziel. Die ältere Mappe schlägt Stein, Holz, Leder, Bronze und gedeckte Farben für eine römisch inspirierte Grenzregion vor. Das ist eine Stilrichtung; die konkrete Epoche und Ausrüstung benötigen noch eine eigene Referenzentscheidung. Historische Aussagen werden mit passenden Quellen überprüft, bevor sie als authentisch beworben werden.

Die vorhandenen 13 Konzeptgrafiken bilden Start, Menü, Dorf, Stadtbau, Verwaltung, Karte, Nahkampf, Kommando, Massenschlacht und Belagerungsfolgen ab. Sie bleiben Referenzen unter ihrem ursprünglichen Titel. Bildschrift, angezeigte Truppenmengen und Bildraten sind keine Spezifikation. Die [Bildübersicht](../09_sources/VISUAL_REFERENCE_INDEX.md) ordnet jedes Motiv einer Funktion zu.

## Stufen einer späteren Assetproduktion

| Stufe | Ergebnis | Abnahme |
| --- | --- | --- |
| A0: Funktionsbedarf | Rolle, Maße, Kollision, Interaktion und Kameradistanz beschrieben | Funktion und nötige Varianten klar |
| A1: Einfaches Raummodell | Primitive Geometrie mit korrekter Größe | Laufwege, Gebäudezugang und Lesbarkeit funktionieren |
| A2: Spielbares Basisasset | Mesh, Kollision, einfache Materialien, nötige Animation | In einem echten Build nutzbar |
| A3: Detailliertes Asset | Material, Textur, Varianten, Detailstufen | Grafikziel innerhalb gemessenen Speicher-/Zeitbudgets |
| A4: Produktionsfreigabe | Herkunft, Version, Export, Rechte und Einsatz dokumentiert | Reproduzierbar importiert und geprüft |

Keine hochauflösende Massenproduktion vor dem Funktionsnachweis. Blender-Dateien entstehen später aus einem beschriebenen Arbeitspaket und einer tatsächlich verfügbaren Installation. Ein ausgeführtes Blender-Skript ist noch kein geprüftes spielbares Asset.

## Modularität und Figuren

Gemeinsame Körper-/Animationsgrundlagen, kombinierbare Köpfe, Frisuren und Ausrüstung reduzieren den Umfang. Der Nutzer hält etwa 20–40 Grundvarianten langfristig für ausreichend; das ist kein Bedarf des ersten kleinen Tests. Anfangs werden nur die tatsächlich nötigen Rollen mit einfachen Varianten geplant. Modularität muss erkennbare Truppenarten, Materialkosten, Tragepunkte, Clipping und Animationen berücksichtigen. Unterschiedliche Gesichter lösen keine CPU-, Wegfindungs- oder Kollisionskosten großer Armeen.

Für Gebäude entstehen wiederverwendbare Teile mit konsistenten Maßen: Fundament, Wand, Dach, Tür, Anschluss an Wege, beschädigte Zustände und Baustadien. Baugrund und Spielfunktion bestimmen die Form. Eine zerstörte Mauer bleibt beschädigt, auch wenn ein anderer Darstellungsmodus geladen wird.

## Animation, Effekte und Audio

Jede Interaktion braucht eine minimale glaubwürdige Rückmeldung: Sammeln, Tragen, Bauen, Befehlen, Blocken, Treffen, Verletzung, Rückzug. Animationsabbruch und Zustandswechsel sind wichtiger als eine große Menge dekorativer Clips. Kampflesbarkeit hat Vorrang vor dichtem Rauch und Bildschirmerschütterung.

Audio wird in Umgebungsgeräusche, Interaktion, Waffen, Befehle, Dialog und Musik gegliedert. Für spätere Sprachgenerierung müssen Rechte, Sprecherfreigaben, Ausfallpfad und Kosten geklärt sein. Vorproduzierte oder regelbasierte Befehle sind ein sinnvoller erster Vorschlag; dauerhaft offene Mikrofonaufnahmen sind nicht vorausgesetzt. Untertitel, Lautstärkeregler und visuelle Alternativen werden mitgeplant.

## Versionierung und Lieferung

Textliche Dokumente liegen in Git. Für große `.blend`-, Textur-, Audio- und Engine-Dateien wird vor Import zwischen Git LFS und geeigneter gesonderter Assetverwaltung entschieden. Speicherbedarf, Sperren beim Bearbeiten, Wiederherstellung, Backup und laufende Kosten gehören zu dieser Entscheidung. Noch ist keine dieser Lösungen eingerichtet.

Jedes Produktionsasset erhält eine stabile ID, Quellpfad, Autor/Herkunft, Lizenzbeleg, Änderungsstand, Exportparameter, abhängige Dateien und einen tatsächlich geprüften Einsatzzweck. Das [Referenzregister](ASSET_REGISTER.csv) erfasst zunächst nur die vorhandenen Konzeptbilder; dessen Eintrag ist keine pauschale Lizenzfreigabe.

## Erste spätere Arbeitspakete

Eine Unterkunft mit Baustadien, ein transportierbarer Ressourcenbehälter, ein Gefährtenmodell, ein einfacher Trainingsgegner, ein Wegstück und ein kleines Bedienungselement reichen als Ausgangspunkt. Die endgültige Liste folgt dem freigegebenen ersten Spielabschnitt. Weitere Fraktionen, Belagerungsgeräte und große Städte werden erst nach einem funktionierenden Zusammenhang produziert.
