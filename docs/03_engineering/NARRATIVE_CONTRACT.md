# IMPERATHEN – Vertrag für die fortlaufende KI-Geschichte

**Stand:** 22.11.2026 · **Status:** Entwurf zur Architekturprüfung · **Keine Programmierung oder Modellaufrufe beauftragt.** „Living Chronicle“ bezeichnet ein geplantes System, kein bereits fertiges Produkt.

## 1. Verbindliche Aufgabe

Der Regisseur entwickelt mögliche Fortsetzungen aus belegten Spielerhandlungen, Weltvorgängen und Figureninteressen. Er darf kein Lebensende, keine Kaiserwürde und keine Freundschaft garantieren. Ein Soldatenleben kann einen vollständigen Abschluss erhalten; höhere Laufbahnen benötigen tatsächliche Leistungen und Gelegenheiten. Beziehungen, Entscheidungen und verlorene Chancen wirken auf folgende Kapitel. Zufällige Variation ergänzt diese Ursachen und ersetzt sie nicht.

Ein bestätigter Karriereabschluss ist ein gespeicherter terminaler Zustand mit Abschlussereignis. Die noch offene Regel für seinen Eintritt darf der Planner nicht selbst ersetzen. Unvereinbare Reserveepisoden werden verworfen, zugehörige Reservierungen gelöst und keine neuen Fortsetzungen desselben abgeschlossenen Bogens aktiviert. Der Aufstieg zum Kaiser wechselt dagegen Rolle und Themen der fortlaufenden Geschichte; er beendet sie nicht automatisch.

Der Planner erhält einen zeitlich begrenzten Weltkontext mit abrufbaren Ereignisbelegen. Zusammenfassungen sind Hilfsansichten; bei Widerspruch gilt die kanonische Chronik. Das Wissen eines NPC wird von der objektiven Weltwahrheit getrennt. Ein Gerücht kann falsch sein, muss aber eine Quelle besitzen; ein unbekanntes Geheimnis darf nicht aus dem globalen Kontext in gewöhnliche Dialoge gelangen.

## 2. Geplanter Datenvertrag

| Teil | Inhalt und Bedeutung |
|---|---|
| Herkunft | Plan-ID, Vertragsversion, Welt-ID, Planungsrevision, Quellereignisse, Faktenhash, Generator-/Vorlagenversion |
| Beteiligte | Bestehende Figuren-, Orts- und Fraktions-IDs; explizit erlaubte neue Figuren nur über regelgebundene Erzeugung |
| Voraussetzungen | Lebensstatus, Karriereabschluss, Rolle, Wissen, Befugnisse, Alter, Wegzugang, Ressourcen, Beziehungen, vorausgehende Ereignisse |
| Ablauf | Vorhandene Szenenbausteine, Ziele, Optionen, Abbruchwege, Scheitern und erlaubte Folgen |
| Ressourcen | Kosten, Reservierungsbedarf, Arbeit, Reisezeit, Asset-IDs, Konflikte mit anderen Plänen |
| Gültigkeit | Ablaufzeit, betroffene Entitäten, Revalidierungsregeln, Priorität und Fallback |
| Nachweis | Validatorversion, Fehlergründe, Freigabestatus, Aktivierungsereignis, einmalige Ausführungs-ID |

Ein Zufallsseed wird mit dem Plan gespeichert, sofern der jeweilige Generator ihn unterstützt. Er garantiert bei externen Sprachmodellen keine identische erneute Antwort. Bereits freigegebene Planobjekte und entscheidende Formulierungen müssen deshalb selbst versioniert gespeichert werden.

## 3. Prüfung in drei Stufen

**Struktur:** Pflichtfelder, erlaubte Befehlsarten, Längen, IDs, Größenlimits und bekannte Inhalte. Freitext ist keine ausführbare Anweisung. Ein Zeichenkettenfeld darf keine Engine-Skripte, Dateipfade zu fremden Dateien oder Toolrechte erzeugen.

**Bedeutung:** Lebensstatus, Wissenszugang, Machtbefugnis, Geografie, Zeit und Kosten. Jede alternative Auswahl wird auf einer eigenen Zustandskopie simuliert; unmittelbar auszuführende Befehle einer Auswahl werden nacheinander und gemeinsam geprüft. Dadurch werden kumulierte Doppelentnahmen und überhöhte Beziehungswerte erkannt. Langlaufende Vorhaben besitzen zusätzlich einzeln geprüfte spätere Prozessschritte. Vor Aktivierung erfolgt eine erneute Prüfung gegen den aktuellen Weltstand. Veraltete Vorschläge werden umgeplant, ersetzt oder verworfen, nicht gewaltsam ausgeführt. Eine geplante Intrige braucht technische Verfügungsbefugnis, obwohl ihr Handeln innerhalb der Spielwelt unrechtmäßig sein kann.

**Spielbarkeit und Erzählqualität:** Ziel erreichbar, mindestens sinnvolle Handlungsfreiheit, sichtbare Folgen, kein erzwungener Weltwiderspruch, keine monotone Wiederholung. Rückblenden werden ausdrücklich vom aktuellen Spielraum getrennt. Eine spielbare Szene muss vorhandene Interaktionsmechaniken und verfügbare Assets verwenden; ein überzeugender Dialogtext allein ist noch keine Mission.

## 4. Planung während und zwischen Sitzungen

Planung startet bei bedeutenden Ereignissen, am Sitzungsende und bei knapper Reserve. Als erste Hypothese gilt: Reserve für die erwartete nächste aktive Spielzeit zuzüglich etwa einer Stunde. Aktive Zeit, Pausen, Inaktivität und tatsächlicher Verbrauch von Erzählinhalt werden getrennt betrachtet. Langes freies Bauen oder eine pausierte Konsole verbraucht nicht automatisch entsprechend viele Storyminuten.

Zur Reserve zählen nur validierte, aktuell erreichbare und miteinander vereinbare Aktivitäten. Ungültige oder durch Karriereabschluss entfallene Zweige zählen null; drei ausschließende Questzweige dürfen nicht zusammen als drei Stunden Vorrat gezählt werden. Weg-, Kampf- und Bauzeiten sind unsicher. Messungen tatsächlicher Nutzung korrigieren die Schätzung; sie garantieren keine exakt passende Spieldauer.

Ein ausgeschalteter Rechner arbeitet lokal nicht weiter. Planung nach dem Ausschalten erfordert einen zugelassenen Dienst; ohne diesen geschieht sie während des Spiels oder beim nächsten Start. Ausstehende Generierung darf den regulären Städtebau, Handel, Training und bestehende Quests nicht sperren.

## 5. Fehler- und Kostenbudget

Ungültige Weltänderungen haben eine Toleranz von null: sie werden vor Übernahme abgewiesen. Generierungsfehler dürfen auftreten, müssen jedoch ohne Saveverlust in kuratierte Vorlagen oder normale Weltaktivitäten übergehen. Vorschlag für die erste spätere Erprobung: höchstens zwei automatische Reparaturversuche pro Plan und danach Fallback; genauer Zeit- und Kostenrahmen erst nach realen Messungen und freigegebenem Budget. Kein dauerhaft laufendes Agententeam pro Spieler und keine unbegrenzten Wiederholungsaufrufe.

Sitzungsdaten werden auf relevante Spielereignisse beschränkt. Mikrofon, reale Identität und private Fremddateien sind keine Voraussetzung. Der Nutzer muss Cloudplanung deaktivieren können. Diese Vorgaben beschreiben Produktverhalten; es wurde kein Anbieter ausgewählt, Konto eingerichtet oder kostenpflichtiger Auftrag gestartet.

**Quellenbasis:** GDD Abschnitt 9, beigefügter Episode-Vertrag und Demonstrationsvalidator; siehe [Weltzustand und Zeit](WORLD_STATE_AND_TIME_CONTRACT.md).
