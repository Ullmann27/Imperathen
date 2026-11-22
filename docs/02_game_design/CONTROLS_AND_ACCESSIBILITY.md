# IMPERATHEN – Steuerung, Kameras und Zugänglichkeit

**Status:** Entwurf eines Bedienkonzepts für spätere Prototypen.  
**Quelle:** Nutzerwunsch nach persönlichem Kampf, eigenem Städtebau und Landkartenstrategie; `MASTER_GDD.md`, Abschnitte 7 und 11. Es liegen noch keine Bedien- oder Gerätetests vor.

## 1. Gemeinsame Bedienlogik

Die Eingabe wird nach Handlungsabsichten definiert: bewegen, ansehen, auswählen, interagieren, bestätigen, abbrechen, angreifen, blocken, bauen und befehlen. Maus/Tastatur und Controller lösen dieselben Absichten aus. Konkrete Tasten werden erst mit dem späteren Prototyp festgelegt und sollen vollständig neu belegbar sein. Sprachbefehle sind eine mögliche Ergänzung; jede notwendige Aktion bleibt ohne Mikrofon ausführbar.

Eine Aktion zeigt ihr Ziel und ihre wesentlichen Kosten, bevor sie bestätigt wird. Abbruch muss aus Dialog, Bauvorschau und Befehlsmodus verlässlich zurückführen. Ein Menüwechsel darf keine bereits bestätigte Spielhandlung heimlich wiederholen.

## 2. Vier Perspektiven

| Perspektive | Kernbedienung | Wesentliche Anzeige |
|---|---|---|
| Persönliche Figur | Bewegung, Interaktion, Kampf und Gespräch | unmittelbare Ziele, Gesundheit/Ausdauer, Kontextaktion |
| Städtebau | Ort wählen, drehen, Wege ziehen, Arbeit priorisieren | Baugrund, Material, Zugang, Beschäftigung, Lager |
| Taktik | Einheit oder Gruppe wählen, Ziel und Formation bestimmen | Befehlsrecht, Moral, Stärke, Auftrag und Sichtinformation |
| Kampagnenkarte | Region wählen, Route, Verwaltung und Diplomatie | Herrschaft, Versorgung, Reisen, Handel und Zeit |

Der Übergang erhält Auswahl und relevante Weltposition. Falls Streaming nötig ist, wird es sichtbar behandelt. „Nahtlos“ ist ein Gestaltungsziel und keine bereits nachgewiesene technische Eigenschaft. Die ausgewählte Stadt und Armee bleiben dieselben Entitäten. Kameraposition und Aufenthaltsort der Hauptfigur sind getrennt: Eine Fernansicht teleportiert sie nicht. Die Rückkehr zur persönlichen Ansicht führt zu ihrem tatsächlichen Ort. Reisezeiten, bekannte Informationen und Befehlsrechte gelten auch bei freier Kamerawahl weiter.

## 3. Persönliche Kamera und Kampflesbarkeit

Die Schulterkamera soll Umgebung und unmittelbare Gefahr zeigen. Abstand, Seitenwahl, Empfindlichkeit, Kamerawackeln, Bewegungsunschärfe und Blickfeld erhalten passende Einstellungen. Kamera und Mauern benötigen Kollisionsregeln; ein enger Eingang darf den Spieler nicht dauerhaft blind machen. Die taktische Übersicht muss Informationen verdichten, ohne sämtliche Nahkampfdetails gleichzeitig einzublenden.

Gegneraktionen benötigen erkennbare Vorbereitung und Reaktion. Trefferinformation darf nicht ausschließlich aus Farbe, Ton oder extrem kleinen Animationen bestehen. Audio, Symbol und Bewegung ergänzen sich. Spezialeffekte und Sonnenblendung sollen nicht die grundlegende Steuerbarkeit verdecken.

## 4. Bauen mit Maus und Controller

Mit Maus kann die Platzierung direkt am Boden folgen. Der Controller benötigt einen stabilen Auswahlzeiger, kontrollierbare Kamerabewegung, schrittweise Drehung und gut erreichbare Bestätigung. Vorschau zeigt gültige Fläche, Kosten und konkrete Ablehnungsgründe. „Zugang fehlt“ ist hilfreicher als ein bloß roter Umriss.

Längere Wege oder Mauern brauchen Vorschau und verständliche Segmente. Der Spieler kann vor Bestätigung korrigieren. Nach bestätigtem Bauauftrag gelten Ressourcen- und Abbruchregeln aus dem Wirtschaftsentwurf; Bedienkomfort darf kein kostenloses Material erzeugen.

## 5. Menüs, Speicherung und Alltag

Das Startmenü bietet Neues Leben, Fortsetzen, Spielstände und Einstellungen. Weitere Modi erscheinen erst, wenn sie tatsächlich existieren. Speichern zeigt Abschluss oder Fehler eindeutig. Ladefehler dürfen nicht als stiller Neustart dargestellt werden. Hilfe erklärt Begriffe wie Versorgung, Legitimität und Formation unmittelbar am jeweiligen Bildschirm.

Texte werden von Spiellogik getrennt geplant, damit Übersetzungen und größere Schrift nicht das Layout zerstören. Entscheidungen mit mehreren Absätzen brauchen Scrollen, stabilen Fokus und vollständige Lesbarkeit. Ein Autosave darf keine Eingabe verschlucken oder einen Dialog versehentlich bestätigen.

## 6. Zugänglichkeit und Leistungsbewertung

Vorgesehen sind skalierbare Schrift, ausreichender Kontrast, Untertitel mit Sprecherkennzeichnung, getrennte Audiopegel, alternative Farbcodierung und reduzierte Bewegungseffekte. Halten und wiederholtes Tippen sollen nach Möglichkeit umstellbar sein. Strategiepausen und Kampfassistenz sind gesondert zu entscheidende Modusoptionen.

**Vorschlag zur Prüfung:** Zugänglichkeitsoptionen dürfen nicht unbemerkt als schlechtere Ausbildung bewertet werden. Welche Trainingsleistungen unter Assistenz vergleichbar bleiben, muss das Bewertungssystem ausdrücklich definieren. Das bewahrt die gewünschte leistungsabhängige Karriere, ohne eine körperliche Bedienbarriere mit schlechter strategischer Entscheidung gleichzusetzen.

## 7. Geplante Bedienabnahme

Ein Durchlauf vom Hauptmenü bis zur ersten Hütte muss vollständig mit Controller und vollständig mit Maus/Tastatur möglich sein. Große Schrift darf keine wesentliche Auswahl verdecken. Ein blockierter Bauplatz nennt seinen Grund. Perspektivwechsel erhält Zustand; Ausfall des Sprachdienstes blockiert keine Grundaktion. Diese Abnahme ist **noch nicht durchgeführt**.
