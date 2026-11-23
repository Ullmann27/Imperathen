# Chat A: Bewegung, unbewaffneter Kampf und Touchsteuerung

Dieser Arbeitszweig setzt den Auftrag aus
`docs/18_childhood/CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md` um. Die erste Fassung
`5d95676626d8eeee5589973603cb1da523ca4970` basierte auf
`2909040deeb33b99ad4180b884b38921f28233a9`. Die anschließende Integration
übernimmt den inzwischen veröffentlichten Familien- und Dorfstand
`e5735509622c9a94564dc5fe21257c07074f9df5` vollständig als zweiten Elternstand.
Der eigene Branch wird in [Draft-PR 39](https://github.com/Ullmann27/Imperathen/pull/39)
geführt. Ein Merge nach `main` gehört nicht zu dieser Lieferung.

## Spielverhalten

Eine neue Italia-Partie beginnt mit der zwölfjährigen Figur im Familienhaus,
Antonia, Sextus und dem verbundenen Kindheitskapitel des Dorfzweigs.
Das neue Steuerfeld lässt die Figur mit analoger
Auslenkung gehen; der Tempoknopf schaltet auf Laufen. Tatsächliche Kollision und
Geschwindigkeit treiben die Körperbewegung. Ruhehaltung, Gegenschwung,
Abbremsen und Richtungswechsel besitzen getrennte Darstellung.

Linke und rechte Gerade stehen von Anfang an bereit. Kontrollierte Kontakte
am Übungspfahl schalten Haken, Uppercuts, Kopfstoß und drei Tritte frei.
Ein Tastendruck startet zuerst die Vorbereitung. Erst das aktive Fenster darf
nach Reichweiten-, Richtungs-, Hindernis- und Zielprüfung einen einzelnen
Kontakt buchen. Kindliche Übung erhöht weder das Alter noch die spätere
erwachsene Ausbildungsbescheinigung.

Bewegung, Kamera und Aktion besitzen getrennte Touchkontakte. Die sechs
häufigen Aktionen stehen direkt am Rand; weitere Techniken und bisherige
Weltaktionen öffnen eigene Menüs. Pause, Hintergrund und Wechsel aus der
Figurenansicht beenden ausstehende Kampfeingaben.

## Prüfen und zusammenführen

- [MOTION.md](MOTION.md): echte Rig-/Blenderarbeit, Vorher-/Nachher-Aufnahmen,
  zehn Techniken, vier LODs, Faustform und vergleichbare Aufwandmessung.
- [COMBAT_CONTRACT.md](COMBAT_CONTRACT.md): verbindliche Regeln, elf gespeicherte
  Felder, Zeitfenster, Schadensweg und konkrete Regressionen.
- [TOUCH.md](TOUCH.md): Bedienung, vollständige UI-Ereignistabelle, native
  Touchprüfungen und abgegrenzte Android-Prüfstrecke.
- [INTEGRATION.md](INTEGRATION.md): Dateizuständigkeiten, Schnittstellen,
  Kompatibilität und Grenzen.
- [integration/](integration/): fünf einzelne Anschluss-Patches und genaue
  Hashes für die koordinierende Arbeitslinie.
- [REFERENCES.md](REFERENCES.md): geprüfte offizielle Referenzen und Herkunft
  der selbst erzeugten Ergänzungen.

Die vollständige lokale Regression startet mit:

```bash
python3 -m unittest discover -s tests -p 'android_*_test.py'
python3 tools/check_prototype.py --godot godot --report /dev/shm/imperathen-chat-a-checks
```

Die Android-Pipeline baut ARM64 und x86_64 aus demselben Commit, prüft den
Paketinhalt einschließlich der sechs Familien-/Dorfmodule und startet anschließend
die x86_64-Ausgabe in einem echten Android-Emulator. Der Familienweg verwendet
das normale Intro, Antonia, den Wasserauftrag und wirkliche Wege durch die Tür.
Das zusätzliche native Eingabeszenario prüft Padbewegung,
Tempowechsel, Technikmenü und eine Pause mit gehaltenem Pointer. Ein erfolgreicher
Python-Test dieses Testwerkzeugs ist noch kein erfolgreicher Emulatorlauf.
Die ersten Bilder und 39-Gruppen-Berichte in diesem Ordner gehören ausdrücklich
zum Quellstand `5d956…` vor der Familienintegration. Sie belegen diese neue
Zusammenführung nicht pauschal.
Der abschließende Lieferbericht benennt den tatsächlichen Build- und
Laufzeitstatus sowie die zugehörigen Commits.

Ein physisches Androidgerät, die Temperatur unter Dauerlast und das Verhalten
beim tatsächlichen Falten eines Geräts sind hier nicht gemessen. Die
hochgezogene Tunika beim Highkick, fehlende richtungsabhängige Deckung und die
noch notwendige ausdrückliche spätere Waffenbeschaffung bleiben dokumentierte
Grenzen.
