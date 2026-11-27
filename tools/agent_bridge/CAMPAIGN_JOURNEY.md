# Chronologische Kimi-Spielentwicklung

Die Reihenfolge wurde aus dem tatsächlich vorhandenen campaign_arc.json (9fa7b141fe7800e1e04a6142a6fd56d4f3c7505c) übernommen: 113 kanonische Missionsdefinitionen in vier Bänden, Hauptmenü und 8 zusätzliche Weltsysteme. Das ist keine Aussage darüber, welche Missionen bereits spielbar sind.

## Bedienung

- `python3 tools/agent_bridge/campaign_journey.py init` erzeugt einmalig die Fortschrittsdatei (existierende Datei wird nicht überschrieben).
- `python3 tools/agent_bridge/campaign_journey.py plan` liefert die nächste Aktion. Nur bei `kimi_candidate` ist ein API-Auftrag zulässig; `--manifest-out` erzeugt das kompatible Einzelmanifest.
- `python3 tools/agent_bridge/campaign_journey.py record --event <geprüfte-event.json>` dokumentiert ausschließlich vom Orchestrator verifizierte Ergebnisse. Ein Modell darf weder eigene Belege noch Freigaben schreiben.
- Baseline → Kritik → kleiner Patch → echter erneuter Render/Test → unabhängiger Vergleich → Geräteprüfung. Wenn V2 nicht genügt, wiederholte Überarbeitung. Bei einem blockierenden Fehler bleibt die Etappe offen. ENGINE_REVIEWED erlaubt Weiterentwicklung des nächsten Abschnitts, nicht die endgültige Freigabe. Erst passende physische Fold7-Belege und unabhängiger visueller Vergleich erlauben ACCEPTED.
- Erstes echtes Capture: Branch review/kimi-campaign-start-20261127, Workflow Kimi campaign start - real engine evidence. Das Capture nutzt vorhandene echte Menü-/I01-Durchläufe; es veröffentlicht nur hashgeprüfte Bilder und Receipt unter art/review/campaign-start. Der Orchestrator verifiziert Run, tatsächlich publizierten Commit, Bildhash und Übereinstimmung der Quellcode-Dateien mit dem gerenderten Commit. Keine erfundenen oder alten Aufnahmen als aktuellen Nachweis.
- Keine parallele NVIDIA-Ausführung; max reasoning, 16384 Token, JSON, 1–2 eng relevante Quellen, 1–2 Bilder. Bei Blockade Ursache reparieren; nicht mit niedrigerer Modellleistung oder unkontrollierten Retries umgehen.
- Bestehender Direct Editor erzeugt begrenzte Kandidaten, die unabhängig geprüft werden. Keine Modelltexte in Shell ausführen und keine Zugangsdaten an Kimi weitergeben. Der Agentenplaner selbst verfügt über keine Schreibrechte oder Netzwerkzugriffe.
