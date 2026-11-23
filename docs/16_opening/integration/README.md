# Geprüfte Zusammenführung für Chat 1

Dieses Paket führt den filmischen Anfang mit dem separat gelesenen, bereits erweiterten Frontier-Arbeitsstand zusammen. Es ersetzt keine Hauptdatei durch eine ältere Fassung. Der Patch ändert ausschließlich:

- `prototype/scripts/main.gd`
- `prototype/scripts/world/game_world.gd`
- `prototype/scripts/ui/game_ui.gd`

Ausgangsbasis des Dreiwegevergleichs ist Commit `148dd69`. Vier Konflikte in Main und zwei in der Spielwelt wurden in einer getrennten Staging-Kopie gelöst; UI ließ sich ohne Textkonflikt zusammenführen. Die drei Inhalte des aktiven Chat-1-Checkouts wurden vor und nach Erstellung anhand SHA-256 verglichen. Das aktive Checkout und die Hauptdateien des Opening-Branches wurden dabei nicht verändert.

## Erhaltene Funktionen

Main behält `frontier_npc`, `_ui_state()`, `frontier_objective`, `set_frontier_time`, die Frontier-Dialoge, die zugehörigen zulässigen Befehle und deren Speicherung. Die Opening-Funktionen einschließlich wartender Zielkarte, Checkpoints, Pause, Wiederaufnahme und `pending_opening` bei einem fehlgeschlagenen Kampagnensave werden hinzugefügt. Vor Übernahme durch die Filmkamera wird ein noch offener Frontier-Fokus gezielt aufgehoben.

Die Spielwelt behält die Dorfpopulation, ihre Positionen, Blicksteuerung, den Wagenfortschritt und sämtliche Frontier-Schnittstellen. Dazu kommen die Filmkamera-Anker und die aus der bestehenden Gefährtenentscheidung abgeleitete Brunnenstrebe. Die Oberfläche behält Frontier-Dialoge und Aufgabenkarte; ihre zusätzlichen Funktionen sind die Filmoberfläche, gespeicherter Lesemodus, gesperrte Hilfsantwort bei zu wenig Holz und der sichtbare Hinweis auf den sechsjährigen Übergang.

## Vor dem Anwenden

Die fünf zusätzlichen Laufzeitmodule aus dem Opening-Branch müssen zusammen mit ihren fünf versionierten `.gd.uid`-Dateien im Zielcheckout vorhanden sein. Die vollständige Liste steht im Manifest unter `required_additive_files`; `additive_sha256` bindet jede dieser zehn Dateien an ihren exakten geprüften Inhalt. Alle fünf Module stimmen mit dem dokumentierten Engine-Prüfstand überein, die UID-Dateien mit demselben versionierten Checkout. Die mitgelieferten Opening-Tests und ihre Prüfläufer gehören ebenfalls zur Gesamtintegration, werden aber nicht durch diesen auf drei bestehende Dateien begrenzten Patch installiert.

Das Manifest `chat1-opening-guard.json` enthält für jede der drei Hauptdateien die exakt gelesene Chat-1-Prüfsumme und die Prüfsumme der geprüften Zusammenführung. Außerdem bindet es die konkrete Patchdatei an deren SHA-256. **Manifest und Prüfer verwenden Version 2.** Der neue Prüfer akzeptiert keine ältere Manifestversion; ein alter Prüfer lehnt das neue Manifest ebenfalls ab. Dadurch kann eine alte Existenzprüfung die zusätzlichen Inhaltshashes nicht unbemerkt ignorieren.

Ein fehlendes, abweichendes oder als symbolischer Verweis abgelegtes Opening-Modul beziehungsweise eine abweichende UID-Datei stoppt die Prüfung vor der Anwendung. Fehlende Hashangaben oder eine verkürzte Liste werden ebenfalls abgewiesen. Die Dateien müssen aus dem geprüften Opening-Stand übernommen werden; ein alter vorhandener Baustein genügt nicht. Falls Chat 1 seither weitergeschrieben hat, muss die neue Fassung erneut zusammengeführt werden. Keine Hashprüfung entfernen und keine fremden Änderungen durch alte Komplettdateien ersetzen.

## Prüfen und anwenden

Im folgenden Aufruf ist `/pfad/zum/chat1-checkout` durch das beabsichtigte Zielcheckout zu ersetzen. Der erste Aufruf führt ausschließlich Prüfungen aus:

```bash
python docs/16_opening/integration/apply_chat1_opening.py --repo /pfad/zum/chat1-checkout
```

Wenn die zusätzliche Prüfung den aktuellen Stand bestätigt, wendet dieser ausdrückliche Aufruf den Patch an:

```bash
python docs/16_opening/integration/apply_chat1_opening.py --repo /pfad/zum/chat1-checkout --apply
```

Der Prüfer kontrolliert die drei Hauptdateien und alle zehn zusätzlichen Dateien vor und nach `git apply --check`. Nach einer tatsächlichen Anwendung prüft er die drei Ergebnishashes und erneut die unveränderten Zusatzdateien. Der Patch schreibt weiterhin ausschließlich die drei Hauptdateien; er ersetzt weder Laufzeitmodule noch UID-Dateien. Der Prüfer erstellt weder einen Commit noch einen Indexeintrag. Während des eigentlichen Anwendens sollen keine anderen Prozesse die geprüften Dateien bearbeiten. Ändert sich der Inhalt vor der Anwendung, bricht der Prüfer ab; die Auflösung muss dann auf dem neuen Stand erfolgen.

## Nachweis der erweiterten Dateiprüfung

Die frühere Lücke wurde auf einer isolierten Kopie tatsächlich reproduziert: Der Prüfer mit Version 1 meldete Erfolg, obwohl `opening_checkpoint.gd` nur noch `extends RefCounted` enthielt und seine gesamte Laufzeit-API fehlte. Die drei Hauptdateien waren dabei unverändert korrekt.

Der [neue Prüfnachweis](guard-runtime-validation.json) dokumentiert **17 ausgeführte Fälle**: passende Dateien bestehen die Prüfung und die kontrollierte Anwendung; falscher Inhalt in jedem der fünf Module und in jeder der fünf UID-Dateien wird abgewiesen. Auch eine fehlende UID-Datei, ein fehlender Modulhash, ein veränderter Main-Snapshot und beide Mischungen aus altem beziehungsweise neuem Manifest und Prüfer werden abgewiesen. Alle **15 Ablehnungen erfolgen ohne Schreibänderung**. Die erfolgreiche Anwendung auf der separaten Kopie verändert exakt die drei vorgesehenen Hauptdateien und bewahrt alle zehn festgelegten Zusatzdateien.

Der Produktionspatch ist bytegenau unverändert. Diese Prüfung betrifft die Dateizusammenstellung und den Guard; sie wird nicht als zusätzlicher Engine-, Grafik- oder Android-Lauf gezählt.

## Separater Schritt: Naht im Wolkenhimmel korrigieren

`sky-seam.patch` aktualisiert ausschließlich `prototype/scripts/world/village/clouds.gdshader`. An der Längengradgrenze der Himmelstextur wurden zuvor falsche Mipmap-Stufen ausgewählt. Die Korrektur verwendet `textureGrad` mit um den Texturumlauf bereinigten Ableitungen. Der bestehende Drei-Datei-Patch und sein Manifest bleiben unverändert; dieser zusätzliche Schritt muss separat übernommen werden.

Das eigene Manifest [sky-seam-guard.json](sky-seam-guard.json) bindet den Ausgangsinhalt aus Commit `cac84fdf4dedbde4c624975f9c1150013fdca626`, den exakt übereinstimmenden Chat-1-Snapshot und das geprüfte Ergebnis:

| Dateiinhalt | SHA-256 |
| --- | --- |
| Ausgangs-Shader | `54c25d9207c817a50727fa9c2cd938ad79e79b457b83a4b06f86690c545891e3` |
| Korrigierter Shader | `be8a689ab1f4ef3bafd02360a7c30dbde6aa6183bf4510c71b4fd529cc6eb391` |
| Separater Patch | `73709e51dbe9ce2e74a136e0c53806b9c72aa568e6ee509d16793a3d0d089163` |

Zuerst den gegen Dateiverwechslungen abgesicherten Prüflauf ausführen:

```bash
python docs/16_opening/integration/apply_sky_seam.py --repo /pfad/zum/chat1-checkout
```

Bei bestätigtem Ausgangsstand wendet dieser ausdrückliche Aufruf ausschließlich den Shader-Patch an und kontrolliert danach seinen Ergebnishash:

```bash
python docs/16_opening/integration/apply_sky_seam.py --repo /pfad/zum/chat1-checkout --apply
```

Der Prüfer kontrolliert die Patch-Prüfsumme, den einzelnen Zielpfad und den exakten Ausgangshash, führt `git apply --check` aus und liest beide Inhalte unmittelbar vor der Anwendung erneut. Abweichende Quellen müssen zuerst neu zusammengeführt werden. Während der Anwendung darf kein anderer Prozess den Shader bearbeiten. Der Prüfer erzeugt keinen Commit und keinen Indexeintrag.

[sky-seam-validation.json](sky-seam-validation.json) enthält **drei tatsächlich ausgeführte Prüfungen auf isolierten Kopien**: der unveränderte Chat-1-Shader besteht den Dry-run, die Anwendung erzeugt exakt den bestätigten Shader, und ein abweichender Shader wird ohne Schreibänderungen zurückgewiesen. Das aktive Chat-1-Checkout wurde dabei nicht verändert. Die bisherigen 17 Laufzeit-Guard-Prüfungen und deren Nachweisdatei bleiben bytegenau erhalten.

Der separat erstellte [Produktionsstill](../evidence/sky-seam/1280x720-valley-corrected.png) stammt aus dem tatsächlichen Main-Einstieg mit dem korrigierten Shader. [Metadaten](../evidence/sky-seam/production-still.json) und [Capturelog](../evidence/sky-seam/production-still.log) dokumentieren Godot 4.7.2, `gl_compatibility` und den Software-Renderer llvmpipe. Der Log enthält einen Hinweis zur nicht unterstützten V-Sync-Umschaltung. Ein physischer Android- oder Hardware-FPS-Nachweis wurde für diesen Schritt nicht ausgeführt. Der nachfolgend beschriebene gemeinsame Frontier-Lauf mit 1.419 Prüfungen dokumentiert weiterhin seinen ursprünglichen, vor dieser Shaderkorrektur erfassten Stand.

## Nachweisgrenze

`git apply --check` wurde gegen die unveränderte erfasste Chat-1-Kopie erfolgreich ausgeführt. Die separate Guard-Prüfung dokumentiert den kontrollierten Staging-Lauf.

Zusätzlich wurde eine weitere vollständige Kopie frisch in Godot importiert und tatsächlich ausgeführt: **sechs Szenario-/Regelgruppen mit insgesamt 1.419 Prüfungen bestanden**, dazu der frische Import, ohne Warnungen. Die Zusammenstellung, die anfängliche Testanpassung und die Nachweisgrenzen stehen in [COMBINED_CHECK.md](COMBINED_CHECK.md). Das ist ein gemeinsamer Engine-Nachweis; ein physischer Android-Lauf oder eine Grafikabnahme wird damit nicht behauptet.

Der separate `frontier-integration-test.patch` ergänzt ausschließlich in Chat 1s bestehendem Integrationstest die neuen Schritte „Film überspringen → Zielkarte annehmen“. Alle alten Assertions bleiben erhalten; die vorhandenen Prüfungen werden weiterhin über echte Main-, UI- und Weltaktionen ausgeführt. `frontier-integration-test-guard.json` bindet diese zusätzliche Testanpassung an die exakt gelesene ursprüngliche Testdatei. Der Produktionspatch bleibt unverändert auf drei Dateien begrenzt. Vor der Übernahme des Testpatches ebenfalls die dort gespeicherte Ausgangs-SHA prüfen; bei Abweichungen den aktuellen Test erneut zusammenführen.
