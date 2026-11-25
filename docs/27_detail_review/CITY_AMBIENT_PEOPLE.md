# Detailauftrag: reale Stadtbewohner in der freien Stadt

Der Stadtrundgang besaß bereits seine Gebäude, das Original-Stadtkollisionsmesh,
einen frei steuerbaren Meshy-Jungen und Marktschilder. Dieses Paket ergänzt
**ausschließlich visuelles und physisches Ambient-Verhalten**. Es ist weder
ein zweites Kampagnenspiel noch ein separater Warenbestand.

## Tatsächliche Modelle und Bewegungen

Die vorhandene `village_person.gd`-Figurenpipeline erzeugt mit
`configure_resident` die Menschen. Händler und Besucher haben
unterschiedliche Erscheinungen, Altersstufen, Höhen und Schrittgeschwindigkeiten.
Die sichtbaren Modelle bleiben an die bestehenden LOD-Profile angebunden.

Jeder Händler steht am realen Stand der gewählten sechs Marktstandorte.
Ein Besucher nähert sich langsam dem Tresen, bleibt für ein mögliches
Gespräch stehen, geht wieder ein Stück weiter und macht eine Pause.
Die zeitlichen Phasen sind je Besucher unterschiedlich; eine ganze Gruppe
marschiert nicht gleichzeitig wie ein Uhrwerk.

Die Bewegung erfolgt durch `CharacterBody3D.move_and_slide()`.
Ein vorhandenes Hindernis blockiert die Bewegung; die Figuren werden
nicht durch Wände teleportiert. Die dargestellte Gehgeschwindigkeit
folgt der wirklich gemessenen Körpergeschwindigkeit.
Erst wenn beide Personen maximal 1,5 m voneinander entfernt,
auf der gleichen Höhe und auf zwei Physikstrahlen (0,85/1,45 m)
gegenseitig sichtbar sind, wird `set_conversation_focus(true)`
auf den echten Figuren aktiviert. Wenn eine Mauer dazwischensteht,
geht die Figur nicht einfach durch sie hindurch und die Animation
beginnt nicht.

Händler zeigen außerhalb des Gesprächs die bestehende Arbeitsgeste.
Das ist **keine frei generierte natürliche Sprachausgabe** und keine
behauptete vollständige NPC-Persönlichkeit oder Karriereentscheidung.

## Android-first Grenzen

| Profil | Händler | Besucher |
| --- | ---: | ---: |
| Leicht | 0 | 0 |
| Ausgewogen | 2 | 2 |
| Hoch | 4 | 4 |
| Sehr hoch | 6 | 6 |

Die Figuren stehen am Markt des Original-Stadtgenerators.
Die Sortierung priorisiert die am Stadtzentrum gelegenen Stände.
Die Figur am ersten Stadteingang wird weder verändert noch
durch eine zusätzliche Spielfigur ersetzt.

Der vorhandene `city_exploration.gd`-Pausenknopf hält
die Ambient-Simulation tatsächlich an. Bei der Rückkehr
wird ohne rückwirkende Reise- oder Belohnungszeit weitergespielt.
Die freie Stadt erhält **keine neue WorldModel-Instanz**,
keine Transaktionsdaten, keine Questauslösung und keine
neue Kamera. Vorhandene Spielstände behalten ihren Vertrag.

## Wirklicher Test und Grenzen

`prototype/tests/city_ambient_people_test.gd` prüft mit realen
Godot-Charakteren und `CharacterBody3D` die Bewegung,
Arbeits-/Gesprächsvorbedingungen, eine tatsächliche Kollisionsmauer,
Pause, LOD-Begrenzung und unveränderte ursprüngliche Stände.

Der Test wird per eigener GitHub-Actions-Prüfung auf der importierten
Projektkopie mit Godot 4.7.2 durchgeführt.

Der Stadtrundgang mit Hunderten Gebäuden, die vollständigen
Straßenkreuzungen, der langfristige NPC-Tagesablauf und die tatsächliche
Fold7-Framerate sind **nicht** allein durch den Fixturetest abgenommen.
Bei einer Sackgasse bleibt der Besucher stehen und kehrt zum nächsten
Planungszeitpunkt zurück; eine komplexe NavMesh-Routenplanung und
freies Ausweichen vor anderen Passanten sind hier noch nicht enthalten.

Kein Merge nach `main` und kein APK-Release.
