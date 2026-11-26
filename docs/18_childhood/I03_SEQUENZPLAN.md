# I-03 „Marcus kennt eine Abkürzung“ – Sequenzplan und Grenzen

Stand: 26.11.2026, Branch `feat/i01-three-cups-slice-20261126`. Grundlage: Masterhandbuch 3.0 S. 14 (Vertiefungsentwurf), S. 10 (Questvertrag, Knoten I-03.B03), S. 70 (Originalblatt), S. 22–31 (Film), S. 46 (Testmatrix), D-016 (kein binäres Freund-/Rivale-Flag). Dialogzeilen sind eigene Produktionsentwürfe in `prototype/assets/story/missions/band1/I-03.json` (`slice.lines`), kein Wortlaut des Originaldrehbuchs.

## Was sich ändert

Bisher war I-03 ein Dialog mit zwei Knöpfen („Streit beilegen“ / „auf dem Standpunkt beharren“), der Marcus sofort als Freund oder Rivalen festlegte. Jetzt ist es ein spielbarer Besorgungsgang mit drei Orten (Gasse, Brunnen, Cassias Stand), einem echten Preisstreit und konkreten Erinnerungen. Kein Knopf legt die Beziehung fest.

## Spielablauf

1. **Gasse – VID-A.** Der Film beginnt erst, wenn der Junge Marcus wirklich erreicht. Bildöffnung auf Marcus’ Hand mit den Münzen, dann beide in derselben Gasse, Marcus’ eigene Sorge (der lahme Ochse), **Wahl**: mit Marcus gehen / später am Markt treffen / eigenen Weg nehmen. Hat der Junge Marcus in I-01 am Brunnen zugehört, erinnert Marcus daran (`I03_A_HOOK_WELL`).
2. **Weg.** „Mitgehen“: Marcus läuft mit dem Jungen. „Später“ und „eigener Weg“: Marcus geht selbst zu Cassias Stand (Wegsuche der bestehenden Begleitlogik). Der Stand steht dort, wo Cassia tatsächlich handelt.
3. **Stand – Haltung.** Marcus hat zwei Asse, Cassia verlangt drei. Der Junge entscheidet im Gespräch am Stand: zusehen / Hilfe anbieten / Marcus widersprechen. Voraussetzung: Marcus ist wirklich am Stand angekommen. Die zwei Asse und Marcus’ leerer Topf liegen danach sichtbar auf dem Stand.
4. **VID-B.** Cassia erklärt den Widerspruch (zwei Asse kostet das kleine Maß, der mitgegebene Topf fasst das große für drei; niemand hat gelogen). Marcus reagiert auf die gespeicherte Haltung. **Wahl**: ruhig nachmessen / großen Preis annehmen / heute nicht kaufen.
5. **Auflösung durch Handlung.** Nachmessen: der Junge füllt das kleine Maß selbst in den Topf. Annehmen nach Hilfsangebot: Cassia nimmt statt des dritten Asses einen Krug Brunnenwasser – am Brunnen schöpfen, zum Stand tragen (Krug in der Hand), Marcus kommt mit. Annehmen ohne Angebot: Marcus schuldet Cassia ein As, der Junge ist Zeuge (Kerbe im Kerbholz). Nicht kaufen: Marcus behält seine Münzen. Der Junge hat kein eigenes Geld; der Haushaltsdenar bleibt für Julias Bestellung reserviert.
6. **Julias Bestellung** (bestehende Schritte `market_meeting`, `market_purchase`).
7. **VID-C – Abschied am Stand.** Marcus eröffnet je nach Hergang (freundlich, Schuld, ohne Salz, offener Vorwurf). **Wahl**: zusammen heimgehen / getrennt / entschuldigen (nur bei offenem Streit). Erst hier wird die Beziehung zusammengefasst.
8. **Übergabe an Julia** (`deliver_food`): Julia erwähnt Wasserdienst oder Schuld nur, wenn sie geschehen sind.

## Erinnerungen statt Flag

Gespeichert werden Ereignisse in `screenplay.i03_events` (jede ID genau einmal): `I-03.route.*`, `I-03.promise.kept`, `I-03.stance.*`, `I-03.marcus.missed`, `I-03.resolve.*`, `I-03.service.water`, `I-03.service.done`, `I-03.salt.*`, `I-03.apology`, `I-03.home.*`. Jede hat in den Daten `immediate_effect`, `delayed_hook`, `long_term_effect`, `line_id`, `speaker_id`.

Ältere Systeme lesen noch `companion.choice` (`help`/`decline`) und einen festen Vertrauenswert (20 / −5); die Weltprüfung rechnet damit. Diese Felder werden beim Abschied **aus den Erinnerungen abgeleitet**: `decline` genau dann, wenn der Junge Marcus widersprochen hat und der Streit weder ruhig geklärt noch entschuldigt wurde. Die Prüfung lehnt jede Zusammenfassung ab, die den Erinnerungen widerspricht. Die vollständige Ablösung durch den Akteurkern (D-016: Vertrauen, Neid, Verpflichtungen, eigene Entscheidungen) ist ein eigenes Arbeitspaket.

## Sequenzplan

| ID | Klasse | Cast | Ort | Entry state | Exit state | Abbruchregel |
| --- | --- | --- | --- | --- | --- | --- |
| I-03.VID-A (`i03_vid_a`) | B, In-Engine | Marcus, Junge | Gasse | I-02 fertig, `i03_route=""`, Marcus anwesend und in Reichweite | `i03_route` gesetzt | Skip springt zur offenen Wahl; Back/Suspend/Continue am selben Beat |
| I-03.VID-B (`i03_vid_b`) | B, In-Engine | Cassia, Marcus, Junge | Cassias Stand | `i03_stance` gesetzt | `i03_resolve` gesetzt | wie VID-A |
| I-03.VID-C (`i03_vid_c`) | B, In-Engine | Marcus, Junge | Cassias Stand | Bestellung gekauft, Marcus anwesend | `i03_home` gesetzt, `i03s=complete` | wie VID-A |

Einstellungen (allgemeine Gesprächsgrammatik im Filmregisseur, aus den lebenden Figuren berechnet): `duo_hands` (Detail Hände, FOV 36→32,5), `duo_wide` (beide Figuren von der Seite, 52→49), `duo_close` (Nah auf den Sprechenden, 35→32), `duo_react` (Nah auf den Jungen, 36→34), `duo_ots` (über die Schulter des Jungen, 46→42), `prop_insert` (Detail auf einen Requisitenanker, hier Münzen und Topf, 35→31,5). Reaktionsschnitte liegen innerhalb der Zeilen, jede Sequenz hat stumme Pausen.

Sprachtracks: nicht produziert. Jeder gesprochene Beat trägt `line_id`, `speaker_id` (`marcus`, `cassia`, `chronik`) und `voice: "pending_recording"`.

## Testzuordnung

| Fall (HB S. 14 / S. 70) | Nachweis |
| --- | --- |
| Marcus abwesend | `i03_slice_test` (keine Route, kein Ereignis; am Stand nur „ist nicht gekommen“), `i03_flow_test` (kein Film, keine Ersatzfigur) |
| Gegenstand bereits bezahlt | `i03_slice_test`, `i03_flow_test`: zweiter Dienst/zweites Maß abgelehnt, nichts doppelt gespeichert, Haushaltsdenar unberührt |
| Getrennte Route | `i03_slice_test` (Station „stall“), `i03_flow_test` (Marcus geht selbst zum Stand, Streit wartet auf seine Ankunft) |
| Kein verstecktes Loyalitätsflag | `i03_slice_test`: alte Knopfaktionen existieren nicht, kein Wert bewegt sich vor dem Abschied, gefälschte Zusammenfassung/Erinnerung ungültig |
| Alternative Wahl / Verzicht | `i03_slice_test`: klären, Dienst, Schuld, kein Kauf, Entschuldigung |
| Save/Load vor und nach der Entscheidung | `i03_slice_test` (an jedem Schritt), `i03_flow_test` (Suspend im Film, Continue nach Abschluss) |
| Kein Reward bei bloßem Filmstart | `i03_slice_test`, `i03_flow_test` |
| T19/T20/T21 | `i03_flow_test` |
| Save-Migration v4 → v5 | `i03_slice_test`, `mission_bridge_data_test` |

## Grenzen

- Kein Münz-, Greif- oder Tragclip: Münzen liegen auf dem Stand, der Krug folgt dem Handknochen ohne Tragepose.
- Marcus’ Wegsuche braucht einige Sekunden, bevor er losgeht.
- Cassias Kasse und Warenbestand sind nicht modelliert (HB S. 70 „endliche Waren, Preise und Händlerkassen“): die Asse gehören Marcus und Cassia, nicht dem Spielerbestand.
- Ist Marcus an der Gasse abwesend, wartet I-03 auf ihn; Julias Bestellung bleibt bis dahin gesperrt (wie zuvor).
- Marcus’ Schuld von einem As wird gespeichert, aber noch von keiner späteren Mission eingelöst.
- Tageszeit und Wetter fehlen; Stimmen, Lippenbewegung und Fingeranimation fehlen.
