# IMPERATHEN – gemeinsame Astra-/Sol-Integration (28.11.2026)

Basis `409818d6904e43dd744fbbada0c7fc364dbf79b7` (VIVA). Dieser Zweig erbt PRIMA #213, GENESIS #214–216,
Sols Stand Zero `4d14cd50` und alle fünf gesicherten VIVA-Commits einschließlich
der beiden Übergabedokumente. Keine Quelldatei der gesicherten Produktionslinien
wird zurückgesetzt; das WIP-Archiv `fc4f8601` bleibt ausgeschlossen.

## Godot Architect – simulierte Prüfung
- Der tatsächliche Stadtgenerator `tools/world/build_roman_test_city.py` versieht
  Porta_west/east/north/south und Wall_* mit `era_min_ce=271`.
- Die produktive CityExploration startet standardmäßig 58 v. Chr. und entfernt
  zukünftige sichtbare und physische Knoten. Laufzeit und historische Daten bleiben
  unverändert. Der Sichtbarkeitstest prüft nun 240 eindeutige Häuser im Kampagnenjahr,
  die Abwesenheit zukünftiger Tore/Wände/Kollider sowie separat alle 244 ursprünglichen
  Prüfpositionen in der Epoche ab 271 n. Chr., jeweils in allen vier Profilen.
- Die alte physische Routen-/Mauerprüfung erhält explizit denselben datierten
  vollständigen Stadtzustand. Sämtliche bestehenden Kollisionstests bleiben erhalten.

## Bug-Hunter / QA – simulierte Prüfung
- Vorheriger realer CI-Lauf 46139717557: in allen vier Profilen exakt 240 Prüfpositionen,
  null Oberflächenverletzungen, aber vier fehlende Tore wegen der falschen Testepoche.
  Originale I02-Korbprüfung 96/96; allgemeiner Engine-Lauf einschließlich Motion-Messung
  bestanden. Die eigentliche Motion-Freigabe wurde wegen des vorangehenden Fehlers
  nicht erreicht.
- Die VIVA-Requisite bleibt an dem tatsächlichen Familienhaustisch (kein Ersatzmodell
  oder zweiter Eintrag). Der neue Prüfmarker bindet ihren bestehenden Geometrie-, Material-,
  Profil-, Positions- und Collider-Test in die vollständige Engine-Regression ein.
  GENESIS-Missionsbelege werden ebenfalls in der vollständigen Regression geprüft.
- Keine gelockerten Grenzwerte, keine geänderte Weltchronologie, keine entfernten
  Routen-/Bewegungstests. Architekturindex unverändert, da keine öffentliche
  Laufzeitschnittstelle verändert wurde. Reservierte NPC-/Marktdateien unangetastet.

## Lead Integrator – simulierte Prüfung und echte Nachweise
- Ausgangsrevision und Remote-Branches verifiziert. Neue isolierte Integrationslinie
  `integration/astra-sol-stand-zero-20261128`; kein Merge nach main oder Änderung an bestehenden Agentenbranches.
- Vorhandene Strict-Formation- und vollständige Fold7-CI sind für diese Linie aktiviert.
  Die fokussierte Prüfung führt auch den originalen VIVA-Assettest sowie den
  Epochen-/Routentest aus. Die vollständige CI baut die tatsächlichen Stadt- und
  Originalfiguren-Ressourcen wie zuvor und exportiert erst nach dem unveränderten
  Motion Quality Gate.
- Beim Commit sind neue Engine-/CI-Nachweise **ausstehend**. Kein Anspruch auf APK,
  Android-Signatur oder Gerätefreigabe. Die Arbeitsumgebung besitzt weder Godot
  noch direkten Git-Netzwerkzugriff; Engine-Prüfungen laufen in GitHub Actions.
- Restliche bekannte Lücken: vollständige Sprache (40/170 technisch akzeptiert),
  spätere Missionen, visuelle Bewegung/Originalrig-Abnahmen, nicht angeschlossene
  Vorschau-Weltmodelle und physischer Fold7-Test. Keine davon als fertig bezeichnen.

Siehe [NEXT_SESSION.md](NEXT_SESSION.md) und die dort verlinkten VIVA-Nachweise.
