# IMPERATHEN · Detail- und Integrationsinventur

Prüfdatum: 25.11.2026. Grundlage: direkt gelesene GitHub-Arbeitszweige und
Dateiinventare, nicht die Aussage, dass ein anderer Chat gerade automatisch
mit diesem Arbeitszweig verbunden wäre.

## Tatsächlich im Stadtrundgang

- `feature/meshy-player-city-exploration-20261125`: originale begehbare,
  unabhängig gespeicherte Teststadt; laut Generator **240** Wohnhausinstanzen
  aus fünf Grundformen mit drei Varianten sowie **63** Marktstände. Eigene
  Testfigur, Kamera, Kollision und ungebundene Modellgalerie. Keine
  Kampagnenökonomie im Freigehen.
- [#60](https://github.com/Ullmann27/Imperathen/pull/60):
  15 originale Steinpflastermodule im lokalen Korridor sowie Amphoren
  und eine Theke neben vorhandenen Marktständen; kein Warentransfer.
- [#64](https://github.com/Ullmann27/Imperathen/pull/64):
  sechs aus dem echten Blender-Generator abgeleitete Ladenstandorte,
  beschildert und ausdrücklich ohne Handel.
- **Dieser Zweig**: optionales, GPU-instanzierte Nahbereichsdetail auf
  vorhandenen Wohnfassaden und abgewittertes Pflaster. Kein Wechsel
  der Originalgebäude, Körper, Kollisionen oder Zeitrechnung.

## Bereits entwickelt, aber nicht als Bestandteil des großen Stadtrundgangs abgenommen

| Quelle | Gesichert vorhanden | Fehlender Produktionsanschluss |
| --- | --- | --- |
| [#58 Weltbau](https://github.com/Ullmann27/Imperathen/pull/58) | 7 editierbare Blenderquellen, 21 GLB-LODs: Taberna, Insula, Basilika, Steinweg, Feldulme, Zypresse, Lorbeer; Windshader; eigene Vorschau | Läuft als separate Weltwerkstatt. Der begehbare Stadtgenerator verwendet diese Asset-GLBs und Wind-Controller noch nicht. Bäume brauchen Laufzeit-LOD, Kollisions-, Schatten- und Windprüfung. Die 4.000er Vorschau ist keine gleichzeitig bewohnte freie Stadt. |
| [#59 Materiallabor](https://github.com/Ullmann27/Imperathen/pull/59) | PBR-Karten u. a. zu Eisen, Holz, Kalkputz und Leder sowie Materialvorschau | Vorschau ist keine nachgewiesene flächendeckende Materialübernahme in Stadt-, Figuren- und Rüstungsmodelle. UV-Ausrichtung, Tangenten und gerätespezifische Kosten sind einzeln zu prüfen. |
| [#57 Innenräume](https://github.com/Ullmann27/Imperathen/pull/57) | Zum geprüften PR-Stand ausschließlich ein Koordinationsvertrag | Modelle, drei Innenräume und Händlerdienste nicht aufgrund dieses PR als geliefert behaupten. |
| [#62 Handel](https://github.com/Ullmann27/Imperathen/pull/62) | Sechs Handelsstellen, 16 Waren, Kauf/Verkauf, Essen, Ausrüstung und Soldatenbelohnungen in einer tatsächlich getesteten **separaten** Marktprüfszene; eigene editierbare Blenderquellen und Gesichtsmaterialien | Eine Transaktion in der **großen** freien Stadt ist noch nicht eingeschaltet. Standort-, Save- und Spielfigurautorität dürfen nicht dupliziert werden. |
| [#63 Inventarbedienung](https://github.com/Ullmann27/Imperathen/pull/63) | Geprüfter UI-Fix zum Ablegen angelegter Gegenstände | Ein eigenständiger PR; erst nach Integration mit dem Handelszweig in der gewünschten Testfassung verfügbar. |
| [#61 Figurenbewegung](https://github.com/Ullmann27/Imperathen/pull/61) | Weitere Bewegungs-/Skelettkorrekturen im Team-A-Zweig | Solange die strengen Bewegungs- und visuellen Prüfungen nicht vollständig abgenommen sind, keine Behauptung endgültig natürlicher NPC-Bewegungen. |
| [#65 NPC-Sicht](https://github.com/Ullmann27/Imperathen/pull/65) | Neu entwickelter physischer Gesprächs-/Blickkontakt-Gate mit gezielten Regressionsprüfungen | Getrennter Team-B-Entwurf. Sein erfolgreicher Engine-Test und anschließender Zweigabgleich sind vor Freigabe nötig. |

## Historischer und visueller Detailanspruch

Die bestehende Stadt enthält Bauwerke aus unterschiedlichen Epochen
(amphitheatrum nach 80 n. Chr., Thermen nach 216 n. Chr.). Ihr freier
Modellpark zeigt sie zu Reviewzwecken gemeinsam. **Die auf 58 v. Chr.
datierte Handlung darf diese spätere Architektur nicht ungeprüft
als zeitgleich zeigen.** Die `era_min_ce`-Markierungen des Generators
müssen bei tatsächlicher Storyweltaktivierung die Sichtbarkeit steuern.

Die neue Oberflächenarbeit begrenzt sich absichtlich auf real
identifizierte Wohnhausfassaden nahe der freien Startposition. Es
werden keine Fenster, Türen, Dachkonstruktionen oder begehbaren Räume
durch die Zierdetails verdeckt. Farbtöne sind eigenständige
Gestaltungsentscheidungen, keine archäologisch gemessene
Farbkartierung des antiken Aquileia.

## Verbindliche noch offene Abnahmen

1. Original-Stadtansicht und Nachher-Bildpaar mit identischer Kamera.
   Der isolierte Mesh-/Physiktest beweist die Integrität des
   Anschlusses, ersetzt aber keine Sichtprüfung vor Ort.
2. Einheitliche Wirtschaftsautorität: Händlerentfernung in
   realen Stadtkoordinaten, eine Quelle für Denare/Inventar und
   saubere Save-Migration ohne Überschreiben von Kindheitssaves.
3. Körpergeste = tatsächlicher Sichtkontakt + passender Abstand +
   gegenseitige Gesprächsentscheidung; keine gespeicherte
   Partnerkoordinate als Beweis einer anwesenden Person.
4. Realer Android-Fold7-Test für GPU-Bildzeiten, Materialschärfe,
   Wärme, Touch, Straßenhöhe, Lod-Popping und Speichern.
5. Unverbundene Blender-/Meshy-Assets nur nach geprüftem
   Import, Skelett-/Socket-/Textur-/Collision- und Lizenzvertrag
   in die Runtime aufnehmen.

Kein Merge nach `main` und keine automatische APK-Freigabe.
