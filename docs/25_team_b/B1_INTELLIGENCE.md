# B1 – NPC-Beziehungen und Wahrnehmung

Stand: 24. November 2026. Basis: `7a21dca5dad83bf637cfbe9c02f4d9ab5cd97337`, PR #53. Arbeitsblock M2.3 von Team B. Dies ist eine Erweiterung der bestehenden 42 Einwohner, keine neue Bevölkerung und kein Ersatz der Drehbuchbeziehungen.

## Implementiertes Verhalten

Einwohner erinnern sich an tatsächlich beobachtete, gegenseitig gewählte Gespräche. Beide müssen `socialize` gewählt haben, einander als Gesprächspartner nennen, verfügbar sein und innerhalb von 1,5 Metern sowie höchstens 1,2 Metern Höhenunterschied stehen. In der laufenden Welt prüft ein Geometrie-Callback zusätzlich die freie Sicht. Nähe allein, ein abwesender Gesprächspartner, eine einseitige Ansprache oder eine Person auf einem anderen Stockwerk genügt nicht.

Eine abgeschlossene Begegnung benötigt acht Sekunden gemeinsames Gespräch. Eine weitere Begegnung benötigt eine neue Gesprächsphase und mindestens 30 Sekunden Abstand zur zuletzt gezählten Begegnung. Eine ununterbrochene Unterhaltung zählt einmal. Nach drei abgeschlossenen Begegnungen und insgesamt mindestens 45 Sekunden entsteht der simulierte Status „Freundschaft gewachsen“. Das sind ausdrücklich technische Spielregeln dieses Arbeitsblocks; die Zahlen und neu entstehenden NPC-Freundschaften sind kein vorgegebener Drehbuchkanon.

Bekanntschaft und Freundschaft beeinflussen die nächste Partnerwahl innerhalb des vorhandenen Wahrnehmungsradius von 3,5 Metern. Der bisherige Einfluss von Nähe und gemeinsamen Interessen bleibt bestehen. Der bestehende Tätigkeitstext nennt bei einem bekannten Nachbarn die gemeinsame Gesprächserinnerung. `social_neighbors(data, id)` liefert eine reine Panelansicht gespeicherter Bekanntschaften und Freunde, unabhängig davon, ob gerade ein Gespräch läuft. Freunde stehen zuerst; innerhalb derselben Gruppe wird nach stabiler Personen-ID sortiert. Sichtbare Namen kommen aus der bestehenden Drehbuch-Namensfunktion, beispielsweise „Wachmann“ für die technische ID `severus`.

Die neuen Beziehungen ändern weder Spielervertrauen noch Missionen, Rohstoffe, Geld, Gesundheit oder Erfahrungspunkte. Ein verstorbener, zur Miliz versetzter oder schwer verletzter Einwohner kann keine neue zivile Begegnung erzeugen. Seine bisherige Beziehungserinnerung bleibt erhalten.

Die Arbeitsabsicht folgt der tatsächlichen Zuweisung: Eine an Feld, Holzlager, Steinbruch oder Handel umgeteilte Wache wählt dort `work`, nicht weiterhin `patrol`. Wachdienst und dessen Wetterausnahme gelten für den Wachposten sowie ambient beziehungsweise unzugewiesen arbeitende Wachen. Die Erfahrung als Wache kann ihre Gefahrenreaktion weiterhin beeinflussen. Damit bleibt die erlaubte zivile Umteilung funktionsfähig; B3 prüft den vollständigen Weg von `village_assign` bis zur tatsächlichen Produktion.

## Wahrnehmungsvertrag

`NpcBehavior.advance(data, delta, sight_check = Callable())` nimmt optional einen Callback `(Vector3, Vector3) -> bool` entgegen. Beide Punkte sind Bodenpositionen. Einwohnerpositionen sind bereits Fußpositionen; beim Spieler wird vor dem Aufruf der vorhandene Kapselmittelpunkt um 0,9 Meter auf die Fußhöhe umgerechnet. Der Weltadapter ergänzt seine eigene Augenhöhe und prüft die Geometrie. Dieser Adapter und die Verbindung über WorldModel/Main gehören zur Integration durch den Koordinator.

Marcus ist die bereits bestehende Ausnahme im Speichervertrag: Seine beobachtete Position enthält einen Offset von 0,9 Metern; die Begleiterwiederherstellung zieht ihn wieder ab. Deshalb normalisiert B1 nur den vorübergehenden Wahrnehmungssnapshot für `marcus`. Gespräch, Partnerwahl, Spielerreaktion und Gefahrenprüfung benutzen denselben Fußpunkt. Der gespeicherte Wert und der vorhandene Wiederherstellungsweg bleiben erhalten.

Reichweite und Höhenabstand werden vor Geometrieabfragen geprüft. Ein symmetrischer Cache gilt nur für die jeweilige 0,5-Sekunden-Entscheidungsrunde. Sichtinformationen werden nicht gespeichert. Aktive Gefahren werden nach Entfernung geprüft; die Suche endet beim nächsten sichtbaren lebenden Gegner. Ein nicht beobachteter Einwohner reagiert nicht mehr auf Gegner an seiner bloß gespeicherten früheren Position. Spielergruß und persönlicher Abstand verwenden dieselbe Sichtprüfung. Ein ausdrücklich ausgelöster Alarm bleibt ein eigenständiges Dorfsignal und erzeugt keine erfundene visuelle Gefahrenerinnerung.

Ohne gültigen Callback arbeiten reine Domainprüfungen weiterhin mit beobachteter Nähe. Dieser Fallback ist kein Sichtnachweis. Es gibt in diesem Block weder einen richtungsabhängigen Blickkegel noch eine vollständige Geräusch-, Gerüchte- oder Wissenssimulation.

## Speicherung und Grenzen

Das bestehende `behavior.version = 1` bleibt erhalten. Der neue additive Untervertrag lautet:

```text
village.behavior.social
  version: 1
  pairs:
    "kleinere_id:größere_id":
      shared_seconds
      encounters
      last_contact
      session_seconds
      session_counted
      last_encounter
```

Es gibt höchstens 96 Paarerinnerungen, 3.600 gespeicherte Gesprächssekunden und 64 gezählte Begegnungen pro Paar. Unter Speicherdruck wird deterministisch die schwächste beziehungsweise älteste Erinnerung verdrängt; gefestigte Beziehungen haben Vorrang vor kurzen Begegnungen. Die früheren vier individuellen Gefahr-/Vertrauenserinnerungen pro Einwohner bleiben unverändert begrenzt.

Die Prüfung akzeptiert ausschließlich den alten exakten Bewohnervertrag oder denselben Vertrag mit dem vollständigen neuen `social`-Bereich. Paar-IDs müssen bekannte unterschiedliche Einwohner in kanonischer Reihenfolge enthalten. Unbekannte Felder, nicht endliche Zahlen, unmögliche Zeiten oder Begegnungszahlen und fehlerhafte Unterversionen werden abgelehnt.

`ensure_social(data)` ergänzt bei einem zuvor erfolgreich validierten alten Spielstand nur einen leeren Untervertrag. Vorhandene fehlerhafte Daten werden niemals zurückgesetzt oder verdeckt. Der Koordinator bindet diesen Aufruf nach der bestehenden Gesamtvalidierung ein und normalisiert `social.version` sowie `encounters` nach dem JSON-Laden wieder zu Ganzzahlen. Schema v5, Speicher-Envelope und Drehbuchversion werden von B1 nicht verändert.

## Dateizuständigkeit

- `prototype/scripts/domain/npc_behavior.gd`: Verhalten, Wahrnehmungsanbindung, Partnerpräferenz, Panelansicht und Untervertragsprüfung.
- `prototype/scripts/domain/npc_social_memory.gd`: begrenzte Beziehungserinnerungen und ihre Validierung.
- `prototype/tests/npc_social_memory_test.gd`: gezielte neue Regelprüfungen.
- Dieses Dokument.

WorldModel, Main, Weltadapter, Bewohnerpanel, gemeinsame Prüfliste und integrierte Speicher-/Geometrieprüfungen werden vom Koordinator bearbeitet.

## Tatsächlich ausgeführte Einzelprüfungen

Godot `4.7.2.stable.official.ed1daf0bf`, headless, isolierte XDG-Verzeichnisse:

| Prüfung | Ergebnis | Aussage |
|---|---:|---|
| `npc_social_memory_test.gd` | 72/72 | Gegenseitige Gespräche, echte Änderung der Partnerwahl, Abwesenheit/Tod/Miliz, Höhenabstand, Sicht-Callbacks, Cache, Marcus-Fußpunkte bei unverändertem Speichervertrag, Cooldown, Wiederholung, JSON-Fortsetzung, Frameaufteilung, Speicherbudget, gefälschte IDs/Zeitwerte, Legacy-Erweiterung und reine Panelansicht |
| Bestehendes `npc_behavior_test.gd` | 85/85 | Bisherige Bedürfnisse, Arbeitspausen, Umweltreaktionen und Speicherregeln bleiben ausführbar |

Die Sichtprüfungen des B1-Einzeltests benutzen kontrollierte Callbacks. Die tatsächliche Wandprobe, vollständige WorldModel-Speicherung und UI-Einbindung sind Gegenstand der separaten Integrationsprüfung. Diese Zahlen werden nicht zusätzlich zu den entsprechenden Gruppen einer Gesamtprüfung addiert. B1 hat keine APK erzeugt und weder Android-Frametimes noch Temperatur oder physische Gerätebedienung gemessen.
