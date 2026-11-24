# IMPERATHEN: Auftrag für Grok Build und Übergabe an das Godot-Projekt

Stand: 24. November 2026. Dieser Auftrag ist ein Vorschlag für eine zusätzliche,
getrennte Arbeit. Er behauptet keine bereits erfolgte Beauftragung von Grok.

## Empfehlung für Heinz

Das bestehende Godot-Spiel und seine Android-Builds werden im Repository
`Ullmann27/Imperathen` weiterentwickelt. Grok Build erhält ein abgegrenztes
Zusatzprojekt: einen spielbaren Entwurf des ersten Dorfabschnitts mit Dialog,
Journal und Touchbedienung. Sein Ergebnis dient als ausführbare Referenz und
liefert offene Daten und Assets. Eine neue Web-Implementierung ersetzt nicht
automatisch die vorhandene Godot-Implementierung.

Die offiziellen Veröffentlichungen beschreiben interaktive Spiele und
3D-Welten im Build-Modus sowie einen vollständigen GitHub-Export. Ein
Godot-Android-Export unmittelbar im auf dem Screenshot gezeigten mobilen Modus
ist damit nicht bestätigt. Grok Build für das Terminal ist eine weitere
Ausführungsumgebung; sie kann Quellcode bearbeiten und Befehle ausführen.
Welche Engine, SDKs und Exportwerkzeuge dort tatsächlich vorhanden sind, muss
vor einem Auftrag am vorhandenen Spiel geprüft werden.

Quellen, am 24. November 2026 aufgerufen:

- https://x.ai/news/grok-build-for-everyone
- https://x.ai/news/grok-build-mode
- https://github.com/xai-org/grok-build

## Diese Unterlagen bei Grok bereitstellen

Grok benötigt die Dateien selbst oder tatsächlich erreichbaren Zugriff darauf.
Ein Verweis auf Dateien in einem anderen privaten Chat stellt diesen Zugriff
nicht her.

1. `IMPERATHEN_Drehbuch_Band_1_DAS_FEUER_VON_VALDORA(1).docx`
2. `IMPERATHEN_Drehbuch_Band_2_DER_ADLER_UND_DER_RUBIKON(1).docx`
3. `IMPERATHEN_Drehbuch_Band_3_DIE_IDEN(1).docx`
4. `IMPERATHEN_Drehbuch_Band_4_DAS_REICH_DANACH(1).docx`
5. `IRON_BANNERS_Projektmappe.zip`, insbesondere die enthaltene
   `IRON_BANNERS_Projektbibel.pdf`, das Master-GDD und die Datenmodelle.
6. Für Arbeiten am echten Godot-Code zusätzlich einen ausdrücklich benannten
   Repository-Stand mit Branch und vollständiger Commit-ID. Ein APK ersetzt
   den Projektquellcode nicht.

Die älteren IRON-BANNERS-Unterlagen nennen Unreal Engine und PC als Erstziel.
Die vier IMPERATHEN-Bände sind vom 23. November 2026. Das derzeit bearbeitete
Spiel verwendet Godot und Android. Diese Unterschiede dürfen nicht unbemerkt
zu einem Enginewechsel oder zu widersprüchlichen Handlungsabläufen führen.

---

## Kopierfertiger Auftrag: Grok Build

Du arbeitest als ergänzender Entwickler an **IMPERATHEN – Rise of an Empire**.
Erstelle ein ausführbares, vollständig exportierbares Zusatzprojekt mit dem
Arbeitstitel **„Valdora: Der erste Morgen“**. Es ist eine spielbare Referenz für
den Dorfanfang und die Bedienung des bestehenden Godot-/Android-Spiels.

### 1. Verbindliche Unterlagen und Reihenfolge

Lies zuerst die von mir angehängten vier IMPERATHEN-Drehbuchbände. Band 1
„Das Feuer von Valdora“ ist die unmittelbare Grundlage. Lies danach die
IRON_BANNERS-Projektbibel und die technischen Datenmodelle aus der ZIP als
ergänzende Konzeptreferenz. Nenne konkret, welche Dateien du tatsächlich
öffnen konntest. Fehlende oder unlesbare Dateien darfst du nicht als gelesen
ausgeben.

Dieser Auftrag legt die technische Zusammenarbeit fest. Aktuelle ausdrückliche
Entscheidungen haben Vorrang vor älteren technischen Empfehlungen. Die
Unreal-/PC-Vorgabe der alten Mappe löst keinen Wechsel des bestehenden
Godot-/Android-Spiels aus. Dokumentiere verbleibende Widersprüche mit Datei
und Abschnitt, statt stillschweigend einen neuen Kanon zu erfinden.

### 2. Zuerst deine tatsächlich verfügbare Umgebung prüfen

Stelle fest, ob du in dieser Build-Sitzung Web-Projekte oder auch echte
Godot-Projekte ausführen und exportieren kannst. Nenne nur nachweislich
verfügbare Werkzeuge und Versionen. Wenn ausschließlich ein Web-Projekt
ausführbar ist, baue die folgende Referenz dafür. Eine Browser-Vorschau darf
nicht als native Android-APK oder als getesteter Godot-Build bezeichnet werden.

Arbeite in einem separaten Projekt. Verändere und überschreibe keine Branches
des bestehenden Spiels. Keine bezahlten Dienste, API-Aktivierungen oder
öffentliche Veröffentlichung ohne ausdrücklichen Auftrag. Die Referenz soll
nach dem Laden ohne erforderliche KI-Abfragen funktionieren.

### 3. Spielbarer Umfang dieses Auftrags

Setze einen kleinen, zusammenhängenden Ausschnitt aus Band 1 um: den Morgen
im Familienhaus und den anschließenden Weg durch Valdora. Verwende für
Missionen I-01 bis I-05 ausschließlich die Inhalte, Figuren, Beziehungen und
Voraussetzungen, die du in den bereitgestellten Quellen gefunden hast.
Halte die Missions-IDs stabil. Kleine verbindende Details kennzeichnest du
als eigene Ergänzung.

Der Spieler ist zwölf Jahre alt; der Anfang spielt 58 v. Chr. in dem fiktiven
Valdora im Raum Aquileia. Der Einstieg bleibt zunächst ruhig und persönlich.
Kein automatischer Sprung zum erwachsenen Soldaten, kein sofortiger
Dorfüberfall und kein eigenmächtiges Überspringen der Kindheit.

Liefern sollst du:

- Einen tatsächlich begehbaren, überschaubaren 3D-Ort mit Familienhaus,
  Dorfweg und den für die ausgewählten Szenen benötigten Orten. Kollisionen
  müssen an den sichtbaren Hindernissen funktionieren.
- Dritte-Person-Kamera, getrennte Touchflächen für Bewegung und Blick sowie
  kontextabhängige Interaktion. Tastatur und Maus dürfen zusätzlich nutzbar
  sein. Prüfe die Bedienung in einer breiten und einer schmalen Ansicht.
- Ein ruhiges, gut lesbares HUD mit Dialog, Aufgabenjournal und den im
  Ausschnitt tatsächlich benötigten Interaktionen. Keine funktionslosen
  Schaltflächen, die weitere fertige Systeme vortäuschen.
- Wenige persistente Dorfbewohner mit nachvollziehbarer Tätigkeit. Dialog,
  Aufgabenfortschritt und freie Bewegung müssen zusammen funktionieren.
- Speichern und Laden sowie einen JSON-Export und -Import des Referenzstands.
  Ein erneutes Laden darf abgeschlossene Aufgaben oder verbrauchte Gegenstände
  nicht willkürlich zurücksetzen oder verdoppeln.

Verwende vorhandene, dafür bereitgestellte Modelle, wenn sie in deiner
Umgebung brauchbar sind. Neu erstellte oder provisorische Modelle werden als
solche ausgewiesen. Konzeptbilder aus den Unterlagen sind Bildreferenzen und
keine Nachweise für bereits vorhandene Spielgrafik. Behaupte keine fertigen
Kampf-, Tier-, Reit- oder Massenschlachtsysteme, wenn sie nicht umgesetzt sind.

### 4. Daten und Darstellung trennen

Halte Charaktere, Missionen, Dialoge und Zustandsänderungen in offenen,
lesbaren Daten. Benutze stabile IDs und eine `schema_version`. Die Darstellung
darf eine Aufgabe nicht allein durch das Abspielen eines Videos abschließen.
Ein gemeinsamer Referenzzustand entscheidet über Inventar, bekannte
Informationen, Beziehungen und Missionsfortschritt.

Der JSON-Export ist ein dokumentierter Austauschvertrag für die Referenz.
Behaupte nicht, er sei ohne Migration mit den bestehenden Godot-Saves
kompatibel. Beschreibe die erforderliche Zuordnung für eine spätere Integration.

### 5. Export und überprüfbare Übergabe

Liefere den vollständigen Quellcode über den tatsächlich verfügbaren
GitHub-Export oder als vollständiges herunterladbares Projekt. Ein alleiniger
Vorschaulink reicht für die Übernahme nicht aus. Dokumentiere Start- und
Buildbefehle, tatsächlich verwendete Versionen und erforderliche Abhängigkeiten.

Zum Übergabepaket gehören:

- `README.md`: Installation, Start, Build, Bedienung und tatsächlicher Umfang.
- `HANDOFF.md`: Architektur, Änderungen, Integrationshinweise und bekannte Fehler.
- `data/`: offene Figuren-, Dialog- und Missionsdaten mit Schema und Beispielspeicherstand.
- `SOURCE_MAP.md`: Zuordnung der übernommenen Inhalte zu Dokument, Mission
  und Abschnitt; eigene Ergänzungen separat kennzeichnen.
- `ASSET_MANIFEST.json`: jede verwendete Asset-Datei mit Herkunft, Lizenz bzw.
  dokumentierter Erstellungsquelle, Maßstab und Exportformat.
- Originale Modelldateien bzw. offene GLB/glTF-Exporte, Texturen und tatsächlich
  vorhandene Animationen; keine unerreichbaren temporären Asset-Links.
- `TEST_REPORT.md`: ausgeführte Prüfungen mit Ergebnis und tatsächliche
  Screenshots oder Videoaufnahmen aus der laufenden Referenz. Nicht
  ausgeführte Prüfungen bleiben ausdrücklich offen.

Prüfe mindestens Start, Bewegung, Kollision, Kamerabedienung, Dialogende,
Fortsetzung der Bewegung nach Dialogen, Missionsvoraussetzungen, doppeltes
Auslösen einer Interaktion, Speichern/Laden und beide Bildschirmformate.

Beginne nach dem Lesen und der kurzen Prüfung deiner Umgebung unmittelbar
mit der Implementierung. Triff gewöhnliche, reversible Umsetzungsentscheidungen
selbstständig. Stelle nur eine gezielte Frage, wenn eine fehlende Datei oder
ein wirklicher inhaltlicher Widerspruch die konkrete Umsetzung blockiert.

---

## Wie das Ergebnis anschließend übernommen wird

Heinz stellt den GitHub-Link mit Commit-ID oder das vollständige Exportprojekt
wieder im IMPERATHEN-Projekt bereit. Zusätzlich hilfreich sind ein Video und
eine kurze Angabe, welche Elemente übernommen werden sollen.

| Ergebnis von Grok | Weg in das bestehende Godot-Spiel |
| --- | --- |
| Figuren-, Dialog- und Missionsdaten | Gegen den Kanon prüfen, IDs zuordnen, an das vorhandene Datenmodell anpassen und testen. |
| GLB/glTF-Modelle und Texturen | Lizenz, Maßstab, Materialien, Rig und Animationen prüfen; in Godot importieren und auf Android vermessen. |
| HUD, Journal, Dialogdarstellung | Gestaltung und Interaktion übernehmen; Web-Oberflächen gegebenenfalls mit Godot-Control-Nodes neu umsetzen. |
| Web-Bewegungs- oder Kampfcode | Verhalten als Referenz nutzen; erforderliche Logik in die vorhandenen Godot-Controller übertragen. |
| Tatsächlicher Godot-Patch auf benanntem Basis-Commit | Diff prüfen, Konflikte auf einer getrennten Integrationsbranch lösen und bestehende Prüfungen ausführen. |
| Grok-spezifische Cloudfunktionen | Abhängigkeiten prüfen; nur bei bewusst gewähltem Betrieb übernehmen, sonst durch passende lokale bzw. vorhandene Dienste ersetzen. |

Eine zusätzliche KI kann Arbeit parallel liefern. Ein erfolgreicher Export
oder eine attraktive Vorschau bestätigt jedoch noch keine funktionierende
Integration, korrekte Animationen oder Leistung auf einem echten Android-Gerät.
