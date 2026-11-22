# Drei Agents: Arbeitsverteilung und Prüfung

**Auftrag vom 22.11.2026:** Den Spielbeginn gemeinsam aufbauen, bereits laufende Arbeit bewahren und die Zusammenarbeit ausführbar organisieren. Koordination: [Issue #16](https://github.com/Ullmann27/Imperathen/issues/16). Die Pipeline benötigt Python 3.10 oder neuer und für JavaScript-Prüfungen eine Node-Version mit `node --test` und ES-Modulen. Die tatsächlich verwendeten Versionen gehören in den Liefernachweis.

## Zuständigkeiten

Das verbindliche Aufgabenmanifest liegt in [`coordination/tasks.json`](../../coordination/tasks.json). Es beschreibt drei Rollen und ihren Dateibesitz:

| Agent | Dateien | Übergabe nach |
| --- | --- | --- |
| `foundation_qa` | `preview/core/**`, `tests/core.test.mjs` | Bestandenen Kernprüfungen |
| `frontend_intro` | HTML, CSS, App-Steuerung und Assets unter `preview/` | Kernübergabe und bestandener Syntaxprüfung |
| `pipeline` | Pipeline, Manifest, Workflow, diese Anleitung und Pipeline-Tests | Beiden vorherigen Übergaben und bestandenen Pipeline-Tests |

Root integriert den Engine-Unterbau, Start-/Buildwerkzeuge, Projektstatus und die tatsächliche Sicht- und Bedienprüfung. Die reservierten Integrationspfade im Manifest verhindern widersprüchliche Zuständigkeiten innerhalb dieses Ablaufs. Neue gemeinsame Dateien werden vor Bearbeitung ausdrücklich zugeordnet.

Die drei Agents können gleichzeitig implementieren. Abhängigkeiten betreffen die abschließende Übergabe, nicht das Anlegen eines Claims. Ein Claim und die Rollenbezeichnung sind **Koordinationshilfen**, keine technischen Schreibrechte, keine Identitätsprüfung und kein Schutz gegen andere Programme. Die Pipeline startet keine zusätzlichen KI-Agents und verschickt keine Nachrichten an fremde Dienste. Abstimmung geschieht im aktiven Agententeam und nachvollziehbar im Koordinationsissue.

## Bedienung

Alle Befehle werden im Repository-Hauptverzeichnis ausgeführt:

```sh
python3 tools/agent_pipeline.py status
python3 tools/agent_pipeline.py check
python3 tools/agent_pipeline.py claim foundation_qa --agent foundation_qa
python3 tools/agent_pipeline.py run --task foundation_qa
python3 tools/agent_pipeline.py handoff foundation_qa --agent foundation_qa --summary "Spielzustand und Speicherung implementiert; Kernprüfungen bestanden." --evidence preview/core/game.mjs --evidence tests/core.test.mjs
```

Für `frontend_intro` und `pipeline` gelten dieselben Befehle mit ihrer Aufgabenkennung und ihren eigenen Nachweisdateien. Vor der Übergabe müssen die festgelegten Checks bestanden sein. Der gespeicherte Fingerabdruck des gesamten eigenen Dateibereichs muss noch dem geprüften Stand entsprechen. Eine bloße Erfolgsaussage in der Zusammenfassung genügt nicht.

Nach einer Übergabe neue Änderungen ausdrücklich beginnen und anschließend erneut prüfen und übergeben:

```sh
python3 tools/agent_pipeline.py claim frontend_intro --agent frontend_intro --reopen
python3 tools/agent_pipeline.py run --task frontend_intro
```

Eine übergeordnete Aufgabe wird vor Änderung ihrer bereits übergebenen Abhängigkeit ebenfalls wieder geöffnet. Andernfalls meldet die gemeinsame Prüfung die fehlende aktuelle Abhängigkeit. Der Integrator prüft am Ende:

```sh
python3 tools/agent_pipeline.py check --require-ready
python3 tools/agent_pipeline.py run
```

`check` prüft das Manifest, überschneidende Pfade einschließlich noch nicht angelegter Unterverzeichnisse, Abhängigkeitszyklen, lokale Claims und vorhandene Übergabenachweise. Der Zusatz `--require-ready` verlangt gültige Übergaben aller drei Rollen. Ein frischer Checkout hat ohne lokale Sitzung offene Aufgaben; das Manifest beschreibt den wiederholbaren Arbeitsablauf und behauptet keinen historischen Testlauf. Der gelieferte Quellstand und seine tatsächlich ausgeführten Prüfungen werden separat im Projektstatus dokumentiert.

## Was `run` tatsächlich ausführt

| Kennung | Fest im Werkzeug hinterlegter Befehl | Aussage |
| --- | --- | --- |
| `core-tests` | `node --test tests/core.test.mjs` | Verhalten des unabhängigen Spielzustands |
| `frontend-syntax` | `node --check preview/app.mjs` | JavaScript ist syntaktisch lesbar |
| `pipeline-tests` | `python3 -m unittest discover -s tests -p pipeline_test.py` | Claims, Übergaben, Dateikonflikte und Fehlerbehandlung |
| `unreal-static` | `python3 tools/verify_unreal.py` | Nur die vom vorhandenen Quellprüfer tatsächlich untersuchten Engine-Dateien |

Das Python-Werkzeug verwendet für Python-Unterprozesse den Interpreter, mit dem es selbst gestartet wurde. Die Aufgaben-Datei darf ausschließlich die bekannten Kennungen nennen. Es werden keine Shell-Zeichenfolgen, frei angegebenen Programme oder Modellaufrufe aus dem Manifest ausgeführt. Jeder Prozess hat eine Zeitgrenze von 120 Sekunden.

Fehlende Werkzeuge oder Dateien erscheinen als **NICHT GEPRÜFT**, nicht als Erfolg. Rückgabewerte: `0` vollständig bestanden, `1` Fehler oder während des Tests veränderter Quellstand, `2` unvollständiger Lauf wegen fehlender Voraussetzungen. Beim gemeinsamen Lauf wird der Unreal-Quellprüfer nur ausgeführt, wenn er vorhanden ist; sein Fehlen führt zu `2` und einem ausdrücklichen Hinweis. Das ist kein Unreal-Build, Editorstart, Render-, Bildraten- oder Gerätetest. Die Frontend-Syntaxprüfung ersetzt insbesondere keine Sichtprüfung und keine Bedienprüfung.

## Lokaler Zustand und Parallelzugriff

Claims, Prüfläufe und Übergaben liegen unter `coordination/.local/`. Eine eigene `.gitignore` hält sie aus Commits heraus. Das Werkzeug reserviert den Schreibzugriff mit exklusiver Dateierstellung und schreibt JSON über eine temporäre Datei mit anschließendem atomarem Austausch. Ein zweiter Schreiber erhält eine klare Sperrmeldung. Während eines Tests wird kein minutenlanger Schreiblock gehalten.

Ein Absturz kann `state.lock` zurücklassen. Vor manueller Entfernung muss geprüft werden, ob die darin genannte Prozess-ID noch arbeitet. Es gibt absichtlich keine automatische Übernahme eines möglicherweise aktiven Claims. Ändert sich das versionierte Manifest, werden alte lokale Zustände abgewiesen. Der Integrator gleicht bestehende Claims ab und archiviert oder entfernt erst danach `state.json`, bevor eine neue Sitzung beginnt. Lokale Daten beweisen keine geräteübergreifende Koordination; getrennte Checkouts stimmen sich zusätzlich über Issue und PR ab.

Übergaben speichern Prüfsummen der Nachweisdateien und des eigenen Dateibereichs. Änderung oder Löschung eines Nachweises wird erkannt. Fingerabdrücke schützen vor versehentlich veralteten Aussagen; sie sind kein signierter Herkunftsnachweis und ersetzen kein Review.

## GitHub-Prüfung und Kostenrahmen

[`foundation-checks.yml`](../../.github/workflows/foundation-checks.yml) führt dieselben vorhandenen lokalen Checks bei betroffenen Pull Requests oder manuell aus. Der Job hat nur lesende Repositoryberechtigungen, keine Secrets, keine Schreib- oder Mergeaktion und höchstens fünf Minuten Laufzeit. Überschneidende Läufe desselben PR werden abgebrochen. Die verwendeten Runtime-Versionen werden im Jobprotokoll ausgegeben.

Es werden keine Modell-APIs, GPU-Instanzen, neuen Abonnements oder externen Agentendienste eingerichtet. GitHub Actions unterliegt den vorhandenen Kontoeinstellungen und gegebenenfalls deren Kontingenten; diese Datei verspricht keine Kosten- oder Kontingentfreiheit. Ein Wechsel des Modells oder Denkmodus ist keine Funktion dieser Pipeline. Wird dafür tatsächlich zusätzliche Leistung benötigt, nennt der verantwortliche Agent vorab konkrete Aufgabe, Werkzeug und bekannten Kostenrahmen.

## Übergabe an die abschließende Durchsicht

Der Integrator vergleicht den aktuellen Repository-Kopf, erhält fremde Änderungen und sammelt Quellstand, ausgeführte Kommandos, echte Bedienbelege und offene Grenzen. Die Pipeline löst weder Merge noch Veröffentlichung aus. Die vom Nutzer vorgesehene abschließende Astra-Durchsicht kann dieses überprüfbare Paket verwenden; sie wird durch einen lokalen Statuswechsel nicht automatisch gestartet.
