# IMPERATHEN · Sechs geprüfte Marktstandorte im Stadtrundgang

Stand: 25. November 2026. Zusätzlicher, kleiner Arbeitszweig auf dem
bestehenden Stadtanschluss aus [PR #60](https://github.com/Ullmann27/Imperathen/pull/60).
Die frei begehbare Stadt, der Meshy-Junge, Kamera, Speichervertrag, Tempel,
Stadtgeometrie und sämtliche bestehenden Handels- und Kampfsysteme bleiben erhalten.

## Warum die bisherigen Test-Shopkoordinaten nicht direkt übernommen wurden

Der echte Stadtgenerator `tools/world/build_roman_test_city.py` zeichnet 63
Marktstände in der Blender-Reihe **Y = −47 m**. Beim Godot-glTF-Export liegt
deren Mitte bei **Z = +47 m**. Die sechs Läden des separaten Marktprototyps
aus PR #62 benutzen dagegen Teststandorte in einem 54 × 46-m-Probeviertel.
Ihre Koordinaten dürfen nicht als reale Gebäude in der großen Stadt ausgegeben
werden. Eine Transaktion muss später genau bei dem tatsächlichen Stadtstand
mit der gleichen `shop_id` gültig sein.

Die hier gewählten sechs Originalstände befinden sich nahe dem Stadtzentrum.
Ihre Gütertypen entsprechen den vorhandenen geometrischen Sortimenten.
Die zusätzliche Beschilderung ist zunächst **lesbar, aber nicht interaktiv**.

| Sortiment | Authored node im Stadt-GLB | Godot X / Z (m) |
|---|---|---:|
| Lebensmittel | `Market_29_Type0_Build1_Size1` | −37,258 / 47 |
| Brot | `Market_31_Type2_Build1_Size1` | −12,419 / 47 |
| Töpferei | `Market_32_Type3_Build1_Size1` | 0 / 47 |
| Tuch-/Lederwaren | `Market_33_Type4_Build1_Size1` | 12,419 / 47 |
| Ausrüstung | `Market_34_Type5_Build1_Size1` | 24,839 / 47 |
| Garküche/Trinken | `Market_35_Type6_Build1_Size1` | 37,258 / 47 |

Die Positionen wurden aus der *tatsächlichen Generatorformel* errechnet,
nicht nach Augenmaß gewählt. Die JSON-Datei
`prototype/assets/city_detail/shops/city_market_anchors.json` vermerkt auch
den exakten Git-Blob-Hash des dazu geprüften Blender-Skripts. Ändert sich
der Generator, fordert das Validierungswerkzeug einen erneuten Abgleich.

## Implementiertes Verhalten

- `CityMarketSignage.install(city, profile)` setzt sechs hölzerne Schilder
  mit deutschsprachigen Ladenbezeichnungen auf die bestehenden
  Meshes; er erzeugt weder Kollisionen noch eine weitere Kamera oder Figur.
- Das vorhandene Stadtskript ruft diesen Adapter nach dem bereits
  integrierten Pflaster-/Marktdetailadapter auf und protokolliert das Ergebnis.
- **Low** lässt die optionale Beschilderung weg, **Balanced** begrenzt die
  Sicht auf 58 m, **High/Very High** auf 90 m.
- Wiederholtes Anwenden ersetzt nur eigene Schilder. Bei fremden
  gleichnamigen Gruppen, veränderter Quelldatei oder fehlenden Originalständen
  wird der Bestand nicht angetastet.
- `read_only=true` und `trading_enabled=false` sind ausdrücklich im
  Integrationsbericht enthalten. Eine Testszene wird weder gestartet noch
  als zusätzliche Stadtszene geladen.

## Nachweise und künftige Verbindung

Die Dateien `tools/city_detail/check_market_anchors.py` und
`prototype/tests/city_market_signage_test.gd` prüfen die Herkunft,
Stalltypologie, Formeln, Knotennamen, Profile, unveränderte Originalmeshes,
Kamerazahl, Kollisionsfreiheit, wiederholte Installation und Fehlerpfade.
Der eigene Workflow lädt eine SHA-512-geprüfte Godot-Engine 4.7.2 und
führt zusätzlich den vorhandenen Stadtarchitektur-Adaptertest aus.

**Nicht geliefert:** Käufe durch die große Stadt, neue Animationen,
vollständig animierte Verkäufer, integrierte NPC-Tagesabläufe, visuelle
GPU-Aufnahme dieses Zusatzes, Android-Test und eine neue APK. Der getrennt
getestete Handelsdienst aus [PR #62](https://github.com/Ullmann27/Imperathen/pull/62)
und die [Inventar-UI-Korrektur #63](https://github.com/Ullmann27/Imperathen/pull/63)
müssen mit dem Stadtzweig abgestimmt werden. Für den Händlerzugriff ist ein
eindeutiger autoritativer WorldModel-Zustand zu verwenden; dabei sind die
ursprünglichen Spielstandkoordinaten beim Besuch zu bewahren und das
bestehende Handelsprotokoll wiederholungsfest zu erhalten. Eine einfach
lokal versetzte UI ohne entsprechende Domänenprüfung wäre unsicher.

Keine Änderung nach `main`.
