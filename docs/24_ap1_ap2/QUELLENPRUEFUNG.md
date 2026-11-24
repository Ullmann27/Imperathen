# AP-1/AP-2: Quellenprüfung der Originaldrehbücher

Stand: 24.11.2026. Quellenprüfung für AP-1 und AP-2; zugehörige Implementierung siehe `AP1_BEGLEITER.md` und `AP2_DATEN.md`.

## Methode und Umfang

Alle vier Original-DOCX wurden geöffnet und ihr gesamter Hauptdokumenttext einschließlich Tabellen in Dokumentreihenfolge extrahiert. Die relevanten Band-1-Abschnitte wurden gezielt gelesen; in allen vier Bänden wurden die Charakterbibeln und die für AP-1 relevanten Namens- und Beziehungsstellen geprüft. Die vollständigen Texte wurden auf die Namen Severus, Fabius und Valeria durchsucht (ganze Wörter, ohne Beachtung der Großschreibung): für jeden Namen **0 Treffer in jedem Band**. Die Produktionsfassung ist jeweils 1.0 vom 23. November 2026.

Tabellennummern zählen die Tabellen des Hauptdokuments in Dokumentreihenfolge, 1-basiert. Die Dialogzeilennummern sind die im Original gedruckten Nummern `NN ·`. `Pnnnn` in den temporären `.txt`-Extraktionen bezeichnet zusätzliche technische Absatznummern; es ist keine gedruckte Seitennummer. Die Extraktionen und die Originaldateien gehören nicht ins öffentliche Repository.

| Original | SHA-256 |
|---|---|
| `IMPERATHEN_Drehbuch_Band_1_DAS_FEUER_VON_VALDORA(1).docx` | `91b8185e0be6d1b79119c8791735d1ca7df570c0f9ddebc4ff11cad242b6a3f2` |
| `IMPERATHEN_Drehbuch_Band_2_DER_ADLER_UND_DER_RUBIKON(1).docx` | `6b55e0ca2e0b74354323524408e5188152e1bc8c3ed260d3b3690bb07e1c699f` |
| `IMPERATHEN_Drehbuch_Band_3_DIE_IDEN(1).docx` | `ed597fcb569083e1bc130194003d9ec2a55d8e4f22b28c11fa65d05920ffe3d2` |
| `IMPERATHEN_Drehbuch_Band_4_DAS_REICH_DANACH(1).docx` | `608ff71e62c70926227a0544582d2ed2cbe415e2630b35df948b9df5a1bf768a` |

## AP-1: konkrete Belege

| Aufgabe | Originalfundstelle | Inhalt / Auswahl |
|---|---|---|
| Silvanus begleitet | Band 1, „I-04 · Der Freund meines Vaters“, Tabelle 7, Besetzung/Storykern; VID-A „Blocking“ | Silvanus, Sextus, Spieler. Silvanus bringt den Jungen zu seinem ältesten Freund. Jede Figur hat einen räumlichen Grund; keine Teleportation beim alternativen Zugang. |
| Silvanus-Dialog | I-04, „Dialog-, Mimik- und Sprachregie“, Zeile 01 (wiederholt 10) | „Du musst nicht der Stärkste sein. Du musst wissen, wann du stehenbleibst.“ |
| Silvanus-Dialog Arbeit | I-04, derselbe Abschnitt, Zeile 04 | „Mach erst die Arbeit. Reden können wir danach immer noch.“ |
| Marcus am Markt | Band 1, „I-06 · Ein Preis ist eine Zusage“, Tabelle 9; Dialogzeile 05 | Besetzung Cassia, Marcus, Spieler. Zeile: „Sag nur, ob wir klug sein wollen oder berühmt. Beides gleichzeitig klappt bei uns selten.“ |
| Marcus am Markt, Alternative | I-06, Dialogzeile 08 | „Ich gehe mit. Aber diesmal entscheidest du nicht allein für uns beide.“ |
| Marcus bei den Spuren | Band 1, „I-08 · Hufspuren im Regen“, Tabelle 11; Dialogzeile 01 (wiederholt 07) | Besetzung Marcus, Decimus, Spieler. Zeile: „Sag nur, ob wir klug sein wollen oder berühmt. Beides gleichzeitig klappt bei uns selten.“ |
| Marcus am Abend | Band 1, „I-09 · Der letzte gewöhnliche Abend“, Tabelle 12; Dialogzeile 04 (wiederholt 09) | Julia, Silvanus, Sextus, Marcus, Spieler. Storykern normaler Abend mit Essen, Zukunftsplänen und optionalen Besuchen. Zeile: „Ich gehe mit. Aber diesmal entscheidest du nicht allein für uns beide.“ |
| Freund/Rivale | Band 1, „I-03 · Marcus kennt eine Abkürzung“, Tabelle 6; „Gameplay, Questlogik und Freiheit“ → „Konsequenzen“; „Dialogverzweigung“ | Freund oder beginnender Rivale durch Münzstreit und Marktweg. Konkrete Erinnerung beeinflusst Hilfe, Widerspruch, Begleitung und spätere Lebenswege. Drei Tonlagen vertraut/neutral/misstrauisch, abhängig von konkreten Erinnerungsereignissen, nicht allein Zahlenwert. |
| Namensklärung I-07 | Band 1, „I-07 · Der kranke Wachmann“, Tabelle 10 und kompletter Missionsabschnitt; Volltextsuche aller vier Bände | Besetzung Decimus, Silvanus, Spieler; beaufsichtigte Wasser-/Nachricht-/Kontrollrundenhilfe. Name „Severus“ nicht belegt. Die Stelle identifiziert Decimus nicht als Kranken. |

### Begründete Umsetzungsentscheidungen und Ergänzungen

- Vorhandenen kranken Wachmann unter der bisherigen technischen Actor-ID erhalten, **Anzeigename „Wachmann“** verwenden. Keinen neuen Eigennamen erfinden und nicht ohne Beleg mit Decimus zusammenlegen. Die technische Zuordnung des namenlosen Kranken zum bisherigen Actor ist eine **Ergänzung**.
- Marcus folgt mit seiner bestehenden Actor-ID und seiner bestehenden I-03-Wahl; keine Doppelgänger erstellen. Die konkrete Begleitdistanz, Wegsuche, Haltepunkte, Wartezeiten und Zuordnung zu bestehenden Teilschritten sind technische **Ergänzungen**.
- I-06 kann für `friend` Zeile 05 und für `rival` Zeile 08 auswählen; die Auswahlzuordnung ist eine **Ergänzung**, die gesprochenen Sätze sind Originaltext. Ein neutraler Fall kann Zeile 05 benutzen, wiederum als dokumentierte Auswahlregel.
- I-08 und I-09 haben in der jeweiligen Szene keine zwei unterschiedlichen zeitlich passenden Marcus-Texte. Dieselbe belegte Zeile kann abhängig von der gespeicherten Freund/Rivale-Wahl mit unterschiedlicher **Ton-/Regiemetadatenanzeige** verwendet werden. Eine frei erfundene zweite Zeile wäre nicht durch die Quellen gedeckt. Eine tatsächliche vertonte Tonlage erfordert eine Aufnahme; bloße Textmetadaten dürfen nicht als Sprachaufnahme ausgegeben werden.
- I-04 kann Silvanus an der Schmiede Zeile 01 sprechen lassen; Zeile 04 passt zum bestehenden Holzauftrag. Auswahl und konkreter Auslösepunkt sind Ergänzungen.

### Nicht übernehmen

I-06 Zeile 02 sowie I-08 Zeilen 04/10 enthalten Marcus' „Weißt du noch, wie wir wegen einer Münze gestritten haben? Jetzt streiten ganze Armeen so.“ Diese Passage steht wörtlich im Drehbuch, ist aber für die zwölfjährige Kindheitsphase zeitlich unpassend. I-09 Spielerzeile 05 behauptet bereits viele Verluste am noch gewöhnlichen Abend. Außerdem wiederholen einige Spielerzeilen ausdrücklich technische Produktionsbegriffe („persistenter Weltzustand“, „Event-Ledger“). Solche Zeilen werden nicht durch bloßes Vorhandensein im Original zu geeigneten Spieltexten.

## AP-2: Metadaten der ausgelagerten Brückenmissionen

Für alle folgenden Missionen: Band 1, Jahr 58 v. Chr., Spieler ca. 12, Status `FICTIONAL THREAD`. Die Tabellen sind jeweils die Einstiegstabellen des genannten Missionsabschnitts.

| ID | Titel / Tabelle | Ort | Besetzung | Storykern |
|---|---|---|---|---|
| I-02 | Der falsche Korb / 5 | Nachbarhaus und Backgasse | Julia, Aurelia, Spieler | Botengang; Fehler erzeugen eine neue Situation statt sofortigem Abbruch. |
| I-08 | Hufspuren im Regen / 11 | Nordweg, Felder, Bach | Marcus, Decimus, Spieler | Frische Spuren und widersprüchliche Aussagen; keinen Täter und kein Volk vorschnell festlegen. Primärziel: Hinweise sichern und belegte Schlüsse. |
| I-10 | Die Nacht der Reiter / 13 | Valdora bei Nacht | Silvanus, Julia, Marcus, Decimus, Spieler | Etwa dreißig Reiter; ausdrückliche Wahl zwischen Verteidigung/Rettung und Verstecken mit den Eltern. |
| I-11 | Die Schmiede im Feuer / 14 | Schmiede | Sextus, Marcus, Spieler | Sextus hält den Fluchtweg offen und stirbt; die Werkstatt verliert tatsächlich ihren Arbeiter. |
| I-12 | Der letzte Weg des Vaters / 15 | Familiengasse und Palisade | Silvanus, Julia, Spieler | Silvanus stirbt in beiden Hauptwegen; Julias Überleben hängt von tatsächlich ausgeführter Hilfe ab. |
| I-13 | Morgen ohne Stimmen / 16 | Valdora nach dem Angriff | Julia, Marcus, Aurelia, Decimus, Spieler | Fehlende Personen und Arbeitskräfte, beschädigte Vorräte und konkrete Folgen. |
| I-14 | Der Schwur / 17 | Waldrand oberhalb Valdoras | Marcus, Julia, Spieler | Erinnerungsstück, Überlebende, Schwur: „Ich werde euch rächen. Ich finde die Verantwortlichen.“ Ermittlung, keine sofortige Soldatenkarriere. |

AP-2 ist ein Datenrefactor. Die heutigen verdichteten Schritte dürfen durch die Metadatenauslagerung keine behauptete Vollumsetzung dieser Storykerne erhalten. Source-Metadaten sollten außerhalb der zur Laufzeit byteidentisch zu vergleichenden Schrittdaten liegen.

## Übergreifende Quellenregeln

- Alle vier Bände: „Cinematic-Grundregel“ verlangt Save-abhängige Inszenierung; Tote erscheinen nicht erneut und kein Erfolg wird vorgespiegelt.
- Alle vier Bände: Charakterbibel Marcus: schnelle, bewegliche, leicht spöttische Stimme; lebhafte Augen; viel Bewegung; im Alter souveräner oder härter; freundschaftlich-freche Sprache. Kein Beleg für ein neues Familienverhältnis oder einen zusätzlichen Namen.
- Für AP-1 wird keine Handlung aus Band 2–4 in die Kindheit vorgezogen. Ihre Beziehungskontinuität begründet gerade, bestehende Wahl- und Actor-IDs zu erhalten.
