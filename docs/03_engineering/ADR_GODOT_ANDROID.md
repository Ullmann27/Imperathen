# Godot 4.7.2 für die Android- und Desktop-Linie

Entscheidung vom 22. November 2026 für die laufende Entwicklungsphase. Android ARM64 verwendet die offizielle Godot-Version 4.7.2.stable.official.ed1daf0bf und die zugehörigen Exportvorlagen. Dieselbe Projektdatei, dieselben GDScript-Regeln und das geprüfte JSON-Speicherformat bilden die Desktop-Linie. Für den ersten Gerätevergleich gilt der Compatibility-Renderer.

| Kandidat | Tatsächliche Grundlage | Konsequenz |
| --- | --- | --- |
| Godot 4.7.2 | Dorf, Kamerawechsel, Touch, korrupte Spielstände und Kämpfe durch Engine-Tests geprüft. Der zusammengeführte Dorfstand ebcf2d8 liefert eine signierte ARM64-APK. | Produktive Linie unter `prototype/`. Ein Android-spezifischer Controller darf ausschließlich die gemeinsamen Spielbefehle aufrufen. |
| Unreal aus #19 | Projektbeschreibung, Targets, native Menüquellen und separat kompilierte C++-Regeln liegen vor. Für diese Quellen gibt es keinen ausgeführten Engine- oder Android-Build. | Technische Referenz unter `game/Imperathen/`. Portierung erst nach einem Vergleich derselben Szene auf demselben Gerät mit Bildzeiten, Speicher, Paketgröße, Temperatur und nachgewiesenem Migrationspfad für Spielstände. |
| Webvorschau | Lokal ausführbarer Einstieg mit eigenem demobezogenen Browser-Speicher und Regressionen. | Weiterhin als Referenz für den Einstieg nutzbar. |

Die Vorproduktion stammt aus #1, der Einstieg aus #19, der persistent gespielte Dorfabschnitt aus #20 und das Originalgrafikpaket samt Schauraum aus #21. Die vier Git-Historien sind Vorfahren dieses Branches.

Die vom Nutzer nachgereichte Projektbibel enthält das Master-GDD in Teil I. Ihre Kapitel 6, 7, 12 und 14 bestimmen Rollen, Maßstab, Animation und die durchgehende Spielprüfung. Der bestätigte Spielname ist IMPERATHEN. Das bereitgestellte PDF hat SHA-256 `ea4029dd922e3d5472e89d346560431367475e31c355d0cbca4f0d3ed9f55018`. Der Hash weicht vom früher inventarisierten PDF ab. Die vollständige ZIP wurde für diese Integration nicht mitgeliefert. Für deren zusätzliche Dateien liegen das Quelleninventar, der frühere Audit und die Abnahmematrix im Repository vor.
