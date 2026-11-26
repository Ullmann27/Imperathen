# Stammeszivilisationen, Überfallverschwörung und militärische Weiterentwicklung – 26.11.2026

Status: **Vorgabe des Auftraggebers** nach Durchsicht von PR #99 und #100. Die Entscheidungen stehen als D-040 bis D-047 im [Entscheidungsprotokoll](DECISION_LOG.md). Sie ergänzen das Masterhandbuch 3.0 und die Anweisungen [A](GAME_DIRECTION_2026-11-26.md), [B](GAME_DIRECTION_2026-11-26_B.md) und [C](GAME_DIRECTION_2026-11-26_C.md). Die Zuordnung unten ist Planung, kein Umsetzungsnachweis.

## Wortlaut

> IMPERATHEN – GAME DIRECTION
>
> Stammeszivilisationen, Überfallverschwörung und militärische Weiterentwicklung
>
> Die Entwicklungen in PR #99 und #100 entsprechen unserer grundsätzlichen Zielsetzung. Arbeite mit sämtlichen Agents und bisherigen Produktionsaufträgen weiter.
>
> 1. Überfall auf Valdora
>
> Bestätigt: etwa 30 Reiter zunächst ungeklärter Herkunft.
>
> Das entspricht I-10 „Die Nacht der Reiter“. Die Angreifer dürfen nicht automatisch einem bestimmten germanischen Stamm zugeordnet werden.
>
> Die Verbindung zur fiktiven Handelsgesellschaft und zum roten Siegel bleibt Bestandteil der langfristigen Verschwörung. Der Lagervertrag aus I-20 nennt Gaius Varro Serranus, beweist seine Schuld jedoch noch nicht.
>
> Entwickle daraus eine weitreichende kriminalistische und politische Handlung:
>
> - Unterschiedliche Zeugenaussagen.
> - Widersprüchliche Hinweise.
> - Verdächtige Handelsbeziehungen.
> - Persönliche Verbindungen zwischen Charakteren.
> - Unschuldige Verdächtige.
> - Beweismittel und langfristige Konsequenzen.
> - Möglichkeiten zur Aufklärung durch Scharfsinn, Kontakte, Handel, Diplomatie und spätere militärische Laufbahnen.
>
> Der Spieler soll die Zusammenhänge selbst entdecken können. Keine automatische Offenlegung der gesamten Verschwörung.
>
> Schütze die verbindlichen Familien- und Überlebenszweige aus dem Originaldrehbuch.
>
> 2. Germanische Truppen
>
> Speerwerfer werden als reguläre Fernkampfvariante entwickelt. Bogenschützen bleiben als seltenere, quellenkritisch gekennzeichnete Designvariante erhalten.
>
> Erweitere den Truppenkatalog um unterschiedliche Ausbildungs-, Ausrüstungs- und Erfahrungsstufen.
>
> Erstelle sämtliche benötigten Modelle, Waffen, Schilde, Skelette und Animationen mit Blender und geeigneten weiteren Werkzeugen.
>
> Die örtliche Passwache bleibt als fiktives, regionales Aufgebot erhalten.
>
> Keine pauschal identischen germanischen Gruppen. Wohlstand, Handelsbeziehungen, Rohstoffvorkommen und kulturelle Entwicklung bestimmen ihre tatsächlichen militärischen Möglichkeiten.
>
> 3. Kampfwertformel
>
> Die Kampfwertformel aus Seite 79 des Masterhandbuchs wird jetzt verbindlich implementiert.
>
> Schaden = Waffenbasis × Qualität × Kompetenz × Trefferzone × Schutzfaktor.
>
> Berücksichtige zusätzlich Ausdauer, Verletzungen, Waffenverschleiß, Schildposition und tatsächlichen Kontaktzeitpunkt.
>
> Hochwertige Ausrüstung muss spürbare Vorteile bringen, aber niemals fehlende Ausbildung vollständig ersetzen.
>
> Ein erfahrener Krieger mit gewöhnlicher Ausrüstung kann einen unerfahrenen Gegner mit hochwertiger Ausrüstung besiegen.
>
> Verbinde das System mit Shops, Handwerk, militärischen Ernennungen, Inventar und Fähigkeiten.
>
> Verhindere unkontrollierte Multiplikatoren und doppelte Boni. Alle Balanceparameter müssen zentral konfigurierbar und reproduzierbar testbar sein.
>
> 4. Militärische Persönlichkeiten
>
> Führe die individuellen Soldatenidentitäten weiter aus.
>
> Soldaten können Freundschaften schließen, gemeinsame Feldzüge erleben, sich gegenseitig retten, Vertrauen verlieren, befördert werden oder das Heer verlassen.
>
> Ihre Familien, Herkunft und wirtschaftlichen Verhältnisse bleiben Bestandteil der Welt.
>
> Rekrutierung, Verwundung, Genesung und Tod müssen Auswirkungen auf die tatsächlichen Siedlungen haben.
>
> Verknüpfe Erscheinungsvarianten mit appearance_seed und militärischem Rang statt ausschließlich mit dem bisherigen Modellindex.
>
> 5. Eigenständige Zivilisationen
>
> Die weibliche Erbin der fiktiven Gemeinschaft Ravensteg kann erhalten bleiben.
>
> Unterschiedliche Regierungs- und Nachfolgemodelle sollen verschiedene politische Entwicklungen ermöglichen.
>
> Germanische Gruppen sollen sich langfristig zu größeren Siedlungen, Handelsgemeinschaften, Bündnissen oder konkurrierenden Machtzentren entwickeln können.
>
> Die Konfliktdichte wird durch tatsächliche Spieltests bewertet. Vermeide eine künstlich erzwungene Anzahl von Überfällen.
>
> Ältere Kampagnen um 100 n. Chr. bleiben als getrennte historische Spielstände erhalten. Kein nachträgliches Umschreiben auf 58 v. Chr.
>
> 6. Gemeinsamer Weltzustand
>
> Führe den Kalender aus PR #98, die Stammeswelt aus PR #99 und die militärische Simulation aus PR #100 kontrolliert zusammen.
>
> Es darf nur eine autoritative Weltzeit, einen konsistenten Speichervertrag und eindeutige Personenidentitäten geben.
>
> Verhindere doppelte Alterung, doppelte Ressourcenbuchungen, wiederbelebte Soldaten und widersprüchliche Spielstände.
>
> Verknüpfe auch Genesung, Beförderungen, Handel, Reisen, Schlaf und historische Ereignisse mit dieser gemeinsamen Weltzeit.
>
> 7. Leistungsoptimierung
>
> Die Verteilung des wöchentlichen Simulationsticks auf mehrere Frames ist ausdrücklich erwünscht.
>
> Zielwert: ungefähr 2 ms Simulationsarbeit pro Frame als zunächst zu überprüfendes Budget.
>
> Die Aufteilung darf Determinismus, Ereignisreihenfolge und Transaktionskonsistenz nicht gefährden. Speichern und Laden während eines laufenden Simulationsticks müssen abgesichert sein.
>
> Die tatsächliche Leistung auf dem Fold7 ist später gesondert zu messen.
>
> 8. Weitere Produktion
>
> Arbeite weiterhin an hochwertigen Städten, Landschaften, Charakteren, Innenräumen, Ausrüstung, Filmsequenzen, Stimmen und Animationen.
>
> Behalte unsere zehn Zielbilder und das 311-seitige Masterhandbuch als verbindliche Qualitätsorientierung.
>
> Die neuen Systeme dürfen nicht nur im Hintergrund existieren. Der Spieler muss ihre Auswirkungen in der begehbaren Welt tatsächlich sehen und erleben können.
>
> Dokumentiere sämtliche Ergebnisse, überprüfe alle Integrationen und führe die vollständige Regression sowie das Motion-Gate aus.
>
> Keine eigenmächtigen Main-Merges und keine vorgetäuschten Fertigstellungen.
>
> Arbeite selbstständig weiter und denke bei jeder Funktion mindestens drei Entwicklungsebenen voraus.

## Zuordnung (Stand 26.11.2026, 06:45 UTC)

| Punkt | Arbeitspaket | Stand |
|---|---|---|
| 1 Überfallverschwörung | neu: `feat/raid-conspiracy-investigation-20261126` (Ermittlungsstruktur: Zeugen, Widersprüche, Beweise, unschuldige Verdächtige, Aufklärungswege; Schutz der Familien- und Überlebenszweige); Reiter offener Herkunft bereits in #99 | neu beauftragt |
| 2 Germanische Truppen | Simulation und Katalog: #100 (Speerwerfer regulär, Bogner selten und gekennzeichnet, Stufen); Modelle, Waffen, Schilde, Skelette, Animationen: `feat/germanic-warrior-families-20261126` | Folgeauftrag |
| 3 Kampfwertformel | zentrales Modul und Balancekonfiguration in #100; Anschluss Nahkampf Ebene A (`feat/melee-combat-core-20261126`), Shops, Handwerk, Inventar und Fähigkeiten über die Integration | Folgeauftrag |
| 4 Militärische Persönlichkeiten | #100 (Beziehungen, Rettung, Vertrauen, Beförderung, Austritt; `appearance_seed` und Rang für die Darstellung); Auswirkungen auf Siedlungen über den gemeinsamen Weltzustand | Folgeauftrag |
| 5 Zivilisationen | #99 (Regierungs- und Nachfolgemodelle, Wachstum zu Machtzentren, keine erzwungene Überfallzahl); 100-n.-Chr.-Stände bleiben getrennt | Folgeauftrag |
| 6 Gemeinsamer Weltzustand | neu: `integ/world-state-20261126` (Kalender #98 + Stammeswelt #99 + Militär #100: eine Weltzeit, ein Speichervertrag, eindeutige Personen-IDs) | neu beauftragt |
| 7 Leistung | #99 (Wochentick auf Frames verteilt, ca. 2 ms je Frame; Speichern/Laden während eines laufenden Ticks abgesichert) | in Arbeit |
| 8 Produktion und Regression | alle Pakete; vollständige Regression und Motion-Gate auf dem Integrationsstand | laufend |
