# Charakterreferenzen, Lebensalter und historische Besetzung

**Stand: 22. November 2026 · Bezug: [Issue #33](https://github.com/Ullmann27/Imperathen/issues/33), R-017, R-019, R-022, R-029 und R-034.**

Dieses Quellenblatt verbindet die ursprüngliche Projektmappe mit dem jüngsten Auftrag: glaubwürdige menschliche Figuren vor dem ersten offiziellen Grafik- und Spieltest, zuerst auf Android. Es dokumentiert Produktionsvorgaben und recherchierte Quellen. Es bestätigt weder fertige historische Figuren noch eine bestandene Geräteabnahme.

## 1. Herkunft und Vorrang der Vorgaben

Die vom Nutzer bereitgestellte `IRON_BANNERS_Projektmappe.zip` enthält unter `01_Konzept/MASTER_GDD.md` folgende Ausgangspunkte:

| Fundstelle | Tatsächlicher Inhalt | Konsequenz für diesen Arbeitsblock |
| --- | --- | --- |
| §1.1 | Fiktive spätrepublikanisch-frühimperiale Welt; genaue Datierung im ursprünglichen GDD noch offen | Die historische Offenheit der Vorlage vom bereits datierten Prototyp unterscheiden; dessen Kalender ist unten dokumentiert. |
| §2.1 | Standardstart mit zwölf Jahren; Name, Aussehen und Herkunft wählbar; arme Kleidung, geliehene Werkzeuge | Ein altersgerechter Dorfjunge ist die erste Hauptfigur. Die spätere Soldatenfigur ersetzt diesen Einstieg nicht. |
| §2.1 und §3.3 | Grenzdorf Valdora als Arbeitstitel; Lebensphasen Kindheit, Jugend/Lehre, erwachsene und späte Karriere | Wiedererkennbare Identität über die Lebensphasen erhalten; Arbeit und militärische Karriere zeitlich unterscheiden. |
| §12.1–12.3 | Modulare Köpfe, Haare, Ausrüstung, kompatible Rigs, LODs, metrische Maße, UVs, Herkunft und Blender-Quelle | Varianten brauchen verlässliche technische Anschlussstellen und überprüfte Exporte. |
| §13 und §15 | Ursprünglich PC zuerst und ausführliche Gesichtsmimik in späterer Phase | Durch den neueren Nutzerauftrag überholt: Android zuerst; menschlich glaubwürdiger Hauptcharakter gehört vor den ersten offiziellen Grafiktest. |

Die früheren Vorproduktionsdokumente und der [Quellenaudit](../00_governance/SOURCE_AUDIT.md) bleiben historische Arbeitsstände. Für ausführbare Entwicklung gilt der aktualisierte Auftrag in [AGENTS.md](../../AGENTS.md). Die aktuelle Darstellung besitzt [vier Grafikstufen](../13_visual_upgrade/FOUR_GRAPHICS_LEVELS.md); diese Stufen dürfen weder Alter, Identität noch Spielregeln ändern.

**Tatsächlicher Kalender des aktuellen Prototyps:** Der Lebenslauf beginnt bereits **94 n. Chr.**, das freie Szenario im Frühjahr **100 n. Chr.** Dies steht im [bestehenden Lieferbericht](../12_integration/DELIVERY.md) und ist im Code nachvollziehbar: [AtlasScreen.refresh](../../prototype/scripts/strategy/atlas_screen.gd) setzt für die junge Phase `year = 94`; [SeasonCampaign.summary](../../prototype/scripts/strategy/season_campaign.gd) berechnet `100 + floori(turn / 4.0)`. Die ursprüngliche GDD-Offenheit bedeutet daher nicht, dass der heutige Prototyp keinen Kalender hätte. Der Nutzer hat in diesem Arbeitsblock keine neue historische Startperiode abschließend festgelegt; die Charakterarbeiten ändern die bestehenden Jahreszahlen nicht.

## 2. Gestaltungsauftrag für den eigenen Hauptcharakter

Der Held ist eine erfundene Person mit frei gestaltbarem Aussehen. Sein Gesicht soll daher nicht versehentlich Caesar, Marcus Aurelius oder einen modernen Schauspieler kopieren. Die folgenden Merkmale sind künstlerische Produktionsentscheidungen, keine archäologische Rekonstruktion einer konkreten Person.

- **Kindheitsphase:** kindliche Schädel-/Kieferproportionen, weiche altersgerechte Gesichtszüge, glaubwürdige Hals- und Schulterverhältnisse, kein Erwachsenenkörper im verkleinerten Maßstab. Natürliche Asymmetrie bleibt dezent.
- **Gesicht:** räumlich modellierte Lider, Nasenflügel, Lippenkontur, Mundöffnung und Ohren. Augen besitzen einen plausiblen Sitz unter den Lidern. Aufgemalte Augen und Lippen allein erfüllen die Nahaufnahme nicht.
- **Material:** natürliche Farb- und Rauigkeitsvariation; Details sollen die Form unterstützen. Übertriebene Poren, überall gleicher Glanz oder harte Gesichtslinien lassen das Kind älter beziehungsweise künstlich wirken.
- **Kleidung:** einfache grobe Tunika, nachvollziehbare Nähte, Gebrauchsspuren und reparierte Säume als erster Entwurf. Exakte Schnitte, Schuhformen und militärische Ausrüstung erhalten eine eigene Epochenprüfung, bevor sie als historisch authentisch bezeichnet werden.
- **Alterung:** Augenabstand, grundlegende Nasenform und charakteristische Asymmetrie erhalten die Wiedererkennbarkeit. Wachstum verändert Proportionen; spätere Karriere darf Haut, Haar und Ausdruck verändern. Ein Wechsel auf einen beliebigen fremden Erwachsenen erfüllt diese Anforderung nicht.
- **Bewegung:** ruhige Augenbewegungen, vollständiger Lidschluss, plausibler Kiefer, sichtbare Gewichtsverlagerung beim Gehen. Waffen und Kleidung müssen dem Körper folgen und dürfen das Gesicht nicht verdecken, um Modellfehler zu verstecken.

Für die erste visuelle Kontrolle sind dieselbe Figur frontal, im Profil und in Dreiviertelansicht bei neutralem Licht sowie in der tatsächlichen Dorfkamera erforderlich. Die Nahaufnahme prüft anatomische Form; die Dorfkamera prüft Erkennbarkeit während des Spielens.

## 3. Quellenblatt historischer Persönlichkeiten

Die Trennung ist verbindlich: **überliefertes Objekt**, **Deutung des Museums** und **eigene Ergänzung zum lebenden Menschen** sind unterschiedliche Belegstufen. Stein, Bronze und Münzrelief liefern keine vollständige Hauttextur, Stimme, Mimik oder sicher belegte Augenfarbe.

### Gaius Julius Caesar

**Quellen:** Rijksmuseum van Oudheden, [Dokumentation der Caesar-Rekonstruktion](https://www.rmo.nl/tentoonstellingen/archief/3d-reconstructie-van-caesar/) und [A new look at Julius Caesar](https://www.rmo.nl/en/news-press/news/a-new-look-at-julius-caesar/).

Das Museum beschreibt die Arbeit von Maja d’Hollosy auf Grundlage eines 3D-Scans seiner beschädigten Porträtbüste. Fehlende Teile wie Nase und Kinn wurden mit Hilfe der Tusculum-Büste ergänzt; zusätzlich wurde das Münzbild des Marcus Mettius herangezogen. Die englische Museumsdarstellung bezeichnet das Ergebnis ausdrücklich als alternative Rekonstruktion mit verbleibenden Unsicherheiten.

**Produktionsentscheidung:** Tusculum-Typ und passende Münzporträts dienen als Bezug für Kopfumriss, Profil und Haaransatz. Eine spätere museale Rekonstruktion ist eine zusätzliche Interpretation, keine Fotografie Caesars. Die in einer Rekonstruktion vorgeschlagene Ursache einer Schädelform wird nicht als gesicherte Diagnose übernommen. Haut-, Haar- und Augenfarbe bleiben als Rekonstruktionsentscheidungen gekennzeichnet, soweit kein gesonderter Beleg vorliegt.

**Rechteabgrenzung:** Das Museum kennzeichnet das Foto der modernen Rekonstruktion mit `© Maja d’Hollosy`. Dieses Quellenblatt importiert weder das Foto noch einen Scan oder ein Modell und erteilt dafür keine Nutzungsfreigabe.

### Marcus Iunius Brutus

**Quelle:** Münzkabinett der Staatlichen Museen zu Berlin, [Objekt 18202198: M. Iunius Brutus und L. Plaetorius Cestianus](https://ikmk.smb.museum/object?id=18202198&lang=en), katalogisiert 43–42 v. Chr., RRC 508,3.

Der Katalog benennt auf der Vorderseite den nach rechts gewandten Kopf des Brutus mit Bart und die Inschrift `BRVT IMP`. Dieses identifizierte Münzporträt ist der erste Bezug für das Profil der späteren Spielfigur. Ein einzelnes kleines Münzrelief bestimmt weder die gesamte Schädelform noch die Vorderansicht. Ergänzungen müssen als solche dokumentiert werden.

**Wichtige Verwechslung vermeiden:** Der [„Capitoline Brutus“, MC1183](https://www.museicapitolini.org/en/opera/bruto-capitolino?tema=1), ist kein gesichertes Porträt des Caesar-Attentäters. Die Musei Capitolini beschreiben bereits die traditionelle Identifikation mit dem ersten römischen Konsul als unbegründet. Dieses bekannte Bronzegesicht darf deshalb nicht automatisch Marcus Iunius Brutus zugeordnet werden.

**Quellenrechte:** Berlin kennzeichnet die Bilddateien des konkreten Münzobjekts als Public Domain Mark 1.0 und nennt Reinhard Saczewski als Fotografen; Katalogtexte besitzen einen eigenen CC-BY-SA-4.0-Hinweis. Hier werden lediglich die Quelle und selbst formulierte Schlussfolgerungen dokumentiert, keine Bilddateien importiert.

### Marcus Aurelius

**Junger Porträttyp:** Museum für Kunst und Gewerbe Hamburg, [Inventar 1997.365](https://www.mkg-hamburg.de/sammlung/objekt/bildnis-des-kaisers-marcus-aurelius/1997.365/dc00127227), um 140–150 n. Chr. Das Museum ordnet den Kopf dem zweiten Bildnistypus zu: ausgeprägte Locken und beginnender Bartwuchs. Es beschreibt für die spätere Kaiserdarstellung einen neuen Typ mit Vollbart. Die Museumsseite nennt 121–180 n. Chr. als Lebenszeit.

**Erwachsener Vergleich:** Musei Capitolini, [Ritratto di Marco Aurelio, MC0448](https://www.museicapitolini.org/it/opera/ritratto-di-marco-aurelio), datiert 161–180 n. Chr.

**Produktionsentscheidung:** Das Alter des gewählten Bildnistyps muss zur Szene passen. Der junge Prinz und der vollbärtige Kaiser sind keine beliebig austauschbaren Kostümvarianten. Marcus Aurelius gehört in ein zeitlich passendes späteres Szenario, nicht als Zeitgenosse Caesars in denselben historischen Lebensabschnitt. In den bestehenden Starts 94 beziehungsweise 100 n. Chr. ist er noch nicht geboren.

**Quellenrechte:** Das MK&G kennzeichnet seine Objektbilder ausdrücklich als gemeinfrei. Dies ist eine Aussage zur dort konkret angebotenen Abbildung, keine pauschale Freigabe anderer Fotos, Rekonstruktionen oder 3D-Scans. Dieses Arbeitsblatt enthält keine importierten Fremdassets.

## 4. Besetzungsregeln für spätere Szenen

Die folgenden Regeln beschreiben den Produktionsvertrag; eine automatische Laufzeitprüfung ist damit noch nicht implementiert.

| Regel | Erwartetes Verhalten |
| --- | --- |
| Stabile Personen-ID | Der erfundene Gefährte „Marcus“ wird niemals über einen Vornamen zu Marcus Aurelius. Marcus Iunius Brutus und Lucius Iunius Brutus bleiben getrennte Personen. |
| Festes Szenario | Der aktuelle Lebenslauf startet 94 n. Chr., das freie Szenario 100 n. Chr. Neue historische Namen dürfen diesen bestehenden Weltstand nicht stillschweigend umdatieren. Eine andere Startperiode benötigt eine ausdrückliche Projektentscheidung. |
| Datum und Lebensstatus | Geburt, Tod und jeweilige Rolle müssen vor historischem Auftreten belegt werden. Fehlende Datierung bleibt offen; keine erfundene Präzision. Caesar ist nach seiner Ermordung 44 v. Chr. kein lebender Akteur einer historisch geführten Szene. |
| Porträttyp und Lebensalter | Junge und späte Porträttypen werden der passenden Phase zugeordnet. Die Datierung eines Kunstwerks ist nicht automatisch das Alter des dargestellten Menschen. |
| Ausrüstung | Gesicht, Kleidung, Rangabzeichen und Waffen erhalten denselben Epochenkontext. Eine glaubwürdige Nase legitimiert noch keine beliebige Rüstung. |
| Rekonstruktionsstatus | Objektbasierte Merkmale, plausible Ergänzungen und offene Merkmale werden getrennt im Assetnachweis erfasst. |
| Referenz und importiertes Asset | Quelle ansehen und eine Datei ins Produkt übernehmen sind getrennte Schritte. Jeder tatsächliche Import erhält eigene Herkunfts- und Nutzungsangaben. |

Der Berliner Brutus-Katalog dokumentiert Caesars Ermordung am 15. März 44 v. Chr.; das MK&G dokumentiert die deutlich spätere Lebenszeit des Marcus Aurelius. Caesar ist deshalb in den bestehenden Starts 94/100 n. Chr. kein lebender Akteur. Die Figuren dürfen in unterschiedlichen Kapiteln einer ausdrücklich generationenübergreifenden Welt vorkommen, sofern Kalender und Lebensstatus dies tragen. Der vorhandene Kalender ist implementiert; eine automatische Prüfung historischer Lebensdaten oder ein generationenübergreifendes historisches Besetzungssystem wird hier nicht als bereits vorhanden behauptet.

## 5. Android-Qualitätsnachweis

Die [offizielle Godot-Rendererübersicht](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), abgerufen am 22.11.2026, empfiehlt den Mobile-Renderer für moderne Mobilgeräte. Forward+ wird auf Mobilgeräten als unterstützt, aber schlecht optimiert eingeordnet. Ein Preset namens „Sehr hoch“ ist deshalb kein ausreichender Grund für einen pauschalen Android-Wechsel auf Forward+.

Leicht, Ausgewogen, Hoch und Sehr hoch dürfen Geometrie-, Textur-, Licht- und Schattenbudgets staffeln. Gesichtserkennung, wichtige Körperformen und die spielbare Lebensphase müssen erhalten bleiben. Die konkreten Werte und der tatsächliche Renderer stehen im technischen [Profilvertrag](../13_visual_upgrade/FOUR_GRAPHICS_LEVELS.md).

**Getrennte Nachweise:** Eine generierte Charakterreferenz belegt die gestalterische Absicht. Ein Blender-Render belegt die gespeicherte 3D-Szene und ihre Darstellung in Blender. Ein Godot-Bild belegt die dort sichtbare Integration. Bildrate, thermische Stabilität und Bedienbarkeit auf einem physischen Android-Gerät benötigen einen eigenen Lauf mit Buildkennung und Messprotokoll. Dieses Quellenblatt ersetzt keinen dieser Nachweise.

## 6. Prüfung dieses Dokuments

- Original-GDD direkt aus der bereitgestellten ZIP gelesen; nicht verändert.
- Die oben verlinkten Museums- und Godot-Seiten recherchiert. Die englische RMO-Seite war über die Websuche textlich zugänglich, der direkte Abruf gab in diesem Lauf HTTP 403 zurück; die niederländische Rekonstruktionsseite wurde vollständig geöffnet.
- Für dieses historische Quellenblatt keine fremden Bild-, Scan- oder Modelldateien in das Repository übernommen. Die separat bearbeitete Hauptcharakter-Pipeline besitzt eigene Asset- und Lizenznachweise.
- Keine bezahlte Generierung, keine neue Lizenzentscheidung und keine behauptete historische Gesichtsabnahme.
