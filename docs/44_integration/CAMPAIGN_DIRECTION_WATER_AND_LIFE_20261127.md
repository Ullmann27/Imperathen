# IMPERATHEN – durchgängige Missionsregie und Lebenswege (27.11.2026)

Status: Produktionsvorgabe und Runtime-Kandidaten auf PR #156. Keine Visual Acceptance, keine APK-Freigabe. Die ursprünglichen vier Drehbücher bleiben erhalten. Der vorhandene Kalender und die 113 registrierten Hauptmissionen bleiben die Quelle für IDs, Daten und Altersstufen. Nur I-01–I-14 sind derzeit als Band-1-Missionsdateien installiert; darüber hinaus existieren weitere Systemslices und das Storyregister, aber daraus folgt keine vollständig spielbare Hauptkampagne.

## Missionsvertrag für alle Bände

Jede Hauptmission erhält: (1) eigenständigen filmischen Auftakt mit Motivation und räumlicher Orientierung, (2) tatsächliche Handlung in der bestehenden Welt, (3) Konsequenz aus dem validierten Save, (4) neues Ziel oder alternativen Lebensweg. Keine Wiederholung bereits gehörter Instruktionen; kein Erfolg im Film ohne bestätigten Spielzustand. Filmskip übergeht nur Präsentation, nie offene Entscheidungen. Schauspiel: beobachtete Blickrichtung, Ruhepausen, Gewicht, Handkontakt, begrenzte Gelenkwinkel; echte Gegenstände und Kollisionsprüfung. In dialogfreien Einstellungen kein künstlich sprechender Mund.

Runtime: Die generischen vorhandenen Missionsübergänge nutzen jetzt einen Reaktionsshot statt der erneut abgespielten alten Instruktion. Dreißig neue deutsche Motivationszeilen in campaign_direction.gd decken I-02–I-31 ab; nur tatsächlich installierte Missionsdateien werden in den aktuellen Sprachproduktions-Export aufgenommen. Die spezialisierten VID-A/B/C-Varianten bleiben erhalten. Neue Zeilen sind Produktionsdialog, keine historischen Zitate.

## Ausgewählte Schlüsselmissionen: zwei Versuche

Regel: ein gestarteter Versuch zählt, nicht das Ansehen des Films. Ein regulärer Fehlschlag oder eine überlebbare Verletzung im ersten Versuch eröffnet einen zweiten, sofern der Auftraggeber und die Weltlage ihn noch erlauben. Erfolg ist endgültig; keine doppelte Belohnung. Zweiter Fehlschlag schließt den spezifischen Auftrag und eröffnet einen alternativen Weg. Bei einem tatsächlich tödlichen Zustand keine automatische Wiederbelebung. Ein verwundeter Erwachsener kann in einer geeigneten sicheren Unterkunft erwachen; Film, Behandlung, Zeit und veränderte Beziehungen müssen aus echten Zuständen abgeleitet werden. Die Kindheitsentscheidungen und festgelegten Verluste in I-10–I-14 werden nicht neu gewürfelt.

Implementiert: isolierter KeyMissionAttempts-Vertrag mit zwei Versuchen, JSON-Roundtrip, Endzuständen und Regression. Noch offen: autoritativer Save-/Missionsrunner, Auswahl konkreter späterer Schlüsselmissionen, Wiederaufwachen, Heilung, Auftraggeber-/Fraktionsfolgen und Ausrüstungsfreigaben. Nicht auf die vorhandenen Kindheitsmissionen angewendet. Die spätere Herrscherrolle wird aus dem Era-Register gelesen: in Caesars Zeit nicht pauschal Kaiser nennen.

## Tempo, Zeitsprünge, Kindheit und Jugend

Vorgabe: Interaktionsfilme und Kampf verwenden Echtzeitsekunden. Für spätere freie Welt als erste Balance-Hypothese 24 Spielminuten pro realer Minute (ein Kalendertag pro realer Stunde), nicht unbemerkt in die bestehende erzählte Kindheitsuhr einschreiben. Historische Anker und offene Missionsereignisse blockieren unzulässige Zeitsprünge. Mehrjährige Entwicklung durch echte spielbare Schlüsselereignisse mit datierten Montage-Interludes. Der bestehende WorldClock ist alleinige Zeitquelle.

Befund: WorldModel._choose_adult_path springt derzeit nach I-14 sechs Jahre vor; der Zeitvertrag simuliert beim Sprung bislang nur Spieler/Gefährtenalter, nicht Besitz, Siedlungen, Politik, Beziehungen oder Ausrüstung. Dieser Prototypweg bleibt bis zu einer vollständigen Migration erhalten, darf aber nicht als vollständiger Band I gelten.

| Lebensalter | Drehbuchanker | Neue Regievertiefung / spielbare Wendepunkte (Entwurf) |
|---|---|---|
| 12, 58 v. Chr. | I-01–I-15 | Wasser als einmalige Einführung; Botengang führt zu Menschen und Konsequenzen, Werkstatt zu Können; Hufspuren steigern Unsicherheit, Abend macht Verlust konkret; Überfall und Schwur führen in echte Ermittlung. |
| 13, 57 v. Chr. | I-16–I-19 | Bauplanung im beschädigten Dorf, Wahl zwischen dringenden Gebäuden, Nachbardorfkonflikt um Holz, Winterversorgung und Reise nach Aquileia; Montage zeigt Wachstum anhand bestätigter Reparaturen. |
| 14, 56 v. Chr. | I-20–I-21 | Spur des Siegels, Zeugenaussagen und Beweiswürdigung statt behaupteter Schuld; Marcus entscheidet eigenständig über seinen Lebensweg. |
| 15, 55 v. Chr. | I-22 | Lehre und Waffenhandhabung; Zugang nach Können und Alter, echte Gegenstände und kontrollierte Übungsduelle. |
| 16, 54 v. Chr. | I-23–I-24 | Karawane über die Alpen, Wetter, Nahrung, Reisegefährten und Entscheidung in fremdem Dorf; Wahl zwischen Handel, Schutz, Diplomatie und weiterem Weg. |
| 17–18, 53–52 v. Chr. | I-25–I-31 | Veteran, Eintritt in einen Lebensweg, militärische Logistik und Alesia; historische Anker und geschützte Konsequenzen. |

## Bau, freies Überleben und Siedlungsgründung

Befund: Der jetzige WorldModel besitzt reale Bauaufträge, Materialverbrauch, räumliche Arbeit und Kollisionsabstand für bis zu 16 Hütten auf einem festgelegten Grundstück (8 Holz je Hütte, derzeitiges Spielbalancing). Das ist kein freies Siedlungsbausystem. Ausbau in getrennten Schritten:
1. Eigentums-/Baurecht am realen Ort, geeigneter Boden, Vorschau, Fundament, Wände, Dach, begehbare Räume; Holz, Stein, Lehm/Ziegel, weitere Materialien je Gebäudetyp.
2. Bezahlte oder eigene Arbeit, Vorräte und Unterhalt, echte Lager und Schlaf-/Heilplätze; Besitz und Baufortschritt im Save.
3. Freie Gründung an geeigneten und erlaubten Stellen mit Wasser, Versorgung, Nahrung, Jagd und Handel; Grenzen der bestehenden Gelände-/Streaming-/Kollisionssysteme beachten.
4. NPCs schließen sich aus eigenen Gründen und beobachteten Beziehungen an; keine erfundenen Einwohner, keine Verdopplung von Arbeitskraft oder Ressourcen. Berufe, Haushalte, Infrastruktur und lokale politische Reaktion wachsen aus realem Zustand.

## Optische Abnahme

Konzeptbilder sind keine Ingame-Aufnahmen. Der neue I-01-Grafikworkflow erzeugt echte Frames vom leeren Krug, der Winde, dem Eimer und allen drei Gießvorgängen. Prüfen: Hände/Griff, Eimerrand, Strahlbeginn und -ende, Kollision, Geh-/Sitzbewegung, Kamera, Gesicht, Gebäudeoberflächen. Noch keine verifizierte physische Handpassung, kein bestätigtes Sitzen des Vaters oder Küchenblocking der Mutter. Software-Renderer ersetzt keine Fold7-Abnahme. Weitere Rig-Arbeit ist erforderlich, insbesondere individuelle Finger der Jugendfigur; die Erwachsenenquelle unterstützt bereits einzelne Fingergelenke.
