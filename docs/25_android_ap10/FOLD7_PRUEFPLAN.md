# AP-10 · Prüfplan auf dem Fold7

Stand: 24.11.2026. Spielgrundlage ist der AP-1/AP-2-Stand `7a21dca`.
Der Android-Prüfbau **8 / 0.8.0-companions** stammt aus Commit
`b2c5970e7c8ce032c1941464e7659ac6d515c854` auf
`feature/ap1-ap2-companions-20261124`.

**Status: geplanter Fold7-Gerätetest.** Die unten bezeichnete APK ist statisch
geprüft und wurde mit demselben verifizierten Signierzertifikat wie die
veröffentlichte Build-7-APK signiert.
Die automatisierten Laufzeitnachweise und ihre Grenzen stehen im
[Lieferbericht](DELIVERY.md). Dieser Prüfplan behauptet keinen bereits
bestandenen Test auf dem Fold7. Bildrate, Frametimes, Akkuverbrauch und Wärme
auf diesem Gerät sind noch offen. Hierzu liegen mir keine gesicherten Daten vor.

Arbeite die Abschnitte nacheinander ab. Nach einem Abschnitt kannst du über das
Pausenmenü speichern und später fortsetzen. Zu jeder Prüfung reicht zunächst
**bestanden / Fehler / noch offen**. Bei einem Fehler helfen die Angaben aus
Abschnitt 9, damit wir ihn gezielt nachstellen können.

## 1. Gerät und Prüfbau festhalten

| Angabe | Eintrag vor dem Test |
|---|---|
| APK-Dateiname | `IMPERATHEN-b2c5970e-arm64.apk` |
| Versionsname und Versionscode | `0.8.0-companions` / **8** |
| Commit des vorgesehenen Prüfbaus | `b2c5970e7c8ce032c1941464e7659ac6d515c854`; bei Verwendung einer anderen APK neu abgleichen |
| Gerät und genaue Modellnummer | Fold7; genaue Modellnummer ergänzen |
| Android-Version / One-UI-Version | Noch einzutragen |
| Datum und Uhrzeit | Noch einzutragen |
| Anzeige | Außendisplay oder aufgeklapptes Innendisplay; Hoch-/Querformat |
| Grafikprofil | Für den ersten Durchgang „Ausgewogen“ |
| Schrift und Oberfläche | Gewählten Prozentwert notieren |
| Akku / Laden / Energiesparen | Akkustand in Prozent, Ladekabel ja/nein, Energiesparen ja/nein |
| Vergleichsbedingungen | Helligkeit, Hülle und gegebenenfalls laufende Bildschirmaufnahme notieren |

Wenn die Android-App-Info nur den Versionsnamen anzeigt, den Versionscode aus
dem Buildbericht übernehmen und keinen Wert schätzen.

Die vorgesehene Datei hat **186.142.729 Bytes** und diese SHA256:

```text
03f76c9e9a16c50f372ce63d56eb32770382256b809fcd9bd2e0a047b241972e
```

Vorhandene App-Daten für diesen Test behalten. Ein Update ist auf das Signierzertifikat
der veröffentlichten Build-7-APK abgestimmt; die tatsächlich bisher installierte
APK wurde hier nicht ausgelesen. Meldet Android einen Signatur- oder Paketkonflikt,
die vorhandene App samt Daten beibehalten und den genauen Fehlertext melden.

**Spielstand beachten:** „Neues Leben“ ersetzt den aktiven Spielstand. Die
Bestätigung im Spiel weist ausdrücklich darauf hin; die automatische Sicherung
ist kein Archiv mehrerer Partien. Einen wichtigen vorhandenen Stand zunächst
mit „Fortsetzen“ prüfen. Einen neuen Testdurchgang erst beginnen, wenn der
vorhandene Stand dafür ersetzt werden darf oder separat gesichert wurde.
Für den Vergleich Freund/Rivale sind zwei bewusst getrennte Testdurchgänge
nötig; eine Mehrfach-Slot-Verwaltung wird hier nicht vorausgesetzt.

## 2. Start, Menü und Vorspann

- [ ] **App starten.** Erwartet: Der Vorspann beziehungsweise die kurze Titelkarte
  endet im bedienbaren Hauptmenü. Kein dauerhaft schwarzes Bild, Absturz oder
  stehengebliebener Ladebildschirm.
- [ ] **Vorspann überspringen.** Während des Vorspanns einmal tippen; bei einem
  zweiten Aufruf die Android-Zurück-Geste beziehungsweise -Taste prüfen.
  Erwartet: genau ein Übergang, danach bleiben Menüschaltflächen bedienbar.
- [ ] **Vollständigen Vorspann erneut ansehen.** Unter „Einstellungen“ →
  „Vorspann jetzt ansehen“ öffnen. „Vorspann bei jedem Start vollständig zeigen“
  einmal ein- und wieder ausschalten. Erwartet: Die Einstellung bleibt nach
  erneutem Start erhalten. Ohne diese Einstellung ist nach dem ersten Start eine
  kurze Titelkarte vorgesehen.
- [ ] **Ton und Darstellung prüfen.** „Musik im Hauptmenü“ verändern, einmal
  stummschalten und wieder einschalten. Erwartet: keine ungewollte doppelte Musik;
  die Schaltflächen und Dialogtexte sind lesbar. Ein störender Klang wird mit
  Zeitpunkt und Lautstärkeeinstellung gemeldet.
- [ ] **Menü prüfen.** „Fortsetzen“, „Neues Leben“ und „Einstellungen“ müssen
  erreichbar sein. Ohne vorhandenen Spielstand darf „Fortsetzen“ deaktiviert
  sein. Eine neue römische Kindheit beginnt über die römische Herkunft und
  „Neues Leben“; bestehende Spielstände werden über „Fortsetzen“ geladen.

Einmal „Bewegungseffekte reduzieren“ prüfen. Erwartet: ruhigere Präsentation
bei weiterhin bedienbarem Menü. Das ist keine Messung der Spielleistung.

## 3. Bewegung und Touch im Dorf

Diese kurze Runde auf einer freien Dorfstraße durchführen, bevor du längere
Aufträge spielst.

- [ ] **Gehen:** Linkes Bewegungspad ungefähr zehn Sekunden gedrückt halten,
  ohne den Finger ständig neu aufzusetzen. Erwartet: durchgehende Bewegung.
  Nach dem Loslassen bleibt die Figur stehen.
- [ ] **Gehen/Laufen:** Während der linke Finger weiter das Pad hält, mit einem
  zweiten Finger die Temposchaltfläche „Gehen“/„Laufen“ antippen. Erwartet:
  merklich unterschiedliches Tempo; der erste Finger verliert die Bewegung
  nicht. Danach wieder auf Gehen stellen.
- [ ] **Kamera:** Beim Gehen im freien rechten Bildbereich umsehen. Erwartet:
  Kamera und Bewegung funktionieren gleichzeitig. Das Antippen einer sichtbaren
  Aktionstaste löst keine unbeabsichtigte große Kameradrehung aus.
- [ ] **Interaktion:** Zu einer Figur gehen und „Interagieren“ antippen.
  Erwartet: das passende Gespräch oder eine verständliche Meldung. Ein Gespräch
  darf nicht allein deshalb aus der Ferne starten, weil die Figur dort früher
  gestanden hat.
- [ ] **Hauszugang:** Durch die offene Haustür über die Rampe ins Familienhaus
  und wieder hinaus gehen. Erwartet: keine sichtbare Bodendurchdringung, kein
  Feststecken an der Schwelle und keine Passage durch geschlossene Wände.
- [ ] **Zurück aus einem Menü:** Ein Dialog- oder Touch-Menü öffnen und wieder
  schließen. Erwartet: Die Figur läuft anschließend nicht ohne erneute Eingabe
  weiter; die Bedienelemente reagieren wieder.

## 4. I-04 · Silvanus zur Schmiede begleiten lassen

Den normalen Aufträgen bis **„Der Freund meines Vaters“** folgen. Die neue
Begleitung ist nach dem Gespräch über das Kleinholz aktiv.

- [ ] **Kleinholz holen:** Silvanus nach dem Kleinholz für Sextus fragen, dann
  zum westlichen Holzlager gehen und das vorbereitete Bündel aufnehmen.
  Erwartet: Silvanus ist als dieselbe sichtbare Figur unterwegs. Er erscheint
  nicht gleichzeitig als zweiter Vater am alten Standort.
- [ ] **Weg zur Schmiede:** Erst gehen, dann kurz laufen; an einer Hausecke
  vorbeigehen und vor einem Bewohner stehen bleiben. Erwartet: Silvanus läuft
  körperlich nach, hält Abstand und benutzt einen freien Weg. Er springt nicht
  durch Gebäude oder Personen. Bei versperrtem Weg darf er zunächst warten;
  nach Freimachen des Wegs muss die Fortsetzung beobachtet werden.
- [ ] **Bei Sextus ankommen:** Das Kleinholz übergeben und die Erlaubnis für
  den Probemorgen ansprechen. Erwartet: Silvanus erreicht seinen Haltepunkt bei
  der Schmiede und lässt sich dort ansprechen. Der Auftrag nennt jetzt diesen
  tatsächlichen Standort.
- [ ] **Gespräch und Stillstand:** Während des Dialogs die Figur beobachten.
  Erwartet: kein Weiterlaufen im Hintergrund und keine endlose Laufanimation
  auf der Stelle. Nach dem Gespräch bleibt der nächste Auftrag erreichbar.

Für einen Befund genügen ein Bild vor dem Ansprechen und gegebenenfalls ein
kurzes Video der problematischen Ecke. Notiere dabei den eingeblendeten Auftrag.

## 5. I-06 · Marcus und die Freund/Rivale-Wahl

### Erster Durchgang: Freund

In I-03 **„Den Streit beilegen und gemeinsam gehen“** wählen. Der entsprechende
Auftragstext kann die ausführlichere Form „Den Münzstreit beilegen und gemeinsam
gehen“ verwenden. In I-06 den geprüften Truhengriff zu Cassia bringen.

- [ ] Marcus kommt tatsächlich zum Markt und erreicht dort seinen Haltepunkt.
  Er bleibt nicht nur als Name in einem Dialog präsent.
- [ ] In seiner Nähe mit ihm sprechen. Erwarteter Titel: **„Marcus · vertraut“**.
  Erwarteter Satz: **„Sag nur, ob wir klug sein wollen oder berühmt. Beides
  gleichzeitig klappt bei uns selten.“**
- [ ] Während des Dialogs hält Marcus an. Nach dem Schließen bleiben Lieferung,
  Abrechnung und der weitere Weg zu Sextus ausführbar.
- [ ] Einmal speichern, fortsetzen und Marcus erneut ansprechen. Erwartet:
  dieselbe Beziehungsvariante; bereits bestätigte Lieferung und Geldbestand
  werden durch das Laden nicht nochmals als neue Belohnung verbucht.

### Zweiter Durchgang: Rivale

Erst nach Abschluss beziehungsweise separater Sicherung des ersten
Testdurchgangs ein neues Testspiel beginnen. In I-03 **„Auf dem eigenen
Standpunkt beharren“** wählen und wieder bis zum Marktauftrag in I-06 spielen.

- [ ] Marcus ist auch nach dieser Wahl tatsächlich am Markt anwesend.
- [ ] Erwarteter Titel: **„Marcus · zurückhaltend“**.
  Erwarteter Satz: **„Ich gehe mit. Aber diesmal entscheidest du nicht allein
  für uns beide.“**
- [ ] Die Variante bleibt nach Speichern und Laden erhalten. Marcus darf auf
  dem Weg etwas mehr Abstand halten; ein anderer Markttext allein ist kein
  Ersatz für seine körperliche Anwesenheit.

Der Unterschied ist hier als Text und Regie umgesetzt. Für diese neuen
Begleitzeilen wurde keine zusätzliche Sprachaufnahme erstellt.

## 6. I-07 bis I-09 · Name, Spuren und Abend

### I-07 · Der kranke Wachmann

- [ ] Aktuelle Aufträge, Figurenanzeige und Gespräche verwenden **„Wachmann“**.
  Decimus bleibt eine eigene Figur und wird nicht zum kranken Wachmann erklärt.
- [ ] Die vorhandene Auftragsfolge mit Kontrollrunde, Versorgung, Erlaubnis und
  geliehenen Sachen weiterspielen. Auch die Wasseraufgabe ausführen: Wasser am
  Haus holen und zum Torabschnitt bringen.
- [ ] Nachricht und Leihsachen ordentlich übergeben. Erwartet: Der nächste
  Auftrag wird erreichbar; kein fehlender Ansprechpartner blockiert den Ablauf.

Bereits gespeicherte alte Chronikeinträge werden nicht umgeschrieben. Ein alter
Name ausschließlich in einer solchen Rückschau ist gesondert von einem falschen
Namen in einem aktuellen I-07-Dialog zu melden.

### I-08 · Hufspuren im Regen

- [ ] Zum Nordweg gehen. Erwartet: Marcus folgt und hält bei den Spuren an,
  ohne das benachbarte Haus zu durchqueren.
- [ ] Marcus dort ansprechen. Erwarteter Satz: **„Sag nur, ob wir klug sein
  wollen oder berühmt. Beides gleichzeitig klappt bei uns selten.“**
  Der Titel entspricht weiterhin der eigenen Freund/Rivale-Wahl.
- [ ] Spuren prüfen und Decimus berichten. Erwartet: Die Beobachtung wird
  übernommen; aus den Hufspuren wird kein bereits bewiesener Täter gemacht.
  Marcus kann dem weiteren Weg folgen.

### I-09 · Der letzte gewöhnliche Abend

- [ ] Zum Familienauftrag zurückkehren. Erwartet: Marcus erreicht seinen
  Haltepunkt **beim Familienhaus**. Er muss nicht hinter dir durch jede
  Innenraumecke laufen; er darf keine Wand durchqueren.
- [ ] Marcus vor dem Schlafengehen ansprechen. Erwarteter Satz:
  **„Ich gehe mit. Aber diesmal entscheidest du nicht allein für uns beide.“**
  Vertrauter beziehungsweise zurückhaltender Titel bleibt erhalten.
- [ ] Mit Julia sprechen; die optionalen Abendbesuche bei Silvanus und Sextus
  bleiben erreichbar. Das Beenden des Tages erfolgt erst durch die bewusste
  Schlafen-Aktion.
- [ ] **Vor dem Schlafengehen speichern** und den folgenden Ladetest ausführen.

I-08 und I-09 besitzen jeweils denselben belegten Satz für beide Beziehungen;
Titel und Textregie unterscheiden sich. Zwei verschiedene Sätze sind dort kein
Sollkriterium. „Abend“ bezeichnet hier den Auftrag und verspricht keine neue
Abendbeleuchtung.

## 7. Pause, Hintergrund und Speichern/Laden

Diese Unterbrechungsrunde möglichst einmal mit Silvanus in I-04 und einmal mit
Marcus in I-06, I-08 oder I-09 durchführen.

- [ ] **Pause während des Laufens:** Bewegungspad halten, dann das Spiel
  pausieren. Erwartet: Spieler und Begleiter halten an. Nach „Weiterspielen“
  bewegt sich der Spieler erst durch eine neue Eingabe.
- [ ] **Gezielt speichern:** Im Pausenmenü „Spiel speichern“ antippen und die
  Rückmeldung abwarten. Auftrag, Begleiterstandort und Geldbestand auf einem
  Screenshot beziehungsweise in einer kurzen Notiz festhalten.
- [ ] **Hauptmenü und Fortsetzen:** „Zum Hauptmenü“ → „Speichern und Hauptmenü“,
  anschließend „Fortsetzen“. Erwartet: Auftrag und Wahl bleiben erhalten. Der
  Begleiter steht beim Laden an seiner gespeicherten Position; danach darf er
  den zur Mission gehörenden Weg wieder aufnehmen. Er wird nicht auf seinen
  alten Heimatpunkt zurückgesetzt.
- [ ] **Android-Hintergrund:** Die App über Home verlassen, ungefähr eine halbe
  Minute warten und über die zuletzt verwendeten Apps zurückkehren. Erwartet:
  kein unkontrolliertes Weiterlaufen, kein verlorener bestätigter Auftrag und
  bedienbare Rückkehr. Im aktiven Dorf ist eine Pause vorgesehen.
- [ ] **Bildschirm sperren:** Einmal sperren und entsperren. Erwartet: Bewegung
  bleibt bis zur bewussten Fortsetzung angehalten. Falls Android die App neu
  gestartet hat, über „Fortsetzen“ den zuletzt gespeicherten Stand prüfen.
- [ ] **Vollständiger Neustart:** Über das Spielmenü „Spiel beenden“ bestätigen,
  anschließend die App erneut öffnen und „Fortsetzen“ wählen. Erwartet:
  Beziehungswahl, bestätigte Lieferung, Auftrag und Begleiterposition bleiben
  erhalten; keine doppelte Figur und keine doppelte Belohnung.

Bei einer Speicher- oder Lademeldung mit Fehlertext diesen **wörtlich erfassen**.
Nicht durch „Neues Leben“ ersetzen, bevor der Befund gesichert ist.

## 8. Fold7-Anzeige und beobachtete Leistung

### Anzeigewechsel

Menü, einen Dialog und das laufende Dorf jeweils auf dem Außen- und Innendisplay
prüfen. Hoch- und Querformat verwenden, soweit die aktuelle Geräteeinstellung
die Drehung zulässt. Einmal im Menü und einmal nach bewusstem Speichern im
Dorf auf- beziehungsweise zuklappen.

- [ ] Texte und wichtigste Schaltflächen bleiben innerhalb der sichtbaren
  Fläche; nichts Entscheidendes wird durch Kameraloch, Systemleisten oder
  Bildschirmrand verdeckt.
- [ ] Bewegungspad und Aktionstasten liegen nicht unbedienbar übereinander.
- [ ] Nach dem Wechsel funktionieren Touch, Kamera und Dialogschließen wieder.
- [ ] Falls der Anzeigewechsel die App unterbricht oder neu startet: Auftrag
  und gespeicherten Stand über „Fortsetzen“ prüfen und den genauen Ablauf melden.

### Gleiche Strecke für den Leistungsvergleich

Zuerst den funktionalen Durchgang mit **„Ausgewogen“** beenden. Danach bei Bedarf
mit **„Hoch“** und **„Sehr hoch“** dieselbe kurze Strecke und denselben
Begleitauftrag wiederholen. Die Profilangaben „Limit 60 FPS“ beziehungsweise
„Limit 30 FPS“ sind eingestellte Obergrenzen, keine zugesagten Messergebnisse.

Unter „Einstellungen“ lässt sich **„Leistungsdiagnose anzeigen“** einschalten.
Sichtbare FPS und ms/Bild samt Profil, Ort und Laufzeit aufschreiben oder
fotografieren. Fehlende Messwerte als **nicht verfügbar** kennzeichnen. Ein
flüssiger Eindruck ist eine Beobachtung, aber kein Ersatz für eine Zahl.

| Zeitpunkt des geplanten Vergleichs | Profil / Ort / Display | FPS | ms/Bild | Akku | Wärmebeobachtung / Messquelle |
|---|---|---|---|---|---|
| Kurz nach Beginn | Noch offen | Noch offen | Noch offen | Noch offen | Noch offen |
| Nach etwa 5 Minuten | Noch offen | Noch offen | Noch offen | Noch offen | Noch offen |
| Nach etwa 15 Minuten | Noch offen | Noch offen | Noch offen | Noch offen | Noch offen |
| Nach etwa 30 Minuten, falls durchgeführt | Noch offen | Noch offen | Noch offen | Noch offen | Noch offen |

Für den Vergleich Helligkeit, Laden, Hülle und Bildschirmaufnahme gleich halten
oder Änderungen mitnotieren. Eine Temperatur nur mit Wert und tatsächlicher
Messquelle angeben; „fühlt sich warm an“ bleibt eine getrennte subjektive
Beobachtung. Auffällige Ruckler, Touch-Verzögerungen, selbsttätige Abdunklung oder
Systemmeldungen mit Zeitpunkt notieren. Daraus wird vor der Auswertung keine
behauptete Geräteursache abgeleitet.

## 9. Fehler kurz und nachstellbar melden

Für einen Befund dieses Schema kopieren:

```text
Prüfung: z. B. Abschnitt 4, Weg zur Schmiede
APK-Dateiname:
Versionsname / Versionscode:
Commit laut Buildbericht:
Gerät / genaue Modellnummer:
Android / One UI:
Außen- oder Innendisplay / Ausrichtung:
Grafikprofil / Schriftgröße:
Auftrag im Spiel und Freund-/Rivalenwahl:
Was habe ich unmittelbar vorher angetippt oder gehalten?
Was hätte passieren sollen?
Was ist tatsächlich passiert?
Fehlertext wörtlich:
Nach Neustart wiederholbar: ja / nein / nicht geprüft
Bild oder kurzes Video / Zeitpunkt:
Laufzeit bis zum Fehler / Akku / Ladekabel:
```

Bei einem Bewegungsfehler zusätzlich angeben: welche Figur, welcher Ort, welcher
Finger noch auf dem Bildschirm lag und ob der Weg frei war. Bei einem Absturz
angeben, ob die App sofort verschwand, stehenblieb oder eine Android-Meldung
zeigte. Ein Screenshot mit Auftrag und Umgebung ist oft hilfreicher als nur ein
stark vergrößerter Ausschnitt.

## 10. Ergebnisübersicht

| Bereich | Bestanden / Fehler / noch offen | Befundnummer oder Notiz |
|---|---|---|
| Menü und Vorspann | Noch offen | |
| Bewegung, Kamera und Touch | Noch offen | |
| I-04 Silvanus | Noch offen | |
| I-06 Marcus: Freund | Noch offen | |
| I-06 Marcus: Rivale | Noch offen | |
| I-07 Wachmann und Fortsetzung | Noch offen | |
| I-08 Nordweg | Noch offen | |
| I-09 Familienabend | Noch offen | |
| Pause / Hintergrund / Sperren | Noch offen | |
| Speichern / Hauptmenü / Neustart / Laden | Noch offen | |
| Außen-/Innendisplay und Anzeigewechsel | Noch offen | |
| Beobachtete Leistung und längere Laufzeit | Noch offen | |

Ein Bereich wird nur als bestanden markiert, wenn er auf dem angegebenen Gerät
mit dem angegebenen Prüfbau tatsächlich ausgeführt wurde. Ein offener
Rivalendurchgang oder eine fehlende Wärmemessung bleibt ausdrücklich offen.

## Quellen dieses Prüfplans

Die erwarteten Abläufe stammen aus der vorhandenen Implementierung; der Plan
führt keine neue Spielfunktion ein.

- [`AP-1-Begleitsystem`](../24_ap1_ap2/AP1_BEGLEITER.md) und
  [`Originalquellenprüfung`](../24_ap1_ap2/QUELLENPRUEFUNG.md):
  Band 1, I-04 Tabelle 7/Zeile 01; I-06 Tabelle 9/Zeilen 05 und 08;
  I-07 Tabelle 10; I-08 Tabelle 11/Zeile 01; I-09 Tabelle 12/Zeile 04.
- [`Missionsdateien Band 1`](../../prototype/assets/story/missions/band1/):
  Auftragsfolge, aktive Begleitschritte, Haltepunkte und Dialogtexte.
- [`companion_story.gd`](../../prototype/scripts/story/companion_story.gd) und
  [`companion_world.gd`](../../prototype/scripts/world/companion_world.gd):
  Freund/Rivale-Regie, physische Anwesenheit, Halten und Rückkehr.
- [`game_ui.gd`](../../prototype/scripts/ui/game_ui.gd): genaue Menünamen,
  Touch-Eingaben, Grafikprofile und Vorspanneinstellungen.
- [`main.gd`](../../prototype/scripts/main.gd): Pause, Android-Unterbrechungen,
  Speichern, Fortsetzen und Bestätigung vor einem neuen Leben.
- [`runtime_display.gd`](../../prototype/scripts/ui/runtime_display.gd):
  verfügbare Diagnoseanzeige; keine Behauptung eines bereits gemessenen Werts.
