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

## Nachgezogene Zeitsteuerung des Überfall-Integrationstests

Der erste vollständige Prüflauf hat drei Positionsabweichungen im bestehenden
`village_experience_test.gd` sichtbar gemacht. Der Test deaktiviert die
automatischen Uhren von `Main` und `GameWorld`, ließ jedoch den inzwischen
eigenständig laufenden Physik-Callback des untergeordneten Überfallcontrollers
aktiv. Während gewarteter UI-Frames bewegten sich dadurch die Angreifer weiter,
obwohl der Test den maßgeblichen Modellzustand bewusst anhielt.

Der Test steuert nun auch diesen Callback ausdrücklich in derselben
Eltern-/Kind-Reihenfolge. Nach einem vollständigen Schritt werden die realen
Körperpositionen über die vorhandene Produktionsfunktion beobachtet, die auch
Befehle und Speichern verwenden. Die ursprüngliche genaue Gleichheitsprüfung
zwischen sichtbarer Gegnerposition und Modellzustand bleibt erhalten.

Zusätzliche Prüfungen belegen, dass reine UI-Warteframes weder Überfallzustand
noch Körperpositionen verändern und dass ein ausdrücklich ausgeführter echter
Physikframe weiterhin mindestens einen Angreifer bewegt, innerhalb der
bestehenden Geschwindigkeitsgrenze von 1,2 m/s. Die produktive Überfalllogik
wird dabei nicht geändert.

## Vollständigkeit der Ausrüstungsmessung

Der vollständige Lauf auf `b553b637477f87305044ada66ed69b0aec24642e`
hat außerdem einen echten GDScript-Laufzeitfehler im Ausrüstungsmessskript
gemeldet: Ein bedingter Ausdruck lieferte eine untypisierte Liste, die nicht
direkt einer Variablen vom Typ `Array[String]` zugewiesen werden konnte.
Der Godot-Prozess beendete sich zwar mit Exitcode null; der bestehende Prüfer
erkannte die Skriptfehlermeldung und bewertete die Messgruppe zutreffend als
fehlgeschlagen.

Die Liste wird nun ausdrücklich als typisierte Liste aufgebaut. Die drei
Identitäten `service`, `unit_roman_signifer` und
`unit_germanic_axe_fighter` sowie ihre Reihenfolge bleiben erhalten.
Messszenarien, Grenzwerte und Freigabebedingungen werden nicht geändert.
Erst ein neuer vollständiger Messlauf kann die tatsächlichen
Ausrüstungsmetriken nachweisen; die zuvor abgebrochene Messung gilt nicht als
Abnahme.

## Fachliche Grundlage

- [Godot PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html):
  `cast_motion()` ignoriert bereits am Ursprung überlappende Formen;
  `collide_shape()` liefert Paare aus Kontaktpunkt der Abfrageform und
  Kontaktpunkt des Hindernisses.
- [Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html):
  `cull_mask` steuert die sichtbaren 3D-Ebenen unabhängig von der Auswahl
  der aktuellen Kamera.
