# IMPERATHEN – Abnahmematrix der grundlegenden Systeme

**Stand:** 22.11.2026 · **Status aller nachstehenden Gameplayfälle:** spezifiziert, nicht implementiert und nicht ausgeführt. Die Matrix legt einen späteren Nachweisumfang fest und startet keine Programmierung.

## 1. Dokumentationsfreigabe in der jetzigen Phase

Eine vollständige Vorbereitung benötigt einen klaren Spieleinstieg, die Abhängigkeiten der Perspektiven, Welt-/Zeitregeln, Narrative-Vertrag, technische offene Entscheidungen und nachvollziehbare Quellen. Die fertigen Pläne müssen außerdem die aktuelle Anweisung „noch keine Spielprogrammierung“ bewahren. Rechte- und Namensprüfung laufen getrennt; ihr offener Status macht einen Architekturentwurf unter gekennzeichnetem Arbeitstitel nicht ungültig. Das Repository bleibt nach ausdrücklicher Nutzervorgabe öffentlich; die fachlichen Vorbereitungsdokumente sind dafür vorgesehen. Personenbezogene Daten und Zugangsschlüssel werden nicht übernommen.

## 2. Wesentliche spätere Akzeptanzfälle

| ID | Ausgang und Aktion | Erwartetes Ergebnis |
|---|---|---|
| AC-01 | Sechs Holz sind an einer Quelle vorhanden; Spieler sammelt drei. | Quelle minus drei, Inventar plus drei, genau ein bestätigtes Ereignis. |
| AC-02 | Dieselbe Sammelanfrage mit identischer Befehls-ID erneut senden. | Ursprüngliches Resultat, keine zweite Entnahme oder Belohnung. |
| AC-03 | Zwölf Holz; eine Auswahl verlangt zweimal acht. | Ganze Auswahl ungültig, Bestände vollständig unverändert. |
| AC-04 | Zwei alternative Antworten verlangen jeweils acht der zwölf Holz. | Jede Option einzeln möglich; nur gewählte Option wird gebucht. |
| AC-05 | Zwei Bauaufträge konkurrieren um denselben freien Bestand. | Reservierungen verhindern Doppelverwendung; Grund ist sichtbar. |
| AC-06 | Zu steilen/besetzten Bauplatz oder fremdes Grundstück ohne ausreichendes Bau-/Nutzungsrecht wählen. | Begründete Ablehnung ohne Materialverlust; illegales Bauen bleibt ein offener späterer Regelpfad. |
| AC-07 | Gültige Hütte errichten und beide Kameramodi besuchen. | Dieselbe ID, Lage, Baustufe, Vorräte und Zugangswege. |
| AC-08 | Holztransport zwischen Lager und Baustelle unterbrechen. | Ware ist genau einem Ort/Transportzustand zugeordnet. |
| AC-09 | Hütte beschädigen, speichern, laden und Weltkarte öffnen. | Schaden und wirtschaftliche Folge bleiben erhalten. |
| AC-10 | Savevorgang abbrechen; anschließend wieder starten. | Letzter konsistenter Stand nutzbar, kein gemischter Zustand. |
| AC-11 | Älteren Save auf neues Schema migrieren. | Geprüfte Migration auf Kopie; Original bei Fehler erhalten. |
| AC-12 | Marcus helfen beziehungsweise ablehnen. | Belegte, unterschiedliche Beziehung; passende spätere Fortsetzung. |
| AC-13 | Marcus stirbt vor Aktivierung einer vorbereiteten Begegnung. | Neue Vorprüfung verwirft/ersetzt den Plan; keine Wiederbelebung. |
| AC-14 | NPC ohne Wissensquelle nach geheimem Verrat fragen. | Kein unerklärlicher Zugriff auf globales Geheimwissen. |
| AC-15 | Planner fordert erfundene Stadt oder nicht vorhandenes Asset. | Plan zurückgewiesen oder regelgebunden ersetzt. |
| AC-16 | Planner schlägt fremden Code oder unzulässige Befehle vor. | Keine Ausführung, strukturelle Ablehnung und sicherer Fallback. |
| AC-17 | Soldat versucht die gesamte Armee ohne Befugnis zu befehligen. | Befehlsumfang auf tatsächliche Rolle beschränkt. |
| AC-18 | Nahkampfschlag verfehlt, danach trifft ein zweiter. | Nur räumlich/zeitlich gültiger Treffer verursacht Schaden. |
| AC-19 | Fünf Kämpfer fallen; Kohorte wird fern und wieder nah geladen. | Verlust bleibt genau fünf, benannte Figuren bleiben identisch. |
| AC-20 | Gleiches Schlachtergebnis mehrfach an die Kampagne liefern. | Nur eine Verlust-/Beute-/Eigentumsbuchung. |
| AC-21 | Lange Sitzung überschreitet die Storyreserve, Dienst ist offline. | Vorhandene Weltaktivitäten bleiben spielbar; kein verlorener Save. |
| AC-22 | Ausschließende/ungültige Zweige, lange Pausen und wenig tatsächlicher Storyverbrauch. | Nur gültige kompatible Reserve zählen; aktive Zeit und Inhaltsverbrauch von Pausen/Inaktivität trennen. |
| AC-23 | Direktkampf, Bauen und Karte nur mit Controller benutzen. | Alle wesentlichen Funktionen und Texte erreichbar. |
| AC-24 | Gleiche Szene mit anderer Detailstufe messen. | Mechanik gleich; Darstellungszahl, Frametimes und Grenzen protokolliert. |
| AC-25 | Arbeiter rekrutieren, später verwunden, gefangen nehmen und militärisch entlassen. | Dienst-, Orts- und Arbeitsstatus konsistent; kein gleichzeitiger voller Arbeits-/Heeresbeitrag. Entlassung bedeutet keine automatische Heilung oder Rückkehr. |
| AC-26 | Produzierende Stadt fern und wieder nah berechnen. | Prozessstand erhalten; keine doppelte Ware, Lohn-, Handels- oder Steuerzahlung. |
| AC-27 | Bau nach Lieferung und teilweisem Verbrauch abbrechen. | Freie Reserven lösen; Erstattung nach Istzustand, keine vollständige Rückbuchung verbauter Mengen oder geleisteter Arbeit. |
| AC-28 | Endgültigen Karriereabschluss beziehungsweise Kaiserantritt speichern und laden. | Abschluss bleibt terminal und verwirft unvereinbare Reserve; Kaiserrolle setzt den Lebensbogen fort. |

## 3. Zuordnung der Nachweise

AC-01 bis AC-05 und AC-19/20 benötigen später maschinenprüfbare Zustandsbilanzen. AC-06 bis AC-09 brauchen zusätzlich echte Szenenprüfung. AC-10/11 verlangen Fehler- und Wiederherstellungstests. AC-12 bis AC-16 verbinden Vertragsprüfung mit menschlicher Bewertung der Kausalität. AC-17/18 und AC-23 brauchen Bedienungs- und Kampfaufnahmen; AC-24 einen reproduzierbaren Benchmark. Es reicht nicht, für alle Fälle denselben Screenshot oder einen allgemeinen grünen Testzähler anzugeben.

AC-25 bis AC-27 benötigen Zustandsbilanzen über mehrere Prozessschritte; AC-28 einen gespeicherten Abschluss- beziehungsweise Rollenwechsel. AC-28 wird erst beim Karriereausbau fällig.

## 4. Fertiger erster Spielabschnitt

Eine spätere Abnahme betrachtet eine durchgehende Sitzung: neues Leben, Material sammeln, Hütte bauen, Marcus begegnen, Ausbildung erleben, kleine Einheit oder direkte Verteidigung steuern, Konsequenz speichern und nach erneutem Laden eine dazu passende Folge erleben. Kommandorechte und Altersübergang müssen dabei zur Rolle passen. Kindheitsphase und erwachsener bewaffneter Truppführer dürfen nicht unbemerkt dieselbe unveränderte Szene sein.

Der Abschnitt wird mit mindestens zwei gegensätzlichen Entscheidungen geprüft. Unterschiede müssen im Weltzustand und im spielbaren Fortgang erkennbar sein, nicht nur in einem anders formulierten Absatz. Höhere Karrierepfade, riesige Heere und Kaiserherrschaft sind Ausbauziele; sie werden durch das Bestehen dieses kleinen Abschnitts nicht als bereits umgesetzt ausgewiesen.

**Bezug:** [Prüfstrategie](TEST_STRATEGY.md), [Weltzustand](../03_engineering/WORLD_STATE_AND_TIME_CONTRACT.md), [Narrative-Vertrag](../03_engineering/NARRATIVE_CONTRACT.md).
