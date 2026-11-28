# GENESIS: Erweiterungen ohne zweite Spielwelt
**Meilenstein 1:** ein gemeinsamer, synchroner Transaktionsvertrag für Missionsobjekte und die dazugehörigen Ereignisse. Es handelt sich nicht um eine neue Game Engine neben Godot und nicht um eine fertige offene Welt. Die Produktbasis ist der explizit angebundene PRIMA-Draft #213, nicht main oder dessen erster Kontrollpunkt. Ein grüner Lauf allein ist keine Produktionsfreigabe.

1. [PRIMA-Spielstrecke](../44_integration/OPERATION_PRIMA.md) und [Systemkarte](SYSTEM_MAP.md): Wo lebt der Zustand?
2. [Datenvertrag](DATA_CONTRACTS.md): Was darf ein Command in einem Schritt ändern?
3. [Missionsmatrix](MISSION_DEPENDENCIES.md) und [Produktionsrezepte](PRODUCTION_COOKBOOK.md): Welche vorhandenen Daten und Werkzeuge lassen sich verwenden?
4. [Prüfanleitung](TEST_AND_BUILD_GUIDE.md), [Freigabekriterien](RELEASE_GATES.md) und [Übergabe](HANDOVER_TO_STANDARD_MODELS.md).

## Quellen und Historie
Der GitHub-Zweig enthält die Spielentwicklung, main absichtlich nur die Gründungs-README. Die lokale Git-Historie ist flach begrenzt: aus dem PRIMA-Basiszweig sind 847 Commits erreichbar. Die Dokumente zu Android-Lieferungen, Editor-/Blender-Herkunft und den Entscheidungen sind historische Nachweise, keine neuen Testergebnisse. Der zweite öffentliche Projektendpunkt (GitLab 89577832) war lesbar: 213 Branches und ein offener MR (!201) beim Abgleich. Er ist kein zusätzlicher Ausgabezweig. Die Kette #208/#209 → #210 → #211 → #213 unterscheidet Modell-/Bewegungskandidaten, gemeinsamen Unterbau, Ausrüstung und Produktionsintegration.

Originalmappe, 13 ursprüngliche Konzeptbilder als vollständige Mappe und vier Master-DOCX standen nicht als private Anhänge zur Verfügung. Das [Inhalts-/Hashregister](../09_sources/SOURCE_INVENTORY.csv), der [Quellenaudit](../00_governance/SOURCE_AUDIT.md), [Narrativvertrag](../03_engineering/NARRATIVE_CONTRACT.md), [Zeit-/Weltvertrag](../03_engineering/WORLD_STATE_AND_TIME_CONTRACT.md) und die installierten Missionen sind keine Ersatz-Drehbücher. Keine Volltextlektüre oder Rekonstruktion fehlender kanonischer Konsequenzen behaupten. Nach privater Bereitstellung mit dem vorhandenen Quellenprüfer abgleichen; keine Originale ins öffentliche Repository kopieren.

**Noch privat benötigt:** `IRON_BANNERS_Projektmappe.zip` mit `IRON_BANNERS_Projektbibel.pdf`, DOCX-/Markdown-Fassung, GDD, 13 Bildtafeln, Technik- und QA-Anlagen; außerdem `IMPERATHEN_Drehbuch_Band_1_DAS_FEUER_VON_VALDORA(1).docx`, `IMPERATHEN_Drehbuch_Band_2_DER_ADLER_UND_DER_RUBIKON(1).docx`, `IMPERATHEN_Drehbuch_Band_3_DIE_IDEN(1).docx` und `IMPERATHEN_Drehbuch_Band_4_DAS_REICH_DANACH(1).docx`. Ein „Ok“ bestätigt die Anfrage, ist aber kein zugestellter Anhang. Bis dahin bleiben Ableitungen aus nicht vorliegenden Originalpassagen gesperrt.

[Gemessene APK-Größe, striktes Bewegungs-Gate und Sprachlücken](RELEASE_DIAGNOSTICS.md). Für neue Arbeit ist die Git-Abstammung des geprüften HEAD maßgeblich, nicht eine in alten Testberichten genannte Zweigspitze.
