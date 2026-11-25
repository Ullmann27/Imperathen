# B3 – Wirtschaft: vollständige Lieferung und gemeinsamer Händlerbestand

**Stand:** 24. November 2026. **Arbeitspaket:** M5, Team B – Simulation.
**Ausgangsstand:** `7a21dca5dad83bf637cfbe9c02f4d9ab5cd97337` (PR #53).
**Umsetzung:** `prototype/scripts/domain/village_economy.gd`; die gemeinsame Weltintegration gehört dem Koordinator.

## Konkretes Spielergebnis

Ein Händler bezahlt eine Holzlieferung vollständig. Reicht sein Geld nicht, wartet der Betrieb und behält die bereits geleistete Teilarbeit. Beim Kauf von Notgetreide erreicht die tatsächliche Zahlung dieselbe Händlerkasse, aus der spätere Holzlieferungen bezahlt werden. Eine ruhende, alarmierte oder zur Verteidigung abgezogene zivile Person produziert während ihrer Abwesenheit keine Handelsladung.

Die bestehenden Konditionen bleiben für vollständig bezahlte Lieferungen erhalten:

| Vorgang | Ware | Zahlung | Voraussetzung |
|---|---:|---:|---|
| Holzlieferung | 4 Holz aus dem zentralen Vorrat | 6 Denare aus der Händlerkasse | Zwei arbeitsfähige und tatsächlich arbeitende Personen, intakter Handelsplatz, 60 Arbeitssekunden |
| Holzlieferung mit erlerntem Handelsberuf | 4 Holz | 7 Denare | Derselbe Personal- und Arbeitsbedarf |
| Notgetreide kaufen | 16 Getreide aus dem endlichen Notvorrat | 6 Denare an die Händlerkasse | Bestehende Arbeitserlaubnis, ausreichendes Geld und Lagerplatz |
| Notgetreide mit bereits erworbener Kapitel-I-Fähigkeit | 16 Getreide | 5 Denare an die Händlerkasse | Der vorhandene Fähigkeitsnachweis bestimmt den Rabatt |

Das sind ausdrücklich **Spielbalancewerte**, keine historisch belegten Produktionsmengen oder Münzpreise. Die Freischaltung und die vorhandene Kapitel-I-Fähigkeit wurden nicht verändert. Insbesondere erteilt dieses Paket dem zwölfjährigen Spieler keine Verwaltungsgewalt und schaltet keine bislang gesperrten Verwaltungsbefehle frei.

## Nachgewiesene Fehler und Änderung

Zuvor begrenzte die gemeinsame Ertragsfunktion auch den Handelslohn auf den verbleibenden Händlerbestand. Gleichzeitig zog die Lieferung stets vier Holz ab. Bei fünf vorhandenen Denaren verlor das Dorf deshalb vier Holz und erhielt lediglich fünf statt der vorgesehenen sechs Denare. Lebensmittelkäufe zogen außerdem Geld aus dem zentralen Vorrat ab, ohne es der Händlerkasse zuzuführen.

Ein tatsächlich ausgeführter Vergleich verwendete für beide Fassungen denselben kontrollierten Wirtschaftszustand: 40 Holz, 30 Denare, fünf Denare Händlergeld, zwei eingeteilte Händler und einen intakten Handelsplatz. Nach 60 Sekunden und anschließend einem Notgetreidekauf ergab sich:

| Gemessener Zustand | Ausgangscode `7a21dca` | Team-B-Code |
|---|---:|---:|
| Holz nach 60 Sekunden | 36 | 40 |
| Zentrales Geld nach 60 Sekunden | 35 | 30 |
| Händlergeld nach 60 Sekunden | 0 | 5 |
| Abgeschlossene Lieferungen | 1 | 0 |
| Geldsumme vor Lebensmittelkauf | 35 | 35 |
| Geldsumme nach Lebensmittelkauf | 29 | 35 |

Die neue Handelsfunktion verlangt die volle Zahlung vor Beginn beziehungsweise Fortsetzung der Arbeit. Die vorhandene Teilarbeit bleibt bei fehlendem Geld erhalten. Eintreffendes Geld beendet keinen Auftrag rückwirkend; erst die noch fehlenden Arbeitssekunden vervollständigen die Lieferung. Grundstoffgewinnung in Wald und Steinbruch darf weiterhin die letzte kleinere Restmenge fördern. Nur die Handelslieferung ist ein unteilbarer Austausch zu einer festen vollständigen Zahlung.

Der angezeigte Betriebsgrund nennt bei Geldmangel den erforderlichen vollständigen Preis. Der letzte Wirtschaftsbericht nennt nach einem Verkauf die tatsächlich gelieferten vier Holz und die tatsächlich erhaltenen sechs beziehungsweise sieben Denare.

## Transaktionen und Arbeitskräfte

Beide Seiten eines Kaufs gehören zur vorhandenen Transaktion. Vor der ersten Änderung werden Geld, Warenbestand, Lagerkapazität und Aufnahmekapazität der Händlerkasse geprüft. Bei Ablehnung bleiben Ressourcen, Händlergeld, Notvorrat und Buchungen unverändert. Die Händlerkasse verwendet die bereits bestehende technische Obergrenze von `MAX_RESOURCE = 1_000_000`; der Anfangsbestand von 600 Denaren ist keine separate Kapazitätsgrenze. Rückgeführte Zahlungen erlauben keine Überschreitung.

Die Waren- und Geldbewegungen des Dorfes bleiben im vorhandenen vorzeichenbehafteten `economy.ledger`. Geldzahlungen zwischen zentralem Vorrat und Händlerkasse erhalten ihre Summe. Das ist eine Aussage über diese beiden Handelsvorgänge, nicht über sämtliche anderen Belohnungen und Kosten des Spiels. Verkaufte Holzfracht verlässt den zentralen Dorfbestand; dieses Paket ergänzt kein separates Warenlager eines Fernhändlers.

Die vorhandenen 14 Wirtschaftsidentitäten werden weiterverwendet. Die größere sichtbare NPC-Bevölkerung ist damit nicht automatisch eine vollständige Wirtschaftsbevölkerung. Abwesenheit und Arbeitsplatzbelegung bleiben getrennt: Ein eingeteilter, gerade ruhender Bewohner besetzt weiterhin seine eine Stelle, liefert aber keine Arbeitszeit. `patrol` und `alert` zählen nur am tatsächlich zugewiesenen Stadtposten als Dienst; zivile Betriebe verlangen `work`. Ein aktiver Überfall pausiert wie bisher die zivile Produktion.

Eine Wache darf mit der vorhandenen Arbeitserlaubnis weiterhin auf einen freien zivilen Arbeitsplatz wechseln. Ihre Persönlichkeitsmerkmale bleiben erhalten; B1 richtet die Tätigkeitsart nach der tatsächlichen Einteilung aus. Sonst würde eine zivil umgeteilte Wache weiterhin `patrol` wählen und dadurch zu Recht von der zivilen Produktion ausgeschlossen. Diese Anschlusskorrektur wird durch eine zusätzliche WorldModel-Produktionsprüfung abgesichert.

Der Koordinator ergänzt **ausschließlich für ausdrücklich neue Kindheitsspiele** Antonia als zweite vorhandene Arbeitskraft am Handelsplatz neben Cassia. Ihre ID, ihr Beruf als Töpferin und ihre Geschichte bleiben erhalten. Ihre Mithilfe am Markt ist eine technische Spielausgestaltung, keine neu behauptete kanonische Drehbuchszene. Silvanus und die bestehenden Begleitrouten werden nicht umverteilt. Alte Spielstände behalten ihre konkrete Belegschaft. Die Prüfung dieser Initialisierung und ihrer Weltintegration liegt beim Koordinator.

## Spielstände und Wiederholungsschutz

Welt-Schema v5, Wirtschafts-Version 1, bestehende Schlüssel, Personen-IDs und Arbeitsplatz-IDs bleiben erhalten. Es werden keine zusätzlichen gespeicherten Felder benötigt. Frühere abgeschlossene Lieferungen und Käufe werden nicht neu berechnet; alte Käufe erhalten keine nachträgliche Gutschrift. Ein alter Spielstand behält deshalb seine konkreten Bestände und setzt ab dem Laden mit den neuen Transaktionsregeln fort.

Die vorhandene WorldModel-Befehlskennung schützt vor doppeltem Lebensmittelkauf. Der neue Integrationstest prüft dieselbe Kennung vor und nach einem echten Speichervorgang samt Envelope und Neustart. Auch der Versuch, diese Kennung für einen anderen Auftrag zu verwenden, wird ohne Zustandsänderung abgelehnt.

## Tatsächlich ausgeführte Prüfungen

Godot **4.7.2**, headless, getrennte Testkonfiguration und Spielstandverzeichnisse. Die Ausgaben wurden zusätzlich auf `SCRIPT ERROR`, `Parse Error`, `ERROR` und `USER ERROR` geprüft; ein alleiniger Erfolgsmarker genügt nicht.

| Prüfung | Ergebnis |
|---|---:|
| `village_economy_test.gd` | 191 Prüfungen, 0 Fehler |
| `commerce_transaction_test.gd` | 245 Prüfungen, 0 Fehler |
| Kontrollierter Vorher-/Nachher-Lauf | Beide Fehler im Ausgangscode reproduziert, geändertes Verhalten im Team-B-Code nachgewiesen |

Der neue Handelstest prüft unter anderem alle Restkassen von null bis unmittelbar unter den beiden Lieferpreisen, exakt ausreichendes Geld, gefüllte Lager/Kassen, Rabattbuchung, Personalpausen, Verteidigungsdienst, Alarm, aktive Überfälle, Fortsetzung von Teilaufträgen, verschiedene Zeitschrittteilungen und JSON-Neustart.

Sein WorldModel-Abschnitt verwendet tatsächliche Spielbefehle: Holz sammeln, Steinbruch besetzen und reparieren, Stein fördern, Markt besetzen und reparieren, eine Lieferung teilweise bearbeiten, Notgetreide kaufen, speichern, neu laden, Kaufkennung erneut senden und die Lieferung abschließen. Ressourcen und Personen werden dabei nicht künstlich gutgeschrieben. Der reparierte Markt liefert danach dieselben autoritativen Bestände wie die ohne Neustart fortgesetzte Vergleichspartie.

Eine weitere WorldModel-Prüfung aktiviert das tatsächliche NPC-Entscheidungssystem, holt Decimus' Erlaubnis ein und teilt Severus sowie Valeria per Spielbefehl dem freien Holzlager zu. Die Reparatur wird mit zuvor gesammeltem Holz bezahlt. Die beiden werden an ihren Arbeitsorten beobachtet, wählen zivile Arbeit und erzeugen nach Reparatur plus Arbeitszeit eine volle Ladung von acht Holz aus dem endlichen Waldvorrat. Müdigkeit und Sozialbedürfnis sind in dieser gezielten Klassifikationsprüfung kontrolliert; Einteilung, Arbeitserfolg und Güter werden nicht direkt gesetzt. Das ist eine Regel- und Integrationsprüfung, kein grafischer Nachweis physischer NPC-Wege.

Reproduktion ab dem Repository-Stamm mit isolierten XDG-Verzeichnissen:

```bash
env IMPERATHEN_ISOLATED_TEST=1 XDG_CONFIG_HOME=/tmp/imperathen-b3-config XDG_DATA_HOME=/tmp/imperathen-b3-data XDG_CACHE_HOME=/tmp/imperathen-b3-cache godot --headless --path prototype --script res://tests/village_economy_test.gd
env IMPERATHEN_ISOLATED_TEST=1 XDG_CONFIG_HOME=/tmp/imperathen-b3-config XDG_DATA_HOME=/tmp/imperathen-b3-data XDG_CACHE_HOME=/tmp/imperathen-b3-cache godot --headless --path prototype --script res://tests/commerce_transaction_test.gd
```

Der neue Erfolgsmarker ist `COMMERCE_TRANSACTION_PASS`. Der Koordinator registriert die Gruppe im gemeinsamen Prüfläufer und führt die vollständige Integrationsmatrix aus.

## Grenzen dieses Pakets

Das Paket belegt Regelverhalten, echte Buchungen und Speicherung. Es enthält keinen Android-Gerätevergleich, keine FPS- oder Temperaturmessung und keine neue APK. Die eigene Händlerkasse ist Teil der vorhandenen Dorfwirtschaft; freie regional unterschiedliche Marktpreise, mehrere konkurrierende Händler, Warenkarawanen, Diplomatie und langfristige Armeelogistik sind dadurch noch nicht implementiert. Die bestehende Saisonkarte bleibt ein getrenntes Planspiel und wurde in diesem Arbeitspaket nicht umgedeutet.
