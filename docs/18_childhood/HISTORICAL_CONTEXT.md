# Historischer Rahmen, Handel und der fiktive Reiterüberfall

Stand: 23. November 2026. Dieser Rahmen gehört zum Kindheitsanfang von Chat B. Die Quellen wurden für diese Fortsetzung erneut geöffnet. Das maschinenlesbare Register steht in [HISTORICAL_SOURCES.json](HISTORICAL_SOURCES.json).

## Ort, Zeit und Gegner

Der historische Ausgangspunkt bleibt ungefähr **100 n. Chr. unter Trajan**. Für die Dorfhandlung wird ein **fiktiver ziviler Ort im römischen Donaugrenzraum** verwendet. Er ist keine archäologische Rekonstruktion eines bestimmten Dorfes. Die bestehende technische Herkunftskennung `italia` bleibt aus Gründen der Spielstandkompatibilität erhalten; sie ist kein Beleg für eine Lage dieses Dorfes in Italien.

Der Donauraum passt zu einer späteren, ausdrücklich getrennten Handlung um die Dakerkriege. Das italienische Kulturministerium datiert Trajans Regierungszeit auf 98–117, den ersten Feldzug auf 101–102 und den zweiten auf 105–106. Der auf UNESCO gehostete, vom rumänischen Kulturministerium eingereichte Tentativlistentext beschreibt die untere Donau als römischen Grenzraum mit Militärbasen im ersten Jahrhundert. Er nennt die Einrichtung der Provinz Dacia erst für 106. Diese Vorlage ist eine staatliche Einreichung und keine unabhängige Bestätigung jedes historischen Satzes durch UNESCO. [Kulturministerium](https://cultura.gov.it/luogo/parco-archeologico-del-colosseo-colonna-traiana) · [Donaulimes-Vorlage](https://whc.unesco.org/en/tentativelists/6446/)

**Parthien gehört zu einer anderen möglichen Kampagnenregion.** Das Metropolitan Museum nennt bei einem Militärdiplom von 113/14 Trajans Partherkrieg 114–117 und den Zug nach Osten. Ein fiktiver Dorfangriff im Donauraum um 100 wird deshalb weder als dieser Krieg noch als eine nachgewiesene parthische Operation bezeichnet. Auch für Dakien wird kein überall gültiger „größter Feind“ behauptet. [Metropolitan Museum, Objekt 23.160.52](https://www.metmuseum.org/art/collection/search/251396)

Die etwa dreißig sichtbaren Reiter der Nachtsequenz sind **eine unbekannte, für das Spiel geschriebene Bande**. Ihre Zusammensetzung, Zahl, Route, Handlungen und der Überfall sind Fiktion. Eine Verwandtschaft ihrer Ausrüstung mit allgemeinen zeitgenössischen Formen weist ihnen weder Herkunft noch Ethnie zu. Die historischen Feldzüge werden erst dann zu spielbaren Ereignissen, wenn gesonderte recherchierte Missionen sie tatsächlich umsetzen. Persönliche Folgen für Julia, Silvanus, Sextus und die übrigen eigenen Dorffiguren gehören zur fiktiven Handlung.

## Kleidung und Pferdeausrüstung: Referenz und Grenze

Das Museum Segedunum beschreibt für römische Reiter der **Hadrianszeit** Tunika, Reithose, Zügel und einen Sattel mit vier Hörnern ohne Steigbügel. Diese Darstellung ist eine allgemeine Vergleichsquelle für die nahe Epoche, kein Uniformnachweis für unsere fiktive Bande im Jahr 100. Die Modelle verzichten deshalb auf moderne Steigbügel, moderne Kleidung und behauptete Stammesabzeichen. Ihre gedeckten Stofffarben, Körperformen und Fellvarianten sind eigene gestalterische Entscheidungen. [North East Museums](https://www.northeastmuseums.org.uk/segedunum/learning/cavalry-soldiers)

Die wissenschaftliche Untersuchung von Peter Connolly und Carol van Driel-Murray, *The Roman Cavalry Saddle*, **Britannia 22 (1991), S. 33–50**, erklärt bereits im öffentlich zugänglichen Auszug, dass kein vollständiger römischer Sattel erhalten ist. Darstellungen sowie Leder- und Metallteile bilden die Rekonstruktionsgrundlage. Ein vollständig gesichertes Originalmodell wird deshalb nicht behauptet. Die Webseite wurde 2011 digital veröffentlicht; das Erscheinungsjahr des Fachaufsatzes ist 1991. [Cambridge University Press, DOI 10.2307/526629](https://www.cambridge.org/core/journals/britannia/article/abs/roman-cavalry-saddle/B94F665AA39C169357EB255B87796211)

Die neuen Pferde und Reiter sind reproduzierbare eigene Geometrie aus dem Godot-Quellcode. Sie sind technische Darstellungsmodelle mit sichtbarem Pferdekörper, vier gegliederten Beinen, Kopf, Mähne, Schweif, Sattel und sitzendem Reiter. Sie ersetzen keine vorhandenen Originalfiguren und sind kein behaupteter AAA-Charakterabschluss. Es wurden keine Bilder, Texturen oder Modelle aus den Quellen übernommen.

## Münzen und tatsächliche Bilanzen

Für das frühkaiserzeitliche Münzsystem belegt die American Numismatic Society die Beziehung **1 Aureus = 25 Denare = 100 Sesterzen = 400 As**. Daraus folgen **1 Denar = 4 Sesterzen = 16 As**. Der Denar ist hier die größere silberne Recheneinheit, Gold wird nicht zur alltäglichen Kleingeldwährung. Die Warenpreise im Spiel sind ausdrücklich eigene Balancewerte; aus der Umrechnung folgt kein historischer Brot-, Holz- oder Steinpreis. [American Numismatic Society](https://numismatics.org/rome-a-thousand-years-of-monetary-history/)

`village_trade.gd` verwendet ausschließlich ganze Zahlen. `data.resources.denarii` enthält weiterhin ganze Denare. Ein neuer gespeicherter Rest `village.trade.change_asses` enthält 0–15 As. Gemeinsam bilden sie das tatsächlich ausgebbare Geld. Ein Kauf für drei As kann daher einen Denar wechseln und dreizehn As zurückgeben. Sesterzen erscheinen als korrekte Darstellungseinheit; die interne Rechnung erfolgt in As. Es gibt keinen zweiten frei ausgebbaren Geldzähler.

Jeder Handel verschiebt Ware zwischen dem gemeinsamen Spielerbestand und Cassias endlichem Handelsvorrat. Zugleich verschiebt er die exakte Münzmenge zwischen Spieler und Händlerkasse. Die Änderung ganzer Denare wird in `trade.ledger.denarii` verbucht, damit die bestehende übergreifende Ressourcenbilanz unverändert prüfbar bleibt. Das Restgeld und der gesamte Münzsaldo besitzen zusätzliche Erhaltungsgleichungen. Käufe und Verkäufe haben unterschiedliche Preise; sofortiger Rückverkauf erzeugt keinen Gewinn.

Jedes angezeigte Angebot trägt die gespeicherte `quote_revision`. Nach einer erfolgreichen Transaktion ist es verbraucht. Ein zweiter Fingertipp auf das alte Angebot, auch nach Speichern und Neustart, zahlt nicht nochmals. Eine neue bewusste Transaktion benötigt das aktualisierte Angebot. Der Domänenbefehl prüft Cassias tatsächlichen Standort, ihren Lebens- und Dienststatus sowie vorhandene Ware, Münzen und Lagerplatz. Die Oberfläche kann diese Bedingungen nicht umgehen.

## Reiter, Zeit und Android-Budget

Die Story speichert `village.childhood.night_raid` mit `phase`, `elapsed` und `seed`. `childhood_raiders.gd` liest diesen Zustand und verändert ihn nicht. Aus demselben gespeicherten Zustand entstehen nach Neustart dieselben dreißig Sichtakteure, Fell-/Kleidungsvarianten und Positionen. Die Einleitung wird nicht durch Rendererzeit oder Offlinezeit ausgelöst. In `dormant` und `aftermath` verschwinden die Reiter einschließlich ihrer Kollisionskörper. Einwohner werden durch das Darstellungsmodul weder erschaffen noch verletzt oder getötet.

Der Zug verwendet drei räumlich getrennte Spuren und zehn Reihen vor dem nördlichen Dorfzugang. Die Animation folgt zurückgelegter Strecke; bei Ankunft gleiten stehende Hufe nicht weiter. Statische Teilgeometrie wird einmal erstellt und in `MultiMesh`-Gruppen geteilt. Die vier Grafikprofile begrenzen den nahen Detailbereich; sie verändern keine Zahl, Reihenfolge oder Folgen der Storyakteure. Das sind überprüfbare Ressourcen- und Darstellungsentscheidungen, keine gemessene Zusage zu FPS oder Handytemperatur.

Die dreißig Reiter der Sequenz sind keine Behauptung über dreißig vollständig ausgearbeitete berittene Kampfgegner. Die vorhandene Kampfautorität bleibt getrennt. Anritt, Nachtbeleuchtung, Kampfphase und gespeicherte Folgen müssen gemeinsam in der Spielintegration geprüft werden. Eine Engineaufnahme ist als Engineaufnahme zu benennen; ein Konzeptbild oder ein alter Android-Bericht ersetzt keinen Nachweis dieser Änderungen.

## Konkrete Prüfbelege dieser Module

Die eigenständigen Godot-Prüfungen umfassen 101 Handelsprüfungen, 144 Reiterprüfungen und 39 Handelsprüfungen gegen das tatsächliche `WorldModel`. Der Modelltest prüft unter anderem eine bezahlte Ware, erhaltenes Restgeld, einen getrennten einmaligen Storylohn, echte Speicherumschläge sowie die Migration eines Schema-5-Spielstands ohne Verlust von Beständen oder Einwohnern. Die gezielte Testanordnung versetzt die Figur zu Prüforten; sie ist deshalb kein Nachweis eines vollständig durchgelaufenen Spielerwegs.

Die [Aufnahmemetadaten](evidence/mounted-raiders/review.json) und [Quellcode-Hashes](evidence/mounted-raiders/source-receipt.json) gehören zu drei tatsächlich gerenderten Godot-Bildern: [Low](evidence/mounted-raiders/raiders-low.png), [Very High](evidence/mounted-raiders/raiders-very_high.png) und [Pferd/Reiter im Detail](evidence/mounted-raiders/rider-detail.png). Low und Very High zeigen dieselbe Kamera, denselben gespeicherten Ankunftszustand und jeweils dreißig Figuren. Die isolierte Prüfbühne lief mit Godot 4.7.2, GL Compatibility und llvmpipe. Sie belegt die Geometrie, Gruppenzahlen und Abstände dieses Moduls; sie belegt weder die vollständige Dorfsequenz noch Android-FPS. `tools/capture_childhood_raiders.py` verwendet den bestehenden privaten Xorg-Helfer und beendet seinen Displayserver nach der Aufnahme.

Die neue Android-Prüfstrecke erkennt die exportierten Kindheitsmodule und verwendet ausschließlich tatsächliche native Eingaben sowie den lesenden Diagnosebeobachter. Sie verlangt eine kurze Stickbewegung in der angeforderten Welt-Richtung, Julias Gespräch, eine während des Dialogs stehende Uhr, die einmalige Entnahme von zwei Getreide für den Essenskorb, Android Back und die erhaltene Welt-/Szenenidentität nach Prozessneustart. Der Paketprüfer verlangt die fünf neuen Story-, Intro-, Handels-, Innenraum- und Reitermodule samt nichtleeren aufgelösten Exportinhalten. Die 78 lokal bestandenen Python-Android-Tests enthalten synthetische Log- und ZIP-Regressionen. **Diese Python-Tests sind kein ausgeführter APK-Test**; dessen Belege entstehen erst beim separaten Lauf auf dem Android-Emulator.

Reproduzierbare Befehle ab Repositorywurzel:

```bash
godot --headless --path prototype --script res://tests/village_trade_test.gd
godot --headless --path prototype --script res://tests/childhood_raiders_test.gd
godot --headless --path prototype --script res://tests/village_trade_model_test.gd
python3 -m unittest discover -s tests -p 'android_*_test.py'
python3 tools/capture_childhood_raiders.py --output docs/18_childhood/evidence/mounted-raiders
```
