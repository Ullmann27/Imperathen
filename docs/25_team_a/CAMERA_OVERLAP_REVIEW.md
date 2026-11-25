# Kamerakollision: lokaler Wiederanlauf und prüfbarer Vergleich

Stand: 25. November 2026. Ausgangsrevision:
`fba220ba635e942a66642da9208b8c4b156aa221` auf
`feature/team-a-character-gameplay-20261124`.

## Behobener Ablauf

Der bisherige Kollisionshelfer erkennt eine Überschneidung am Kameraanker.
Sind weder die vorherige Kameraposition noch eine gespeicherte freie Position
verfügbar, gibt er denselben überschneidenden Anker zurück. Das betrifft
insbesondere den ersten Kameraframe an einer Wand. Die bisherige Regression
prüfte nur den Fall mit einer bereits freien vorherigen Position.

Die neue Fassung erhält unabhängig geprüfte freie Vorgängerpositionen.
Ohne solche Historie versucht sie, den Kameraanker anhand realer
Physikkontakte aus der Überschneidung zu lösen. Kontaktkorrekturen und eine
begrenzte lokale Stichprobensuche bleiben innerhalb eines Meters. Jede
akzeptierte Position wird mit dem vollständigen Kameravolumen geprüft.
Erst von einem freien Ursprung aus wird die gewünschte Kamerabewegung
einschließlich Glättung geprüft.

Ein vollständig eingeschlossener Bereich kann keine freie Position liefern.
Der Helfer meldet dann ausdrücklich einen Fehlschlag. Die Welt übernimmt
keine unendlichen Koordinaten, erhält die bisherige endliche Transformation
und blendet die Geometrie dieser Kamera vorübergehend aus. Benutzeroberfläche,
Umgebung und Kameraauswahl bleiben erhalten. Nach erfolgreicher Platzierung
oder beim Wechsel in die Stadt- beziehungsweise Kartenansicht wird die
ursprüngliche Sichtmaske exakt wiederhergestellt, auch wenn sie schon null war.

Die begrenzte Suche garantiert keine global optimale Position und keine
stetige kollisionsfreie Bewegung aus einem bereits überschneidenden Ursprung.
Sie verändert weder die bestehenden Grenzwerte des Motion Quality Gate noch
dessen Freigaberegeln.

## Regressionen

Der Physiktest verwendet die produktive Kameramethode und echte
`StaticBody3D`-Hindernisse. Er prüft:

- Erster Frame neben einer dünnen Wand ohne gespeicherte Kameraposition.
- Zwei sich überschneidende Wände und ein zusätzliches Hindernis im Kameraschwenk.
- Ungültige Eingaben mit blockierter beziehungsweise nachweislich freier Historie.
- Vollständiger Einschluss, wiederholte Fehlversuche und unveränderte endliche Transformation.
- Entfernung des Hindernisses und genaue Wiederherstellung der ursprünglichen Sichtmaske.
- Erhalt einer bereits aktiven anderen Kamera.
- Wiederherstellung der Stadt- und Kartenansicht.
- Die bereits vorhandenen Wand-, Eck-, Dialog-, Glättungs- und Erholungsfälle.

Die optionalen JPEGs stammen aus dem tatsächlichen Godot-Viewport mit klar
bezeichneter Testgeometrie. Sie zeigen diese Kamerafälle; sie sind weder
Spielwelt-Aufnahmen noch eine visuelle Abnahme von Figurenanimationen.

## Nachweis über GitHub Actions

Der Workflow `Team A camera review` arbeitet mit der exakten PR-Head-Revision.

1. Die Python-Tests verwenden das projektübliche Muster `*_test.py`.
2. Der vollständige Godot-Prüfer führt die im Ausgangsstand definierten
   70 Gruppen aus und legt Quellrevision, Inhaltsfingerabdruck und Einzelprotokolle ab.
3. Der grafische Vergleich führt dieselbe aktuelle Testdatei einmal gegen die
   unveränderten Produktionsdateien der Ausgangsrevision und einmal gegen den
   PR-Head aus. Die externe Testdatei wird gesondert gehasht. Ein nachgewiesener
   alter Fehler und ein fehlerfreier neuer Testlauf sind beide erforderlich.
4. Das bestehende Motion Quality Gate wird zusätzlich ausgeführt. Ein eigener
   Check bleibt fehlgeschlagen, solange dessen tatsächlicher Exitcode nicht null ist.

Prüfergebnisse sind erst durch die jeweiligen ausgeführten Actions-Läufe
belegt. Dieses Dokument enthält keine vorweggenommene Bestehensbehauptung.
Es wird keine APK exportiert oder veröffentlicht.

## Fachliche Grundlage

- [Godot PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html):
  `cast_motion()` ignoriert bereits am Ursprung überlappende Formen;
  `collide_shape()` liefert Paare aus Kontaktpunkt der Abfrageform und
  Kontaktpunkt des Hindernisses.
- [Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html):
  `cull_mask` steuert die sichtbaren 3D-Ebenen unabhängig von der Auswahl
  der aktuellen Kamera.
