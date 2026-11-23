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
