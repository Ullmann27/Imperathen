# Band 1 · Abgleich Kindheitskapitel (I-01 ff.) mit dem Godot-Stand

Quelle: `IMPERATHEN_Drehbuch_Band_1_DAS_FEUER_VON_VALDORA(1).docx`, Produktionsfassung 1.0 vom 23. November 2026. Fundstellen nennen den Abschnitt (Überschrift) des Drehbuchs, die Tabellennummer in Dokumentreihenfolge und bei Dialogen die Zeilennummer „NN ·“ im Abschnitt „Dialog-, Mimik- und Sprachregie“. Basis des Abgleichs: Build 7, Commit `7c3194db13acef2702e5e92336b94e9be41c7b58`. Die Drehbuch-Datei selbst liegt nicht im Repository.

Nicht gelesen: `IRON_BANNERS_Projektmappe.zip` (Projektbibel, Master-GDD, Datenmodelle) lag nicht vor.

## Ergebnis des Titelabgleichs

Alle 113 Hauptmissionen und 96 Nebenquests in `prototype/assets/story/campaign_arc.json` stimmen in ID und Titel mit den Storykarten (Tabelle 2 je Band) und den Nebenquest-Überschriften der vier Bände überein. Es war keine Titelkorrektur nötig.

## Missionen I-01 bis I-06

| ID | Drehbuch (Abschnitt „I-0x · …“, Tabelle) | Stand Build 7 | Änderung in diesem Branch |
|---|---|---|---|
| I-01 Die drei Becher | Tab. 4: Familienhaus Valdora; Julia, Silvanus, Spieler; Storykern: erster spielbarer Morgen macht Eltern, Zuhause, Essen, Arbeit und kleine Wahlmöglichkeiten vertraut, bevor Gefahr existiert. Spezialmotiv: „Hände, Becher, Werkzeug, Brot“. | Julia gibt Denar, Spieler füllt einen Krug, Silvanus schickt zum Markt. Kein Becher im Spiel. HUD zeigte „Ein Morgen zu Hause“. | Aufgabe „Wasser holen und die drei Becher füllen“. Julia erhält Dialogzeile 01, Silvanus Zeile 02. HUD zeigt „I-01 · Die drei Becher“. *Eigene Ergänzung:* Die drei Becher stehen für Julia, Silvanus und den Spieler; das Drehbuch erklärt den Titel nicht. |
| I-02 Der falsche Korb | Tab. 5: Nachbarhaus und Backgasse; Julia, Aurelia, Spieler; Fehler erzeugt neue Situation statt Abbruch. | Persistentes Tor `i02_basket`/`i02_correct` mit Aurelia und Julia. | Keine inhaltliche Änderung nötig. |
| I-03 Marcus kennt eine Abkürzung | Tab. 6: Gassen, Brunnen, Markt; Marcus, Cassia, Spieler; Freund oder Rivale, Münzstreit, Marktweg. | `i03_marcus` (Freund/Rivale) und Marktkauf bei Cassia. | Keine. *Abweichung:* `deliver_food` (Rückgabe an Julia) ist I-03 zugeordnet, Julia steht nicht in der I-03-Besetzung. |
| I-04 Der Freund meines Vaters | Tab. 7: Schmiede des Sextus; Silvanus, Sextus, Spieler; Silvanus bringt den Jungen zu seinem ältesten Freund; Arbeit, alte Scherze, konkrete Hilfe. | Julia verweist auf eine Frage des Vaters an Fabius; Kleinholz-Botengang über Fabius; Sextus wird nicht als Freund des Vaters vorgestellt. | Julia: Vater möchte, dass du Sextus, seinen ältesten Freund, kennenlernst. Sextus begrüßt „Silvanus’ Kind“ und erhält Zeile 02 („Wenn du etwas nicht kannst …“). Silvanus erhält Zeile 01, Sextus Zeile 05 („Sieh hin …“). *Eigene Ergänzung:* „Dein Vater und ich kennen uns länger, als du lebst.“ *Offen:* Silvanus begleitet den Spieler nicht körperlich zur Schmiede; Fabius ist keine Band-1-Figur. |
| I-05 Sieh hin, bevor du Kraft brauchst | Tab. 8: Schmiede; Sextus, Spieler; erste echte Lehre; „ein beschädigter Griff wird geprüft statt blind bearbeitet“. | Blasebalg, Amboss, Kühlbottich mit einem *Scharnier*; keine Prüfung vor dem Richten. Kartenfehler: `rest_forge` existiert nicht, `rest_first` hatte keine Mission. | Werkstück ist ein beschädigter Griff: am Amboss zuerst den Riss suchen, dann richten. Item `checked_hinge` heißt jetzt „Geprüfter Truhengriff“ (ID bleibt für Spielstände). Zuordnung `rest_first → I-05` korrigiert. *Eigene Ergänzung:* Der Griff gehört zu Cassias Truhe (verbindet I-05 mit I-06). |
| I-06 Ein Preis ist eine Zusage | Tab. 9: Markt Valdora; Cassia, Marcus, Spieler; Handel als Beziehung, endliche Waren, Lieferzusagen und Ruf. | Lieferung an Cassia war I-05 zugeordnet. | `deliver_hinge → I-06`; Cassia erhält I-06 Zeile 10 („Ein Versprechen wiegt genau so viel …“). *Abweichung:* `smith_apprentice` (Sextus) ist I-06 zugeordnet; Marcus fehlt in der Code-Fassung von I-06. |

## I-07 bis I-09 (nur dokumentiert, nicht geändert)

- **I-07 Der kranke Wachmann** (Tab. 10: Wachposten und Dorfrand; Decimus, Silvanus, Spieler): Der Code nutzt Severus, Valeria und Aurelia. Severus, Fabius und Valeria kommen in keinem der vier Bände vor. Der Kern (beaufsichtigte Hilfe, kein Kindersoldat) ist im Code eingehalten.
- **I-08 Hufspuren im Regen** (Tab. 11: Nordweg, Felder, Bach; Marcus, Decimus, Spieler): Code mit Decimus und dem Dialog „Zeig mir, was du weißt …“ stimmt mit Zeile 05 überein; Marcus fehlt in der Code-Fassung.
- **I-09 Der letzte gewöhnliche Abend** (Tab. 12: Familienhaus und Dorf; Julia, Silvanus, Sextus, Marcus, Spieler): Der Code zeigt nur Julia (`family_evening`).

## Hinweis zu den Dialogzeilen des Drehbuchs

Die Dialogabschnitte der Missionen wiederholen Zeilen aus einem gemeinsamen Pool. Mehrere Spielerzeilen passen nicht zu einem friedlichen Morgen eines Zwölfjährigen, zum Beispiel I-01 Zeile 03 „Ich will wissen, wer dahintersteht …“ oder I-05 Zeile 04 „Ich habe zu viele Menschen verloren …“. Übernommen wurden nur Zeilen, die zur jeweiligen Handlung passen; die übrigen bleiben als Widerspruch dokumentiert und sind nicht eingebaut.
