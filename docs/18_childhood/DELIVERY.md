# Entwicklungsstand: ein langsamerer Anfang im bewohnten Dorf

23. November 2026 · Arbeitszweig `feature/childhood-village-20261123`

Dieser Stand setzt Heinz’ Rückmeldung zur sehr frühen Android-Rohfassung in tatsächliche Spieländerungen um. Er wird als **prüfbarer Entwicklungsstand mit Code, echten Engine-Aufnahmen und zwei Folgechat-Aufträgen** gesichert. Für diesen Umbau wurde noch keine neue Android-APK gebaut oder auf einem Telefon abgenommen. Die bisher veröffentlichte APK auf Basis von `e1b1c1fb16d63056e4eb80891d84ed75c79b4ed6` bleibt ein älterer Stand.

## Ergebnis im Spiel

- **Vorhandenes Zuhause:** Ein neues römisches Spiel beginnt mit zwölf Jahren im bestehenden Familienhaus. Antonia und Sextus sind seine Eltern; Quintus wird als Schmied kennengelernt. Alle drei verwenden bestehende Einwohneridentitäten.
- **Verbundene Kindheit:** 35 aufeinander bezogene Handlungen führen über vier bewusst begonnene Dorftage. Besorgungen, konkrete Übergaben, Schmiedearbeit, eine unterschiedliche Marktentscheidung, beaufsichtigte Dorfrunde und die Krankheit eines tatsächlich ausfallenden Wächters greifen ineinander. Der Junge bleibt zwölf. Ein Arbeits- oder Überfalltimer überspringt die Geschichte nicht.
- **Größeres bewohntes Dorf:** 20 betretbare Wohnhäuser sowie die vorhandene Domus und Gewerbebauten; 26 Hintergrundbewohner und 15 Figuren des Dorfmodells. Familienhaus, Werkstatt, Markt und weitere Räume besitzen zusätzliche selbst erstellte Requisiten.
- **Boden und Menschen:** Die sichtbaren Hausböden, Schwellen und offenen Zugänge tragen die Figur tatsächlich. Personen und passende Möbel sind Hindernisse; Hintergrundbewohner bewegen sich mit Kollisionsprüfung. Die störende alte innere Palisade ist im bewohnten Dorf deaktiviert.
- **Bewegung und Kampfgrundlage:** Seitliche Ruhehaltung der Arme, gegenläufiger Armschwung, getrenntes Gehen/Laufen und zehn unterscheidbare prozedurale Nahkampfclips. Ein bestätigter Treffer benötigt den richtigen Zeitpunkt, Reichweite, Richtung, ein gültiges Ziel und freie Sicht. Übung wird getrennt von tatsächlichem Gegnerkontakt geführt.
- **Bedienung:** Größeres, höheres Steuerfeld, Gehen/Laufen, beschriftete Kampficons, Technikauswahl und eine kleine Karte mit dem aktuellen Ziel. Der nachgewiesene Fehler beim Loslassen nach einer emulierten Mauskopie ist korrigiert. Große, über den Auftrag ragende Interaktionstexte wurden nach Bildprüfung verkleinert.
- **Begrenzte Renderarbeit:** Gleiche primitive Geometrie wird geteilt, örtlich zusammengehörende statische Requisiten werden zusammengefasst und korrigierte Bewegungsclips je Rig wiederverwendet. Bewohner laden Identität und anfängliche Detailstufe gemeinsam statt zunächst ein generisches und anschließend ein zweites Modell.

## Tatsächliche Prüfung

Der zentrale Lauf unter **Godot 4.7.2.stable.official.ed1daf0bf** hat **alle 40 registrierten Gruppen** auf dem abschließenden Quellstand beim ersten Gesamtdurchlauf bestanden. Es gab **keine Fehler und keine Warnungen**. Der Bericht enthält 220 Quellhashes einschließlich Shader und unterscheidet die Headless-Prüfung ausdrücklich von einer grafischen Messung.

| Nachweis | Ergebnis |
| --- | --- |
| Gesamte Engine-Regressionsfolge | 40 von 40 Gruppen bestanden |
| Python-Tests für vorhandene Pipeline, Paket- und Laufzeitprüfer | 69 Tests bestanden |
| Neue Kindheits-Domain | 323 Prüfungen bestanden |
| Neuer Nahkampfvertrag | 69 Prüfungen bestanden |
| Neuer Main-/Touch-/Save-Weg | 62 Prüfungen bestanden |
| Natürliche Bewegung, Techniken, Leihdarstellung und anfängliches Bewohnerladen | 102 Prüfungen bestanden |
| Gemeinsame Geometrie und statische Zusammenfassung | 17 Prüfungen bestanden |
| Siedlungsgeometrie und wirkliche Kapselbewegung | 1.496 Prüfungen bestanden |
| Kindheitswelt, Personen und Produktionsfigur auf Böden | 184 Prüfungen bestanden |
| Erweiterte Einwohnerwege und bisherige Bevölkerung | 841 Prüfungen bestanden |

Die Teilprüfungen sind Bestandteile beziehungsweise ergänzende Aufschlüsselungen der Gesamtabnahme; die Zahlen werden nicht als voneinander unabhängige Spielerlebnisse addiert. Der Domainlauf positioniert Figuren gezielt an Auftragspunkten. Er ist kein gemessener menschlicher Komplettdurchlauf des Kapitels.

Der [zentrale Bericht](evidence/engine/validation_report.json) und seine Einzelprotokolle sind maßgeblich. Seine SHA-256 lautet `ed1812bfa4579f96780b6b0efc9de1a20438d843ffdfd638b58d5d42eeb0fea2`. Der tatsächliche Python-Lauf steht in [python-unittests.log](evidence/python-unittests.log).

### Echte Bilder und ihre Grenzen

Die sechs [Dorfansichten](evidence/world/settlement-review.json) wurden mit der wirklichen Produktionswelt unter OpenGL Compatibility/Mesa llvmpipe bei 854 × 480 und niedrigem Profil erstellt und einzeln angesehen. Sie zeigen Familieninnenraum, Hauseingang, Schmiede, Markt, Wohnstraße und die gesamte Siedlung. Die Kameras und Spielerpositionen wurden ausdrücklich zur Prüfung gesetzt. Ein vorheriger 720p-Weltversuch endete vor dem ersten Bild mit Prozesscode −9; daraus wird kein Erfolg abgeleitet.

Ein vollständiger grafischer UI-Lauf bei 1280 × 720 im niedrigen Profil bestand **69 Prüfungen einschließlich vier tatsächlicher Bildaufnahmen**. Die anschließende Bildkontrolle fand den zu großen Interaktionstext. Nach dessen Korrektur entstanden **drei aktuelle Bilder** von Haus, Muttergespräch und Steuerung. Der spätere Teil dieses erneuten grafischen Laufs endete mit Prozesscode −9. Dieser letzte Lauf wird ausdrücklich **nicht als vollständig bestanden** geführt. Die vierte Technikansicht stammt daher aus dem vorherigen erfolgreichen Lauf. Beide unveränderten Protokolle, Quellhashes, Bilddateien und Grenzen stehen in [review-scope.json](evidence/ui/review-scope.json). Die abschließende vollständige Headless-UI-Prüfung mit zusätzlicher Anfangskartenprüfung bestand danach alle 62 Prüfungen.

Diese Unterscheidung ist relevant: aktuelle gerenderte Einzelansichten und bestandene Domain-/Eingabetests belegen andere Eigenschaften als ein vollständiger, dauerhaft stabiler Android-Lauf. Es wurde keine APK dieses neuen Stands auf Heinz’ Telefon geprüft.

### Vergleich identischer Requisiten

Ein kleiner, unverändert bestückter Vergleich mit denselben Kameras und Einstellungen wurde wirklich gerendert. Die Zeichenaufrufe sanken beim Wagen von **130 auf 31**, beim Garten von **169 auf 49** und in der entfernten Straßenansicht von **125 auf 36**. Alle 24.064 modellierten Dreiecke, 19 Materialien und acht Kollisionen des Fixtures blieben erhalten. In der entfernten Ansicht wurden wegen der gemeinsamen Sichtbarkeitsentscheidung eines Batches etwas mehr Primitive übermittelt. Messbedingungen und der vollständige Vergleich stehen in [PERFORMANCE.md](PERFORMANCE.md) und [comparison.json](evidence/performance/comparison.json).

Das ist ein tatsächlicher begrenzter Renderbefund auf dem Software-Renderer. Er beweist weder ein kühleres Handy noch bessere anhaltende Android-FPS und ist kein Vergleich der gesamten, inzwischen vergrößerten Siedlung.

## Was als Nächstes zusammengeführt werden muss

Die Kindheit endet derzeit mit einem gespeicherten **offenen Nachtereignis**. Die ausdrückliche Schnittstelle zur einmaligen Raid-Freigabe existiert und ist geprüft. Eine neue Filmsequenz mit ungefähr dreißig Reitern, originalen Pferden, unterschiedlichen Reitern, Ton und Übergang in die Spielwelt ist noch nicht umgesetzt. Sie muss auf die bereits aufgebauten Beziehungen und den wirklichen Spielstand reagieren.

Auch der langfristige Lebenskalender, spätere Jugendjahre und militärische Laufbahn, umfassende persönliche Wirtschaft, freie Innenraumhandlungen, weiter verfeinerte Animation und Schwert-/Schildkampf brauchen weitere Kapitel beziehungsweise Systeme. Die vier erzählten Tage sind ein Anfang; ihre Wirkung und tatsächliche Länge müssen mit einem menschlichen Durchlauf bewertet werden. Konsolenqualität bleibt das Gestaltungsziel.

Die konkrete Aufgabenverteilung und alle wichtigen Schnittstellen stehen in [HANDOFF.md](HANDOFF.md). Historische Ausgangsdaten, Entwurfsentscheidungen und Referenzgrenzen stehen in [REFERENZEN_UND_RICHTUNG.md](REFERENZEN_UND_RICHTUNG.md).

## Zwei kopierfertige Folgechat-Aufträge

1. [CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md](CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md): drei tatsächliche Agenten für Fortbewegung/Rig, Kampf/Treffer sowie Touch/Kamera/Prüfung.
2. [CHAT_B_DORF_GESCHICHTE_WELT.md](CHAT_B_DORF_GESCHICHTE_WELT.md): drei tatsächliche Agenten für Geschichte/Beziehungen/Zeit, Dorf/Bewohner/Innenräume sowie historische Welt/Wirtschaft/Reiter/Leistung.

Beide arbeiten auf eigenen Branches vom überprüften Remote-Stand aus und melden tatsächliche Commits, Prüfergebnisse und Grenzen zurück. Dieser Entwicklungsstand wurde nicht nach `main` gemergt und nicht als Store-Release veröffentlicht.
