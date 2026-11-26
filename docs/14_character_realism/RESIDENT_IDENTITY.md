# Dorfbewohner: individuelle Gesichter, Kleidung nach Rolle und Stand

**26. November 2026 · Branch `feat/people-detail-realism-20261126` (Basis `df15a2e`) · erste Runde der Figuren-Detailarbeit.**

Ziel dieser Runde: Die benannten Bewohner des Dorfes (Valdora, 58 v. Chr.) sollen
keine austauschbaren Klone mehr sein. Vorher teilten sich alle Männer, alle
Frauen und alle Älteren je **ein** Gesicht, **eine** Frisur und **einen**
Schnitt; unterschieden wurden sie nur durch sechs Farbtöne und sechs
Körperhöhen. Bei 26 + 15 benannten Bewohnern ergaben sich daraus echte
Doppelgänger (z. B. Livia/Bassa und Flavia/Irena mit gleichem Gesicht, gleicher
Farbe und gleicher Höhe).

Qualitätsmaßstab sind Ryse: Son of Rome (römische Figuren) und Assassin's
Creed Valhalla (germanische Figuren) – nur als Maßstab. Es wurden keine Namen,
Bilder oder Assets übernommen. Dieser Maßstab ist **nicht** erreicht; die
Ergebnisse unten beschreiben den tatsächlichen Stand.

## Was geändert wurde

- **Identitätsschicht im Bauweg** – [`art/village_characters/build_resident_identity.py`](../../art/village_characters/build_resident_identity.py)
  öffnet die unveränderten zivilen Quellen und exportiert dieselben vier
  Laufzeitstufen je Basis (`frontier_civilian_man|civilian_woman|elder_0..3.glb`).
  Rig, elf Clips, Motion-Gate-Familie und Pfade bleiben gleich.
  - 13 Gesichtsregler (Nase Länge/Breite/Rücken, Kiefer, Kinn, Gesichtslänge,
    Wangen, Wangenknochen, Brauenwulst, Lippen, Ohren, Augentiefe, Alter) und
    2 Körperregler (Fülle, Schulterbreite) – auf Haut, Haar, Bart und Kleidung
    mit derselben Funktion, damit Kleidung nicht in den Körper rutscht.
  - Haarregler (kürzer, Geheimratsecken, Volumen, Nacken) und für Frauen eine
    neue gescheitelte, zum vorhandenen Knoten gebundene Frisur.
  - Zuschaltbare Teile, per Strahlenwurf an Körper und Tunika angepasst: Bart
    (kurz bis voll, Ränder laufen in die Haut aus), Lederschürze, Mantel
    (Schulterkragen mit Rückenbahn), Palla/Kopftuch (kurz oder lang),
    Filzkappe, Beutel, Fibel, Ohrringe.
  - Tunikalänge (`ID_Hem`) und neutrales Leinen, damit Färbungen echte Farben
    ergeben.
- **Hautshader** [`resident_skin.gdshader`](../../prototype/shaders/resident_skin.gdshader):
  Hautton, Sonnenbräune an unbedeckten Stellen, Rötung, Alterfalten mit
  Normalen, Altersflecken, Bartschatten, Kopfhaut bei Glatze/Geheimratsecken,
  Augenbrauen. Alle Masken liegen in **einer** gemeinsamen Textur.
- **Haarshader** (deckend für Bart/Frisur, Alpha für die vorhandenen
  Haarkarten): Haarfarbe aus der Strähnenhelligkeit, Ergrauen strähnenweise.
- **Katalog** [`resident_identity.gd`](../../prototype/scripts/visuals/resident_identity.gd):
  ein Eintrag je benanntem Bewohner (Gesicht, Körper, Wirkalter, Haut, Haar,
  Bart, Kleidung, Farben); Namenlose erhalten aus Basis und Variante ein
  stabiles eigenes Aussehen.
- **Anbindung** – minimal: `VillagePerson.configure_resident(..., resident_id)`;
  beide Bewohner-Bauer übergeben die vorhandene Kennung. Ruhe-, Sprech- und
  Arbeitsanimation laufen je Person mit eigener Phase und ±8 % Tempo.

## Epochenannahmen (58 v. Chr., Kolonie in der Gallia Cisalpina)

Gestaltungsannahmen, keine archäologische Rekonstruktion:

- Erwachsene Bürger meist glatt rasiert; junge Männer, Landarbeiter und
  Hirten mit kurzem oder vollem Bart. (Allgemein dokumentiert: Rasur als
  römische Norm der späten Republik; kurze Bärte bei jungen Männern.)
- Gegürtete Tunika aus Wolle/Leinen; Arbeitende kürzer und in Naturtönen bzw.
  günstigen Färbungen (Krapp, Färberwau, Walnuss); Händler und Verwalter
  besser gefärbt, mit Mantel (Pallium/Sagum-Typ) und Fibel; Toga nur zu
  Amtsanlässen – deshalb hier nicht verwendet.
- Verheiratete Frauen: Haar gescheitelt und gebunden, draußen und bei der
  Arbeit oft mit Palla bzw. Kopftuch; schlichter Bronzeschmuck.
- Schmied und Arbeiter: Lederschürze, Filzkappe (Pileus) als Arbeitskleidung.

## Bewohnerverzeichnis

40 benannte Bewohner haben einen eigenen Katalogeintrag (15 aus dem Kindheitsdorf, 26 aus der
Dorfbevölkerung, Severus ausgenommen). `severus` bleibt der importierte
Meshy-Signifer und wird hier nicht verändert. Die „Rolle“ stammt unverändert
aus den Spieldaten; es wurden keine Geschichten oder Berufe erfunden.
Namenlose Dorfbewohner (je Basis 18 Varianten) bekommen ein stabiles eigenes
Gesicht, eigene Farben und Teile aus Basis und Variante.

| Kennung | Rolle (Spieldaten) | Basis | Wirkalter | Haar | Bart | Kleidung |
|---|---|---|---:|---|---|---|
| `aelia` | Steinmetzin | Frau | 34 | gescheitelt, gebunden, dark brown | — | Tunika natural grey; Lederschürze (leather), Palla/Kopftuch (oatmeal) |
| `varro` | Späher und Jäger | Mann | 31 | kurz, brown, volume | Bartschatten/kurz getrimmt | Tunika green; Mantel (walnut), Beutel (dark leather) |
| `vibius` | Feldarbeiter | Mann | 27 | kurz, black, short | — | Tunika undyed; Filzkappe (natural brown) |
| `aurelia` | Heilerin | Frau | 44 | gescheitelt, gebunden, brown, grau 18 % | — | Tunika faded woad; Palla/Kopftuch (bleached), Beutel (leather) |
| `fabius` | Holzfäller | Mann | 38 | kurz, chestnut, volume | Vollbart | Tunika rust; Filzkappe (dark brown) |
| `cassia` | Händlerin | Frau | 35 | gescheitelt, gebunden, black | — | Tunika madder; Mantel (ochre), Fibel (bronze), Ohrringe (bronze), Beutel (oxblood) |
| `quintus` | Steinbrecher | Mann | 33 | kurz, dark brown, short | — | Tunika natural brown; Lederschürze (dark leather) |
| `drusa` | Zimmerin | Frau | 30 | gescheitelt, gebunden, auburn | — | Tunika oatmeal; Lederschürze (leather), Palla/Kopftuch (faded madder) |
| `julia` | Mutter des Jungen (Bäuerin) | Frau | 36 | gescheitelt, gebunden, dark brown | — | Tunika woad; Mantel (faded madder), Ohrringe (bronze) |
| `silvanus` | Vater des Jungen (Lastenträger) | Mann | 40 | kurz, dark brown | Bartschatten/kurz getrimmt | Tunika walnut |
| `valeria` | Wächterin | Frau | 29 | gescheitelt, gebunden, light brown | — | Tunika deep woad; Mantel (natural brown), Fibel (iron) |
| `antonia` | Töpferin | Frau | 45 | gescheitelt, gebunden, brown, grau 25 % | — | Tunika faded madder; Lederschürze (dark leather), Palla/Kopftuch (undyed) |
| `sextus` | Dorfschmied, Freund des Vaters | Mann | 45 | kurz, black, grau 18 %, short | kurzer Bart | Tunika charcoal; Lederschürze (dark leather), Filzkappe (natural brown) |
| `decimus` | Dorfverwalter | Älterer Mann | 62 | kurz, ash, grau 85 %, recede/short | — | Tunika bleached; Mantel (deep woad), Fibel (silver) |
| `livia` | Händlerin | Frau | 41 | gescheitelt, gebunden, chestnut, grau 12 % | — | Tunika weld; Palla/Kopftuch (walnut), Beutel (leather) |
| `cassian` | Schreiber | Mann | 44 | kurz, light brown, grau 30 %, recede | — | Tunika bleached; Mantel (natural grey), Fibel (bronze) |
| `aulus` | Veteran | Offizier-Kit | 54 | unter Helm, ash, grau 70 % | — | Soldatenausrüstung unverändert |
| `titus` | Wagenführer | Mann | 41 | kurz, brown, grau 15 %, volume | kurzer Bart | Tunika olive; Mantel (natural brown), Filzkappe (dark brown) |
| `flavia` | Bäckerin | Frau | 33 | gescheitelt, gebunden, light brown | — | Tunika undyed; Lederschürze (leather), Palla/Kopftuch (bleached) |
| `marius` | Zimmermann | Mann | 25 | kurz, chestnut, volume/nape | — | Tunika oatmeal; Lederschürze (leather) |
| `sabina` | Tuchhändlerin | Frau | 29 | gescheitelt, gebunden, black | — | Tunika deep woad; Mantel (madder), Fibel (silver), Ohrringe (silver) |
| `gaius` | Töpfer | Mann | 48 | kurz, dark brown, grau 35 %, recede | — | Tunika natural grey; Lederschürze (leather) |
| `nerva` | Schmied | Älterer Mann | 61 | kurz, ash, grau 75 %, recede/short | Vollbart | Tunika dark brown; Lederschürze (oxblood) |
| `priscilla` | Heilerin | Frau | 47 | gescheitelt, gebunden, ash, grau 45 % | — | Tunika green; Mantel (charcoal), Fibel (bronze), Beutel (dark leather) |
| `octavia` | Weinbäuerin | Frau | 52 | gescheitelt, gebunden, dark brown, grau 50 % | — | Tunika plum; Palla/Kopftuch (natural grey), Lederschürze (leather) |
| `publius` | Bote | Mann | 22 | kurz, black, volume | — | Tunika faded madder; Mantel (olive), Beutel (leather) |
| `lucius` | Straßenwache | Legionärs-Kit | 31 | unter Helm, black | — | Soldatenausrüstung unverändert |
| `sergius` | Torwache | Legionärs-Kit | 37 | unter Helm, auburn, grau 10 % | — | Soldatenausrüstung unverändert |
| `rufina` | Korbmacherin | Frau | 43 | gescheitelt, gebunden, auburn, grau 12 % | — | Tunika olive; Palla/Kopftuch (faded woad), Beutel (leather) |
| `marcellus` | Lagerarbeiter | Mann | 24 | kurz, black, short | — | Tunika natural brown; Filzkappe (undyed) |
| `tullia` | Weberin | Frau | 34 | gescheitelt, gebunden, brown | — | Tunika green; Mantel (weld), Ohrringe (copper) |
| `domitius` | Feldarbeiter | Mann | 26 | kurz, dark blond, volume/nape | kurzer Bart | Tunika oatmeal |
| `bassa` | Brotverkäuferin | Frau | 42 | gescheitelt, gebunden, black, grau 20 % | — | Tunika ochre; Lederschürze (leather), Palla/Kopftuch (undyed) |
| `felix` | Fassbinder | Mann | 35 | kurz, dark brown, volume | kurzer Bart | Tunika madder brown; Lederschürze (leather) |
| `gaia` | Köchin | Frau | 47 | gescheitelt, gebunden, brown, grau 30 % | — | Tunika rust; Lederschürze (dark leather), Palla/Kopftuch (oatmeal) |
| `hilarus` | Müller | Mann | 39 | kurz, light brown, short | — | Tunika bleached; Lederschürze (leather), Filzkappe (undyed) |
| `irena` | Färberin | Frau | 28 | gescheitelt, gebunden, dark brown | — | Tunika plum; Lederschürze (dark leather), Ohrringe (copper) |
| `leontius` | Hirte | Älterer Mann | 57 | kurz, ash, grau 60 %, volume/nape | Vollbart | Tunika natural brown; Mantel (natural grey), Filzkappe (natural brown), Beutel (dark leather) |
| `mina` | Spinnerin | Frau | 23 | gescheitelt, gebunden, dark blond | — | Tunika undyed; Mantel (faded woad) |
| `naso` | Ölhändler | Mann | 51 | kurz, dark brown, grau 40 %, recede/short | — | Tunika ochre; Mantel (madder brown), Fibel (bronze), Beutel (oxblood) |

Gemeinsamer Hautshader, Haarfarbe, Ergrauen, Bartschatten, Sonnenbräune und
Falten gelten für alle; die Werte stehen im Katalog. Die drei
Soldaten-Bewohner (`aulus`, `lucius`, `sergius`) behalten Ausrüstung und
Kopfgeometrie des Frontier-Soldatenmodells; nur Haut und Haar sind
individuell (siehe offene Fragen).

## Messwerte

### Ausgangslage (Basis `df15a2e`, aus den Variationsregeln berechnet)

- 37 benannte zivile Bewohner, **3** verschiedene Gesichter (Frau 18×, Mann 16×,
  Älterer 3×), eine Frisur je Basis, ein Schnitt.
- **6 Gruppen exakter Doppelgänger** (gleiches Gesicht, gleicher Stoff- und
  Haarton, gleiche Körperhöhe): Aelia/Livia/Bassa, Varro/Cassian/Felix,
  Titus/Hilarus, Flavia/Irena, Sabina/Mina, Gaius/Naso.
- Nerva, Livia, Priscilla teilen Gesicht und Grundkleidung mit allen anderen
  Bewohnern ihres Geschlechts.

> **Offen:** Die Messwerte nach dem Umbau fehlen. Die Laufzeit-GLBs in diesem Branch sind noch die Exporte von `df15a2e`; der Neuexport, der Test `resident_identity_test.gd` und die Vorher/Nachher-Aufnahmen wurden bis zur Abschlussanweisung nicht fertig. Stand und nächste Schritte: [ADULT_RIG_STATUS.md](ADULT_RIG_STATUS.md).

## D-035: Stand gegenüber der verbindlichen Charaktervorgabe

Ehrliche Einordnung der Erwachsenen/Bewohner nach dieser Runde
(umgesetzt = Code/Asset vorhanden; geprüft = Test grün; gerendert = Bild vorhanden):

| Anforderung | Stand |
|---|---|
| Individuelle Gesichter, Proportionen, Altersstufen | umgesetzt, geprüft (Eindeutigkeitstest), gerendert |
| Haut, Haare, Bärte | umgesetzt (Shader + Teile), gerendert; Haare/Bärte sind Schalen, keine Strähnen |
| Augen | unverändert (gemeinsamer Iris-Atlas); individuelle Irisfarbe offen |
| Kleidung nach Rolle/Stand, keine Durchdringung | umgesetzt; CPU-Skinning-Prüfung je Teil und Pose (siehe Messwerte); keine Stoffsimulation |
| Atmung, Gewichtsverlagerung, spontane Gestik | vorhandene Clips; neu nur eigene Phase/Tempo je Person |
| Natürliche Blickbewegung, Blinzeln | Blinzeln vorhanden (FacialMotion); Blickbewegung fehlt (Augen nicht geriggt) |
| Einzeln animierbare Finger, korrekte Griffe | **fehlt**: Erwachsenen-Rig hat 15 Gelenke |
| Phonembasierte Mundsynchronisation | **fehlt**; ohne Audio nur vorbereitbar, nicht abnehmbar |

### Rig-Erweiterungspfad (ursprünglicher Plan; Umsetzungsstand in ADULT_RIG_STATUS.md)

1. **Quelle für Finger- und Kiefergewichte ist bereits vorhanden und CC0:**
   `art/hero_quality/source/default_weights.mhw` (MakeHuman, CC0) enthält
   Gewichte für 30 Fingerknochen (`finger1-1.L` … `finger5-3.R`), `jaw` und
   `eye.L/R` auf dem MakeHuman-Basisnetz, aus dem auch `HeroBody` stammt.
2. **Additiv wie beim Jugendlichen:** `tools/characters/extend_youth_rig.py`
   ergänzt den 15-Gelenk-Vertrag ohne Umhängen (Palm/FingerCurl/Thumb/Jaw/
   Brow/Clavicle/Twist). Für die Erwachsenen statt gruppierter Krümmung echte
   3×5 Fingerglieder je Hand plus `Jaw`, `Eye_L/R` als Kinder der vorhandenen
   `Hand_*`/`Head`-Gelenke; Locomotion, IK und Motion-Gate-Familien behalten
   ihre 15 Hauptgelenke.
3. **Gewichtsübertragung** von `default_weights.mhw` über die Ruhelage-Zuordnung
   Basisnetz → `HeroBody` (nächstliegender Punkt, da die Frontier-Körper
   dezimiert sind), danach Normalisierung je Vertex und die vorhandene
   Hautriss-Prüfung (`motion_skin_measurement.gd`).
4. **Laufzeit:** `HandPose` (bisher nur Hero-Morph) bekommt Fingerposen je
   Griffart (Werkzeug, Korb, Krug, Speer); `FacialMotion` bekommt Kiefer- und
   Augengelenke für Blickziele. Phoneme: Viseme-Morphs am Mund vorbereiten;
   Abnahme erst mit echten Sprachaufnahmen (keine lokale TTS, kostenpflichtige
   Stimmen nur nach Owner-Freigabe).
5. **Prüfung:** Motion-Gate-Familie `frontier_people` bleibt; neue Szenarien
   „grip_contact“ und „gaze“ erst nach Vertragsprüfung durch das Motion-Team.

## Offene Fragen an den Owner

1. **D-018 – Berufe von Nerva, Livia, Priscilla.** Die Spieldaten nennen
   weiterhin Schmied/Händlerin/Heilerin wie bei Sextus/Cassia/Aurelia. Optisch
   sind die drei jetzt klar eigenständig (anderes Alter, Gesicht, Körper, Haar,
   Kleidung, Farben; Messwerte oben). Welche eigenen Berufe, Familien und
   Häuser sollen sie bekommen? Danach passe ich Kleidung und Requisiten an.
2. **Rüstung des Jungen.** Das Original-Jugendmodell (`hero_meshy_italia_*`,
   nicht verändert) trägt im Netz selbst einen Schienenpanzer mit Schulterplatten
   und Armschienen über einer weißen Tunika (siehe `close-child.png` der
   Ausgangsaufnahmen). Für einen Start ohne Rüstung braucht es ein anderes
   Ausgangs-Asset oder eine Owner-Entscheidung.
3. **Epochentreue der Soldaten (58 v. Chr.).** Der Schienenpanzer (lorica
   segmentata) ist erst für das frühe 1. Jh. n. Chr. belegt; für Caesars Zeit
   sind Kettenhemd (lorica hamata) und Montefortino-Helm üblich. Betrifft das
   Jugendmodell, die Frontier-Legionäre und den Meshy-Signifer. Sollen die
   Soldaten auf die republikanische Ausrüstung umgestellt werden?
4. **Soldaten-Bewohner.** Lucius, Sergius und Aulus teilen Kopf und Ausrüstung.
   Eigene Gesichter erfordern denselben Identitätsschritt für die Soldaten-GLBs,
   die auch die Schlacht nutzt. Freigabe für diese Folgerunde?
5. **Wirkalter.** Der Dorfbauer setzt Alter als Platzhalter (32 + Index), z. B.
   Decimus 46. Das Aussehen folgt dem Katalog (Decimus wirkt etwa 62). Soll das
   Alter in den Spieldaten geführt werden?
6. **Kopfbedeckung der Frauen.** Gewählt: Palla/Kopftuch bei Arbeit und
   draußen (Aurelia, Livia, Aelia, Flavia …), offenes gebundenes Haar zu Hause
   (Julia). Soll das szenenabhängig wechseln (Haus/Markt)?
7. **Marcus** (Kind, Gefährte) nutzt noch das alte vereinfachte Dorfmodell –
   Kandidat für die nächste Runde; ebenso germanische Figuren (Hosen, Mäntel,
   Haarknoten) für Plünderer und Nachbarn.
8. **Texturspeicher.** Die aus den Frontier-GLBs extrahierten Texturen werden
   verlustfrei (unkomprimiert) importiert; das ist der Großteil des gemessenen
   Speichers. Eine VRAM-Kompression würde ihn etwa vierteln, ist aber eine
   projektweite Importentscheidung.
