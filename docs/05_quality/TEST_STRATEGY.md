# IMPERATHEN – Prüfstrategie für Vorbereitung und spätere Entwicklung

**Stand:** 22.11.2026 · **Status:** Prüfplan. In diesem Arbeitspaket werden Dokumente erstellt; es werden keine Spiel-, Unreal-, Blender- oder Cloudtests ausgeführt. Die historische Mappe enthält ein Testprotokoll für einen kleinen Python-Validator. Dieses belegt nur den damaligen Demonstrationsumfang.

## 1. Nachweisarten auseinanderhalten

| Aussage | Erforderlicher Nachweis |
|---|---|
| Dokument vollständig | Inhalt gelesen, Verweise gültig, Quellen und offene Entscheidungen gekennzeichnet |
| Verhalten spezifiziert | Ausgangszustand, Aktion, erwartete Folgen und Fehlerwege beschrieben |
| Implementiert | Tatsächliche Dateien und zugehöriger Commit vorhanden |
| Funktioniert integriert | Wiederholbarer Ablauf im echten Build mit mehreren beteiligten Systemen |
| Leistung erreicht | Benannte Hardware, Szene, Einstellungen und Messprotokoll |
| Veröffentlichung vorbereitet | Rechte, Abnahmeumfang und tatsächliche Auslieferungsartefakte nachvollziehbar |

Ein entworfenes Testverfahren wird nicht als bestanden markiert. Dass ein Schema syntaktisch gültig ist, beweist weder die Spielbarkeit einer Quest noch die wirtschaftliche Korrektheit ihrer Folgen. Ein generiertes Konzeptbild ist kein Rendernachweis aus Unreal.

## 2. Prüfung der jetzigen Vorproduktion

Die aktuelle Abnahme prüft die Dokumente: keine widersprüchlichen Sofort-Coding-Aufträge, eindeutige Trennung zwischen Vorgabe und Vorschlag, nachvollziehbarer Import aus der Projektmappe, durchgehende Begrifflichkeiten und korrekt gekennzeichnete Lücken. Verweise auf Repository, Branch und PR müssen auf tatsächlich vorhandene Objekte zeigen. Der Status von Sichtbarkeit, Schutzregeln und CI wird gelesen, nicht aus Planungsdokumenten als wirksam angenommen.

Fachliche Prüffragen: Haben alle vier Perspektiven denselben Weltzustand? Ist der Anfang ohne Macht konkret beschrieben? Sind Beziehungen kausal? Sind individuelle Kämpfe mit Formationsbefehlen verbunden? Ist Städtebau wirklich räumlich? Können Geschichten weiterlaufen, ohne freie Weltmutationen zu erlauben? Sind die maximalen Heereszahlen korrekt von lokalen Renderzahlen getrennt? Können unterschiedliche Laufbahnen einschließlich Soldatenleben eigene Enden haben?

## 3. Spätere Testschichten nach Entwicklungsfreigabe

**Domainprüfungen:** Ressourcenbewegung, Auftragserlaubnis, Besitz, Rechte, Ausbildung, Beziehungen und Kohortenübergänge. Technische Befugnis und spielinternes Unrecht sind getrennte Prüfdimensionen. Rekrutierung, Verwundung, Gefangenschaft und Entlassung müssen Arbeitsverfügbarkeit und Dienststatus konsistent ändern. Für jedes System werden hauptsächlich Grenzen, Fehlerfälle und Erhaltungseigenschaften geprüft; Tests sollen nicht nur den aktuellen Code nacherzählen.

**Vertragsprüfungen:** Datenversionen, vollständige ID-Referenzen, Typen, Narrative-Vorschläge, erlaubte Befehle, Assetmanifest und Save-Migration. Falsch erzeugte Inhalte werden gezielt injiziert, damit Ablehnung und Fallback nachweisbar werden.

**Integration:** Dieselbe Hütte in Boden- und Bauansicht, derselbe Soldatenverlust in Schlacht und Kampagne, gegenseitig konsistente Lager und Transportvorgänge. Sequenztests umfassen Absturz, Wiederholung, Zeitbeschleunigung und Distanzwechsel. Eine produzierende Stadt darf beim Wechsel keine Güter oder Zahlungen doppelt buchen; Bauabbruch muss bereits verbrauchte von nur reservierten Materialien trennen.

**Spielprüfung:** Vollständiger Weg vom Start bis zur ersten Ursache-Wirkung-Fortsetzung. Zu prüfen sind Verständlichkeit, Kontrolle, Timing, Lesbarkeit, Controllerbedienung und die Frage, ob eine Entscheidung tatsächlich etwas verändert. Automatische Tests allein beantworten dies nicht.

**Karriere und Reserve:** Ein gespeicherter Abschluss verwirft unvereinbare Fortsetzungen; Kaiserantritt bleibt ein Rollenwechsel. Die Reserveberechnung unterscheidet aktive Zeit, Pausen, Inaktivität und verbrauchten Inhalt. Ungültige und gegenseitig ausschließende Zweige dürfen den Vorrat nicht künstlich erhöhen. Diese Prüfungen werden beim jeweiligen Systemausbau fällig, nicht alle schon beim ersten Hüttenprototyp.

**Langzeit und Leistung:** Erst bei stabiler kleiner Schleife längere Wirtschafts-/Politikläufe, größere Heere und begrenzte Soak-Tests. Weitere Testläufe nur bei konkretem Risiko oder Abnahmeanforderung; kein unbegrenztes Wiederholen grüner Checks.

## 4. Fehlerfälle mit Vorrang

Höchste Priorität erhalten Saveverlust, Ressourcenvermehrung, doppelte Personen/Truppen, unberechtigte Befehle und widersprüchliche dauerhafte Ereignisse. Danach folgen Spielabbrüche, nicht erreichbare Ziele, falsche Storyfolgen und erhebliche Bedien-/Leistungsprobleme. Eine reine Farb- oder Textkorrektur braucht eine passende Sichtprüfung, keine vollständige Neuberechnung der gesamten Welt.

Jeder Defektbericht benennt reproduzierbare Schritte, beobachtetes und erwartetes Verhalten, betroffenen Build sowie Belege. Ein Fix benötigt den Test, der den Fehler tatsächlich aufdeckt, und die unmittelbar betroffenen Regressionen. „Alles getestet“ ohne klaren Umfang gilt nicht als Ergebnis.

## 5. Evidence-Paket einer späteren Lieferung

Enthalten sind Commit/Branch, Build-ID, Engine- und Inhaltsversion, Umgebung, ausgeführte Befehle, Resultate, Messgrenzen und verbliebene Fehler. Logs dürfen keine Zugangsdaten oder privaten Spielerinformationen enthalten. Screenshots nennen ausdrücklich Konzept, Editoransicht oder tatsächlichen Spielbuild. Bei fehlender Engine wird nur der unabhängige Teil als überprüft ausgewiesen.

Die [Abnahmematrix](ACCEPTANCE_MATRIX.md) priorisiert den ersten integrierten Spielabschnitt. Die 92 historischen Prüffälle bleiben ergänzendes Ausgangsmaterial; sie werden nach Schnittstellen und realem Scope zugeordnet, nicht pauschal als notwendige Hürde für jede Textänderung aktiviert.
