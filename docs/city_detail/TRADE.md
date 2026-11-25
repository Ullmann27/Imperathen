# Stadtmarkt, Ausrüstung und belegte Belohnungen

## Gelieferter Umfang

Der optionale Stadtmarkt verwendet den vorhandenen `WorldModel`, dessen atomare Befehle, dessen Wiederholungsschutz und denselben Spielstand. Er ergänzt sechs tatsächlich nutzbare Verkaufsstellen mit 16 Waren. Der einzige ausgebbare Geldbestand bleibt `resources.denarii`; Zahlungen laufen gegen die vorhandene endliche Kasse `village.economy.stocks.merchant_denarii`.

Die Unterstützungsszene aktiviert den Markt ausdrücklich mit `model.execute("city_trade_enable")`. Normale neue Spiele und alte Saves erhalten dadurch keinen ungefragten Moduswechsel. Der Zwölfjährige bleibt zwölf; die Initialisierung schreibt weder Kindheitsfortschritt noch Questgegenstände, Ausrüstung, Siege oder Geld. Die Reservierung von Haushaltsmünzen und Paketen im bestehenden `childhood.carried` bleibt vollständig getrennt von verkäuflichen Waren.

Das Modul führt den bislang fehlenden allgemeinen Warenbestand `village.city_trade.inventory` ein. Es dupliziert kein vorhandenes Geld- oder Questinventar.

## Verkaufsstellen und reale Transaktionen

| Verkaufsstelle | Welt-X/Z | Sortiment |
| --- | --- | --- |
| Bäckerei | −10 / −8 | Brot |
| Lebensmittelstand | −4 / −8 | Oliven, Käse, getrocknete Feigen |
| Garküche und Trinkwasser | 4 / −8 | Warmer Eintopf, Trinkwasser |
| Töpferei | 10 / −8 | Tonbecher, Öllampen |
| Tuch- und Lederwaren | −10 / 4 | Leinentunika, Wollmantel, Ledergürtel |
| Waffen- und Ausrüstungsschmiede | 10 / 4 | Gladius, Scutum und als Belohnung erworbene Wertgegenstände |

Ein Kauf oder Verkauf verlangt tatsächliche Nähe von höchstens drei Metern, vorhandene Ware und eine vollständige Zahlung. Fehlbeträge, fremde Sortimente, negative oder gebrochene Mengen, fremde Preise und erschöpfte Vorräte werden verworfen. Verkaufserlöse stammen aus derselben endlichen Kasse; Käufe füllen sie wieder auf. Ausrüstung muss vor dem Verkauf abgelegt werden.

Die Mengen aller Käufe, Verkäufe, Verbräuche, Dienstausgaben und Auszeichnungen ergeben den Inventarbestand. Die daraus hergeleitete Geldsumme ergänzt die bestehende Weltbilanz, wie bereits die getrennten Erzähl- und Wirtschaftsbeiträge. Auch ein gemeinsam veränderter Kaufbeleg und Gegenstandsbestand ohne die zugehörige Zahlung wird dadurch abgelehnt. Das ist Integritätsprüfung für den lokalen Spielstand, kein Schutz vor absichtlichem vollständigem Umschreiben durch dessen Besitzer.

Preise, Warenbestände, Wiederverkaufswerte und Ausrüstungswirkungen sind vorläufige Spielbalance; sie werden nicht als historische römische Preise oder physiologische Messwerte ausgegeben.

## Essen und Trinken

Gekaufte Speisen stellen begrenzt Gesundheit und Ausdauer her; Trinkwasser stellt Ausdauer her. Eine tatsächliche Portion wird aus dem Warenbestand entfernt. Die Gesundheitsänderung wird im bereits vorhandenen `village.health_delta` verbucht. Werte werden bei 100 begrenzt. Ist die Figur bereits vollständig erholt, bleibt die Portion erhalten.

Während einer laufenden Kampfbewegung oder eines aktiven Angriffs sind Handel und Verbrauch gesperrt. Die Anwendung einer Portion ist derzeit eine Regelaktion; eine vollständig animierte Essens- oder Trinkbewegung wird damit nicht behauptet.

## Soldatenweg und kostenlose Erstausrüstung

Die erste Dienstausgabe setzt die vorhandene vollständig bestätigte erwachsene Ausbildung voraus: mindestens 18 Jahre, Rolle Soldat, abgeschlossene drei Ausbildungstreffer und passende gespeicherte Spielphase. Alter allein oder eine dekorative Waffenfigur genügen nicht.

An der Ausrüstungsschmiede erhält dieser Soldat genau einmal kostenlos:

- einen Gladius;
- ein Scutum;
- eine Leinentunika;
- einen Ledergürtel.

Diese kostenlose Ausgabe ist eine ausdrückliche Spielregel aus Heinz' Auftrag, keine Behauptung über die römische Besoldungspraxis. Der Ausgabestatus übersteht Speichern, Laden und wiederholte Befehlsübermittlung. Waffen und Schild sind auch beim Kauf für das Kind gesperrt.

Im optional aktivierten Stadtmodus genügt die frühere bloße Ableitung des Waffenrechts aus der Ausbildung nicht mehr: Die vorhandene Kampfautorität verlangt tatsächlich besessene und angelegte Waffen. Das Ablegen des Gladius beendet das Schwertrecht. Alte Karrieren ohne Stadtmodus behalten ihren bisherigen Vertrag.

Die Stadt-Ausrüstungsausgabe ist eine namenlose Verkaufsstelle. Sie ersetzt oder belebt Sextus nicht. Seine Rolle, die Schmiedelehre in der Kindheit und seine kanonische Geschichte bleiben unverändert.

## Auszeichnungen und echte Wirkungen

| Auszeichnung | Erforderlicher gespeicherter Beleg | Zusätzlicher Gegenstand | Ausgabelohn |
| --- | --- | --- | --- |
| Verlässlich bei der Wachhilfe | Kindheitsauftrag `return_gear` tatsächlich abgeschlossen | Bronzefibel | 3 Denare |
| Bewährte Dorfverteidigung | Erwachsen; zuletzt erfolgreich abgewehrter Überfall mit eigenem Beitrag | Ausgezeichneter Gladius | 8 Denare |
| Bestätigte Versorgungslieferung | Vorhandener Frontier-Lieferauftrag vollständig abgeschlossen | Ledergürtel | 6 Denare |
| Gesicherte Talstraße | Tatsächlicher gespeicherter Sieg im Talgefecht | Verdienstmantel | 15 Denare |

Die Beträge sind eine einmalige zusätzliche Ausgabe am Ausrüster. Bereits bestehende unmittelbare Missionsvergütungen bleiben erhalten. Es gibt keinen öffentlichen Befehl, der eine Mission als erfolgreich erklärt oder frei gewählte Erfahrungspunkte vergibt. Die Auszeichnung folgt den vorhandenen Zuständen; ihre ID kann nach der Ausgabe nicht erneut vergütet werden.

Erlernte Erfahrung wird aus den bestätigten Auszeichnungen abgeleitet und bleibt beim Ablegen oder Verkauf eines Gegenstands erhalten. Ausrüstungsboni werden ausschließlich aus den aktuell belegten Plätzen berechnet.

Die angeschlossenen Wirkungen sind:

- **Kampf:** Gelernter Kampffortschritt und bei Schwerttechniken der angelegte Waffenbonus erhöhen den echten Schaden im vorhandenen Trefferfenster.
- **Abwehr:** Gelernter Abwehrfortschritt und angelegte Schutzausrüstung verlängern das echte Schutzfenster innerhalb einer festen Grenze.
- **Kommando:** Gelernter Kommandofortschritt und angelegte Kommandogegenstände erhöhen begrenzt die tatsächliche Truppmoral, sobald ein real angeworbener Trupp vorhanden ist.

Daraus folgt keine neue magische Spezialfähigkeit. Es entsteht auch noch kein neues sichtbares Tunika- oder Mantelmodell am Körper. Diese Kleidungsgegenstände besitzen Bestand, Anlegeplätze und regelwirksame Eigenschaften; ihre gesonderte visuelle Umsetzung bleibt eine eigene Integrationsarbeit.

## Integrationsschnittstelle

`preload("res://scripts/city_trade.gd")` liefert den Domänendienst.

| API / Befehl | Vertrag |
| --- | --- |
| `shop_catalog()` | Kopierter Katalog mit ID, Name, Art, Weltposition und Sortiment |
| `view(data, shop_id)` | Nur lesende Ansicht für Geld, Läden, Angebote, Inventar, Erfahrung, Ausrüstungsboni, Ausgabe und Auszeichnungen |
| `city_trade_enable {}` | Explizite Aktivierung des optionalen Modus, ohne Geschenke |
| `city_buy / city_sell {shop_id,item_id,quantity}` | Atomare Waren- und Geldtransaktion |
| `city_consume {item_id}` | Eine vorhandene Portion anwenden |
| `city_equip {item_id}` | Vorhandene Ausrüstung anlegen; derselbe aktive Gegenstand wird abgelegt |
| `city_issue_service {shop_id:"armorer"}` | Einmalige kostenlose Erstausgabe nach erwachsener Ausbildung |
| `city_claim_reward {shop_id:"armorer",reward_id}` | Einmalige belegte Auszeichnung an der Ausgabestelle |

Alle schreibenden Befehle laufen durch `WorldModel.execute`. Die Anzeige darf niemals selbst Geld, Waren, Erfahrung, Gesundheit oder Erfolge vergeben. `view().service.eligible` und `view().rewards[].eligible` sind die freigegebenen UI-Felder.

## Ausgeführte Prüfungen

Die endgültigen Zahlen, Engine-Version, Quellhashes und unveränderten Ausgaben stehen in [evidence/trade/report.json](evidence/trade/report.json) und den zugehörigen Protokollen.

Die neue Handelsgruppe prüft Nähe, sechs Sortimente, fehlerhafte Mengen, Kauf-/Verkaufsbilanz, endliche Vorräte, Kindersperre, reale Regeneration, falsche Inventare und unbezahlte Belege, Save/Load, dauerhafte Befehlsreplays, kostenlose Einmalausgabe und Einmalbelohnung. Für die Soldatenprüfung werden Dorfleben, Verteidigung und erwachsene Ausbildung über bestehende echte Befehle erreicht. Lediglich die Testfigur wird an die erforderlichen Orte gesetzt; die Geometrieprüfung verwendet dokumentierte deterministische Callbacks.

Die neue Prüfung erfasst außerdem einen echten Gladiuskontakt: Der Gegner verliert 20 von 60 Lebenspunkten, zusammengesetzt aus 18 Basisschaden, einem erlernten und einem angelegten Bonuspunkt. Ein tatsächlicher Abwehrbefehl erzeugt ein Fenster von 0,927 Sekunden: 0,85 Sekunden Basis, 0,032 aus Erfahrung und 0,045 aus Ausrüstung.

Zusätzlich wurden die bestehenden Domain-, CombatActions- und CombatModel-Integrationsgruppen ausgeführt. Die anschließende gezielte Wirtschaftsprüfung bestand mit 191/191 VillageEconomy- und 245/245 CommerceTransaction-Prüfungen. Diese beiden Gruppen verwendeten jeweils eigene temporäre XDG-Daten-, Konfigurations- und Cacheverzeichnisse sowie den isolierten Testmodus. Diese Nachweise gelten für lokale Regel- und Speicherfunktion auf Godot 4.7.2. Sie behaupten weder einen durchgängigen menschlichen Spieldurchlauf noch Android-Bildrate, Temperatur, eine neue APK oder eine vollständige historische Stadt.

