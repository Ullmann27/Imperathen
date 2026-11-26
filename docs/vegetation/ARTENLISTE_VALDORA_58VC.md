# Artenliste Valdora bei Aquileia, 58 v. Chr.

Stand 26.11.2026, Branch `feat/vegetation-20261126`. Grundlage für die Vegetation der Region, die der Spieler zuerst sieht (First Play I-01 bis I-04). Vorgabe: Punkt 6 der [AAA Visual Quality Directive](../00_governance/GAME_DIRECTION_2026-11-26_C.md) (Branch `docs/game-direction-20261126`).

Valdora ist ein fiktives Dorf. Die Liste beschreibt eine glaubwürdige, nicht vermessene Pflanzenwelt der friaulischen Tiefebene zwischen Isonzo-Schwemmland und Lagune im 1. Jahrhundert v. Chr. **Belegt** heißt: in einer der unten genannten Quellen für Norditalien, Venetia oder Aquileia ausdrücklich genannt. **Annahme** heißt: aus der heutigen potenziellen natürlichen Vegetation zurückgeschlossen und nicht durch einen Fund aus Valdoras Umgebung gedeckt.

## Verwendete Arten

| Art | Spielasset | Rolle in Valdora | Status | Quelle |
|---|---|---|---|---|
| Stieleiche, *Quercus robur* | `quercus_robur` | Hauptbaum des Eichen-Hainbuchen-Waldes im Westen, Feldeichen in Hecken und als Solitäre | belegt (Waldtyp) | [Q2], [Q3], [Q4] |
| Zerreiche, *Quercus cerris* | `quercus_cerris` | Haine auf den trockeneren Hügelhängen im Norden | Annahme (Standort Hügel) | [Q5] |
| Feldulme, *Ulmus minor* | `ulmus_minor` | Wald, Hecken, Bäume im Dorf; erster Rebenträger bei Plinius | belegt | [Q1], [Q3] |
| Schmalblättrige Esche, *Fraxinus angustifolia* | `fraxinus_angustifolia` | feuchtere Waldteile, Bachufer | belegt (Waldtyp), Esche als Rebenträger | [Q1], [Q3], [Q4] |
| Hainbuche, *Carpinus betulus* | `carpinus_betulus` | Unterstand und Mischbaum im Wald, Hügelhaine | belegt | [Q1] („yoke-elm“), [Q2] |
| Schwarzpappel, *Populus nigra* | `populus_nigra` | große Einzelbäume am Bach und in der Feuchtwiese | belegt | [Q1] |
| Silberweide, *Salix alba* (Baum und Kopfweide) | `salix_alba`, `salix_alba_pollard` | Bachufer; geschneitelte Kopfweiden liefern die Korbruten (Rufina) | belegt: Weiden in Venetien wegen des feuchten Bodens | [Q1] |
| Schwarzerle, *Alnus glutinosa* | `alnus_glutinosa` | Bachufer, nasse Senken | belegt (Waldtyp) | [Q3] |
| Feldahorn, *Acer campestre* (Baum und Kopfbaum) | `acer_campestre`, `acer_campestre_arbustum` | Wald, Hecken; geköpfter Ahorn als lebende Rebenstütze | belegt: „opulus“ und Ahorn jenseits des Po | [Q1] |
| Weinrebe, *Vitis vinifera* | `vitis_arbustum`, `vitis_stake` | an Feldahorn „verheiratete“ Reben entlang der Feldraine; Pfahlreben mit Querstange am Südhang („am selben Hang“, Octavia) | belegt | [Q1], [Q6] |
| Hasel, *Corylus avellana* | `corylus_avellana` | Waldmantel, Unterholz, Hecken, Ufer | Annahme (Waldtyp) | [Q2] |
| Eingriffeliger Weißdorn, *Crataegus monogyna* | `crataegus_monogyna` | Hecken und Waldmantel | Annahme; Dornhecke als „natürliche“ Einfriedung belegt | [Q7] |
| Schlehe, *Prunus spinosa* | `prunus_spinosa` | Dornhecken, Waldmantel, Hügelgebüsch | Annahme; Dornhecke belegt | [Q7] |
| Schwarzer Holunder, *Sambucus nigra* | `sambucus_nigra` | an Häusern, Höfen und Ufern | Annahme (stickstoffliebend, heute an jedem Hof) | – |
| Saatweizen/Hartweizen (Nacktweizen), *Triticum aestivum/durum* | Kachel `wheat`, `wheat_green` | häufigstes Getreide der Felder | belegt | [Q6] |
| Gerste, *Hordeum vulgare* | Kachel `barley` | Felder | belegt | [Q6] |
| Emmer, *Triticum dicoccum* | Kachel `emmer` | Felder (Spelzweizen „far“) | belegt | [Q6] |
| Rispenhirse, *Panicum miliaceum* | Kachel `millet` | Felder | belegt (häufig) | [Q6] |
| Kolbenhirse, *Setaria italica* | Kachel `foxtail` | Felder | belegt | [Q6] |
| Ackerbohne, Linse | Kacheln `bean`, `lentil` | Felder, Gärten | belegt (Hülsenfrüchte vor der Römerzeit vorhanden) | [Q6] |
| Lein, *Linum usitatissimum* | Kachel `flax` | kleine Felder | Annahme | – |
| Kohl (*Brassica oleracea*), Lauch/Zwiebel (*Allium*) | Kacheln `kale`, `leek` | Hausgärten hinter den Häusern | Annahme (Gemüse und Würzpflanzen bereits in der Eisenzeit vielfältiger) | [Q6] |
| Klatschmohn, Kornblume | Kacheln `poppy`, `cornflower` | Ackerränder (Archäophyten) | Annahme | – |
| Wiesensalbei, Margerite, Flockenblume, Hahnenfuß, Wilde Möhre | Kacheln `sage`, `daisy`, `knapweed`, `buttercup`, `carrot` | Heuwiesen in Flecken, Waldsaum | Annahme (Glatthaferwiesen der Ebene) | – |
| Glatthafer/Knaulgras, Weidegräser, Trockengras | Kacheln `meadow`, `pasture`, `dry` | Wiesen, Weide am Dorf, Hügel | Annahme | – |
| Schilf (*Phragmites australis*), Seggen (*Carex*), Binsen (*Juncus*), Sumpf-Schwertlilie (*Iris pseudacorus*), Blutweiderich (*Lythrum salicaria*) | Kacheln `reed`, `reed_plume`, `sedge`, `rush`, `iris`, `loosestrife` | Bachränder, Röhricht in der Feuchtwiese Richtung Lagune | Annahme | – |

## Geprüft und nicht verwendet

| Art | Entscheidung | Begründung |
|---|---|---|
| Zypresse, *Cupressus sempervirens* | nicht verwendet | Plinius nennt sie einen Fremdling, der nur mit größter Mühe heimisch wird (Heimat Kreta) [Q8]. In einem Grenzdorf 58 v. Chr. nicht plausibel, allenfalls später in Villengärten. |
| Pinie, *Pinus pinea* | nicht verwendet | Status in Italien als Archäophyt umstritten; Zunahme in etruskischer und römischer Zeit, große Küstenpflanzungen erst in römischer Zeit [Q6]. Für die Ebene bei Aquileia 58 v. Chr. nicht belegt. Die bisherige generische Valdora-Pinie wird für Valdora nicht mehr gezeigt. |
| Ölbaum, *Olea europaea* | nicht verwendet | In Aquileia seit der Eisenzeit nachgewiesen, die geringe Kernzahl spricht aber für Import [Q6]. Anbau eher im Karst/Istrien. Der bisherige Ölbaum entfällt in Valdora. |
| Edelkastanie, *Castanea sativa* | nicht verwendet | Römerzeitliche Funde in Norditalien, anfangs vor allem als Bauholz [Q6]; sie braucht saure Böden der Hügel. Nicht in der kalkreichen Schwemmlandebene. |
| Pfirsich, *Prunus persica* | nicht verwendet | erst ab dem 1. Jahrhundert n. Chr. in Norditalien [Q6]. |
| Dinkel, *Triticum spelta* | nicht als eigene Kachel | in Norditalien „wie in früheren Zeiten kaum angebaut“ [Q6]. Emmer ist der passende Spelzweizen. Siehe Entscheidung E-V2. |
| Neuweltpflanzen (Mais, Kartoffel, Tomate, Gartenbohne *Phaseolus*), Robinie, Götterbaum, Platane-Hybride, Amorpha | ausgeschlossen | erst nach 1492 beziehungsweise neuzeitlich eingeführt; Robinie und Amorpha prägen das heutige Friaul, nicht das antike. |
| Walnuss, Süßkirsche, Feige | nicht modelliert | plausibel (Feige bei Plinius als Rebenträger [Q1]), aber für den Kern von Valdora nicht nötig; spätere Erweiterung. |

## Offene Entscheidungen für den Auftraggeber

- **E-V1 Kastanie, Zypresse, Pinie:** geprüft und für Valdora 58 v. Chr. nicht verwendet (Begründung oben). Sollen sie trotzdem erscheinen, dann nur an klar begründeten Orten: Zypresse und Pinie später in Villengärten, Kastanie auf sauren Hügelböden außerhalb der Schwemmlandebene.
- **E-V2 „Dinkel“:** Der Auftrag nennt Dinkel, Gerste und Reben. Dinkel (*Triticum spelta*) wurde in Norditalien kaum angebaut [Q6]; das lateinische *far* der Quellen ist Emmer (*Triticum dicoccum*) und wird im Deutschen und Englischen oft ungenau mit „Dinkel“ oder „spelt“ wiedergegeben. Umgesetzt ist deshalb Emmer als Spelzweizen neben Nacktweizen, Gerste und Hirse. Eine eigene Dinkel-Kachel lässt sich im Atlas ergänzen (vier Kacheln sind frei), wäre aber für diese Region eine bewusste Abweichung von der Fundlage.

## Quellen

- [Q1] Plinius, *Naturalis historia* 17,35 (§ 199–201), Übersetzung Bostock/Riley, [Perseus](https://www.perseus.tufts.edu/hopper/text?doc=Perseus:text:1999.02.0137:book=17:chapter=35): Ulme an erster Stelle, dann Schwarzpappel, Esche, Feige, Ölbaum; „In Italy beyond the Padus … the cornel, the opulus, the linden, the maple, the ash, the yoke-elm, and the quercus“; „in Venetia they grow willows for the purpose, on account of the humidity of the soil“. In dieser Sitzung gelesen.
- [Q2] Natura-2000-Gebiet IT3320034 „Boschi di Muzzana“ (friaulische Ebene an der Marano-Lagune), Lebensraumtyp 91L0 Illyrische Eichen-Hainbuchenwälder (Erythronio-Carpinion), [EUNIS](https://eunis.eea.europa.eu/sites/IT3320034). Über die Suchergebnisse geprüft; die Seite selbst war zum Abrufzeitpunkt nicht erreichbar (HTTP 503).
- [Q3] Poldini et al. 2009 (Natura Bresciana 36, 179–184), nach dem Suchergebnis: Stieleichenwälder als vorherrschende Serie der mittleren Ebene Friauls und Venetiens, *Fraxinus angustifolia* subsp. *oxycarpa*- und *Alnus glutinosa*-Wälder als untergeordnete Serien. Volltext nicht abrufbar (HTTP 410); nur Suchauszug.
- [Q4] ISPRA Carta della Natura, Lebensraumblatt Eichen-Hainbuchenwald der Ebene: *Fraxinus angustifolia* begleitet *Q. robur* und *Carpinus betulus* auf Böden mit hohem Grundwasser. Nur Suchauszug (Seite HTTP 503).
- [Q5] EUNIS-Lebensraum „Northern Italian *Quercus cerris* forests“ (Titel im Suchergebnis). Annahme für die Hügel, nicht für die Ebene.
- [Q6] G. Bosi, E. Castiglioni, M. Mazzanti, M. Rottoli: *New crops in the 1st millennium CE in northern Italy*. Vegetation History and Archaeobotany 2023, [doi:10.1007/s00334-023-00955-9](https://doi.org/10.1007/s00334-023-00955-9), Volltext gelesen: häufigste Getreide Nacktweizen, Gerste, Rispenhirse; Emmer und Einkorn von Bedeutung; Dinkel kaum angebaut; Kolbenhirse verbreitet; Ölbaum in Aquileia seit der Eisenzeit, aber wohl importiert (nach Maselli Scotti/Rottoli 2007, Ausgrabung ex Essiccatoio Nord in Aquileia); Pinie, Kastanie und Pfirsich wie oben. Zur Rebe in Aquileia zusätzlich Cottica/Cipolato 2024 (archäobotanische und palynologische Hinweise auf lokalen Rebbau; nur Abstract über die Suche).
- [Q7] Varro, *Rerum rusticarum* 1,14,1–2, [LacusCurtius](https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Varro/de_Re_Rustica/1*.html): die „natürliche“ Einfriedung ist eine lebende Hecke aus Gestrüpp oder Dornen. In dieser Sitzung gelesen.
- [Q8] Plinius, *Naturalis historia* 16,60 (§ 139–141), [Perseus](https://www.perseus.tufts.edu/hopper/text?doc=Perseus:text:1999.02.0137:book=16:chapter=60): „The cypress is an exotic, and has been reckoned one of the trees that are naturalized with the greatest difficulty“, Heimat Kreta. In dieser Sitzung gelesen.

## Landschaftsregeln (Umsetzung in `prototype/scripts/vegetation/vegetation_ecology.gd`)

- **Bach und Feuchte:** Abstand zur Wasserkante und eine Feuchtefunktion (Bachnähe, Senken, das sich südlich zur Lagune hin öffnende Röhricht) steuern Röhrichtgürtel, Seggen, Schwertlilien, Weiden, Erlen, Pappeln. Kopfweiden stehen nahe am Dorf, wo Ruten geschnitten werden.
- **Wald im Westen:** organische Waldkante mit Buchten und Vorsprüngen (Rauschfunktion), Mantel aus Schlehe, Weißdorn, Hasel, davor ein Krautsaum; im Inneren Poisson-Abstände je Art, Lichtungen, Esche und Erle in feuchteren Teilen.
- **Hügel im Norden:** Haine aus Zerreiche, Stieleiche, Hainbuche dort, wo keine Kollision die Überfallroute berührt; sonst Gebüsch und Trockenrasen; zum steinigen Kamm hin lichter. Rebzeilen am Südhang im Nordosten.
- **Felder:** Parzellen auf einem leicht gedrehten Raster (Anklang an die zenturiierte Flur von Aquileia), je Parzelle eine Feldfrucht, Ackerränder mit Mohn und Kornblume, Hecken (Varros lebende Einfriedung) oder Reihen von Kopfahornen mit Reben (Arbustum nach Plinius) an den Rainen, freie Wege.
- **Wiesen:** Glatthaferwiese, beweidete Kurzrasen am Dorf, Trockengras; Blumen in eigenen Flecken je Art statt gleichmäßig gestreut; Solitärbäume in offener Lage.
- **Dorf:** Die bestehenden Baumstandorte und ihre Kollision bleiben unverändert (Überfallroute, Kameratests), nur Art und Größe ändern sich; Kronen halten Abstand zu Dächern. Holunder an Hausecken, Gemüsebeete hinter einigen Häusern, Wege frei.
- **Gleichmäßigkeit vermeiden:** Die Prüfung `tests/vegetation_test.gd` misst den Dispersionsindex (Varianz/Mittel je Quadrat) für Kräuter und Gebüsch; zufällige Streuung ergäbe etwa 1, eine gleichmäßige Verteilung weniger als 1.
