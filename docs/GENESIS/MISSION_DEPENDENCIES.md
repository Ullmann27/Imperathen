# Quellenbegrenzte Übersicht der Hauptmissions-IDs

## Kurzbefund

Das Kampagnenregister enthält **113 Hauptmissions-IDs**. Das ist die Anzahl der
registrierten IDs – **nicht** die Anzahl nachgewiesen implementierter,
spielbarer oder fertiggestellter Missionen. Im abgegrenzten Ordner
`prototype/assets/story/missions/band1/` liegen JSON-Datensätze zu **14 IDs**:
I-01 bis I-14. Das belegt nur, dass diese JSON-Dateien vorhanden sind; es ist
keine Abnahme ihrer Vollständigkeit oder Spielbarkeit. Zu I-00 gibt es einen
Registereintrag, aber keine entsprechende Missions-JSON-Datei. Für die übrigen
98 IDs gibt es in diesem Missionsordner keine passende JSON-Datei.

Die getrennten Zählungen:

| Missionsfamilie | Hauptmissions-IDs im Register | IDs mit passender Missions-JSON | Sonderfall I-00 ohne Missions-JSON | Weitere IDs ohne passende JSON |
|---|---:|---:|---:|---:|
| I | 32 | 14 (I-01–I-14) | 1 | 17 (I-15–I-31) |
| II | 25 | 0 | 0 | 25 |
| III | 25 | 0 | 0 | 25 |
| IV | 31 | 0 | 0 | 31 |
| **Gesamt** | **113** | **14** | **1** | **98** |

Damit haben 99 der 113 registrierten IDs keine gleichnamige Missions-JSON im
abgegrenzten Ordner: I-00 ist der ausdrücklich getrennt geführte Sonderfall;
die übrigen 98 haben den Status „nur im Register“. Die insgesamt 96
Nebenmissions-IDs sind nicht Teil dieser Matrix.

## Umfang und Beleggrenzen

Die TSV-Matrix wird aus IDs und Titeln in
`prototype/assets/story/campaign_arc.json` sowie strukturierten Feldern der
vorhandenen JSON-Datensätze unter
`prototype/assets/story/missions/band1/` erzeugt. Sie wertet weder Drehbuchprosa
noch `mission_timeline.json` oder andere erzählerische Zusammenfassungen aus.
Die Reihenfolge im Register, Reihenfolge von Bridges und narrative Formulierungen
werden nicht als Abhängigkeiten oder Freischaltbedingungen interpretiert.

Ein vorhandener JSON-Datensatz ist keine Aussage darüber, ob die Mission
vollständig, lauffähig oder im Spiel durchgehend umgesetzt ist. Umgekehrt
beweist das Fehlen einer Missions-JSON in diesem Ordner nicht, dass keinerlei
zugehöriges Laufzeitverhalten existiert: Skripte und andere Quellen wurden
nicht als vollständiger Implementierungsnachweis auditiert. Bei IDs ohne
JSON-Datensatz sind Laufzeitablauf, Wahlmöglichkeiten und Freischaltbedingungen
hier unbekannt.

## Explizit strukturierte Beziehungen

- **Abhängigkeiten:** In den untersuchten Register- und Missions-JSON-Strukturen
  wurde kein explizites Abhängigkeitsfeld gefunden.
- **Voraussetzungen:** In diesen Strukturen wurde kein explizites
  Voraussetzung- oder Prerequisite-Feld gefunden.
- **Wahlmöglichkeiten:** I-01 enthält strukturierte Wahlmetadaten unter
  `slice.steps.i01_choice` und Folgen unter den Schlüsseln
  `slice.consequences.I-01.choice.*`. I-10 enthält die ausdrücklich benannte
  Bridge `i10_choice`. Die Matrix nennt dazu nur Quellpfade beziehungsweise
  IDs, keine Dialoge oder behaupteten Folgen.

Das sind Befunde zu den untersuchten JSON-Strukturen. Daraus folgt nicht, dass
in Laufzeitskripten oder den fehlenden Drehbüchern keine weiteren Bedingungen
oder Verzweigungen existieren.

## TSV-Felder und Statuswerte

Die TSV-Spaltennamen und Statuswerte bleiben englisch, damit der Generator
stabile maschinenlesbare Werte ausgibt:

- `mission_id`, `band`, `title`: Missions-ID, Familie und Registertitel.
- `registry_status`: `installed_json_present` bedeutet: passende JSON-Datei
  vorhanden; `special_registry_only` kennzeichnet I-00; `registry_only`
  bedeutet: Registereintrag ohne passende JSON-Datei im geprüften Ordner.
- `registry_source`, `runtime_source`: Quellpfade. Ein leerer Laufzeit-Quellpfad
  bedeutet, dass in diesem Umfang keine passende Missions-JSON vorliegt.
- `explicit_dependencies`, `explicit_choices`, `explicit_prerequisites`:
  gefundene strukturierte Verweise; `none_explicit_in_scoped_json` heißt, dass
  im geprüften JSON-Umfang kein explizites Feld dazu gefunden wurde.
- `unknowns`: Einschränkungen, die für die jeweilige ID gelten.

Die TSV-Datei enthält keine Drehbuchtexte.

## Fehlende private Originalquellen

Die angeforderte IRON-BANNERS-Projektmappe und die vier Master-Drehbücher liegen
in diesem Checkout nicht vor. Ihre Bereitstellung wurde privat angefragt; die
Originaldateien sind weiterhin nicht verfügbar. Diese Übersicht rekonstruiert
sie nicht und ersetzt sie nicht. Manuskript-Kanon und die daraus möglicherweise
entstehenden Beziehungen bleiben ungeprüft, bis die Originale in einer für
diesen Arbeitsbereich freigegebenen privaten Quelle vorliegen.

## Erzeugen und prüfen

Im Repository-Hauptverzeichnis:

```sh
python3 tools/story/build_mission_dependencies.py
python3 tools/story/build_mission_dependencies.py --check
python3 tools/story/validate_campaign_arc.py
```

Der Generator prüft die vier Familien und ihre erwarteten ID-Folgen, verlangt
für die vorhandenen JSON-Datensätze genau I-01 bis I-14 und unterscheidet I-00
als Sonderfall. `--check` meldet, ob die eingecheckte TSV dem aktuellen
Quellstand entspricht. Der Validator prüft zusätzlich die Registerstruktur
und Gesamtzahl der Hauptmissions- und Nebenmissions-IDs.
