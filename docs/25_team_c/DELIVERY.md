# Team C – Presentation & Delivery

Stand: 24. November 2026. Arbeitszweig:
`feature/team-c-presentation-delivery-20261124`.
Ausgangsstand: `7a21dca5dad83bf637cfbe9c02f4d9ab5cd97337` aus
[PR #53](https://github.com/Ullmann27/Imperathen/pull/53), einschließlich
der dort geprüften Begleiter und ausgelagerten Missionsschritte.

## Ergebnis dieses Arbeitspakets

| Zuständigkeit | Konkreter Beitrag | Nachweis |
| --- | --- | --- |
| C1 – Story | Reproduzierbarer Prüfer für private Drehbuch-DOCX; Abgleich mit Missions-IDs, Fundstellen für Produktionssprache, Wiederholungen und Altersfragen. | [Quellenprüfung](STORY_AUDIT.md), [maschineller Bericht](story_source_audit.json) |
| C2 – Render | Hintergrundbetrieb auf maximal 15 FPS begrenzt; Pause und Fokus getrennt behandelt; Bildzeitmessung nach Profil-, Größen- und Lebenszykluswechsel neu begonnen. | [Renderbericht](RENDER.md), [30 gezielte Prüfungen](evidence/render/runtime-display-lifecycle.log) |
| C3 – Integration | Tatsächliche Signierzertifikate werden mit dem APK-Hash im Baunachweis erfasst; ein bekannter Zertifikatabweichler blockiert die APK-Übernahme; ARM64 und Emulator müssen denselben Signiervertrag erfüllen. | [Integrationsbericht](INTEGRATION.md), [gesamte Python-Regression](evidence/python-tests.log) |

Der neue PR-Workflow `presentation-delivery.yml` führt die Python-Verträge
und die vollständige isolierte Godot-Regression aus und archiviert deren
Nachweise. Er baut und veröffentlicht keine APK. Die Pfadfilter des bestehenden
Android-Workflows berücksichtigen den neuen Signaturhelfer ebenfalls; der
Team-C-Zweig wird dadurch nicht zum automatischen Veröffentlichungszweig.

## Tatsächlich ausgeführte Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| Godot 4.7.2, vollständiger Headless-Lauf | **65/65 Gruppen bestanden**, keine Warnungen |
| Python, alle `android_*_test.py` | **201/201 Tests bestanden** |
| Darin enthalten: neuer Render-Lebenszyklustest | **30 Einzelprüfungen bestanden** |
| Darin enthalten: neue Signaturtests | **22 Tests bestanden** |
| Darin enthalten: neuer Drehbuchprüfer | **12 Tests bestanden** |
| Workflow-Dateien | Beide geänderten YAML-Dateien erfolgreich geparst |
| Diff-Prüfung | `git diff --check` ohne Befund |

Die Teilzahlen werden nicht zusätzlich zu den Gesamtsummen addiert.
[Alle Engine-Protokolle](evidence/engine/) und der
[Verifikationsbericht mit Quellprüfsummen](evidence/verification.json)
beschreiben den getesteten Code. Die Signaturtests verwenden kontrollierte
Verifier-Ausgaben und prüfen tatsächliche Erfolgs- und Fehlerpfade; sie sind
kein neuer Android-Bau. Die unabhängige Gegenprüfung entdeckte eine
Python-3.10-Unverträglichkeit des ersten Signaturhelfers. Sie wurde durch
blockweises Hashen behoben und durch eine zusätzliche Regression abgesichert.

## Storybefunde und Quellenabdeckung

Die hier verfügbaren Originale umfassen **Band 2, 3 und 4**. Der Prüfer findet
darin **81 Hauptmissionen und 72 Nebenquests** sowie **810 nummerierte
Hauptmissions-Dialogzeilen**. **96 dieser Zeilen** enthalten technische
Produktionsbegriffe und werden vor einer Vertonung zur Überarbeitung markiert.
Es gibt außerdem **250 zusätzliche identische Sprecherzeilen innerhalb
derselben Szene**, verteilt auf **77 Szenen**. Wiederholung ist ein
redaktioneller Prüfhinweis, nicht automatisch ein inhaltlicher Fehler.

Band 1 und `IRON_BANNERS_Projektmappe.zip` waren in dieser Sitzung nicht
lesbar verfügbar. Band 1 ist im Bericht ausdrücklich ungeprüft. Vorhandene
Repository-Übergaben ersetzen keinen erneuten Originalabgleich.
Die Originaldrehbücher, Volltextextraktionen und zusätzlichen gesprochenen
Inhalte werden nicht in das öffentliche Repository aufgenommen. Die Dateien
unter `assets/story/` und das Spielstandschema bleiben unverändert.

Ein erfolgreicher Unit-Test des Prüfwerkzeugs ist keine Freigabe des
Manuskripts. Der tatsächliche Quellenlauf meldet korrekt `needs_revision`;
`production_clearance` bleibt `not_assessed`.

## Grafik- und Geräteumfang

Der aktive Renderer bleibt `gl_compatibility`. Alle vier vorhandenen Profile
und ihre Vordergrundlimits bleiben erhalten. Die 15 FPS im Hintergrund sind
eine konfigurierte Obergrenze und kein gemessener Energie- oder Wärmegewinn.
Der getestete Größenwechsel prüft den produktiven Viewport-Signalweg; er ist
kein physischer Faltvorgang auf dem Galaxy Z Fold7.

Vulkan, Shader, Materialien und Beleuchtung wurden in diesem Paket nicht
umgestellt. Vor einer Übernahme benötigen entsprechende Änderungen einen
Vergleich derselben Szene und Kamera sowie Messungen auf echter Android-GPU.
Das vorhandene Profilfeld `glow` ist weiterhin nicht an die Spielumgebung
angeschlossen und wird nicht als aktiver Effekt ausgegeben.

## Freigabe und Integration mit den anderen Bereichen

Dieser Stand ist ein **Entwurfsbeitrag**, kein neuer APK-Release. Es erfolgte
kein Merge nach `main` und keine Veröffentlichung im Store.

- **Team A:** Das separate [Motion Quality Gate in PR #48](https://github.com/Ullmann27/Imperathen/pull/48)
  und seine noch offenen Bewegungsbefunde sind nicht in der Ausgangsbasis
  enthalten. Ihre visuelle Abnahme bleibt eine eigene Voraussetzung.
- **Team B:** NPC-Verhalten, Begleiter, Weltgeometrie und Simulation bleiben
  auf dem übernommenen Stand. Die gesamte Regression umfasst auch diese
  Bereiche; der Team-C-Patch ändert deren Autorität und Speicherfelder nicht.
- **C1:** Band 1 erneut bereitstellen, markierte Dialogstellen redaktionell
  klären und historische Besetzung/Zeitleiste vor Vertonung abgleichen.
- **C2:** Falten, Hintergrundwechsel und die vier Profile auf dem echten
  Fold7 prüfen; daraus erst Bildzeit- und Wärmeaussagen ableiten.
- **C3:** Einen dauerhaft passenden Signierschlüssel und die Referenz der
  vorhandenen Installation klären. Der bestehende Workflow erzeugt weiter
  pro Lauf einen Debug-Schlüssel; der neue Nachweis allein behebt das nicht.
  Ohne Referenzpin lautet der Vergleich ausdrücklich `not_checked`.

Die bei dieser Prüfung jüngste vorhandene Veröffentlichung ist
[0.7.0 aus `7c3194db`](https://github.com/Ullmann27/Imperathen/releases/tag/cc0-motion-2026-11-24-7c3194db).
Sie enthält nicht automatisch die späteren AP1/AP2- und Team-C-Änderungen.

## Reproduzierbare Befehle

```bash
python3 -m unittest discover -s tests -p 'android_*_test.py'
python3 tools/check_prototype.py --godot godot --keep-going --report artifacts/team-c/engine
python3 tools/story/audit_screenplays.py /privat/Band2.docx /privat/Band3.docx /privat/Band4.docx --report artifacts/team-c/story-audit.json
```

Die letzten drei Pfade stehen für die privat bereitgestellten Originale.
Beim aktuellen Manuskriptbestand ist Exitcode 1 des Storyprüfers das erwartete
Ergebnis der gefundenen Produktionssprache. Das bedeutet Quellenbefunde,
nicht einen Absturz des Werkzeugs. `--require-all-volumes` verlangt zusätzlich
alle vier Originalbände.
