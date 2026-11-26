# Aeterna II – Integrations- und Reparaturübergabe

## Ausgangspunkt und Grenzen

- Gemeinsamer Basisstand: PR #126, `1ab12647deafb8645c97b327fc584587b962343e`.
- Lebenssimulation: PR #121, `c2d4ab3b9b3f78a1db6f2b95773acc64b28037ef`, mit eigener Merge-Historie und zusammengeführtem Test-Runner.
- PR #127 ist ein Draft, keine Freigabe. Keine Änderung an main, kein Release.
- GitHub-Connector statt lokalem Checkout; Godot, Blender und Android-Runtime waren in der Sitzung nicht verfügbar. Sämtliche neuen Engine-Tests sind unbestätigt.

## Jetzt implementiert

- Vollständige Domänenübernahme aus #121; Originaldateien außer dem gezielt korrigierten Handel und Test-Runner bleiben erhalten.
- Exakte, vorab validierte Geld-/Warenbuchung; unbekannte Artikel, fehlende Waren und ungedeckte Verkäufe werden ohne Zustandsänderung abgewiesen.
- `city_life_session.gd`: externe Kalenderbindung, monotone Zeit, budgetierte Aufholverarbeitung, explizite Ablehnung eines nicht migrierten Epochenwechsels und Schnittstelle für die spätere einheitliche Persistenz.
- `city_market_bridge.gd`: echte vorhandene WorldModel-Kauf-/Verkaufskommandos im **nicht persistenten QA-Modus** mit der Stadtökonomie gekoppelt; fehlgeschlagene WorldModel-Kommandos buchen nicht im Stadtbuch. Ein Fehler nach dem WorldModel-Kommando führt zur Rücknahme des Kandidaten. Persistenter Modus wird absichtlich nicht gekoppelt, bevor der einheitliche Save-Vertrag steht.
- `city_exploration.gd`: expliziter QA-Schalter `enable_living_city_qa` (nur bei `persist=false`), Szenenknotenprüfung für Aktivitätsanker und `set_living_city_clock` für externe Weltuhr. Keine zweite autonome Uhr. Kein Umschalten des Produktionsmodus.
- Tests: `city_life` und `city_market_bridge` um Zustands-/Währungs-/Waren- und Uhrprüfungen erweitert.

## Verbindliche Reihenfolge für parallele Agenten

| Zuständigkeit | Offener Anschluss | Abnahmekriterium |
|---|---|---|
| Integration / Save | Ein WorldModel-Transaktionsvertrag für Stadtzustand, Kalender, Geld, Waren, Inventar und Queststatus; atomare Speicherung und Altspielstandmigration. | Korruptions-/Rollback-/Doppelbuchungs-Tests; keine getrennte produktive Stadtgeldbörse. |
| Living World | Sichtbare Bewohner aus city_life anhand stabiler IDs, Routen, Anker, Tätigkeiten; bestehende Ambient-/Crowd-Modelle kontrolliert ablösen. | Keine Doppelpersonen, keine Kollision mit alten Statisten, Fußkontakt, reproduzierbarer NPC-Alltag, reale 3D-Durchläufe. |
| Assets / Stadt | #119 Ausrüstungsmarkt und #120 Kolosseum auf #126/#127 abgleichen; keine Überschreibung der neuen Handwerks-/Töpfergasse oder Pferdeläden. | Asset-/Lizenzprüfung, Epochenfilter, Kollision, LOD und begehbare Räume. |
| Story / Motion | Marcus, Kindheitsabschnitte I-01 ff., bestehende Dialog- und Bewegungsarbeit bewahren; #117/weitere Bewegungszweige gegen aktuellen Stand prüfen. | Echter zusammenhängender Durchlauf; Motion-Gate und Kontaktbefunde. |
| Render / Performance | #123 Hotspots einzeln übernehmen, #116 Vegetation und #122 Stimmen anhand tatsächlicher Integration prüfen. | Messwerte pro Grafikprofil, echte Renderbelege, keine Verschlechterung der Steuerung. |
| Delivery | Erst vollständige Regression und Motion-Gate, dann ARM64-QA-APK mit vorhandenem Signiervertrag; Fold7-Geräteprüfung separat. | Nachvollziehbare Testprotokolle, kein Merge nach main ohne Freigabe. |

## Nächste ausführbare Checks

```sh
python3 tools/check_prototype.py --only city_life city_market_bridge
python3 tools/check_prototype.py
```

Zusätzlich vorhandenen Straßengraph gegen die erweiterte Stadt aus #126 neu backen und Kollisionen in Godot prüfen. Der Graph aus #121 ist unverändert und erfasst die neuen Viertel nicht automatisch. Die synchronisierte QA-Sitzung ist kein Ersatz für den noch zu implementierenden einheitlichen Kampagnenspielstand und keine sichtbare Menge. Die Stadtwirtschaft muss auf tatsächliche Preis-/Warenangebote, neue Pferde- und Ausrüstungsläden, Zeitmigration und die Render-LOD-Schnittstelle abgestimmt werden. Nicht gemessene FPS oder Tests nicht als bestanden ausgeben.
