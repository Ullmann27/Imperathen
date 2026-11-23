# Dorfwirtschaft mit tatsächlicher Belegschaft

Stand: 23. November 2026. Dieser Teil implementiert die Regeln in `prototype/scripts/domain/village_economy.gd`. Die Verbindung mit Spielfigur, Gesprächen und Darstellung liegt bei der gemeinsamen Integration.

## Herrschaft und Mitarbeit

Der Spieler beginnt als Bewohner. Der fiktive Verwalter Decimus bleibt für das Dorf verantwortlich. Das erste wirkliche Gespräch mit ihm wird im Sozialzustand als `social.npcs.decimus.met` gespeichert. Erst danach kann `village_request_work` eine Erlaubnis erteilen, freiwillige Helfer und Reparaturen zu koordinieren. Die Wirtschaft setzt die Spielerrolle niemals auf Herrscher.

Es gibt 14 namentlich geführte erwachsene Einwohner. Jeder besitzt eine einzige Einteilung, einen Beruf, Gesundheit, Hunger und einen Lebensstatus. Der Spieler und sein jugendlicher Gefährte werden nicht als zusätzliche erwachsene Betriebsarbeiter gezählt. Die bisherigen anonymen Personalzähler bleiben für ältere Spielstände erhalten; sie sind kein Gesamtzähler der neuen Dorfbevölkerung. Im neuen Abschnitt besitzt auch der persönliche Trupp ausschließlich tatsächlich vorhandene Einwohner.

Die bereits vorhandenen Frontier-Figuren Titus, Flavia, Lucius, Marcellus und Publius behalten ihre bisherigen Rollen. Neue Wirtschaftsfiguren verwenden die getrennten Namen Fabius, Aurelia, Vibius, Silvanus und Sextus. Gesprächsfiguren des neuen Dorflebens stimmen mit der Belegschaft überein: Aelia als Steinmetzin, Varro als Späher und Jäger, Fabius als Holzfäller, Aurelia als Heilerin, Cassia als Händlerin und Severus als Wachausbilder. Diese erfundenen Dorffiguren sind keine Behauptung über historische Personen.

## Betriebe und Abhängigkeiten

Die folgenden Werte sind ausdrücklich Spielbalance für den aktuellen Prototyp, keine historischen Produktionsdaten.

| Betrieb | Pflichtbesetzung | Laufzeit eines Produktionsschritts | Ergebnis | Abhängigkeit |
| --- | ---: | ---: | --- | --- |
| Dorffelder | 2 | 30 Sekunden | 6 Getreide | Erntereifer, endlicher Feldvorrat |
| Holzfällerlager | 2 | 30 Sekunden | 8 Holz | Endlicher örtlicher Holzbestand |
| Steinbruch | 4 | 40 Sekunden | 6 Stein | Endlicher örtlicher Steinvorrat |
| Handelsplatz | 2 | 60 Sekunden | 6 Denare | 4 Holz als Ware und Geldvorrat des Händlers |
| Stadtposten | 2 | 60 Sekunden | Eine abgeschlossene Patrouille | Reparierter Posten und zwei arbeitsfähige Wachen |

Damit werden zwölf Arbeitsstellen bei vierzehn Erwachsenen benötigt. Zwei Personen können zunächst Reserve bilden. Krankheit, Hunger und Verteidigungsdienst nehmen eine konkrete Person aus der verfügbaren Belegschaft; die Betriebsliste zeigt sowohl die belegten als auch die tatsächlich arbeitsfähigen Stellen.

Ein beim passenden Charakter erlernter Beruf verändert reale Abläufe: Holzfällerwissen erhöht die Lagerladung um ein Holz, Steinmetzwissen die Steinbruchladung um einen Stein und Handelswissen den Verkaufserlös um einen Denar. Das zusätzliche Gut stammt immer aus dem tatsächlichen örtlichen Vorrat. Der Beruf hebt weder Personalbedarf noch Reparatur- oder Frachtkosten auf. Heilwissen verbessert die Erholung versorgter Reservepersonen um zwei zusätzliche Gesundheitspunkte pro Dorftag. Die Darstellung kann die wirkliche aktuelle Ladungsmenge direkt aus `view().workplaces[].yield_per_cycle` übernehmen. Diese Wirkung setzt das im Sozialmodul tatsächlich erlernte `social.profession` voraus.

Die Arbeitsplätze besitzen feste Kapazitäten. Eine Person kann nicht gleichzeitig Holz schlagen und Wache stehen. Ein Wechsel entfernt sie aus ihrer vorherigen Einteilung. Eine dritte Person kann eine Zweierstelle nicht überbelegen. Fehlende Mindestbesetzung stoppt Produktion und Reparatur vollständig. Bereits geleistete Teilarbeit bleibt erhalten; die Ausfallzeit wird nicht nachträglich als Arbeit gutgeschrieben.

Zu Spielbeginn sind nur die Felder betriebsbereit. Holzlager, Steinbruch, Handel und Posten müssen repariert werden. Ein Reparaturauftrag verbraucht sofort die der Beschädigung entsprechenden Mengen Holz und Stein. Er wird jedoch erst mit der vollständigen tatsächlichen Belegschaft über die festgelegte Arbeitszeit fertig. Das Holzlager benötigt zunächst nur Holz; es ermöglicht danach weitere Reparaturen. Der Steinbruch benötigt ebenfalls zuerst Holz und liefert anschließend den Stein für Handel und Posten. Dadurch besteht kein Kreis, in dem ein noch nicht zugänglicher Rohstoff seine eigene Freischaltung blockiert.

## Nahrung, Erholung und Verteidigung

Ein Dorftag dauert im aktuellen Funktionsprototyp 120 laufende Simulationssekunden. Pro Tag benötigt jeder lebende erwachsene Einwohner eine Einheit Getreide. Zwei Feldarbeiter können unter ungestörten Bedingungen 24 Getreide pro Dorftag ernten; bei 14 Einwohnern bleibt ein Überschuss von zehn. Getreide stammt aus demselben zentralen Vorrat wie andere Spielhandlungen.

Zwei versäumte Mahlzeiten machen eine Person vorübergehend arbeitsunfähig. Nahrung senkt den Hunger wieder. Eine Person in Reserve erholt sich bei einer versorgten Mahlzeit um fünf Gesundheitspunkte, eine eingeteilte Person um einen. Hungrige oder schwer verletzte Menschen können nicht zusätzlich für die Verteidigung eingeteilt werden. Fehlende Rationen werden nicht immer denselben Personen zugeteilt: Die Reihenfolge rotiert zwischen den Tagen.

Als begrenzter Ausweg steht ein örtlicher Notvorrat von 64 Getreide zur Verfügung. Ein Kauf kostet sechs Denare für sechzehn Getreide; nach vier solchen Käufen ist dieser Vorrat erschöpft. Er ist eine vorhandene, bezahlte Reserve und kein unbegrenztes Hilfsgeschenk. Abgeerntete Felder lassen sich mit vier Getreide als Saat und einem weiteren Dorftag Arbeit zweier Personen neu bestellen. Die nächste Ernte umfasst dann 120 Getreide.

Beim Verteidigungsdienst wird die frühere zivile Einteilung gemerkt. Während eines aktiven Überfalls ruht die gesamte zivile Produktion einschließlich Reparaturen; Nahrung und Dorfzeit laufen weiter, wenn die übergeordnete Spielsimulation weiterläuft. Ein Verteidiger kann während eines aktiven Angriffs nicht in einen Zivilbetrieb zurückversetzt werden. Nach dem Angriff kehrt er an seinen alten Arbeitsplatz zurück, sofern dieser frei geblieben ist; sonst steht er als Reserve bereit. Verletzungen können den tatsächlichen Personen zugewiesen werden. Die Wirtschaft entscheidet selbst keine Kampfausgänge.

## Zeit, Vorräte und Buchungen

Alle nutzbaren Güter liegen ausschließlich unter `data.resources`: Holz, Getreide, Denare und Stein. Die Wirtschaft besitzt keinen zweiten Geldbeutel. `data.village.economy.ledger` verzeichnet ihre vorzeichenbehafteten Nettoänderungen. Der Weltvalidator kann die ursprünglichen Ressourcenbilanzen um diese Buchungen ergänzen. Die örtlichen Wald-, Stein-, Ernte- und Händlervorräte werden bei jeder Produktion tatsächlich kleiner.

Der Zeitschritt wird an Produktions-, Bau- und Mahlzeitgrenzen aufgeteilt. Die Arbeitsfähigkeit jedes Betriebs wird jeweils am Anfang dieses Teilintervalls festgehalten. Holz, das erst am Ende eines Intervalls ankommt, ermöglicht deshalb keine rückwirkende Handelsarbeit während desselben Intervalls. Ein langer Zeitschritt und dieselbe Zeit in vielen kurzen Schritten ergeben denselben Spielzustand.

Das Modul speichert ausschließlich JSON-fähige Werte. Teilarbeit, Baufortschritt, Mahlzeiten und frühere Verteidigerstellen überstehen das Speichern und Laden. Das Modul verändert selbst weder die chronologische Weltzeit noch das Alter der Spielerfigur und erteilt keine automatischen Karriereaufstiege.

## Gemeinsame Welt und namentliche Miliz

`WorldModel.new_game("italia", true)` aktiviert den neuen Abschnitt. Bestehende regionale Karrieren und andere Herkünfte werden nicht stillschweigend umgestellt. Die Schemamigration von 4 auf 5 ergänzt den neuen Datenvertrag ohne Rohstoffgeschenke und lässt die neue Jugendphase für alte Spielstände ausgeschaltet. Die originalen Speicherdateien werden beim Laden nicht überschrieben.

Sobald die erwachsene Ausbildung tatsächlich abgeschlossen ist, verwendet auch der ältere Truppbefehl `recruit` im neuen Abschnitt reale Einwohner. `data.village.militia` enthält ihre IDs in Rekrutierungsreihenfolge. Für den automatischen Aufruf stehen nur gesunde, freie Nicht-Mentoren zur Verfügung; sind alle geeigneten Menschen beschäftigt, muss zuerst eine reale Person aus ihrer Arbeit für die Reserve freigegeben werden. Der angeworbene Einwohner erhält `assignment="defense"` und fehlt damit im Betrieb. Die normale Dorfzuweisung kann ein solches Truppmitglied nicht gleichzeitig wieder als Arbeiter einsetzen. Bei einer Truppverlustmeldung wird genau derselbe Einwohner als verstorben geführt. Nahrung, Arbeitskräfte, sichtbare Personen und gespeicherte Verluste können so auf dieselbe Identität zugreifen.

Während einer Dorfwarnung oder eines laufenden Überfalls sind ein neuer militärischer Kampf und der sechsjährige Übergang gesperrt. Die übergeordnete Zeitfunktion taktet Bauarbeit, Wirtschaft und Dorfereignisse gemeinsam an den 0,1-Sekunden-Grenzen des Kampfsystems. Bereits vor dem Angriff geleistete Arbeit bleibt erhalten; die Angriffsphase kann keinen früheren ganzen Zeitschritt rückwirkend entwerten. Ein aktiver Überfall unterbricht auch das automatische Weiterbauen einer eigenen Hütte.

Neue Gesundheitsschäden und Behandlungen werden in `data.village.health_delta` vorzeichenrichtig gebucht. Sie ersetzen den alten militärischen Schadenszähler nicht. Der Weltvalidator prüft beide zusammen: `encounter.damage_taken == 100 + village.health_delta - player.health`. Eine Behandlung kann dadurch auch nach einem älteren Truppgefecht korrekt speichern, ohne einen gefallenen Einwohner wiederherzustellen. Alle kumulierten Wirtschafts-, Gesprächs- und ursprünglichen Ressourcenänderungen werden vor der Übernahme des vollständigen Weltzustands gemeinsam geprüft.

## API für die Integration

Eigener Datenbereich: ausschließlich `data.village.economy`, mit zentralen Ressourcenbuchungen unter `data.resources`.

| API | Wirkung |
| --- | --- |
| `initial_state()` | Neue Wirtschaft und 14 erwachsene Einwohner |
| `ensure(data)` | Fehlenden Wirtschaftsteil und Ressource `stone` ergänzen; vorhandenen Stand erhalten |
| `execute(data, command, args)` | Validierter, atomarer Auftrag mit `{ok, message}` |
| `advance(data, delta)` | Tatsächliche Zeit, Arbeit, Produktion und Mahlzeiten; Rückgabe, ob der Zeitschritt akzeptiert wurde |
| `view(data)` | Kopierte reine Ansicht für Personen-, Betriebs- und Versorgungsanzeige |
| `validate(data)` | Leerer String bei gültiger Wirtschaft, sonst verständlicher Fehler |
| `repair_cost(economy, workplace_id)` | Aktueller Holz- und Steinbedarf anhand des Schadens |

Aufträge: `village_request_work`, `village_assign(resident_id, workplace_id)`, `village_repair(workplace_id)`, `village_shift(resident_id, duty)`, `village_buy_food` und `village_resow`. Der spezielle Arbeitsplatz `idle` steht für Reserve; `duty` erlaubt `defense` und `return`. Die übergeordnete Befehlsgrenze sollte ihre vorhandene dauerhafte Befehlskennung verwenden, damit wiederholte Übertragungen desselben Auftrags nicht doppelt gebucht werden.

## Ausgeführte Prüfungen

Der eigenständige Lauf mit der vorhandenen Godot-Version 4.7.2 bestand **189 Prüfungen**. Ausführung:

```sh
godot --headless --path prototype --script res://tests/village_economy_test.gd
```

Geprüft wurden insbesondere Autorität nach Gespräch, Ablehnung ohne Mutation, 14 eindeutige Personen, Pflichtbesetzung, Materialverbrauch, wirkliche Reparaturdauer, endliche Rohstoffe, Handelsfracht, Mitarbeiterentzug durch Verteidigung, Stillstand während eines Angriffs, Nahrungskreislauf und Hungererholung, endlicher Notvorrat, Aussaat, Speicherrundreise, fortgesetzte Teilarbeit, Berufsauswirkungen mit echten Lagerbuchungen, gleiche Ergebnisse bei unterschiedlicher Zeitschrittteilung und Ablehnung beschädigter Zustände. Ein gezielter Test prüft, dass der Händler keine Arbeitszeit vor dem tatsächlichen Eintreffen des ersten Holzes erhält. Ein weiterer bestätigt die vollständige Rücknahme eines Zeitschritts, falls dieser die zulässigen Zustandsgrenzen überschreiten würde.

Dies sind ausgeführte Regelprüfungen. Sie belegen für sich allein keine Darstellung der Arbeitsschritte, Wegfindung, Charakteranimation, Android-Bildrate oder historische Genauigkeit der vorläufigen Spielbalance.

Die zusätzlich ausgeführte `village_model_test.gd` enthält **227 Regelfälle** für die vollständige Weltintegration: echte Gesprächs- und Arbeitsbefehle, bezahlte Reparaturen, Produktion, Überfallwarnung, tatsächliche Angriffe und Schutzfenster, Rettung einer vorhandenen Person, Sieg, Behandlung, Bündnis, wiederholte Befehlskennungen, echte Zeitkopplung, Speichern während Teilaufgaben, Schemamigration, abgewiesene gefälschte Ressourcen-/Gesundheitsbilanzen, namentliche Trupprekrutierung und identische Opfer in Dorf und Trupp. Ein weiterer Fall prüft explizit die Behandlung nach einem älteren militärischen Gefecht, während dessen Schadens- und Verlustbuchung bestehen bleibt.

Auch die **329 bisherigen Domain-Regelfälle** und **308 Frontier-Erzählregelfälle** bestanden nach Integration erneut. Ihre historischen Save-Fixtures wurden um die damals tatsächlich fehlenden neuen Felder bereinigt; die Negativkoordinate liegt nun außerhalb der erweiterten Weltgrenze. Es wurden keine inhaltlichen Assertions entfernt und keine Bilanzanforderungen abgeschaltet.
