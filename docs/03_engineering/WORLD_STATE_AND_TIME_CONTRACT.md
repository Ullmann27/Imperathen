# IMPERATHEN – Weltzustand, Zeit und Speichern

**Stand:** 22.11.2026 · **Status:** Architekturvorschlag zur Prüfung · **Arbeitsphase:** ausschließlich Vorproduktion. Dieses Dokument spezifiziert Verhalten; es enthält keine implementierte Engine und keine ausgeführten Spieltests.

## 1. Zuständigkeit und Datenbesitz

Personenansicht, Stadtbau, taktische Schlacht und Kampagnenkarte verwenden dieselbe kanonische Welt. Jede Darstellung darf Daten zwischenspeichern; sie erhält dadurch keine zweite Entscheidungsgewalt. Die Wirtschaft besitzt Güterbuchungen, die Personenverwaltung Lebensstatus und Beziehungen, die Heeresverwaltung Dienstzuordnung und Verluste. Änderungen zwischen diesen Bereichen erfolgen gemeinsam über definierte Transaktionen. Die Narrative-KI darf zukünftige Handlungen vorschlagen, aber keinen Bestand direkt überschreiben.

| Datensatz | Erforderlicher Inhalt | Unveränderliche Regel |
|---|---|---|
| Welt | Welt-ID, Revision, Kalender, Schema, Inhaltsversion | Eine Revision bezeichnet genau einen bestätigten Zustand. |
| Person | ID, Lebensstatus, Alter, Ort, Haushalt, Rechte, Wissen, Beruf/Dienst | Wechsel der Kamera oder Distanz erzeugt keine neue Person. |
| Lebensbogen | ID, Karrierepfad, Abschlussstatus, Abschlussereignis, aktuelle Rolle | Ein bestätigter Abschluss bleibt gespeichert; Kaiserantritt allein beendet keinen Lebensbogen. |
| Besitz und Güter | Eigentümer, Lagerort, Einheit, frei/reserviert/unterwegs | Jede Menge hat einen nachvollziehbaren Ort und Buchungsgrund. |
| Gebäude | ID, Grundstück, Grundriss, Baustufe, Schaden, Arbeit | Dasselbe Bauwerk erscheint in allen Ansichten. |
| Heeresverband | ID, Personenbestand, Teilverbände, Ausrüstung, Moral, Befehl | Auflösung in Einzelkämpfer und Zusammenfassung bewahren Bestände. |
| Ereignis | ID, Ursache, beteiligte IDs, Zeit, Revision vorher/nachher | Geschehene Ereignisse werden durch spätere Erzählungen nicht ersetzt. |

## 2. Befehle als atomare Vorgänge

Jeder Auftrag erhält eine eindeutige Befehls-ID, handelnde Figur oder Systemrolle, erwartete Revision, Typ, Ziel-IDs, Parameter und Berechtigungsbereich. Zuerst werden Rechte, Lebensstatus, räumliche Voraussetzungen, Ressourcen und konkurrierende Reservierungen geprüft. Danach wird die gesamte unmittelbar auszuführende Befehlskette einer Auswahl auf einem vorläufigen Zustand durchgerechnet. Nur wenn **alle** Schritte gültig sind, werden Änderungen und Ereignisse gemeinsam bestätigt. Ein Fehler verwirft diese Transaktion; keine halbfertige Belohnung bleibt zurück.

Technische Verfügungsbefugnis bestimmt, welche Figur oder Einheit überhaupt gesteuert werden darf. Spielinternes Unrecht ist davon getrennt: Eine ausdrücklich vorgesehene Diebstahlhandlung kann technisch zulässig sein und strafbare Folgen in der Spielwelt haben. Sie benötigt einen eigenen erlaubten Regelpfad. Illegales Bauen bleibt offen; gewöhnliche Bauaufträge benötigen ausreichendes Bau- oder Nutzungsrecht, auch auf fremdem Eigentum.

Beispiel: Ein Lager besitzt zwölf Holz. Zwei Transfers von acht Holz innerhalb derselben Auswahl sind gemeinsam ungültig, obwohl jeder für sich gegen den Ausgangsbestand bestehen würde. Zwei alternative Spielerwahlen werden dagegen jeweils unabhängig bewertet, weil nur eine ausgeführt wird. Produktionsrezepte dürfen Güter umwandeln: Ihre Eingaben, Ausgaben, Verluste und Arbeit sind ausdrücklich zu buchen; „Erhaltung“ bedeutet keine falsche Gleichsetzung von Holz mit fertigen Häusern.

Eine wiederholte Befehls-ID mit gleichem Inhalt liefert das ursprüngliche Ergebnis, ohne nochmals zu buchen. Dieselbe ID mit anderem Inhalt wird abgelehnt. Bei geänderter Revision werden relevante Vorbedingungen erneut geprüft. Reservierungen besitzen Besitzer, Ablauf und Freigaberegeln, damit abgebrochene Baustellen und ungültige Quests keine Bestände dauerhaft blockieren.

Ein mehrtägiger Hausbau ist keine einzige offene Transaktion. Auftrag, Lieferung, Materialverbrauch und Fertigstellung sind gesondert bestätigte Teilschritte eines gespeicherten Prozesses. Jeder Schritt prüft den aktuellen Zustand. Abbruch arbeitet vom tatsächlichen Baufortschritt aus: freie Reservierungen lösen, unverbautes Material behandeln, verbautes Material nach Abbruchregeln verwerten. Bereits geleistete Arbeit wird nicht rückwirkend ungeschehen gemacht.

## 3. Eine Zeitlinie, unterschiedliche Arbeitstakte

Es gibt eine kanonische Spielzeit. Häufige Nahkampfschritte und seltenere Wirtschaftsschritte sind unterschiedliche Berechnungsraten **auf derselben Zeitlinie**, keine voneinander unabhängigen Kalender. Aktive Spieldauer, Pausen, Inaktivität und tatsächlich verbrauchter Erzählinhalt werden getrennt erfasst; offene Programmlaufzeit ist kein Inhaltsbedarf. Pausen verändern die Spielwelt nicht; Hintergrundplanung darf Vorschläge erzeugen, aber keine Stunden im Save verstreichen lassen. Inaktivität ist nicht automatisch eine Weltpause. Zeitsprünge (etwa Erwachsenwerden) und Zeitbeschleunigung berechnen betroffene Personen und offene Prozesse nach und halten bei relevanten Ereignissen kontrolliert an.

## 4. Speicherung und Wiederherstellung

Ein Snapshot referenziert Weltrevision, letzte Ereignisposition, Inhaltsversion, Zufallszustände und Schemaversion. Speicherung benötigt atomare Übernahme, Integritätsprüfung und einen unabhängig erhaltenen letzten gültigen Stand. Ein Inhalts-Hash erkennt unbeabsichtigte Beschädigung; er ist allein kein Manipulationsschutz gegen absichtliche Änderungen. Weltereignisse, Inventare und Story-Aktivierung dürfen beim Laden nicht teilweise aus verschiedenen Revisionen stammen.

Ein endgültiger Karriereabschluss erhält einen terminalen Zustand und ein begründendes Ereignis. Welche Ereignisse ihn auslösen, bleibt eine Designentscheidung. Unvereinbare Reserveepisoden werden verworfen und ihre Reservierungen freigegeben. Der tatsächliche Kaiserantritt ist dagegen ein Rollenwechsel mit fortgesetztem Lebensbogen; er aktiviert passende Reichsaufgaben und wird nicht automatisch als Spielende behandelt.

Migrationen laufen auf einer Kopie, prüfen Invarianten und ersetzen das Original erst nach Erfolg. Ein Rückweg zum unveränderten alten Save bleibt erhalten. Ereigniswiederholung rekonstruiert den Domainzustand; eine bitgenaue Wiederholung sämtlicher Grafik- und Physikframes wird nicht versprochen. Nichtdeterministische Kampfergebnisse werden einmal autoritativ gebucht.

## 5. Abnahmebedingungen für die spätere Umsetzung

Geprüft werden müssen doppelte Befehle, konkurrierende Baustellen, Transferketten, Bauabbruch, Saveabbruch, Migration, Karriereabschluss sowie Distanzwechsel von Armeen und produzierenden Städten. Rekrutierung, Verwundung, Gefangenschaft und Entlassung ändern Arbeitsverfügbarkeit und Dienststatus konsistent. Verlust-, Vorrats- und Personenbilanzen bleiben bei Kameraumschaltung gleich. Diese Prüfungen sind hier **definiert, nicht ausgeführt**.

**Quellenbasis:** Überarbeitung der beigefügten `03_Technik/ARCHITEKTUR_UND_DATENFLUSS.md`, `WORLD_STATE_SCHEMA.json` und `08_Werkzeuge/chronicle_validator.py`. Die vorhandenen JSONs bleiben historische Demonstrationsverträge; sie erfüllen diese vollständige Spezifikation noch nicht.
