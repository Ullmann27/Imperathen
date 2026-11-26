# IMPERATHEN – Meshy-Asset-Ledger

Stand: 23. November 2026. Grundlage ist der aktuelle Bewegungs-/Kampfzweig
`feature/chat-a-movement-combat-20261123` bei
`a87e3918872ad2aa76aa2359f810658b4821ca0b`.

Dieses Ledger protokolliert Meshy-Quellen. **Ein erfolgreicher Meshy-Task ist
noch kein im Spiel integriertes Asset.** Die GLB-Binärdateien konnten in dieser
Sitzung nicht aus den signierten Meshy-Download-URLs in das Repository
übertragen werden. Deshalb bleiben alle Einträge im Manifest
`runtime_ready=false`, bis Import und Zielrenderer tatsächlich geprüft sind.

## Fertige Waffen

| Stable ID | Meshy Final-Task | Stand |
| --- | --- | --- |
| `weap_roman_gladius_pompeii` | `01a208f9-7d6d-7433-81f3-b939a32df26c` | texturiert |
| `weap_roman_spatha` | `01a20901-f1c3-76c5-ab9f-81ad2a6c0250` | texturiert |
| `weap_roman_pugio` | `01a2091d-c4d6-7211-bd16-ce6cf3ba04d6` | texturiert |
| `weap_roman_pilum` | `01a20902-102b-764b-b107-03a81497c2e1` | texturiert |
| `weap_germanic_spear` | `01a20902-324a-77d5-9f1c-fa7d95ab11fc` | texturiert |
| `weap_germanic_hand_axe` | `01a2091d-a272-7367-a22f-848695eccb27` | texturiert |
| `weap_roman_aux_bow` | `01a2091d-8656-76a6-bb5d-ed0e061dddb6` | texturiert |
| `weap_crossbow_concept` | `01a2091d-61c4-7096-8831-4b411f591505` | texturiert; Forschungs-/Spielkonzept, **keine** behauptete archäologische Replik |

## Fertige Truppentypen

Die sieben neuen Figuren wurden für Animation als neutrale A-Pose mit
Smart-Topology und Zielwert 28.000 Faces erzeugt. Die Finaltexturen wurden als
4K-PBR gerechnet. Ein Meshy-Modell besitzt dadurch noch **kein bestätigtes
Spielrig**.

| Stable ID | Meshy Final-Task |
| --- | --- |
| `unit_roman_heavy_cavalry_rider` | `01a20922-0cce-7353-80a4-3d06dead3be3` |
| `unit_roman_light_cavalry_rider` | `01a20922-1d22-777f-b822-865f6b994efe` |
| `unit_roman_aux_archer` | `01a20922-2cd0-7548-8505-5e2a143809ac` |
| `unit_germanic_axe_fighter` | `01a20922-3da8-7164-b3ef-0d60b4c04729` |
| `unit_germanic_light_spearman` | `01a20922-4d17-70f5-89b9-7a658e7dae82` |
| `unit_roman_signifer` | `01a20922-65cb-74a8-9cc1-7479aec8622b` |
| `unit_germanic_mounted_retainer` | `01a20922-790b-77dc-aa63-9cee4c47c625` |

## Fertige modulare Ausrüstung

| Stable ID | Meshy Final-Task |
| --- | --- |
| `gear_roman_scutum` | `01a20922-872f-701d-a442-b55d0673a9b3` |
| `gear_roman_cavalry_oval_shield` | `01a20922-9c05-77b1-9b22-42ac731456e2` |
| `gear_germanic_round_shield` | `01a20922-ab81-74fa-9139-87adebe3a5d9` |
| `gear_roman_cavalry_lance` | `01a20922-ba31-769d-837c-6303249958a9` |
| `gear_sling` | `01a20924-ac18-7424-a1fe-b05e3f13aaf9` |
| `gear_roman_signum` | `01a20924-b3e4-7055-bc44-a7d05160d252` |
| `gear_roman_four_horn_saddle` | `01a20924-cc2d-73ae-aeb5-2e8dbcdf2739` |

Der römische Sattel ist ausdrücklich ohne Steigbügel angelegt. Waffen und
Schilde bleiben getrennte Props, damit Inventar, Ausrüstung, Animation und
Beschädigung nicht an eine einzige starre Figur gebunden werden.

## Ressourcen

| Stable ID | Meshy-Task | Stand |
| --- | --- | --- |
| `resource_iron_ore` | `01a20902-4f21-73b9-a775-2770650563fd` | texturiert |
| `resource_firewood` | `01a20924-e498-76cf-ad2f-66e95a923d97` | 4K-PBR |
| `resource_clay` | `01a20924-f606-7041-b3ab-2e80125567f0` | 4K-PBR |
| `resource_limestone` | `01a20925-0424-70bc-bf56-271a644fd6f9` | 4K-PBR |
| `resource_copper_ore` | `01a20926-b179-7152-b822-7eceeb32d867` | 4K-PBR |
| `resource_galena` | Preview `01a20926-3f65-721f-9f63-6f5a42644d73` | Geometrie fertig, Textur offen |

Für Galena/Blei-Silber wurde die Finaltextur nicht erzeugt, weil das verfügbare
Meshy-Guthaben für diesen Schritt nicht mehr ausreichte. Der fehlgeschlagene
Refine-Versuch erzeugte laut Meshy **kein** neues Modell.

## Frühere Meshy-Ausgaben ohne sicher zugeordneten Task

Aus der vorherigen Produktionsrunde sind u. a. Legionär, germanischer Kämpfer,
Sextus, Pferd, Kettenhemdsoldat, Gladiator und Gesichtsvarianten gemeldet. In
diesem Fortsetzungsfenster liegen dafür keine belastbaren Einzel-Task-IDs vor.
Sie werden deshalb im Manifest nur als `legacy_generated_unmapped` geführt.
Es werden keine IDs geraten.

## Nicht verwechseln

Parallel tauchten in Meshy weitere Tasks auf, darunter eine Caesar-Vorschau und
eine zusätzliche schwere-Kavallerie-Finalisierung. Diese wurden in dieser
Arbeitslinie nicht als kanonische Quelle angelegt und werden bewusst nicht mit
den oben protokollierten IDs vermischt.

Maschinenlesbare Quelle: `prototype/assets/meshy/manifest.json`.

## Paralleler historischer Kandidat

Meshy-Preview `01a20926-85e5-70be-a646-d57d40c474d0` ist eine untexturierte
Caesar-A-Pose. Sie wird als `historical_caesar_58bce_candidate` gesichert,
aber **nicht** unter die 28 kanonischen Assets gezählt. Vor einer Übernahme sind
historischer Referenzvergleich, Texturpass, Rigging und echte Bildprüfung nötig.

## Kanonisches Kavalleriepferd

`mount_ancient_cavalry_horse` verwendet die Meshy-Preview
`01a20934-c44a-77ea-95a7-5e2c2c804d5e`. Die 28k-Smart-Topology-Geometrie
ist fertig und texturierbar, aber mit dem verbliebenen Guthaben nicht mehr
texturiert worden. Sie ist deshalb kanonisch registriert, bleibt jedoch
`geometry_ready_untextured`, `rigging_required=true` und `runtime_ready=false`.

Damit umfasst der kanonische Bestand **29 Assets**: 27 texturierte Finals sowie
zwei untexturierte Geometrien (Galena und Kavalleriepferd). Die Kavallerie wird
nicht als verschmolzenes Modell behandelt; Reiter, Pferd, Vierhornsattel,
Schild und Waffen sind getrennte Komponenten in `loadouts.json`.

## Bestandsaufnahme des Meshy-Kontos vom 26. November 2026 (D-058)

Quelle sind die beiden lesenden Listenabrufe `GET /openapi/v2/text-to-3d` und `GET /openapi/v1/image-to-3d` (alle Seiten). Es wurde kein Auftrag erzeugt, verfeinert, neu vernetzt, texturiert oder geriggt; verbrauchte Credits dieser Arbeit: 0. Die vollständige maschinenlesbare Liste mit Prompts, Zeitstempeln, Prüfsummen und Bildgrößen steht in `meshy-task-inventory.json`. Signierte Download-Adressen werden nicht gespeichert.

Das Konto enthält **58 Text-zu-3D-Aufträge** (30 Vorschauen, 28 texturierte Finals) und **43 Bild-zu-3D-Aufträge**. 71 Aufträge gehören zu IMPERATHEN. 30 Bild-zu-3D-Aufträge (Tierfiguren im Rennanzug, Fahrzeugkarosserien, Spielzeugrequisiten und zwei bereits abgelaufene Einträge) gehören zu einem anderen Projekt und werden hier nur gezählt.

**Ablauf:** Bild-zu-3D-Ergebnisse laufen drei Tage nach Fertigstellung ab. Die sechs früheren Figuren und das texturierte Pferd vom 23.11. waren nur noch bis 26.11.2026 gegen 15:15–15:45 UTC abrufbar, Tempel, Brustpanzer und Caesar bis 28.11.2026. Alle wurden am 26.11. heruntergeladen und in `lock.json` mit SHA-256 festgehalten. Text-zu-3D-Ergebnisse tragen kein Ablaufdatum.

### Text-zu-3D

| Auftrag | Inhalt | Art | Datum (UTC) | Dreiecke | Texturen | Zuordnung |
| --- | --- | --- | --- | ---: | --- | --- |
| `01a208f7-87f2-71bb-9765-7e5682142993` | Roman gladius of the Pompeii pattern | preview | 11-23 15:12 | – | nicht geladen | `weap_roman_gladius_pompeii` · Vorschau zum Final |
| `01a208f9-7d6d-7433-81f3-b939a32df26c` | Roman gladius of the Pompeii pattern | refine | 11-23 15:15 | 2084 | 2048×2048 PBR | `weap_roman_gladius_pompeii` · kanonisches Final |
| `01a208fc-d9bb-73ea-b046-04e965956c37` | practical Roman cavalry spatha sword circa AD100 | preview | 11-23 15:18 | – | nicht geladen | `weap_roman_spatha` · Vorschau zum Final |
| `01a208fc-f450-748b-a4c0-c5f9ac954c1d` | Roman pugio dagger circa AD100 | preview | 11-23 15:18 | – | nicht geladen | `weap_roman_pugio` · Vorschau zum Final |
| `01a208fd-1033-7116-a97c-27ac88a0a728` | Roman pilum javelin circa AD100 | preview | 11-23 15:18 | – | nicht geladen | `weap_roman_pilum` · Vorschau zum Final |
| `01a208fd-2c10-7654-9968-8ef13dc1d475` | practical early first-century AD European iron-tipped spear | preview | 11-23 15:19 | – | nicht geladen | `weap_germanic_spear` · Vorschau zum Final |
| `01a208ff-8bc6-7133-9a34-31184e75e3ce` | practical compact early European iron hand axe | preview | 11-23 15:21 | – | nicht geladen | `weap_germanic_hand_axe` · Vorschau zum Final |
| `01a208ff-a9a8-717d-9928-fea573ee555a` | compact ancient composite recurve bow for a Roman auxiliary archer | preview | 11-23 15:21 | – | nicht geladen | `weap_roman_aux_bow` · Vorschau zum Final |
| `01a208ff-cb33-746f-9e56-0859c8827458` | simple historical-style wooden crossbow concept | preview | 11-23 15:21 | – | nicht geladen | `weap_crossbow_concept` · Vorschau zum Final |
| `01a208ff-eb64-7106-b014-ca149feb9102` | natural iron-bearing rock outcrop for a realistic game landscape | preview | 11-23 15:22 | – | nicht geladen | `resource_iron_ore` · Vorschau zum Final |
| `01a20901-f1c3-76c5-ab9f-81ad2a6c0250` | practical Roman cavalry spatha sword circa AD100 | refine | 11-23 15:24 | 2154 | 2048×2048 PBR | `weap_roman_spatha` · kanonisches Final |
| `01a20902-102b-764b-b107-03a81497c2e1` | Roman pilum javelin circa AD100 | refine | 11-23 15:24 | 1390 | 2048×2048 PBR | `weap_roman_pilum` · kanonisches Final |
| `01a20902-324a-77d5-9f1c-fa7d95ab11fc` | practical early first-century AD European iron-tipped spear | refine | 11-23 15:24 | 1402 | 2048×2048 PBR | `weap_germanic_spear` · kanonisches Final |
| `01a20902-4f21-73b9-a775-2770650563fd` | natural iron-bearing rock outcrop for a realistic game landscape | refine | 11-23 15:24 | 2524 | 2048×2048 PBR | `resource_iron_ore` · kanonisches Final |
| `01a2091d-61c4-7096-8831-4b411f591505` | simple historical-style wooden crossbow concept | refine | 11-23 15:54 | 2588 | 2048×2048 PBR | `weap_crossbow_concept` · kanonisches Final |
| `01a2091d-8656-76a6-bb5d-ed0e061dddb6` | compact ancient composite recurve bow for a Roman auxiliary archer | refine | 11-23 15:54 | 1819 | 2048×2048 PBR | `weap_roman_aux_bow` · kanonisches Final |
| `01a2091d-a272-7367-a22f-848695eccb27` | practical compact early European iron hand axe | refine | 11-23 15:54 | 1860 | 2048×2048 PBR | `weap_germanic_hand_axe` · kanonisches Final |
| `01a2091d-c4d6-7211-bd16-ce6cf3ba04d6` | Roman pugio dagger circa AD100 | refine | 11-23 15:54 | 1852 | 2048×2048 PBR | `weap_roman_pugio` · kanonisches Final |
| `01a2091f-9b06-7524-904a-8b453bbd057f` | full-body Roman heavy cavalry rider circa AD 100 | preview | 11-23 15:56 | – | nicht geladen | `unit_roman_heavy_cavalry_rider` · Vorschau zum Final |
| `01a2091f-ac3e-7185-b5cc-bd35aa5eefc4` | full-body Roman auxiliary light cavalry rider circa AD 100 | preview | 11-23 15:56 | – | nicht geladen | `unit_roman_light_cavalry_rider` · Vorschau zum Final |
| `01a2091f-bdae-76b8-9b03-f3396166de10` | full-body Roman auxiliary archer circa AD 100 | preview | 11-23 15:56 | – | nicht geladen | `unit_roman_aux_archer` · Vorschau zum Final |
| `01a2091f-cf92-72cb-8fcd-237fd23e6927` | full-body Germanic axe fighter circa AD 100 | preview | 11-23 15:56 | – | nicht geladen | `unit_germanic_axe_fighter` · Vorschau zum Final |
| `01a2091f-e310-7255-9783-54110690e55e` | full-body Germanic light spearman circa AD 100 | preview | 11-23 15:56 | – | nicht geladen | `unit_germanic_light_spearman` · Vorschau zum Final |
| `01a2091f-f20e-76ae-baa7-83f0e604bbf2` | full-body Roman signifer standard bearer circa AD 100 | preview | 11-23 15:56 | – | nicht geladen | `unit_roman_signifer` · Vorschau zum Final |
| `01a2091f-ffb8-7033-bc53-f7a3e307e028` | full-body elite Germanic mounted retainer circa AD 100 | preview | 11-23 15:57 | – | nicht geladen | `unit_germanic_mounted_retainer` · Vorschau zum Final |
| `01a20920-772d-7175-b422-b72e14a5a269` | Roman legionary scutum circa AD 100 as one isolated prop | preview | 11-23 15:57 | – | nicht geladen | `gear_roman_scutum` · Vorschau zum Final |
| `01a20920-8795-70b1-8fab-88ee2b50b3e6` | Roman cavalry oval shield circa AD 100 | preview | 11-23 15:57 | – | nicht geladen | `gear_roman_cavalry_oval_shield` · Vorschau zum Final |
| `01a20920-9962-778f-a6c8-41a757190433` | Germanic round wooden shield circa AD 100 | preview | 11-23 15:57 | – | nicht geladen | `gear_germanic_round_shield` · Vorschau zum Final |
| `01a20920-a798-7288-8c0c-df88b4ab0037` | Roman cavalry lance circa AD 100 | preview | 11-23 15:57 | – | nicht geladen | `gear_roman_cavalry_lance` · Vorschau zum Final |
| `01a20920-b693-77dd-93d9-601b98758d46` | ancient leather sling circa AD 100 | preview | 11-23 15:57 | – | nicht geladen | `gear_sling` · Vorschau zum Final |
| `01a20920-c4bc-70d3-b11a-00a2363126e0` | Roman signum military standard circa AD 100 | preview | 11-23 15:57 | – | nicht geladen | `gear_roman_signum` · Vorschau zum Final |
| `01a20920-d47d-7741-9095-c72a2060527e` | Roman four-horn cavalry saddle circa AD 100 | preview | 11-23 15:57 | – | nicht geladen | `gear_roman_four_horn_saddle` · Vorschau zum Final |
| `01a20920-e4d9-7542-a5f2-1cbce8db4d2d` | resource prop: stacked split firewood and rough timber logs for a Roma | preview | 11-23 15:58 | – | nicht geladen | `resource_firewood` · Vorschau zum Final |
| `01a20920-f729-70f1-8af5-f88852d2c1b8` | clay resource deposit for an ancient Roman frontier landscape | preview | 11-23 15:58 | – | nicht geladen | `resource_clay` · Vorschau zum Final |
| `01a20921-07b3-72bc-a515-848d7d18c612` | limestone building-stone resource outcrop for a Roman frontier landsca | preview | 11-23 15:58 | – | nicht geladen | `resource_limestone` · Vorschau zum Final |
| `01a20922-0cce-7353-80a4-3d06dead3be3` | full-body Roman heavy cavalry rider circa AD 100 | refine | 11-23 15:59 | 26817 | 4096×4096 PBR | `unit_roman_heavy_cavalry_rider` · kanonisches Final |
| `01a20922-1d22-777f-b822-865f6b994efe` | full-body Roman auxiliary light cavalry rider circa AD 100 | refine | 11-23 15:59 | 25164 | 4096×4096 PBR | `unit_roman_light_cavalry_rider` · kanonisches Final |
| `01a20922-2cd0-7548-8505-5e2a143809ac` | full-body Roman auxiliary archer circa AD 100 | refine | 11-23 15:59 | 29218 | 4096×4096 PBR | `unit_roman_aux_archer` · kanonisches Final |
| `01a20922-3da8-7164-b3ef-0d60b4c04729` | full-body Germanic axe fighter circa AD 100 | refine | 11-23 15:59 | 29134 | 4096×4096 PBR | `unit_germanic_axe_fighter` · kanonisches Final |
| `01a20922-4d17-70f5-89b9-7a658e7dae82` | full-body Germanic light spearman circa AD 100 | refine | 11-23 15:59 | 29555 | 4096×4096 PBR | `unit_germanic_light_spearman` · kanonisches Final |
| `01a20922-65cb-74a8-9cc1-7479aec8622b` | full-body Roman signifer standard bearer circa AD 100 | refine | 11-23 15:59 | 29527 | 4096×4096 PBR | `unit_roman_signifer` · kanonisches Final |
| `01a20922-790b-77dc-aa63-9cee4c47c625` | full-body elite Germanic mounted retainer circa AD 100 | refine | 11-23 15:59 | 29280 | 4096×4096 PBR | `unit_germanic_mounted_retainer` · kanonisches Final |
| `01a20922-872f-701d-a442-b55d0673a9b3` | Roman legionary scutum circa AD 100 as one isolated prop | refine | 11-23 15:59 | 8456 | 4096×4096 PBR | `gear_roman_scutum` · kanonisches Final |
| `01a20922-9c05-77b1-9b22-42ac731456e2` | Roman cavalry oval shield circa AD 100 | refine | 11-23 15:59 | 8901 | 4096×4096 PBR | `gear_roman_cavalry_oval_shield` · kanonisches Final |
| `01a20922-ab81-74fa-9139-87adebe3a5d9` | Germanic round wooden shield circa AD 100 | refine | 11-23 15:59 | 8732 | 4096×4096 PBR | `gear_germanic_round_shield` · kanonisches Final |
| `01a20922-ba31-769d-837c-6303249958a9` | Roman cavalry lance circa AD 100 | refine | 11-23 16:00 | 9618 | 4096×4096 PBR | `gear_roman_cavalry_lance` · kanonisches Final |
| `01a20924-ac18-7424-a1fe-b05e3f13aaf9` | ancient leather sling circa AD 100 | refine | 11-23 16:02 | 9473 | 4096×4096 PBR | `gear_sling` · kanonisches Final |
| `01a20924-b3e4-7055-bc44-a7d05160d252` | Roman signum military standard circa AD 100 | refine | 11-23 16:02 | 8522 | 4096×4096 PBR | `gear_roman_signum` · kanonisches Final |
| `01a20924-cc2d-73ae-aeb5-2e8dbcdf2739` | Roman four-horn cavalry saddle circa AD 100 | refine | 11-23 16:02 | 9455 | 4096×4096 PBR | `gear_roman_four_horn_saddle` · kanonisches Final |
| `01a20924-e498-76cf-ad2f-66e95a923d97` | resource prop: stacked split firewood and rough timber logs for a Roma | refine | 11-23 16:02 | 9230 | 4096×4096 PBR | `resource_firewood` · kanonisches Final |
| `01a20924-f606-7041-b3ab-2e80125567f0` | clay resource deposit for an ancient Roman frontier landscape | refine | 11-23 16:02 | 9552 | 4096×4096 PBR | `resource_clay` · kanonisches Final |
| `01a20925-0424-70bc-bf56-271a644fd6f9` | limestone building-stone resource outcrop for a Roman frontier landsca | refine | 11-23 16:02 | 9299 | 4096×4096 PBR | `resource_limestone` · kanonisches Final |
| `01a20925-8e9e-76ba-b788-202a5c316e1c` | full-body Roman heavy cavalry rider circa AD 100 | refine | 11-23 16:03 | 26817 | 4096×4096 PBR | `unit_roman_heavy_cavalry_rider` · Dublette des Finals |
| `01a20926-3261-7070-aee2-6bdcfb8f4f4c` | copper ore resource outcrop for an ancient Roman frontier landscape | preview | 11-23 16:03 | – | nicht geladen | `resource_copper_ore` · Vorschau zum Final |
| `01a20926-3f65-721f-9f63-6f5a42644d73` | lead and silver-bearing galena ore resource outcrop for an ancient Rom | preview | 11-23 16:03 | 9201 | keine | `resource_galena` · kanonische Geometrie, untexturiert |
| `01a20926-85e5-70be-a646-d57d40c474d0` | full-body Gaius Julius Caesar | preview | 11-23 16:04 | 31457 | keine | `historical_caesar_58bce_candidate` · Kandidat, nicht kanonisch |
| `01a20926-b179-7152-b822-7eceeb32d867` | copper ore resource outcrop for an ancient Roman frontier landscape | refine | 11-23 16:04 | 9998 | 4096×4096 PBR | `resource_copper_ore` · kanonisches Final |
| `01a20934-c44a-77ea-95a7-5e2c2c804d5e` | full-body ancient cavalry horse for a Roman frontier setting | preview | 11-23 16:19 | 23137 | keine | `mount_ancient_cavalry_horse` · kanonische Geometrie, untexturiert |

Von den 30 Vorschauen wurden nur die drei geladen, die selbst kanonisch oder Kandidat sind (Pferd, Galena, Caesar-Vorschau); die übrigen 27 sind die untexturierten Vorstufen der Finals.

### Bild-zu-3D (IMPERATHEN)

| Auftrag | Inhalt | Datum (UTC) | Ablauf (UTC) | Dreiecke | Texturen | Zuordnung |
| --- | --- | --- | --- | ---: | --- | --- |
| `01a208f9-5601-7111-8751-e447499039dc` | Roman legionary, lorica segmentata (legacy image-to-3d) | 11-23 15:14 | 11-26 15:15 | 15218 | 2048×2048 PBR | `unit_legacy_roman_legionary_segmentata` |
| `01a208fe-0855-74e0-b2ad-2f5c2791c0d0` | Long-haired man in tunic and trousers (legacy image-to-3d) | 11-23 15:19 | 11-26 15:20 | 14245 | 2048×2048 PBR | `unit_legacy_tunic_villager` |
| `01a208fe-236f-731b-97da-2cd94a6e2e09` | Blacksmith with leather apron (legacy image-to-3d, Sextus candidate) | 11-23 15:20 | 11-26 15:20 | 15484 | 2048×2048 PBR | `unit_legacy_blacksmith` |
| `01a208ff-057d-73d6-8f70-1c3636ccaf6f` | Bay horse, textured (legacy image-to-3d) | 11-23 15:21 | 11-26 15:21 | 14002 | 2048×2048 PBR | `mount_legacy_bay_horse` |
| `01a20913-d021-722f-a1e0-10095201c6da` | Soldier in mail shirt (legacy image-to-3d) | 11-23 15:43 | 11-26 15:44 | 14733 | 2048×2048 PBR | `unit_legacy_mail_soldier` |
| `01a20913-e8fb-7039-9639-f72d1d54cfdd` | Gladiator (legacy image-to-3d) | 11-23 15:43 | 11-26 15:44 | 15568 | 2048×2048 PBR | `unit_legacy_gladiator` |
| `b6856033-bc9f-44fe-af12-e9843f161aed` | Roman adolescent warrior (private, owned by another agent) | 11-25 07:50 | 11-28 07:52 | – | nicht geladen | privat, einem anderen Agenten zugeordnet, nicht abgerufen |
| `acdf2d5b-769e-5b81-9997-b3d673338762` | Roman adolescent warrior (untextured twin; private) | 11-25 07:52 | 11-28 07:52 | – | nicht geladen | privat, einem anderen Agenten zugeordnet, nicht abgerufen |
| `629bd668-c5ed-4057-bd6d-c02322c80e4e` | Roman imperial temple | 11-25 07:59 | 11-28 08:01 | 4673896 | 4096×4096 PBR | `building_roman_imperial_temple` |
| `e6687410-20ed-48a1-8823-e591df9cb1d1` | Roman centurion cuirass (textured) | 11-25 10:15 | 11-28 10:18 | 3576992 | 4096×4096 PBR | `armor_roman_muscle_cuirass` |
| `1fbbb763-0aba-54bf-bb4f-de80ca4d6134` | Roman centurion cuirass (untextured twin) | 11-25 10:18 | 11-28 10:18 | 3576992 | keine | `armor_roman_muscle_cuirass` |
| `daf2d776-1be5-4960-bdec-bbab84523699` | Julius Caesar (textured) | 11-25 10:30 | 11-28 10:32 | 2245620 | 4096×4096 PBR | `historical_caesar_image` |
| `33983306-05ce-5a50-a5e9-eace192c0c2a` | Julius Caesar (untextured twin) | 11-25 10:32 | 11-28 10:32 | 2245620 | keine | `historical_caesar_image` |
