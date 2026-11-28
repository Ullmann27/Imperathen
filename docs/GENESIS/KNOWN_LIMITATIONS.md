# GENESIS — bekannte Grenzen

**Quellbasis:** GENESIS fc28428; PRIMA 0f67268 ist in der Vorgängerlinie enthalten. Stand der Inventur: 2026-11-28.

## Geltungsbereich und Nachweise

- SYSTEM_MAP.md ist eine System-/Pfadzuordnung und kein Implementierungs- oder Freigabenachweis. Die Endpunkte AP01 Foundation und AP36 Automation folgen dem Nutzerauftrag. Eine vollständige kanonische Liste der mittleren AP-Titel wurde in den lokalen GENESIS-Dokumenten nicht gefunden; AP02–AP35 sind deshalb beschreibende Codebereiche. Die 36 Zeilen wurden nicht aus Absätzen der AGENTS.md abgeleitet.
- Die Matrix nennt vorhandene Module und repräsentative Tests. Testdateien und historische Protokolle beweisen keinen Testlauf auf der hier bezeichneten Quellbasis.
- Der generierte Architekturindex enthält 273 Runtime-Skripteinträge; der entsprechende Runtime-Dateiumfang unter prototype/scripts/ beträgt ebenfalls 273 .gd-Dateien, Tests ausgenommen. Dies ist Deklarationsinventar, kein vollständiger Szenen-, Asset-, Abhängigkeits- oder Laufzeitnachweis.
- Im Dokumentationsschritt wurden die beiden Node-Indexprüfungen ausgeführt. Die Godot-Gesamtsuite, Android-APK, Gerätelauf, Leistungsmessung und vollständige Regression wurden hier nicht ausgeführt.
- Es wurde kein CODEOWNERS-, OWNERS- oder MAINTAINERS-Verzeichnis mit menschlichen Zuständigkeiten gefunden. In der Matrix steht daher der belegte Modulpfad, kein erfundener Personenname.

## Offene Architekturgrenzen

1. **Erzählplanung:** docs/03_engineering/NARRATIVE_CONTRACT.md kennzeichnet den Narrative-Vertrag als Entwurf. Herkunftsmodell, dreistufige Validierung, erneute Prüfung veralteter Pläne und Fallback sind in dieser Inventur nicht als vollständiger Runtime-Planer belegt. Geschriebene Storyskripte sind kein Nachweis dynamischer Planung.
2. **Weltzustand:** WorldModel, WorldState, Uhr/Kalender sowie Speicher-/Ladepfade existieren. Diese Inventur beweist keine durchgängige Revisionsgleichheit aller Ansichten, keine vollständige Alles-oder-nichts-Transaktion über alle Domänen und keine atomare Wiederherstellung/Migration.
3. **Story-Aktionen — in Arbeit:** I-01 und I-04 verwenden MissionEventBatch.stage()/commit() für deklarierte Drehbuchfelder und Ereignisbelege; der Kindheitsadapter bindet I-04 ein. Der Batch kopiert und veröffentlicht synchron einen begrenzten Arbeitssatz. Er ist weder allgemeine Datenbanktransaktion noch eigener Speicher und beweist keinen vollständigen Commit im autoritativen WorldModel. Den AP05-Status erst nach Integration in den bestehenden Story-Befehlspfad und gezielten Tests ändern.
4. **Ereignisgeschichte:** WorldModel führt eine Chronik aus Zeit/Text-Einträgen mit Obergrenze 256; TribalWorld hat eine separate, sichtbarkeitsgefilterte Chronik; Storyskripte besitzen Beleglisten. Eine einzelne revisionsverknüpfte Ereignisgeschichte mit stabilen IDs und Ursachen ist damit nicht belegt.
5. **Persistenzvollständigkeit:** WorldModel-Speicherung und TribalWorld-Migration sind implementiert und besitzen Testpfade. Snapshot-Integrität, Abbruchwiederherstellung, Versionierung und domänenübergreifende Konsistenz sind mit diesem Dokumentationsschritt nicht abgenommen.
6. **PRIMA-Abnahme:** docs/44_integration/OPERATION_PRIMA.md enthält einen eigenen, begrenzten Status: einzelne Spielstrecken-Gates als ENGINE_PASS, mehrere Darstellungs-/Integrationsbereiche als REVIEW_PENDING und Gerätemessung als DEVICE_PENDING. Diese Einträge sind der dort dokumentierte Stand, nicht das Ergebnis eines neuen Laufs hier. Sie belegen weder Gesamtfreigabe noch physische Geräte-, Temperatur- oder FPS-Abnahme.
7. **Vollständige Automation:** .github/workflows/operation-prima.yml und tools/ci/operation_prima.sh sind vorhanden; der Runner umfasst Import, Indexchecks und gezielte Engine-Tests einschließlich der Story-Batch-Regression. In diesem Dokumentationslauf wurde nur der Index lokal geprüft. Die vollständige Godot-Suite muss auf dem freizugebenden integrierten Commit laufen.

## Übergabe

AP05 bleibt in Arbeit, bis Story-Aktionen mit dem autoritativen WorldModel-Befehlspfad integriert und gezielt geprüft sind. Danach AP05/AP09 anhand realer Quell- und Testbelege aktualisieren und die Index-/Gesamtsuite auf derselben integrierten Revision erneut prüfen. Diese Dokumente beauftragen weder externe Dienste noch Änderungen an anderen GENESIS-Dateien.
