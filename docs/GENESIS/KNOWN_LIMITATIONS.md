# GENESIS — bekannte Grenzen

**Quellbasis:** GENESIS fc28428; PRIMA 0f67268 liegt in seiner Vorgängerlinie. Die AP-Titel und -Reihenfolge entsprechen der vom Auftraggeber gelieferten GENESIS-Liste. Die Systemkarte weist für jedes Paket konkrete Pfade aus oder kennzeichnet fehlende dedizierte Runtime-Abdeckung.

## Aussagegrenzen

- Quell- und Testdateien belegen Existenz, nicht erfolgreichen Engine-Lauf, vollständige Funktion oder AP-Abnahme. In dieser Dokumentationsaufgabe wurden keine Gameplay-/Godot-Tests, APK, Android-Geräteprüfung, FPS-/Temperaturmessung oder Vollregression ausgeführt.
- Auf fc28428 wurden die Architekturindex-Generatorprüfungen (14 Checks) und Aktualitätsprüfung ausgeführt; der Index enthielt 273 Runtime-Skripte. Das ist ein deklarativer Inventarnachweis, kein Godot- oder Integrationsnachweis.
- Für einzelne APs existieren nur angrenzende Teilsysteme. Diese werden in SYSTEM_MAP.md ausdrücklich nicht als gleichwertiger Ersatz für fehlende AP-Runtime ausgegeben.
- Es wurde kein CODEOWNERS-, OWNERS- oder MAINTAINERS-Verzeichnis mit menschlichen Zuständigen gefunden.

## AP-bezogene Lücken und Risiken

- **AP02 Universal CharacterCore:** CharacterCore und Komponenten existieren. Die universelle Wiederverwendung über Spieler, Begleiter, Bewohner, Soldaten und Tierfiguren ist durch die benannten Dateien nicht vollständig belegt. Die getrennte Phase-1-Abnahme bleibt maßgeblich.
- **AP04 Anatomie/Gesichter/FacialCore:** Gesichtsdarstellung und Facial-/Dialogansteuerung sind vorhanden; vollständige Anatomie-, Rig- und Morphabdeckung oder ein einheitlicher Core ist nicht nachgewiesen.
- **AP05 InteractionCore:** Weltaktionen, Touchaktionen und domänenspezifische Interaktionen existieren, aber kein allgemeiner Interaktionskern mit einem gemeinsamen Ziel-, Reichweiten- und Berechtigungsvertrag wurde identifiziert.
- **AP06 Hand/Finger/Kontaktphysik:** Gezielte Hand-/Objekt- und Trefferkontaktpfade existieren. Das ist keine vollständige Hand-/Finger-Kinematik oder allgemeine physikalische Kontaktabnahme.
- **AP10 CultureCore:** Stammes-/Völkerdatensätze und Darstellung existieren. Ein allgemeiner Kulturkern mit gemeinsamen Bräuchen, Sprachen und sozialen Regeln ist nicht belegt.
- **AP11 Combat Intelligence:** Nahkampf-KI und taktische Befehlsbausteine existieren; adaptive, koordinierte Kampfentscheidungen als vollständige Runtime sind nicht nachgewiesen.
- **AP15 SiegeCore — Lücke:** Im abgegrenzten Runtime- und Testbaum wurde kein dediziertes Belagerungsmodul/-test gefunden. Feldschlacht- und Taktikpfade ersetzen es nicht.
- **AP23 Autonomous Settlement AI — wesentliche Lücke:** NPC-/Bevölkerungsaktivität existiert, aber sie belegt weder autonome Siedlungsplanung noch eine fortlaufende kollektive Wirtschaft und Off-screen-Entscheidungen.
- **AP27 WitnessCore/Fahndung:** Es gibt einen konkreten Überfall-Ermittlungspfad und Stadtwache. Eine allgemeine Zeugenaussagekette, Fahndung und zugehörige Rechtsfolgen sind nicht als ein Core belegt.
- **AP28 Living Chronicle:** WorldModel hat eine auf 256 Zeit-/Text-Einträge begrenzte Chronik; TribalWorld besitzt eine separate gefilterte Chronik; Storymodule führen Beleglisten. Eine einzige revisionsverknüpfte Ereignisquelle mit stabilen Ursachen/IDs ist nicht nachgewiesen.
- **AP29 StoryCore/113 Hauptabschnitte:** 113 registrierte Hauptmissions-IDs bedeuten nicht 113 fertige oder spielbare Abschnitte. Im Missionsordner liegen JSONs für I-01–I-14; I-00 ist ein Register-Sonderfall ohne gleichnamige JSON, und weitere registrierte IDs sind dort nicht mit einer Missions-JSON belegt. Register, strukturierte Abhängigkeiten und Runtime-Abnahme sind getrennte Aussagen.
- **AP33 Asset Production Pipeline:** Assetregistrierung und einzelne Import-/Geometrieprüfungen existieren. Ein vollständiger herkunfts-, lizenz- und runtimeverknüpfter Produktionsnachweis für alle Assets fehlt.
- **AP34 RenderCore/Android:** Profil- und Android-Diagnosecode sowie Workflows sind vorhanden. Ein physischer Android-Lauf einschließlich Wärme, FPS und Grafikfreigabe ist hier nicht belegt.
- **AP35 Persistence/Lebenszeit/Dynastie:** Speicher-/Lade- und Alterungs-/Lebenswegbausteine existieren. Generationenübergreifende Dynastie, Erbe und vollständige atomare Recovery sind nicht als Gesamtsystem nachgewiesen.
- **AP36 Automation/QA/Technologietransfer:** CI-Einstiege und Indexchecks sind vorhanden. Der Godot-Gesamtlauf und die PRIMA-/Geräteabnahme wurden in dieser Dokumentationsaufgabe nicht ausgeführt; eine vorhandene Übergabedokumentation ersetzt deren Ergebnis nicht.

## Übergabe

AP15 bleibt als dedizierte Lücke markiert; AP23 und AP35 benötigen eine explizite Abgrenzung bzw. Implementierung der fehlenden Kernfunktion. AP28 braucht einen revisionsbewussten Chronikvertrag. AP29 darf die Registerzahl nicht als Lieferumfang ausgeben. Alle Statusänderungen müssen an reale Runtime-Pfade und Prüfungen derselben integrierten Revision gebunden sein. Änderungen in diesem Auftrag beschränkten sich auf SYSTEM_MAP.md und KNOWN_LIMITATIONS.md.
