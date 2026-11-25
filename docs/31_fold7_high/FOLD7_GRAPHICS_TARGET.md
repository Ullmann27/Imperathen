# IMPERATHEN – Fold7-Grafikvertrag: Hoch und Sehr Hoch

Stand: 25.11.2026. **Entwicklungs- und Abnahmevertrag, kein bereits erreichter FPS-Wert.**

## Ziel und ehrliche Aussagegrenze

Die zuvor KI-generierte IMPERATUM-ROME-Marktszene ist ein **visuelles Leitbild**,
kein Godot-Bild und kein Android-FPS- oder Temperaturbeleg. Der Projektname
bleibt **IMPERATHEN**. Die eingeblendeten 58 FPS/97 % GPU/42 °C sind
erfundene Bildelemente und dürfen nie in Telemetrie, Screenshots oder
Freigabeberichte übernommen werden.

Zielgerät: Samsung Galaxy Z Fold7, Android 17, Adreno 830.
Die Engine und Grafikprofile sind aktuell Godot 4.7.2 / GL Compatibility.
Vulkan Mobile, HDR und mehrstufige Posteffekte werden nicht ohne echten
Renderervergleich versprochen oder stillschweigend aktiviert.

| Profil | FPS-Obergrenze | Bereits vorgegebene 3D-Pixelobergrenze | Ziel |
| --- | ---: | ---: | --- |
| Hoch | 60 | 3.686.400 | Bevorzugter Ausgangsmodus für die erkannte Adreno-830-Android-Geräteklasse |
| Sehr Hoch | 30 | 5.760.000 | Optisch aufwendigerer, ausdrücklich anwählbarer Modus |
| Ausgewogen | 60 | 2.073.600 | Bestehende sichere Rückfallstufe, besonders für andere Geräte |
| Leicht | 30 | 921.600 | Bestehendes Minimalkostenprofil |

Die Auflösungsbudgets sind keine garantierte Bildrate und kein
Gerätespeicherwert. Ein Smartphone kann auch bei 30 FPS warm werden,
je nach Akkuzustand, Raumtemperatur und dauerhafter GPU-Arbeit.

## Tatsächlich integrierte Qualitätssteuerung

- Bei einer **neuen Installation ohne vorhandene Grafikeinstellung**
  empfiehlt die UI `Hoch` genau dann, wenn Android und ein gemeldeter
  Videoadapter mit `Adreno 830` erkannt werden. Die Zeichenfolge erkennt
  nur eine GPU-Familie, **nicht eindeutig das Fold7-Gerätemodell**.
  Bestehende Nutzereinstellungen behalten Vorrang.
- `RuntimeDisplay` überwacht die aktive freie Stadtszene auch bei
  ausgeblendetem Entwickler-Diagnosefenster. Die Daten stammen aus
  monoton gemessenen Frameintervallen und, falls verfügbar, echten
  Renderzeitmessungen des Renderers.
- Erst **drei aufeinanderfolgende überlastete Zeitfenster** verringern die
  3D-Auflösung um maximal 0,06 Skaleneinheiten. Nach einer Anpassung
  sperrt ein Cooldown weitere unmittelbare Änderungen. Die Mindestfaktoren
  betragen 0,70 (Hoch) und 0,68 (Sehr Hoch), jeweils multipliziert mit
  dem vorhandenen, aus Pixelzahl berechneten Profil-Renderfaktor.
- Automatische langsame Rückkehr zur höheren Auflösung erfolgt
  ausschließlich bei **gemessener freier GPU-Renderzeit**, nicht durch
  bloßes Ableiten aus einer FPS-Begrenzung. Fehlen GPU-Messwerte,
  bleibt die niedrigere Skalierung bis zur Profilneuwahl oder zum
  Szenenwechsel bestehen; das wird nicht als thermische Erholung bezeichnet.
- Die 2D-/Touch-Oberfläche wird nicht herunterskaliert.
  Spielfigur, NPC-Kollision, Missionen, Wirtschaft, Gamedata und
  Speicherstand werden durch den Governor **nicht verändert**.
- Pause, Shop-Overlay, Fokusverlust und Hintergrund wechseln die
  Sampling-Regeln und verhindern, dass Standbilder als belastbare
  60-FPS-Spielmessungen ausgegeben werden. Nach Szenenende beginnt
  der nächste Besuch wieder mit dem gewählten Qualitätsbudget.
- Der Diagnosereport nennt nur beobachtete Frame-/Renderzeitdaten.
  Temperatur bleibt `thermal_measured=false`, bis ein
  tatsächlich erfasster Android-Thermalservice-Wert mit Quelle vorliegt.

## Laufzeit-Bildgestaltung – aktuelle Integration

Der gemeinsame Stadtarbeitszweig besitzt bereits die optionalen
VIVA-ROMA-Boden-/Atmosphärenshader, Materialausarbeitung an
Hauptfigur und Architektur, bepflasterte Straßen, Fassaden-MultiMeshes,
Marktschilder, Crowd-/Ambient-Figuren und eine getestete Handelsbrücke.
Das bedeutet **Quellintegration**, nicht automatisch einen vollständig
auf dem Fold7 freigegebenen 4K- oder Ultra-Fotorealismus-Modus.

Für die vom KI-Bild gezeigte Oberfläche müssen die realen, vorhandenen
Handlungen genutzt werden: Kamera, Bewegung, Kampf, Interaktion,
Handelsfenster, Inventar und Pausensystem. Zusätzliche Buttons wie
Provinzverwaltung, strategischer Truppenbefehl, Pferd und Fähigkeiten
dürfen nicht als funktionsfähig angezeigt werden, bevor sie tatsächlich
an eine Spielhandlung gebunden und in der Android-Testfassung geprüft sind.

## Reproduzierbare Freigabekriterien

1. Import, neuer Governor-Test und bestehender Display-Lebenszyklustest
   auf **dem exakt selben Commit**. Keine synthetische Kamera-Grafik
   als Nachweis von Stadt-FPS.
2. Reale Bildaufnahmen auf dem Fold7: 3D-Markt, Straße, Fassade,
   Nahporträt, Vegetation, Händlerdialog und Kampf jeweils mit
   **gleicher Kamera, Uhrzeit, Szene und Qualitätsprofil**.
3. Pro Profil mindestens **20 Minuten** zusammenhängender
   realer Stadtrundgang mit festgehaltenem Batteriestand,
   Helligkeit, Ladezustand und Umgebung. Protokolliert werden
   tatsächliche Bildzeit P50/P95/P99, GPU-Zeit (falls verfügbar),
   CPU-Auslastung, RSS/PSS, Grafikauflösung und allfällige
   thermische Drosselung (nur mit tatsächlicher Sensorquelle).
4. Touch in allen Ausrichtungen, Fold/Unfold, Pause/Resume,
   Einkauf, Speichern/Laden sowie NPC-Kollisionen dürfen nicht
   durch die Skalierung beeinflusst werden.
5. Erst nach bestandener App-Integration und Signaturvergleich
   wird eine neue APK mit bestehender Paketkennung als
   installierbarer Kandidat bezeichnet.
6. Bewegungsgate und visuelle Genehmigung müssen zusätzlich
   bestanden sein. Ein erfolgreicher Display-Test ersetzt kein
   AAA- oder Release-Gesamtgate.

Eine unbelegte thermische Temperaturgrenze oder ein fiktiver
GPU-Prozentwert ist ausdrücklich **kein** Freigabekriterium.

Referenz-API: https://docs.godotengine.org/en/stable/classes/class_viewport.html
und https://docs.godotengine.org/en/stable/classes/class_renderingserver.html

Kein automatischer Merge nach `main`.
