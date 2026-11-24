# Bildprüfung · Import und unveränderte Aufnahmequellen

Der erste grafische Lauf
[45431164623](https://github.com/Ullmann27/Imperathen/actions/runs/45431164623)
hat neun echte Basisbilder erzeugt, den Vergleich danach aber beim
Quellenhash-Guard beendet. Diese Aufnahme gilt nicht als abgeschlossener
Vorher-/Nachher-Nachweis.

Die Ursache waren 294 beim ersten Import neu extrahierte PNG-/JPEG-Dateien.
Keine zuvor vorhandene gehashte Quelle wurde verändert. Der unveränderte
Projektstand verwendet den GLB-Importmodus „Extract Textures“; die zusätzlichen
Dateien waren auf der bereits importierten lokalen Arbeitskopie vorher vorhanden,
im frischen CI-Checkout dagegen noch nicht.

Die 294 im CI gemeldeten Pfade wurden anhand der lokal vorhandenen Importtexturen
gegen die eingebetteten Bildbereiche der ursprünglichen 3D-Dateien geprüft:
exakter Zielpfad, Byteanzahl und SHA-256. Die 97 untersuchten GLBs stimmen mit
der unveränderten Handoff-Revision überein. Ergebnis dieser lokalen Reproduktion:
**294/294 belegt, keine veränderte GLB**. Die Maschinenquittung enthält
für jede Datei ihren GLB-Ursprung, Bildindex, Pufferbereich und Hash:
[`evidence/import_provenance_check.json`](evidence/import_provenance_check.json).
Die zusätzlichen CI-Texturdateien selbst waren nicht im ersten Bildartefakt;
ihre direkte Byteprüfung erfolgt erst im korrigierten CI-Lauf.

Der korrigierte Helfer trennt deshalb zwei überprüfte Phasen:

1. **Importvorbereitung:** Jede vorher vorhandene Quelle muss unverändert bleiben.
   Neue Texturen sind nur zulässig, wenn ihr Pfad und vollständiger Bytehash
   einem eingebetteten PNG-/JPEG-Bild einer bereits zuvor gehashten, unveränderten
   GLB entsprechen. Zusätzliche Skripte, neue GLBs, frei ergänzte Texturen und
   beschädigte Quellen führen weiterhin zum Abbruch.
2. **Renderaufnahme:** Der vollständige vorbereitete Stand einschließlich aller
   nachgewiesenen Importtexturen wird eingefroren. Jede Hinzufügung, Löschung oder
   Byteänderung sowie jeder Wechsel von Git-HEAD lässt die Aufnahme fehlschlagen.

Der Vergleich benötigt weiterhin echte PNG-Aufnahmen, identische Kameras und
dasselbe externe Prüfszenenskript. Der Schutz wird nicht pauschal für ungetrackte
Dateien oder Bilddateien abgeschaltet. Spielcode, Assets, Missionsdaten,
Renderer und Kameras wurden durch diese Korrektur nicht verändert.

Die 14 neuen positiven und negativen Guardtests bestehen. Zusammen mit der
vorhandenen Python-Prüfung sind **167/167 Tests** grün; die vorgeschriebene
erneute Engine-Prüfung besteht **64/64 Gruppen ohne Warnungen**.
Nachweise: [`evidence/review_fix_python.log`](evidence/review_fix_python.log) und
[`evidence/review_fix_engine_report.json`](evidence/review_fix_engine_report.json).

Der eigentliche neue grafische Lauf und seine Sichtbewertung werden nach
Abschluss in `DELIVERY.md` dokumentiert. Ein erfolgreicher Importnachweis allein
belegt keine fertige Bildabnahme und keine Android-Leistung.
