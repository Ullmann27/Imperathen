# Folgechat B – Gelebtes Dorf, zusammenhängende Kindheit und römische Welt

Kopiere den folgenden Auftrag vollständig in einen zweiten neuen Chat mit GitHub-Zugriff.

---

Du arbeitest am bestehenden Spiel **IMPERATHEN**, Repository **Ullmann27/Imperathen**, für Heinz. Setze **genau drei tatsächliche Arbeitsagenten** ein und integriere ihre Arbeit selbst. Falls Agenten nicht verfügbar sind, sage das offen. Setze die vorhandene Entwicklung fort; beginne kein fremdes Ersatzprojekt.

## Grundlage und Grenzen

Lies zuerst AGENTS.md, den tatsächlichen aktuellen Branch-/PR-Stand und docs/18_childhood einschließlich der Übergabe des koordinierenden Chats. Dieser baut auf feature/childhood-village-20261123 einen neuen Kindheitsanfang. Historischer Ausgangscommit ist f2900eb86b90b185627dcd490fef550fd0cbed11, alte veröffentlichte APK e1b1c1fb16d63056e4eb80891d84ed75c79b4ed6. Alte Tests zählen nicht als Prüfung deiner Änderungen.

Android ist das erste Ziel, später PC. Öffentliches Repository beibehalten. Eigene Implementierung, Blender, lokale Tests, isolierter Entwicklungsbranch, Draft-PR und geprüfte Android-Testlieferung sind autorisiert. Kein eigenmächtiger Merge nach main, Store-Release, kostenpflichtiger Dienst oder Assetkauf.

Erstelle einen eigenen Branch für Chat B. Chat A bearbeitet Animation, Kampf und Touchsteuerung. Du besitzt Erzählung, Alltagswirtschaft, Dorfwelt, Häuser, Einwohner und historische Einordnung. Teile notwendige Änderungen an gemeinsamen Integrationsdateien klar ab und liefere kleine überprüfbare Patches. Erhalte reale Einwohner-IDs, Speichermigrationen, vorhandene Ressourcenbilanzen und fremde Arbeit.

## Verbindliche Spielrichtung

Der Spieler beginnt mit zwölf Jahren in einem **bereits bestehenden, funktionierenden Dorf**. Eltern, Nachbarn, Häuser, Markt, Landwirtschaft, Handwerk, Handel und Tagesabläufe existieren schon. Er ist kein sofortiger Dorfherrscher und muss nicht als erste Aufgabe aus dem Nichts eine Hütte errichten. Das Dorf soll räumlich und sozial größer werden; zusätzliche Häuser ohne nutzbare Wege und Einwohner erfüllen den Wunsch nicht.

Zuerst lernt der Junge seine Familie, Freunde und Berufe kennen. Kleine Aufträge haben einen nachvollziehbaren Nutzen und Folgen: Essen oder Werkzeug liefern, einen Fehler aufklären, einem Handwerker helfen, eine Lieferung begleiten, Geld verdienen, Vertrauen gewinnen. Mutter, Vater und Schmied benötigen wiederkehrende persönliche Szenen und Erinnerungen. Auch misslungene oder abgelehnte Hilfe braucht sinnvolle Fortsetzung; keine Sackgasse und kein bloßes Belohnungsfarmen.

Später darf er eine beaufsichtigte Kontrollrunde begleiten, beim Schmied üben und zeitweise an einem Wachposten helfen, weil ein Soldat erkrankt ist. Ausrüstung ist sichtbar erworben oder ausgeliehen. Das ist lokale Fiktion, kein unbelegter Nachweis regulären römischen Militärdienstes Zwölfjähriger.

Der erste Überfall kommt erst nach einem zusammenhängenden Dorfabschnitt und aufgebauten Beziehungen: überraschende Nachtsequenz mit ungefähr dreißig Reitern. Daraus entstehen konkrete Folgen für Menschen und Orte, die der Spieler bereits kennt. Keine Überfälle nach bloß zwei Minuten und kein automatischer Sprung von zwölf auf achtzehn, Soldat und Kaiser. Lebensalter, erzählte Tage und Wirtschaftszeit benötigen eine ausdrückliche, gespeicherte Beziehung. Ein langer Lebensweg ist ein Architektur- und Inhaltsziel; keine unendliche fertige Story behaupten.

## Drei Arbeitsagenten

**Agent 1 – Geschichte, Beziehungen und Zeit:** Entwickle und implementiere einen verbundenen Handlungsbogen mit klarer Motivation, Voraussetzungen, Entscheidungen, Folgen und Rückbezügen. Verlängere nicht einfach Timer. Verwende konkrete Szenen, Arbeitsabläufe, Besuchsmöglichkeiten, Tagesabschlüsse und spätere Rückkehr. Auftragsanzeige und Kompass müssen tatsächlich zum richtigen verfügbaren Ziel führen. Tage und Alter schreiten nachvollziehbar fort; Lesen, Pause oder Offlinezeit überspringen keine Kindheit. Überfall und späteres Altern brauchen eindeutige, einmalige Übergänge mit Save/Load-Prüfung.

**Agent 2 – Dorf, Bewohner und Innenräume:** Erweitere die bespielbare Siedlung mit Häusergruppen, Gassen, Markt, Werkstätten und Feldern. Baue nutzbare Innenräume mit passenden Krügen, Geschirr, Vorräten, Schlaf-/Arbeitsplätzen und glaubwürdigen Alltagshandlungen wie Wasser trinken. Sichere Türen, Schwellen, Treppen und Fußböden physisch ab. Niemand versinkt im Boden, steht in der Palisade oder läuft durch andere Menschen. Nutze eindeutige Einwohneridentitäten, kollisionsverträgliche Wege, Tagespläne und verständliche Aufenthaltsorte. Mehrere Rollen derselben Person dürfen keine Doppelgänger erzeugen. Originalmodelle und reproduzierbare Blenderquellen sichern.

**Agent 3 – Geschichte, Wirtschaft, Reiter und Leistung:** Prüfe mit Museums-, wissenschaftlichen oder anderen maßgeblichen Quellen Epoche, Grenzraum, plausible Gegner, Kleidung, Ausrüstung und Münzen. Um 100 n. Chr. gibt es nicht pauschal einen nachgewiesenen „größten Feind“ für jeden Ort. Begründe den gewählten Schauplatz und trenne historische Ausgangslage, fiktiven Dorfüberfall und spätere Alternativgeschichte. Prüfe Dakien/Donau gegenüber Parthien/Osten, bevor du Angreifer festlegst. Denare und andere Münzen korrekt einordnen; Gold nicht ohne Grund zur alltäglichen Kleingeldwährung machen. Baue den Handel in die tatsächliche Bestands-/Geldbilanz ein. Plane und implementiere Reiter mit eigenen Pferden, Varianten, ausreichendem Abstand und nachvollziehbarer Bewegung. Eine vorgerenderte Sequenz muss zum Spielstand passen; echtes Engine-Material und Konzeptbilder klar unterscheiden.

## Technische und inhaltliche Abnahme

Prüfe eine vollständige neue Partie, einen übernommenen alten Spielstand und Speichern/Neustart mitten in Auftrag, Tagesabschluss und Überfallvorbereitung. Keine doppelte Bezahlung, verschwundenen Pflichtpersonen, unerreichbaren Ziele oder irreversible Fortschrittsfehler. Prüfe alternative Auftragsausgänge. Bewegungs-/Kampfänderungen von Chat A über die abgesprochenen Schnittstellen integrieren.

Nutze Offline-Berechnung für passende statische Arbeit: vorbereitete Materialien, Texturen, Licht/AO soweit vom Renderer unterstützt, wiederverwendete Geometrie, LODs und räumlich begrenzte Aktivität. Server-Rendering wäre ein eigener kosten- und verbindungsabhängiger Ansatz und darf nicht stillschweigend eingeführt werden. Vergleiche identische Szenen; behaupte keine geringere Gerätetemperatur ohne Messung.

Liefere tatsächlichen Code, verständliche Quest-/Zeit-/Identitätsverträge, Szenen und Assets samt Herkunft, reale Prüfergebnisse und Bilder, einen Draft-PR und eine präzise Übergabe. Benenne, welche Reiter-, Innenraum-, Alltags- und Storyfunktionen wirklich spielbar sind und welche offen bleiben. Übernimm keine fremden Spielinhalte. Arbeite bis zu einem zusammenhängenden überprüfbaren Ergebnis.

