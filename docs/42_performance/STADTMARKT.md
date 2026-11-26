# Laufzeitprofil des bewohnten Kampagnenmarkts

Die Messzeuge stammen aus PR #123, Quellcommit `350496da0a518d1444f420e4aca80de3f00af628`. Die neue Szene `campaign_market` lädt den vorhandenen I‑02-Migrationsspielstand über das Hauptmenü, besucht den Markt über die Kampagnenpause und wartet am Ankunftspunkt auf die besetzte Bäckerei. Zeit und Bewohner stammen aus der laufenden Kampagne. Der Anlauf ruft die gewöhnliche budgetierte Synchronisation auf. Er zeichnet die aktive Welt beim Gang zum Verkaufstresen auf.

```bash
python3 tools/perf/runtime_profile.py --scenes campaign_market --label stadtmarkt \
  --frames 120 --warmup 10 --repeat 1 --natural-only --render \
  --render-frames 64 --render-warmup 8 --width 640 --out /tmp/imperathen-profile
```

Der Renderlauf verwendet das vorhandene Display oder startet Xvfb. Jeder Durchlauf erhält ein frisches Benutzerverzeichnis. Das Laden der Startdatei und das Aufholen der Weltzeit erfolgen vor dem Render-Warm-up. Die vier Stufen verwenden dieselbe Startdatei und denselben Controller. Ihre unterschiedlichen Sichtbudgets dürfen eine andere Zahl an Körpern darstellen. Im Ergebnis stehen die tatsächlich verkörperten Personen-IDs, die Zahl verarbeiteter Ereignisse, der verstrichene Simulationsabschnitt, die Gehstrecke und die Engine-Zähler. Die isolierte CPU-Messung und der grafische Lauf stehen in eigenen Einträgen. CPU-/GPU-Renderzeit bleibt bei fehlender Treiberunterstützung null im JSON. Fest eingestellte 60 Simulationsschritte pro Sekunde sind kein Nachweis für 60 gerenderte Bilder pro Sekunde.

Der kurze Desktoplauf dient zur Fehlersuche und zum Vergleich identischer Szenen. Er belegt keine Geräte-FPS und kein Wärmeverhalten. Niedrige Stichprobenumfänge begrenzen vor allem die Aussagekraft von p99.
