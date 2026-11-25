# AETERNA · Live-Arbeitsstand (versioniert)
Stand 24.11.2026, Baseline 7c3194db. Profile erstellt ≠ laufende Agenten. Alle neuen Aufgaben sind geplant, nicht als abgeschlossen markiert. Nur Koordinator ändert diesen Tracker nach tatsächlichem Nachweis.
Status: READY, IN_PROGRESS, BLOCKED, REVIEW, VERIFIED, RELEASED. Kein Prozentwert ohne festgelegte Messgröße.
| ID | Arbeitspaket | Zuständig | Status | Abnahmekriterium / bekannter Befund |
|---|---|---|---|---|
| M0 | Architektur & neun Profile | Koordination | REVIEW | Plan und TOML-Dateien auf isoliertem Branch; keine Gameplayänderung |
| M0.1 | Aktuellen Remote/Signatur/Tests inventarisieren | C3 | READY | exakte Heads, Baseline und Testmatrix |
| M1.1 | Bewegungsgate korrigieren | A1 | BLOCKED | #48, letzter Lauf 101 Befunde; neu vermessen, kein Gate-Bypass |
| M1.2 | Menü/Trailer/Audio zusammenführen | C1/C3 | READY | #49 prüfen, Integrationstest, visuell/akustisch abnehmen |
| M1.3 | Story-Fähigkeiten integrieren | C1/C3 | READY | #50 prüfen, Save-Kompatibilität, Originalquelle für Ausbau |
| M1.4 | Build 8 Integrations-APK | C3 | BLOCKED | nach M1.1–3, Gate/ARM64/Emulator/Hash/Signatur erfolgreich |
| M2.1 | Figuren und Ausrüstung | A2 | READY | 2 von 7 registrierten Truppenkörpern integriert; Rest pro Asset prüfen |
| M2.2 | Kampf/Kamera/Touch | A3 | READY | funktionale und visuelle Prüfung, gerichtete Abwehr |
| M2.3 | 42 lebendige NPCs | B1 | READY | deterministische Tages-/Sozial-/Gefahrenszenarien, Save |
| M2.4 | Valdora I-00–I-14, beide Wege | C1 | READY | vollständige Quellenmatrix und Spielabläufe; 60–90 min Ziel |
| M2.5 | I-15 ff./Nebenmissionen | C1 | BLOCKED | Original-DOCX im zuständigen Arbeitskontext sicherstellen |
| M3.1 | GL vs Mobile Vulkan | C2 | READY | reproduzierbare Bild-/Leistungsvergleiche |
| M3.2 | Vier Grafikprofile | C2 | READY | dokumentierte Qualität, Geräte-/Frametimebudget |
| M3.3 | Fold7 physische Abnahme | C3/C2 | BLOCKED | physisches Gerät, reale Telemetrie; Emulator reicht nicht |
| M4 | Streaming, Umland, Pferd | B2/A3/A2 | READY | stabiler Zellwechsel, Kollision, validiertes Reitmodell |
| M5 | Region, Wirtschaft, Stadt | B2/B3/B1 | READY | gemeinsame IDs und transaktionale Welt |
| M6 | Kohorten und Schlachtmodus | B3/A3/C2 | READY | gestufte Lasttests; sichtbare, simulierte, strategische Einheiten getrennt |
| M7 | Weitere Bände und PC | C1/C3 | READY | nur belegte Inhalte und Plattformabnahme |
## Report pro Aufgabe
Ticket, Agent, Status, Basis/Head-SHA, PR, geänderte Dateien, echte Tests, Geräte-/Renderbedingungen, Belege, Restbefunde, nächster Schritt. Status nur mit Beleg hochstufen. Bei BLOCKED Ursache und konkreten Entblocker angeben. Keine automatische Veröffentlichung und kein main-Merge.
## Bekannte Quell-PRs
[#44 NPC/Meshy](https://github.com/Ullmann27/Imperathen/pull/44) · [#45 NPC/Kampf](https://github.com/Ullmann27/Imperathen/pull/45) · [#47 Build 7](https://github.com/Ullmann27/Imperathen/pull/47) · [#48 Gate](https://github.com/Ullmann27/Imperathen/pull/48) · [#49 Menü](https://github.com/Ullmann27/Imperathen/pull/49) · [#50 Story](https://github.com/Ullmann27/Imperathen/pull/50).
