# Referenzen, historische Einordnung und nächste Gestaltung

Recherche- und Entwicklungsstand: 23. November 2026. Dieser Text trennt überprüfte Ausgangsdaten von Entscheidungen für die erfundene Spielhandlung. Er ist keine Behauptung, dass die geplante Reitersequenz schon existiert.

## Bewegung und Bedienung

Heinz nennt Assassin’s Creed Valhalla, GTA VI und Ghost Recon als Maßstab für glaubwürdige Bewegung, eine lesbare Kamera und zugängliche Steuerung. Das Kartellspiel ist **Ghost Recon Wildlands**; Ubisoft beschreibt seinen Schauplatz als Bolivien. Die offizielle Produktseite dient der Zuordnung der Referenz, nicht einer Messung der dortigen Laufgeschwindigkeit: [Ubisoft, Ghost Recon Wildlands](https://www.ubisoft.com/en-us/games/tom-clancys-ghost-recon-wildlands).

Die [offizielle GTA-VI-Seite](https://www.rockstargames.com/VI) und [Ubisofts Valhalla-Hilfe](https://www.ubisoft.com/en-us/help/assassins-creed-valhalla/gameplay/article/accessibility-features-in-assassin-s-creed-valhalla/000079358) sind Ausgangspunkte für eine folgende konkrete Referenzsichtung. In diesem Arbeitsblock wurde kein fremdes Spiel durchgespielt, kein Video frameweise vermessen und kein Bewegungsdatensatz daraus übernommen. Deshalb sind die gewählten **1,5 m/s beim Gehen und 3,6 m/s beim Laufen** eigene vorläufige Spielwerte. Sie sind keine belegten Geschwindigkeiten dieser Referenzspiele.

Für die weitere Animation zählt die beobachtbare Wirkung: Bodenkontakt, gegensinnige Arm- und Beinbewegung, Bremsen, Drehen, Körpergewicht und eine ruhige Kamera. Die vorhandene Armkorrektur ist ein erster tatsächlicher Eingriff in die gebundenen Animationsspuren. Die zehn Kampfclips bleiben prozedurale Prototypen. Besondere Kinderproportionen, natürlichere Hände, Übergänge, belastete Schritte und passende Trefferreaktionen brauchen weitere sichtbare Arbeit.

Die Touchkorrektur verwendet die dokumentierte Gerätekennung `InputEvent.DEVICE_ID_EMULATION = -1`, um die von einer Berührung erzeugte Mauskopie zuverlässig zu erkennen. Eine bloße Unterdrückung für 180 Millisekunden war bei langen Renderframes unzureichend. Quelle: [Godot 4.7, InputEvent](https://docs.godotengine.org/en/4.7/classes/class_inputevent.html). Die tatsächliche Mehrfingerprüfung im Produktions-UI ist in `childhood_integration_test.gd` enthalten.

## Epoche und Gegner

Getty datiert Trajans Dakerkriege auf **101–102 und 105–106 n. Chr.** und verbindet sie mit dakischen Bedrohungen der römischen Provinz Moesia. Quelle: [Getty Research Institute, Dacian Wars of Trajan](https://www.getty.edu/cona/CONAIconographyRecord.aspx?iconid=901001384).

Das Museo della Civiltà Romana führt einen Abguss der Trajanssäule, auf dem Daker einen befestigten Platz mit Unterstützung sarmatischer Reiterei angreifen. Das ist ein belegtes antikes Bildmotiv, kein Beleg für den erfundenen Dorfüberfall in diesem Spiel. Quelle: [Museo della Civiltà Romana, Angriff mit sarmatischer Reiterei](https://www.museociviltaromana.it/it/opera/colonna-traiana-daci-assaltano-un-posto-fortificato-con-laiuto-della-cavalleria-sarmatica?tema=1).

**Gestaltungsvorschlag:** Für einen Schauplatz an der Donau um diese Zeit sind dakische Angreifer und sarmatische Reiter eine begründbare Richtung. Vor der Produktion müssen genauer Ort und Jahr mit der bestehenden Weltkarte und Herkunftswahl zusammengeführt werden. Der vorhandene Ursprung `italia` beschreibt noch eine römische Herkunft und ist kein automatisch geänderter Geografiebeweis für Moesia. Es wurde daher kein bestehender Kartenort stillschweigend umgeschrieben. Die pauschale Bezeichnung „größter Feind des ganzen Reiches“ ist für die örtliche Szene nicht notwendig.

Der konkrete Überfall mit ungefähr dreißig Reitern bleibt verfasste Fiktion. Die Zahl stammt aus Heinz’ gewünschter Inszenierung. Welche Angehörigen bedroht werden, wie sich die zuvor geschlossenen Beziehungen auswirken und welche Handlungsmöglichkeiten der Junge erhält, müssen aus dem gespeicherten Dorfabschnitt hervorgehen. Vorproduzierte Einstellungen dürfen nicht plötzlich verstorbene Personen oder zurückgegebene Leihgegenstände wieder erscheinen lassen.

## Kleidung und Varianten

Die Untersuchung der University of St Andrews unterscheidet die dargestellten Figurentypen der Trajanssäule. Für Daker beschreibt sie unter anderem lange Hosen, gegürtete langärmlige Tuniken, Mäntel, geschlossene Schuhe und häufig Bärte. Sarmatische Reiter werden teils mit Schuppenrüstung für Reiter und Pferd dargestellt. Die Untersuchung erklärt zugleich die Erwartungen des römischen Publikums und die begrenzte militärische Sachkenntnis der Bildhauer. Solche Darstellungen sind deshalb eine Quelle unter mehreren und keine fotografisch genaue Uniformvorschrift. Quelle: [University of St Andrews, The Human Figure Types](https://arts.st-andrews.ac.uk/trajans-column/the-project/the-human-figure-types/).

Für eigene Modelle folgt daraus eine Arbeitsrichtung: Gesicht, Haar, Bart, Stofffarbe, Mantel, Helm und Alter variieren; Ausrüstung nach Rolle begründen. Gleiche Rig- und Materialgrundlagen dürfen geteilt werden. Eigene Pferde benötigen tragfähige Anatomie, getrennte Gangarten und passende Reitersitze. Diese Assetarbeit wurde durch den neuen Kindheitsvertrag noch nicht erledigt.

## Geld und Alltagswirtschaft

Das Institut für Klassische Archäologie der FAU beschreibt für die römische Kaiserzeit ein abgestuftes Münzsystem mit dem goldenen Aureus, dem silbernen Denar sowie kleineren Nominalen aus Kupferlegierungen. Quelle: [FAU, The Roman Imperial Coinage-System](https://www.klassischearchaeologie.phil.fau.de/ausstellungen/machtszenarien-scenarios-of-power-eine-numismatische-ausstellung/understanding-the-background-the-roman-imperial-coinage-system/).

Die vorhandene Denar-Anzeige ist deshalb kein Anlass, alle Beträge in Goldstücke umzubenennen. Die kleinen Belohnungen des neuen Abschnitts sind gegenwärtig **Spielbalance**, keine historisch belegten Löhne oder Warenpreise. Eine spätere feinere Wirtschaft sollte Wechselgeld, Familienhaushalt, persönlichen Verdienst und gemeinschaftliche Bestände ausdrücklicher trennen. Aktuell wird der eigene Auftragslohn bereits gesondert im Sozialbuch protokolliert, zusätzlich zur Buchung in den vorhandenen gemeinsamen Geldbestand.

## Reihenfolge des weiteren Ausbaus

Zuerst den neuen Anfang tatsächlich auf Android durchspielen: Gehen und Kamera, Familie, Marktweg, Schmiede, Nachbarschaft und bewusste Tagesabschlüsse. Danach die Zeitwirkung anhand einer wirklichen Spielzeitmessung und Rückmeldungen verfeinern. Vier erzählte Tage und 35 Schritte ergeben von sich aus noch keinen langen, emotional dichten Lebensabschnitt.

Parallel dazu sollen die beiden Zusatzchats ihre abgegrenzten Bereiche verbessern. Die Nachtsequenz folgt mit eigener Szenenabnahme, gespeichertem Eintritt/Austritt und einem überprüften Übergang in die vorhandene Raid-Domain. Eine spätere Ausbildung, Lebensjahre, militärische Laufbahn und Alternativgeschichte benötigen weitere Kapitel. Die gegenwärtigen Sperren verhindern lediglich den früheren ungewollten Sofortsprung.
