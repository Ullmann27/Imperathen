# IMPERATHEN – offene Römerwelt aus einem gelebten Dorfanfang

Umsetzungsspezifikation für Chat 1 · 23. November 2026

## 1. Verbindliches Spielerziel

Die Hauptfigur lebt zunächst unter einer bereits bestehenden Herrschaft. Sie kommt in eine beschädigte Siedlung, hilft beim Wiederaufbau und wird durch Begegnungen, Arbeit, Freundschaft und übernommene Verantwortung Teil dieser Gemeinschaft. Erst aus diesem Leben können militärischer Dienst, Handel, Einfluss oder spätere politische Macht entstehen. Ein Herrschertitel ist kein Startzustand und kein automatischer Lohn für den ersten erfolgreichen Kampf.

Die gewünschte Erfahrung ist eine große, zusammenhängende, frei begehbare Römerwelt: Menschen mit erkennbaren Aufgaben, bewohnte Orte, laufender Alltag, persönliche Gespräche, Berufe, nachvollziehbare Gewaltfolgen und Wege zwischen den Siedlungen. Die Bezugnahme auf GTA beschreibt diese Offenheit und räumliche Glaubwürdigkeit. Assassin’s Creed Valhalla und das vom Nutzer gemeinte Spiel mit persönlichem römischem Kampf dienen als Qualitäts- und Erlebnisreferenzen. Namen, Figuren, Karten, Dialoge und Spieldateien dieser Spiele werden nicht als eigene Inhalte übernommen.

Android bleibt die erste Zielplattform. Dieselbe Welt soll später auch auf PC sinnvoll erweitert werden können. Visuelle Details dürfen zwischen den Grafikprofilen wechseln; Figurenidentitäten, Bauzustände, Besitz, Beziehungen und Kampfausgänge dürfen das nicht.

Dieses Dokument unterscheidet den aktuell ausführbaren Abschnitt von seinem nächsten Ausbau. Die vorhandenen Modelle und Kampfanimationen erreichen den verlangten Produktionsmaßstab noch nicht durchgehend.

## 2. Historischer Rahmen und veränderbarer Verlauf

### Belegte Ausgangslage

Der vorhandene römische Ursprung beginnt um **100 n. Chr.** Historischer Kaiser ist **Trajan**, dessen Regierungszeit das italienische Kulturministerium mit **98–117 n. Chr.** beschreibt. Seine Dakerkriege werden dort auf **101–102** und **105–106 n. Chr.** datiert. Das Quellenregister liegt in [HISTORICAL_SOURCES.json](HISTORICAL_SOURCES.json). Die verwendeten Primärseiten sind die [Beschreibung der Trajanssäule](https://cultura.gov.it/luogo/parco-archeologico-del-colosseo-colonna-traiana) und die [staatliche interaktive Darstellung der Säule](https://colonnatraiana.cultura.gov.it/).

Dieser Rahmen legt Epoche und historische Anker fest. Er belegt weder das konkrete Spielerdorf noch dessen Gespräche oder örtliche Überfälle. Decimus, Aelia, Varro, Fabius, Aurelia, Cassia und Severus sind für das Spiel geschaffene Figuren. Das Dorf und die neue Region sind ebenfalls fiktiv. Ihre Ereignisse können historisch plausibel gestaltet werden, ohne ihnen einen erfundenen Quellenbeleg zuzuschreiben.

Caesar und Trajan gehören nicht in dieselbe gegenwärtige Figurenbesetzung. Weitere Epochen benötigen einen eigenen Startzustand mit passender Politik, Ausrüstung, Orten und Lebensdaten. Ein frei wählbarer Jahrhundertwechsel innerhalb derselben unverändert jungen Figur wäre keine konsistente Kampagne.

### Drei getrennte Ebenen der Geschichte

| Ebene | Inhalt | Darf sich durch den Spieler ändern? |
| --- | --- | --- |
| Dokumentierter Ausgangsrahmen | Belegte Herrschaft, datierte Ereignisse, nachgewiesene Personen und Orte | Die Quelle bleibt unverändert; sie beschreibt den historischen Vergleich |
| Fiktiver persönlicher Lebensweg | Dorfbeziehungen, Beruf, örtliche Rettungen, Aufbau und neue Verbündete | Ja, unmittelbar durch die tatsächlich gespielten Handlungen |
| Spätere alternative historische Entwicklung | Eigenständig entwickelte Missionen mit einem ausdrücklich markierten Abzweig von einem belegten Verlauf | Ja, sobald Voraussetzungen, Kausalität und Folgen dieser Mission implementiert sind |

Der aktuelle Zustand `history.mode = fictional_branch` bezeichnet die eigenen Entscheidungen der Spielfigur. Eine Hilfe für Fabius schreibt damit noch keinen Dakerkrieg um. Spielbare historische Großmissionen und ihre alternativen Ausgänge sind bisher zukünftige Arbeit.

Eine solche Mission benötigt vor ihrer Umsetzung einen kleinen Faktenvertrag: Ort und Zeitraum, belegte Beteiligte, gesicherte Vorgeschichte, bekannte Quellenlücken, tatsächlicher Handlungsspielraum der Hauptfigur und der genaue Punkt, ab dem das Spiel eine andere Geschichte erzählt. Beispielsweise könnte eine vom Spieler gesicherte Lieferung die Versorgung einer fiktiven Einheit verändern. Daraus darf erst dann ein anderer Schlachtverlauf entstehen, wenn diese Einheit, Lieferung, Reisezeit und militärische Wirkung auch im Spiel existieren. Eine Dialogantwort allein ersetzt diese Ursache nicht.

### Kalender und Lebensalter

Die bestehende Figur beginnt mit zwölf Jahren. Der bisherige spätere Ausbildungsschritt lässt sechs Jahre vergehen und führt sie auf achtzehn Jahre, im römischen Rahmen also von 100 nach 106 n. Chr. Der erste Dakerkrieg fällt in diese Lücke. Die nächste historische Mission muss diese Chronologie respektieren: Sie kann beispielsweise mit belegten Ereignissen des Jahres 106 verbunden werden; eine rückwirkende aktive Teilnahme der bereits achtzehnjährigen Figur im Jahr 101 passt nicht zu diesem Start.

Die derzeitigen Dorftage sind ein beschleunigter Systemtakt. 120 Simulationssekunden entsprechen einem Prototyptag für Versorgung und Abläufe. Sie sind noch kein vollständiger Kalender, der Figuren, Jahreszeiten und dokumentierte Kriege automatisch gemeinsam fortschreibt. Vor einer historischen Kampagne sind Alltagstakt, Kalender, Alter und größere Zeitsprünge ausdrücklich miteinander zu verbinden.

## 3. Der erste spielbare Lebensabschnitt

### Ankommen und Orientierung

Der filmische Einstieg zeigt das Dorf und seinen beschädigten Zustand. Die erste eigene Aufgabe bleibt ein Dach vor dem Abend. Der Spieler erfährt, welches Holz er verwenden darf, wo ein Bauplatz liegt und warum er dort gebraucht wird. Decimus erklärt die bestehende Ordnung und erlaubt die Mitarbeit am Wiederaufbau. Diese Erlaubnis macht den Spieler zum Helfer mit einem Auftrag; die Verwaltung des Ortes bleibt bei Decimus.

Das Intro führt in dieselbe Welt, in der die Arbeit anschließend geschieht. Der Bau, die Gesprächspartner und die Schäden müssen später wiedererkennbar sein. Eine gezeigte Reparatur darf keinen Zustand behaupten, den der Spieler weder bezahlt noch fertiggestellt hat.

### Menschen vor Aufgabenlisten

Die erste Dorfphase verbindet unterschiedliche Personen mit verständlichen Bedürfnissen:

| Person | Konkreter Anlass zum Kennenlernen | Spielbare Verbindung |
| --- | --- | --- |
| Decimus | Ein beschädigtes Dorf muss versorgt und wiederhergestellt werden | Erlaubnis zur Arbeitskoordination |
| Aelia | Eine beschädigte Mauer braucht zunächst eine sichere Stütze | Steinmetzlehre und Arbeit mit Stein |
| Varro | Spuren am Waldrand und fehlender Proviant für die nächste Runde | Späherlehre und frühe Erkundung einer Gefahr |
| Fabius | Im Holzlager ist sichere Zusammenarbeit zu zweit nötig | Holzfällerlehre und Materialversorgung |
| Aurelia | Verletzte brauchen Nahrung, Versorgung und Ruhe | Heilkundelehre, Rettung und Erholung |
| Cassia | Ein beschädigter Wagen und unsichere Wege blockieren Waren | Handelslehre und nachvollziehbare Warenflüsse |
| Severus | Wache und Ausbildung verlangen Vorbereitung und Disziplin | Wachausbildung, Alarm und persönliche Abwehr |

Das erste Gespräch findet bei der tatsächlichen Person statt. Eine einmal bezahlte Hilfe verändert ihre eigene Beziehung zum Spieler. Begrüßungen und mehrfach eingereichte Antworten erzeugen keine wiederholten Belohnungen. Eine abgelehnte Bitte beendet nicht grundsätzlich jeden Kontakt; spätere echte Verteidigung kann Vertrauen aufbauen.

Der Spieler kann mehrere Bekanntschaften und Verbündete besitzen. Der aktuell gewählte Beruf ist ein Schwerpunkt, kein unveränderliches Lebensende. Ein Wechsel benötigt eine passende Beziehung und drei Denare für das neue Werkzeug. Ein Bündnis benötigt erarbeitetes Vertrauen und gemeinsame Versorgung. Der Verbündete bleibt dieselbe Person mit derselben Gesundheit und Arbeitseinteilung.

### Alltag, Warnung und Folge

Der erste Angriff setzt eine fertige Unterkunft, drei Bekanntschaften und mindestens einen vergangenen Prototyptag voraus. Der Spieler erlebt zuvor einen Zusammenhang zwischen Versorgung, Arbeit und Sicherheit. Die folgende Warnphase lässt Zeit, eine Spur zu lesen, Alarm zu geben und tatsächliche Personen für die Verteidigung freizustellen.

Während eines Angriffs ruhen die zivilen Arbeiten. Gegner kommen durch die Welt, bedrohen Menschen und versuchen, Getreide zu erreichen. Der Spieler kann persönlich kämpfen, sich schützen, eine gefährdete Person retten und mit einer wirklich besetzten Wache zusammenarbeiten. Seine Fähigkeiten wachsen aus den bestätigten Beiträgen. Ein Sieg allein durch die Wache wird nicht als seine persönliche Kampferfahrung verbucht.

Nach dem Angriff bleiben Vorratsverluste, Verletzungen, veränderte Beziehungen und die getroffenen Entscheidungen bestehen. Der Spieler muss die Versorgung wieder aufnehmen und benötigte Menschen zurück in ihre Arbeit bringen. Der nächste Tag verwendet diesen Zustand. Die spätere Ausbildung bleibt erst nach ausreichender Dorfzeit und einem abgeschlossenen Überfall erreichbar; ein Haus allein überspringt den Abschnitt nicht.

## 4. Zusammenhängende Spielmechanik

### Ein Mensch, eine Aufgabe

Das neue Wirtschaftssystem führt **14 namentliche erwachsene Arbeitskräfte**. Jeder besitzt eine stabile ID, einen Beruf, Gesundheit, Hunger und genau eine aktuelle Zuweisung. Die Hauptfigur und ihr jugendlicher Gefährte werden nicht als zusätzliche erwachsene Betriebsarbeiter gezählt. Bereits bestehende andere Dorfcharaktere behalten ihre Identität und Rolle; zusätzliche Kulissenfiguren dürfen nicht als kostenlose Belegschaft behandelt werden.

| Betrieb | Erforderliche Personen | Unmittelbare Abhängigkeit |
| --- | ---: | --- |
| Holzfällerlager | 2 | Reparierter Betrieb und verfügbarer Holzbestand |
| Steinbruch | 4 | Reparierter Betrieb und verfügbarer Steinbestand |
| Handelsplatz | 2 | Reparierter Betrieb, tatsächliche Holzfracht und Geld des Käufers |
| Stadtposten | 2 | Reparierter Posten, einsatzfähige Menschen und wirkliche Nähe zur Gefahr |
| Dorffelder | 2 | Erntereife Felder, später Saatgut und Arbeit für die nächste Ernte |

Alle fünf Betriebe gleichzeitig benötigen zwölf Personen. Zwei bleiben bei voller Besetzung als Reserve. Werden drei Menschen dauerhaft für den persönlichen Trupp angeworben, kann nicht zusätzlich jeder dieser Betriebe unverändert vollständig besetzt bleiben. Diese Entscheidung muss sich in Versorgung, Ertrag oder Sicherheit zeigen.

Die vorhandene Arbeitseinteilung setzt den gemeinsamen Arbeitsort der Figur. Tatsächliche Wege zum Arbeitsplatz, Werkzeugaufnahme und ausführliche Arbeitsschritte sind ein nächster Ausbau. Sie dürfen später erst dann Produktion freigeben, wenn die benötigten Personen angekommen sind. Bis dahin ist die aktuelle sofortige Zuweisung als Vereinfachung des Prototyps zu behandeln.

### Material und Wiederaufbau

Der zuerst notwendige Bau darf keine Ressource verlangen, die ausschließlich dieser noch ungebauten Anlage entstammt. Deshalb benötigen die ersten Reparaturen von Holzlager und Steinbruch Holz. Erst der funktionierende Steinbruch erschließt Stein für die weiteren Betriebe.

Ein Reparaturauftrag bezahlt sein Material beim Beginn. Er benötigt danach echte Arbeitszeit und die gesamte vorgeschriebene Belegschaft. Fehlende Menschen pausieren den Auftrag; sie liefern keine rückwirkende Arbeitszeit. Der Fortschritt bleibt gespeichert, wenn der Spieler das Spiel beendet oder sich zunächst um einen Überfall kümmert.

Holz, Getreide, Denare und Stein liegen in einem einzigen maßgeblichen Vorrat. Jeder Verbrauch und Ertrag wird zusätzlich seinem auslösenden System zugeordnet. Die örtlichen Bestände des Waldes, des Steinbruchs, der Felder und des Händlers sind endlich. Berufsboni beschleunigen eine tatsächliche Gewinnung oder verbessern einen tatsächlichen Verkauf; sie erzeugen keine Rohstoffe außerhalb dieser Bestände.

### Versorgung vor Wachstum

Jeder lebende erwachsene Einwohner benötigt pro Prototyptag eine Getreideration. Zwei Feldarbeiter können derzeit unter ungestörten Bedingungen 24 Getreide pro Tag ernten. Vierzehn Einwohner verbrauchen vierzehn. Überfälle, Verletzungen, fehlende Arbeitskräfte und Hilfeleistungen verändern diesen Überschuss.

Wer zweimal keine Ration erhalten hat, wird vorübergehend arbeitsunfähig. Nahrung und Ruhe stellen die Arbeitsfähigkeit wieder her. Ein begrenztes Notlager kann gegen echte Zahlung helfen; es ist keine endlose Auffüllung. Die Neuaussaat braucht vier Getreide und einen Tag Arbeit zweier Menschen. Weil während dieses Tages keine neue Ernte anfällt, benötigt die vollzählige Belegschaft **mindestens achtzehn Getreide für Saat und einen ungestörten Versorgungszyklus**, zuzüglich einer sinnvollen Reserve gegen weitere Ausgaben oder Verluste. Diese Reserve muss später rechtzeitig im Spiel sichtbar angekündigt werden.

Der aktuelle Rohstoffpool bildet den gemeinsamen Vorrat dieses Abschnitts ab. Private Taschen, Gemeindeeigentum, Sold, Steuern und rechtmäßige Baugrundrechte sind vor ihrer Einführung getrennt zu spezifizieren. Dieselbe Menge darf beim Umbuchen zwischen Privatbesitz, Lager und Handelsfracht nicht verdoppelt werden.

### Verteidigung, Miliz und Fähigkeiten

Ein zur Verteidigung eingeteilter Mensch fehlt an seiner bisherigen Arbeitsstelle. Er kann nach dem Angriff nur in einen noch freien Arbeitsplatz zurückkehren. Die spätere persönliche Miliz rekrutiert ebenfalls vorhandene Menschen; `village.militia` verbindet die Truppfiguren mit ihren Einwohner-IDs. Dieselbe Person darf dabei nicht zugleich als arbeitender Dorf-NPC sichtbar und als Soldat vorhanden sein.

Fällt ein solcher Soldat im bestehenden militärischen Gefecht, trägt sein tatsächlicher Dorfbewohner den Verlust. Gesundheit, Belegschaft und Nahrungsbedarf müssen diesen Zustand beim nächsten Speichern und Laden weiterführen. Ein später geheilter Spieler stellt keine gefallenen Personen wieder her.

| Fähigkeit | Geeignete bestätigte Handlungen | Ungeeignete automatische Belohnung |
| --- | --- | --- |
| Mut | Tatsächliche Teilnahme an der Verteidigung und Rettung einer gefährdeten Person | Bloßes Warten während eines Angriffs |
| Kampf | Wirksamer Treffer, tatsächlich abgefangener Angriff | Wiederholtes Schwingen ohne gültiges Ziel |
| Scharfsinn | Eine konkrete Spur richtig untersuchen, einem tatsächlichen Angriff ausweichen | Öffnen und Schließen eines Informationsfensters |
| Taktik | Rechtzeitiger Alarm und miteinander verbundene Vorbereitung | Beliebiges Umstellen eines Befehls ohne Folge |

Der vorhandene Nahkampf prüft Ziel, Entfernung, Ausdauer und zeitliche Fenster. Für die angestrebte Qualität müssen als nächster Schritt sichtbarer Ansatz, Schlaganimation, Kontaktzeitpunkt, Abwehrreaktion und tatsächlicher Treffer miteinander synchronisiert werden. Eine schönere Animation allein darf weder die Reichweitenprüfung umgehen noch einen zweiten Treffer erzeugen.

## 5. Große Welt mit nutzbaren Orten

Der bestehende technische Rahmen umfasst eine eigene **32 × 32 km große Koordinatenwelt** mit **250-m-Sektoren**. Das entspricht **1.024 km²**. Diese Zahl ist eine Projektentscheidung; sie wird nicht als verifizierte Flächengröße von GTA VI ausgegeben. Der Stand und die Quellen zur Vergleichsrecherche stehen in [ASSETS_AND_WORLD.md](ASSETS_AND_WORLD.md).

Der Planer enthält neun Landschaftszonen, vierzehn benannte Orte und sechzehn Straßenverbindungen. Das vorhandene Grenzdorf ist als bestehender Inhalt markiert, die dreizehn Fernorte als geplant. Ein Geländeadapter erzeugt tatsächlich begehbare Sektorgeometrie und Nahbereichskollision. Daraus entsteht noch keine ausgestaltete Marktstadt, kein belebter Hafen und keine große historische Mission.

Jeder nächste Ort braucht vor seiner Freigabe einen konkreten Zweck: eine zusätzlich erschließbare Rohstoffquelle, einen tatsächlichen Käufer, einen Verbündeten, eine andere Ausbildungsstelle oder ein Ereignis mit Folgen. Der erste sinnvolle Regionalausbau ist ein erreichbarer Außenort mit Reiseweg, Personen, Produktion, Transport und gespeicherter Rückwirkung auf das Heimatdorf.

Nah- und Fernsimulation müssen denselben Zustand führen. Wenn ein Holzarbeiter aus dem sichtbaren Bereich verschwindet, darf er weder aufhören zu existieren noch zusätzlich als zweiter Fernarbeiter erzeugt werden. Ein ruhender Sektor muss beim erneuten Betreten denselben Baufortschritt, dieselben Verletzungen und dieselbe Fracht wiedergeben. Kartenlinien beschreiben Wege; sie buchen keine Handelserträge.

## 6. Figuren und Gestaltung als Produktionsauftrag

Die gewünschte menschliche Glaubwürdigkeit benötigt nachvollziehbare Gesichter, Körperproportionen, Hände, Kleidung, Ausrüstung und Bewegungen. Wache, Legionär und Offizier sind unterschiedliche Aufgaben mit passenden Ausrüstungsvarianten. Eine Kohorte entsteht aus individuellen Einheiten, Formation, Befehlen, Versorgung und Verlusten. Ein einziges zusammengebackenes Kohortenmodell kann diese Regeln nicht ersetzen.

Das vorhandene Assetregister enthält recherchierte Kandidaten, einschließlich eines als FBX beschriebenen frei lizenzierten Römermodells sowie kommerzieller Angebote mit angegebenen GLB-/glTF-Konvertierungen. Diese Fremdmodelle wurden in diesem Schritt nicht heruntergeladen, importiert oder als geprüft spielbereit übernommen. Die Anbieterangabe „GLB“ beweist weder ein nutzbares Gesichtsskelett noch exportierte Kampfanimationen. Die konkreten Funde und ihre Grenzen stehen in [ASSETS_AND_WORLD.md](ASSETS_AND_WORLD.md).

Der nächste tatsächlich übernommene Mensch braucht Originalquelle, Autor, genaue Lizenz, Dateiprüfsumme und technische Prüfung. Anschließend folgen Maßstab, Skelett, Gesicht, Hände, Waffenanschluss, Fußkontakt, Bewegungsübergänge und LODs in derselben echten Spielszene. Für Dorfmaterialien kommen die dort dokumentierten CC0-Quellen infrage; Materialmaßstab und Wiederholung sind am tatsächlichen Haus zu prüfen.

Die erste visuelle Abnahme sollte eine zusammenhängende Handlung zeigen: am Dorf ankommen, mit einer Person sprechen, zum Arbeitsplatz gehen, gemeinsam arbeiten, den Alarm wahrnehmen, die Verteidigung erreichen und nach dem Angriff die verletzte Person wiederfinden. Das zeigt zugleich, ob Figuren, Orte und Mechanik zusammenpassen. Ein einzelnes Standbild kann diesen Zusammenhang nicht ersetzen.

## 7. Nächste Arbeitspakete in Abhängigkeitsreihenfolge

| Priorität | Konkretes Ergebnis | Voraussetzung | Abnahme |
| --- | --- | --- | --- |
| 1 – Dorfablauf vollständig sichtbar | Tatsächliche Personen, Betriebe, Gefahr und Folgen in einer durchgehend spielbaren Szene | Gemeinsame Identitäten und aktueller Zustand | Derselbe Einwohner wird im Gespräch, bei Arbeit, Rettung und nach dem Laden wiedererkannt; keine Doppelmodelle |
| 2 – Alltag und Arbeitswege | Hinweg, Ankunft, Werkzeugeinsatz, Pause und Rückkehr | Verlässliche Bewegung und erreichbare Arbeitsanker | Produktion beginnt erst nach Ankunft; bei blockiertem Weg erklärt der Betrieb seinen Stillstand |
| 3 – Längerer Aufbau ohne Rohstoffsackgasse | Weitere zugängliche Wald-/Steinbestände und rechtzeitige Saat-/Versorgungsplanung | Erster betretbarer Außenort, konkrete Wege und Materialtransport | Die erschöpfte Ausgangsquelle lässt sich durch ein erspieltes, bezahltes Vorhaben ersetzen; kein unbegrenztes Auffüllen |
| 4 – Persönlicher Kampf mit sichtbarer Ursache | Animationen, Kontakt, Abwehr, Verletzung und Ton stimmen mit dem Kampfereignis überein | Geeignetes Rig und Waffenanschluss | Ein Angriff hat einen erkennbaren Ansatz, genau einen bestätigten Treffer und eine passende Reaktion |
| 5 – Regionaler Handel und Bündnisse | Eine tatsächlich reisende Lieferung und ein verbündeter Außenort | Außenort, Frachtzustand, Reisezeit, sichere Rückkehr | Frachtverlust oder Rettung verändert exakt den Warenbestand und die Beziehung der beteiligten Orte |
| 6 – Historische Mission mit klarem Abzweig | Eine belegte Ausgangslage und mehrere kausal unterschiedliche spielbare Folgen | Gemeinsamer Kalender, funktionierende Region und benannte beteiligte Einheiten | Historische Fakten und eigene Ereignisse sind erkennbar; der alternative Ausgang folgt aus gespeicherten Taten |
| 7 – Erweiterte Bevölkerung und politische Stellung | Zuzug, Ausbildung, Entlassung aus der Miliz und begrenzte neue Zuständigkeiten | Versorgung, Wohnraum, sichere Wege, geklärtes Eigentum und Autorität | Jede zusätzliche Person muss ankommen und versorgt werden; jede Machtbefugnis hat eine nachvollziehbare Ursache |

Vor einer starken Vergrößerung der Zahl sichtbarer Personen ist die kombinierte Szene auf dem vorgesehenen Android-Gerät zu messen. Die vier Grafikprofile verändern Darstellungsbudgets. Sie dürfen weder unbemerkt Gegner entfernen noch Arbeitskräfte, Verluste oder Beziehungen anders berechnen.

## 8. Fachliche Grenzen, die bei der Fortsetzung nicht verloren gehen dürfen

1. **Kalender:** Der gegenwärtige sechsjährige Übergang überspringt dokumentierte Ereignisse. Historische Missionsreihen benötigen deshalb zuerst eine ausdrücklich konsistente Zeitachse.
2. **Langzeitversorgung:** Getreide lässt sich durch bezahlte Aussaat erneuern; Wald und Steinbruch des Startabschnitts sind endlich. Ohne neue reale Quellen ist ein unbegrenzt wachsendes Dorf nicht spielbar. Rohstofferschöpfung ist ein Anlass für Regionalinhalt, keine Aufforderung zum heimlichen Zurücksetzen des Vorrats.
3. **Personal:** Drei Rekruten plus alle zwölf festen Arbeitsstellen überschreiten vierzehn Erwachsene. Entlassung, Zuzug, Schichtplanung oder bewusst reduzierte Produktion benötigen jeweils eine eigene nachvollziehbare Regel. Der bestehende Milizauftrag ist noch kein vollständiges Personal- und Dienstzeitsystem.
4. **Wege:** Die aktuelle Arbeitseinteilung verlegt den gemeinsamen Arbeitsanker unmittelbar. Ankunftszeit und Wegfindung sind als nächster mechanischer Schritt nötig, bevor die Karte viele Kilometer täglicher Arbeitswege zulässt.
5. **Autorität und Eigentum:** Eine einmalige Mithilfeerlaubnis darf bei der Erweiterung nicht versehentlich zur uneingeschränkten politischen Befehlsgewalt werden. Neue Baugrundstücke, Gemeindegeld, Abgaben und militärischer Dienst benötigen verständliche Zuständigkeiten.
6. **Geschichtsschreibung:** Lokale fiktive Entscheidungen bleiben als solche gekennzeichnet. Eine tatsächliche historische Abweichung wird erst behauptet, wenn die passende Mission und ihre Folgen existieren.
7. **Grafik und Fläche:** Der Koordinatenrahmen und begehbares Gelände sind vorhanden. Vollständige Bevölkerung dieser Fläche, produzierte historische Großschlachten und durchgehend erreichte AAA-Charakterqualität sind damit nicht behauptet.

Der nächste integrierte Ausbau soll jeweils einen vollständigen Zusammenhang schließen: Person, Ort, Handlung, Kosten, Folge und gespeicherter Fortbestand. Dadurch entsteht aus dem Dorfanfang schrittweise die gewünschte offene Römerwelt.
