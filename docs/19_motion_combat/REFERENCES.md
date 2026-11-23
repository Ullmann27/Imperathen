# Referenzen und eigene Bewegungsparameter

Geprüft am 23. November 2026. Dieser Arbeitsstrang verwendet eigene Bewegungen,
Godot-Code und die bereits im Projekt nachgewiesenen Figurenquellen.

## Offizielle Materialien

- [Assassin’s Creed Valhalla – Ubisoft](https://www.ubisoft.com/en-us/game/assassins-creed/valhalla):
  offizielle Beschreibung von Nahkampf, persönlicher Entwicklung und Siedlung.
- [Grand Theft Auto VI – Rockstar Games](https://www.rockstargames.com/VI):
  offizielle Präsentation mit Trailer-, Bild- und Figurenbereichen.
- [Ghost Recon Wildlands – Ubisoft](https://www.ubisoft.com/en-us/games/tom-clancys-ghost-recon-wildlands):
  offizielle Vorstellung der offenen Spielwelt und des taktischen Teamspiels.
- [Ghost Recon Wildlands – offizieller Gameplay-Trailer von Ubisoft](https://www.youtube.com/watch?v=6dL9swgpYgM):
  als offizielle Videoquelle identifiziert. Eine framegenaue Bewegungsmessung
  dieses Videos wurde nicht durchgeführt.

Diese Quellen dokumentieren die vom Spieler genannten Vergleichswerke. Sie
liefern keine verlässlich vermessene Gehgeschwindigkeit, Schrittlänge oder
Beschleunigung für diese Spiele. Solche Zahlen werden hier nicht behauptet.
Die abgeleitete Gestaltungsvorgabe – verständliche Kamera, erkennbares Gewicht,
ruhige Fortbewegung und klar lesbare Aktionen – ist eine eigene Umsetzung des
Nutzerwunsches und kein kopierter Animationsdatensatz.

## Eigene Parameter

Gehen verwendet 1,45 m/s. Die zwölfjährige Figur kann auf 3,8 m/s laufen; die
vorhandene erwachsene Höchstgeschwindigkeit von 4,6 m/s bleibt für den späteren
Laufmodus erhalten. Beschleunigung, Abbremsen und begrenzte Drehgeschwindigkeit
werden getrennt behandelt. Diese Werte sind abstimmbare Spielparameter, keine
Aussage über die Geschwindigkeiten fremder Spiele oder über medizinische
Normwerte von Kindern.

Der Gang folgt der tatsächlich gemessenen `CharacterBody3D`-Bewegung. Ein
gegen eine Wand gedrückter Joystick darf damit keine weiterlaufenden Füße
antreiben. Die Entfernung eines Standfußes wird im Rigtest gegen die
entsprechende Translation geprüft. Das ersetzt keine vollständige Fuß-IK auf
beliebigen Treppen, Schrägen oder beweglichen Untergründen.

## Herkunft

Keine Modelle, Texturen, Animationen, Musik oder Markenzeichen aus den genannten
Spielen wurden in IMPERATHEN übernommen. Die neuen Posen entstehen aus den
tatsächlichen Restachsen des vorhandenen Rigs. Der neue Faustgriff wird aus den
bereits vorhandenen, im Figurenquellenregister nachgewiesenen Fingergewichten
abgeleitet. Die ursprünglichen GLBs, Gesichter, Altersformen und Materialien
bleiben erhalten. Der genaue Blender- und Ressourcenweg ist im
Bewegungsnachweis dokumentiert.
