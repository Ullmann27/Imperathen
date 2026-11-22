# Android-Grafikmessung

Das Standard-APK startet mit Godots Compatibility-Renderer. Das zusätzliche `*-arm64-vulkan.apk` verwendet dieselbe Spielrevision, Paket-ID und Signatur aus demselben CI-Lauf und fordert den Mobile-Renderer an. Android kann beim Wechsel zwischen diesen beiden Paketen innerhalb desselben Laufs die vorhandenen App-Daten behalten. Für Vergleiche zwischen verschiedenen CI-Läufen sind die jeweiligen Debug-Signaturen zu beachten.

## Durchführung

Der Workflow `Android prototype APK` exportiert auf dem Branch `integration/realistic-android-23` beide ARM64-Varianten und je ein passendes x86_64-Testpaket. Ein API-35-Emulator durchläuft zunächst den normalen Spieltest mit ADB-Berührungen, Speichern, Fortsetzen und Größenwechsel. Die anschließende Grafikmessung verwendet seinen bestehenden Dorfspielstand.

1. Der Treiber öffnet den Spielstand und schaltet in der sichtbaren Dorfwelt nacheinander Leicht, Ausgewogen, Hoch und Sehr hoch ein. Der Profilwechsel verwendet denselben Einstellungspfad wie das Dorfmenü.
2. Im echten Talübungsszenario wählt er die Grafikstufe über die Signale der Tal-HUD-Steuerung und löst „Fortsetzen“ aus. Die Kamera behält die Spielansicht. Nach dem Gefechtsende öffnet der Treiber das Übungsszenario erneut. Nur zusammenhängende Frames bei laufender Simulation zählen. Aufrufe zwischen Gefechten, Laden und Pausen zählen nicht.
3. Jedes Profil muss wenigstens 300 aktive Wandzeitsekunden erreichen und tatsächlich weiterlaufende Simulationsticks nachweisen. Fehlender Fortschritt, ein beendeter Prozess oder Laufzeitfehler führen zu einem fehlgeschlagenen Test.
4. Anschließend prüft ein kurzer separater Dorfstart die tatsächliche Renderer-Methode, den Treiber, den Adapter und die Prozess-ABI im Vulkan-Paket. Die native x86_64-Probe und der Start des identischen ARM64-Downloads unter angebotener ARM-Übersetzung erhalten getrennte Berichte.

## Messwerte lesen

Das Artefakt `imperathen-android-runtime-…` enthält unter `android-runtime/` folgende Dateien.

| Pfad | Inhalt |
| --- | --- |
| `runtime-report.json` | Standard-Spieltest, Gerätekennung, ABI und SHA-256 des ARM64-Downloads |
| `soak/report.json` | Aktive Sekunden, Simulationsticks, mittlere FPS, Framezeit sowie Render-CPU/GPU P50, P95 und P99 je Profil, Spitzenwerte und Überschreitungen der Prüfbudgets |
| `soak/frames.jsonl` | Zeit zwischen zwei Prozessframes in Millisekunden und die pro Frame verfügbaren Godot-Viewport-Renderzeiten. Die Zusammenfassung verwendet den nächsten Rang in der sortierten Liste. |
| `soak/system.json` | Wiederholte ADB-Abfragen mit Originalausgabe von `dumpsys meminfo`, `thermalservice` und `battery`, einschließlich PSS und RSS in KiB |
| `vulkan/report.json`, `vulkan-arm64/report.json` | Tatsächlich gewählter Renderer, Treiber, ABI, Übersetzung und eigener APK-Hash. `vulkan_mobile_verified` erfordert sowohl `mobile` als auch `vulkan`. |

Die Prüfbudgets in `prototype/assets/quality_profiles.json` sind Vergleichsgrenzen für Draw Calls, sichtbare Primitive, Grafikpuffer, Texturen, Lichtquellen, animierte Talfiguren, Schlüssel geteilter Animationen und Prozess-PSS. Sie verändern keine Spielregeln. „Primitive“ stammt direkt aus dem Viewport und kann auch Linien oder Punkte enthalten. Die Grafikpufferzahl umfasst weitere Puffer neben Mesh-Daten. Animationen teilen Ressourcen zwischen Figuren. Die Bestandsaufnahme zählt ihre Clips und Schlüssel einmal pro Ressource. Für einen eigenen Animations-RSS liefert die Engine keinen Zähler.

Die Übersichtsdiagnose zeigt im Spiel P50/P95/P99 der letzten bis zu 180 Prozessframes. Der Langzeitbericht aggregiert sämtliche aufgezeichneten Frames des jeweiligen Profils. `null` steht für einen fehlenden Zähler. Ein Emulator kann virtuelle Temperaturen und einen unveränderten Akkustand melden. Belastbarkeit, Wärmeentwicklung und Akkulaufzeit auf realen Telefonen erfordern denselben Versuch auf den konkreten Geräten.
