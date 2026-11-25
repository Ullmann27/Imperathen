# Integrierter Detailstand für den bestehenden Stadtrundgang

**Zweck:** Die zuvor getrennten Nacharbeiten für römische Fassaden, abgenutztes
Straßenpflaster und lebendige Marktpassanten sind in **einer einzigen**
`CityExploration`-Szene angeschlossen. Ausgehend vom ausführlich geprüften
Fassadenzweig [PR #67](https://github.com/Ullmann27/Imperathen/pull/67)
wurde der optionale Ambient-Bewohnermodus aus dem unabhängigen Zweig
[PR #69](https://github.com/Ullmann27/Imperathen/pull/69) quellenidentisch übernommen.

## Reihenfolge der tatsächlichen Runtime-Anschlüsse

`CityExploration._ready()` baut zunächst die bereits vorhandene Stadt,
dann den Meshy-Jungen mit Originalkamera, anschließend die kleine Ambient-
Bevölkerung. Die bestehenden Gebäude erhalten beim Laden der Stadt die
zusätzlichen Fassaden-/Pflaster-MultiMeshes sowie die sechs Marktstandschilder.
Ein separater alter Markt-GameWorld oder eine zweite Szene mit eigenem
Spieler wird nicht erzeugt.

- `CitySurfaceMicrodetail`: begrenzte Fassaden-/Straßenmikrodetails; vier
  gebündelte GPU-Instanzgruppen, keine neue Kollision
- `CityMarketSignage`: sechs korrekte Ladenbeschriftungen aus dem
  Original-Stadtgenerator; **noch kein kaufbarer Markt in der Erkundung**
- `CityAmbientPeople`: wenige erwachsene Händler und Passanten, die
  tatsächlich langsam durch die Marktstraße gehen und physisch an Wänden
  scheitern statt durch sie zu teleportieren. Eine Sprechpose entsteht nur
  bei beidseitigem Kontakt mit freiem Sichtkorridor.

Die neue Arbeitskopie enthält die tatsächlich geschriebenen Quellpfade;
sie übernimmt bewusst keine riesige 1:1-Kopie des separaten Marktviertels,
keine zweite Währungsverwaltung und keine fremde Story.

## Abnahmeregeln

Ein eigener CI-Workflow führt die originalen Marktstandorttests und
Pflastertests, die realen Passanten-/Mauertests sowie den realen
OpenGL-Fassadentest mit gleichen Ressourcen in **demselben Checkout** aus.
Die CI benutzt Godot 4.7.2 mit geprüfter offizieller Prüfsumme.
**Erst bei grünem Lauf ist diese kombinierte Codeintegration geprüft.**

Das ist ein eigener Android-first Entwicklungszweig, noch kein neuer
signierter Android-Build. Ein vollständiger visueller Rundgang der ganzen
GLB-Stadt auf dem physischen Fold7 ist weiterhin nicht abgenommen.

Ein zeitgleicher Merge beider Einzelzweige nach `main` wurde nicht
durchgeführt. Vor der endgültigen Integration in den Kampagnenzweig sind
Save-/Geschichtszeit, die aus PR #58 bislang unverbundenen Vegetations-GLBs,
die Materialien aus PR #59 und der echte Händlerdienst aus PR #62 gesondert
zu koordinieren.
