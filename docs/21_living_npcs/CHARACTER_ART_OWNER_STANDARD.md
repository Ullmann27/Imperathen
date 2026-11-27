# Verbindlicher Charakter- und Originalasset-Standard (Owner, 27.11.2026)

- Vorhandene Meshy-Originale haben Vorrang. Nur Julia und Silvanus neu modellieren; keine unnötigen Neugenerierungen der vorhandenen Figuren. Quellen unverändert und privat aufbewahren. Nur geprüfte, optimierte Derivate in den Spielbestand.
- Rollen selbstständig anhand der Handlung, Kleidung, Tätigkeit, Anatomie und Epoche zuordnen. Keine Vermischung mit LUMO oder anderen Projekten. Kleidung, Waffen und Rüstung an die tatsächliche historische Spielzeit anpassen; späteres Modell nicht automatisch in 58 v. Chr. einsetzen.
- Julia klar als erwachsene Frau, Silvanus klar als erwachsener Mann; individuelle Gesichtsmerkmale, altersgerechte Falten, Haut und Proportionen. Randvi als Qualitätsmaßstab, keine Kopie. Figuren anhand echter Renderaufnahmen einzeln beurteilen.
- Gewänder eigenständig am Körper gewichten: Hände dürfen den Saum nicht hochziehen. Plausible Gewandbewegung beim Gehen, Laufen und Stehen; kein Durchdringen, keine gerissenen Kanten. Lebendige Bewegung ab Brustkorb, Hals, Kopf und Blick; keine starre Dauerpose und keine unnatürliche Überlagerung von Kampfanimationen.
- Deutschsprachige Dialoge vollständig mit korrekter Sprecherzuordnung, synchronisiert mit der Darstellung; keine stummen oder falschen englischen Ersatzzeilen als fertig deklarieren.
- Freigabe nur nach realem Godot-Import, visueller Prüfung, Rigging-/Gewichts- und Bewegungsregression, Android-Gerätetest. Fehlende Dateien und fehlgeschlagene Prüfungen offen ausweisen.

## Verifizierter Bestand und Wiederherstellung

Am 27.11.2026 wurden in der privaten Sicherung 130 GLBs gefunden, alle 71 IMPERATHEN-Aufträge waren vorhanden; alle 42 bereits dokumentierten Quellhashes samt Größe stimmen überein. 35 echte Blender-Renderprüfungen: sieben priorisierte IMPERATHEN-Originale und 28 als LUMO erkannte, zuvor nicht zugeordnete Quellen. Keine neue Meshy-Generierung.

Maschinenlesbare Rollenzuordnung: `OWNER_CHARACTER_ASSIGNMENTS_20261127.json`.

```sh
python tools/art/stage_owner_character_sources.py --local-models /private/extracted/models
blender -b -t 2 -P tools/characters/build_meshy_people.py -- --types unit_legacy_blacksmith
python tools/art/recover_meshy_sources.py --local-models /private/extracted/models --report /tmp/meshy-recovery.json
```

Der zweite Schmied-Versuch exportierte vier LODs ohne Abbruch des Nahtprüfers; kein Godot- oder Fold7-Nachweis. Beim Zivilisten meldete der Prüfer nach Korrektur noch 859 gerissene Kanten (zuvor 2347), daher gesperrt. Neue Kandidaten werden ausdrücklich angefordert, bestehender Standard-Build bleibt unverändert. Das lokale Wiederherstellungswerkzeug erzeugt nur Review-Derivate, keine automatische Aktivierung ungeprüfter NPCs. Die Eltern bleiben in eigenen Modelfamilien.

Keine Backup-URLs, Zugangsdaten oder Rohdateien im Repository.
