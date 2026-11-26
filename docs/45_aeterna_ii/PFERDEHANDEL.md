# Pferdehandel

Ein Kauf nutzt denselben Geldbestand sowie die Händlerkasse, Zeitbuchung und Befehlskennung wie der bestehende Stadtmarkt. Die drei Pferde sind einzelne Angebote mit Bestand eins. Ihre Kennung verbindet die Welt-ID mit der Katalog-ID. Ein Verkauf führt dieselbe Kennung zum Händler zurück. Auswahl und Zaumzeug werden im vorhandenen Ausrüstungsbuch gespeichert.

| Pferd | Kaufpreis in Denaren | Zugang | Qualitäten |
| --- | ---: | --- | --- |
| Fara | 18 | Ab 18 Jahren | Ruhige Packstute, leicht zu führen |
| Silex | 36 | Bestätigte Versorgungslieferung | Trittsicheres Reisepferd mit mehr Ausdauer |
| Iuba | 58 | Lieferung sowie bestätigte Dorfverteidigung oder Sieg im Tal | Schnelles, anspruchsvoller zu handhabendes Kurierpferd |

Lederhalfter und wollene Reitdecke mit Gurt sind getrennte, bezahlte Gegenstände. Ein ausgewähltes Pferd kann angelegtes Geschirr tragen. Die Werte für Tempo, Ausdauer und Handhabung sind Balancing-Indizes für die spätere Reitphysik. Preise, Pferde und Händler sind fiktive Spieldaten. Das Zeitfenster ab 58 v. Chr. ist im Epochenregister verankert.

Der optionale Händler ist nur bei einem bereitgestellten, gültigen Weltanker in Reichweite zugänglich. Die sechs vorhandenen Stände behalten ihre Standorte und Verträge. Die Weltanbindung erhält den Katalog mit `CityTrade.shop_catalog(true)`, prüft ihren physischen Anker und übergibt die Position als `city_trade_sites["equarius"]` an WorldModel. `CityTrade.view` und `CityTrade.selected_horse` liefern eine lesbare Projektion für Handel, Anzeige und spätere Darstellung.

Handelsstände v1 behalten Belege, Geld, Zeit, Waren und Ausrüstung. Beim Laden ergänzt das Handelsmodul v2 die Zähler des Gestüts und freie Ausrüstungsplätze. Der übergeordnete Speichervertrag bleibt v6.

Der erste Kampagnenmorgen beginnt weiterhin zu Fuß, mit zwölf Jahren und ohne Geld. Stadtverankerung, animierte Tiere und Reiten sind eigene Integrationsschritte.

## Prüfung

```sh
python3 tools/check_prototype.py --keep-going --only horse_commerce city_trade commerce_transaction era_registry --report /tmp/imperathen-pferdehandel
```
