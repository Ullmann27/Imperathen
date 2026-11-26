**Marker:** [V] in Code/Datei geprüft (Stand df15a2e) · [D] dokumentiert (Handbuch-PDF-Seite/Docs/Vor-Audit) · [I] Ableitung · [Q] antike Quelle aus Fachwissen, Stelle vor Übernahme prüfen (kein Download). Godot nicht gestartet, nichts geändert.

## 1. Inventar
- **Regeln:** 6 fest codierte Verbände, 30:30, Typen infantry/spear/archer (battle_model.gd:35-40) [V]; 7 Formationen mit Ausrüstungsgate (formation_slots.gd:3-7, battle_model.gd:20) [V]; 13 Befehle inkl. Front per Ziehen, Flanke, Reserve, Feuer bündeln/einstellen (:22) [V]; Befehlsverzögerung nach Disziplin/Offizier/Moral (:286-293); Moral, Müdigkeit, Kohäsion, Munition, Verwundete/Tote, Stellvertreter (:369-387); deterministisch, validiertes Save (:556ff); 67 Checks in battle_rules_test.gd [V].
- **Spieler heute:** pausiert befehlen, wählen per Tippen/Box/Strg+1-9-Gruppen, Ziel tippen = Marsch/Angriff, lang drücken+ziehen = Frontlinie mit Geisterplätzen, drei Popup-Menüs, Tempo 1×/0,35×, Pinch-Zoom (valley_scene.gd:279-521, valley_hud.gd:63-83) [V]. Keine Spielerfigur auf dem Feld [V].
- **Anzeige:** nur Label3D-Name in Seitenfarbe (valley_scene.gd:95-104,172-177); Karten „Name · Stärke“ (valley_hud.gd:106); Moral nur in Statuszeile nach Antippen (valley_scene.gd:321) [V].
- **LOD:** nah frontier_*_0 = 19 060 Dreiecke, mittel *_1 = 7 345, fern soldiers/*_far.glb = 210, statisch, MultiMesh + rank_stride-Shader, 4 Batches je Rolle [V, GLB gemessen]; animierte Akteure 24/40/64/90 (quality_profiles.json); nah/mittel/fern-Zähler (runtime_display.gd:237) [V].
- **Assets:** Meshy unit_roman_signifer/unit_germanic_axe_fighter mit 4 LODs, gleiche 15 Knochennamen wie Frontier, aber ohne wall/testudo/shoot/retreat-Clips [V]; 7 Loadouts inkl. Kavallerie alle runtime_enabled:false (meshy/loadouts.json); Pferd untexturiert; mounted_units inaktiv (motion_contract.json) [V].
- **Ausrüstung:** 16 Items ohne Q-Stufe, family_id, epoch (city_trade_catalog.gd:4-21) [V]; gefordert 36 Familien, Q0–Q4, epoch_tags (PDF S.82, 113–124) [D].
- **Überfall:** ≤6 Feinde, einheitlich 45 HP (village_life.gd:529,717,724); Drehbuch fix 30 sichtbar (village_childhood.gd:127) [V]. Germanen-KI-Branch hat noch keine eigenen Commits (= ffbe3ad) [V].

## 2. Lücken
1. **H** Keine Truppendaten/Kulturen/Stufen; Rolle nur aus `kind`, beide Seiten gleiche Modelle (valley_scene.gd:187), Tönung nach Index (soldier_visual.gd:10) [V].
2. **H** Verluste immer hinten (battle_model.gd:375), Soldaten-ID = Slotindex (:94,124) → Front stirbt nie, kein Nachrücken; Offizier fällt stets nach 3 Verlusten (:56,379) [V].
3. **H** Slotzuordnung nach Index, Ausgleich bis 4,8 m/s (:491-497) [V].
4. **H** „Sammeln“ beendet Flucht sofort (:242-243) [V]; keine Moralansteckung, kein Flanken-/Bannerverlust-Schock.
5. **H** Befehlsrecht nach Rang/Präsenz fehlt (PDF S.68) [D].
6. **M** Fehlend: Folgen, Vorrücken, Zurückfallen, Sturm, Ausrichten, Kreis, Pila (Kommandorad PDF S.283) [D].
7. **M** Kein Banner, Bodenmarker, Moralbalken; Buttons 44×40 Basis-px bei 1280×720 canvas_items (project.godot:14-16) [V] ≈ 4,7 mm innen/3,6 mm außen [I, DPI nicht gemessen].
8. **M** LOD-Wechsel instanziert Szene neu (soldier_visual.gd:133-163) [V]; 40 × 19 060 = 762 k Dreiecke > balanced 320 k [I, Mesh-LOD ungemessen].
9. **M** Motion-Gate: battle_rigs Gleiten 0,915 m/Eindringen 0,176 m (meist Todesclip), distant_ranks LOD-Sprung 0,138 m > 0,04 (Handover motion_quality_gate_ffbe3ad.txt:489-494) [V]; Angriffsgleiten 0,1675 m [D].
10. **M** Skala 60 statt Messleiter 16/64/256→5000 (PDF S.284); simuliert/gerendert/animiert nicht vollständig getrennt berichtet (S.43) [D].
11. **L** AGENTS.md nennt 100 n. Chr., Code start_year -58 (village_childhood.gd:68) [V] – Lead entschied 58 v. Chr.

## 3. Entwurf
**(a) Truppenbäume** – `prototype/data/troops/*.json`, Zeitspannen statt Epochenflag: troop_id, culture, valid_from/valid_to (Jahr, negativ = v. Chr.), tier 1–5, role, loadout{slot:{family_id,q_min,q_max}}, drills, upgrades[{to,xp,items[{family_id,q_min,n}],authority}], visual, attestation(attested/plausible/design), sources. Kampfwerte nur aus Item × Qualität × Ausbildung (Formel PDF S.79) [D].
- *Rom 58–50 v.:* Tiro (Helm, Scutum, Leih-Gladius, 1 Pilum) → Miles (+Hamata, 2 Pila) → Veteranus (Q2–3, Disziplin) → Evocatus (BC 3.88 [Q]). Rekruten- vs. Veteranenlegionen BG 1.24 [Q]. Centurio/Optio/Signifer/Cornicen sind Ernennungen (commander_id/deputy_id existieren), keine XP-Stufe (PDF S.68) [D]; Signifer = Moralanker, Cornicen −1 Step Verzögerung [I]. Hilfstruppen: kretische Bogner, balearische Schleuderer, Numider (BG 2.7), gallische Bundesreiter (BG 1.18) [Q]. *Spätere Varianten:* Germanen in römischem Dienst ab 52 v. (BG 7.65) [Q]; Weisenau-Helm, feste Auxilia, Segmentata frühestens augusteisch [Q/plausible] – nie 58 v. (PDF S.82) [D].
- *Germanische Gruppen* (Gemeinwesen mit Familien und Anführern; Haltung zu Rom dynamisch, Bündnis möglich): Jungkrieger-Speerwerfer → Heerbann (Stoßspeer, Schild) → Krieger → Gefolgsmann (Schwert selten; Tac. Germ. 13–14, ~98 n. [Q]) → Edler (Hamata/Helm selten, Pferd). Zweig Reiter + Fußläufer als gemischte Einheit (BG 1.48), Absitzen (BG 4.2), Keil nach Sippen (Tac. Germ. 6–7) [Q]. Axt-Schild = **Designannahme** (vorhandenes Asset als Heerbann-Variante). Bogner kaum belegt → „Hangbogner“ zu Speerwerfern [I].
- *Aufstieg:* XP je Soldat + reale Items. Rom: Depot→Soldat mit Soldabzug (PDF S.43/68) [D]; Germanen: Gabe des Anführers aus Beute/Handel (Tac. Germ. 14 [Q]). Ohne Item kein Aufstieg; Gefallene → Verlust/Beute im Ledger.

**(b) Befehle → battle_model:** neu follow, advance (Stopp 6 m, Logik wie :410), fall_back (10 m, Blick halten, 1 m/s), charge (2,65 m/s, Stoßbonus 1. Treffer, Kohäsion −), face, pila (Einmalsalve 12 m, Schildfaktor Ziel 10 s geschwächt, BG 1.25 [Q]), fire_at_will; Formation orbis (BG 4.37 [Q]); testudo nur Scutum+Drill≥2. Rally → Status „rallying“, endet bei Moral ≥40, kein Feind ≤8 m, ≥5 s, Führer lebt. Moral −8 je fliehendem Nachbarn ≤12 m, Rückentreffer ×1,5, Bannerverlust −15. Verluste in Reihe 0, Nachrücken (PDF S.86) [D], stabile soldier_uid, Slot-Sortierung, Mitglied ≤2,65 m/s. `commandable_by` begrenzt Befehle.

**(c) Visualisierung:** Signifer trägt gear_roman_signum (vorhanden); germanisches Feldzeichen als eigenes Tierbild (Tac. Germ. 7 [Q]). **Seite ≠ Kultur** (verbündete Germanen!): Seitenfarbe auf Bodenring, Bannerplakette, Karte; Fern-Batches je Kultur×Rolle, Seite als Shader-Parameter, da COLOR/CUSTOM belegt (far_ranks.gd:3) [V]. Bodenumriss + Blickpfeil + Befehlssymbol. Karten: Emblem, Typ, lebend/initial, Moralbalken (grün/gelb/rot, blinkend = Flucht), Formation, Befehl, Verzögerungsuhr. Ziele ≥ 9 mm per DPI; innen Karten unten + Befehlsrad rechts, außen (21:9) einklappbare Kartenspalte + 2×4-Befehlsraster, PC F1–F8.

**(d) LOD (Startwerte, messen):** L0 voll, L1 7k-Rig mit geteilter Phase, L2 210-Dreieck-Instanzen, L3 Verbandsblock + Banner > 120 m. Animiert/sichtbar: low 8+16/256, balanced 12+28/512, high 24+40/2000, very_high 32+58/5000; L0 ≤ 30 % visible_primitives; Hysterese ±3 m, 1 s (PDF S.45). Getrennte Zähler simuliert/sichtbar/animiert/aggregiert. Fold7 ohne Gerät = BLOCKED.

**(e) Integration:** gemeinsames Roster `{group_id, polity, stance_to_rome, leader_id, troops{troop_id:{count,xp,wounded}}, noncombatants}`; Germanen-KI schreibt, Schlacht und Überfall lesen. Raubzug = freiwillige Schar eines Anführers (BG 6.23 [Q]); Überfallgegner aus Stufe/Ausrüstung statt 45 HP. Rückgabe: Verluste, Beute, Haltung. Familien/Wagenburg (BG 1.51 [Q]) sind Nichtkombattanten, keine Befehlsziele.

## 4. Pakete (Slice = P1–P5, ~14 h)
1. **Truppenkatalog (3 h):** data/troops, scripts/battle/troop_catalog.gd, Test. Abnahme: 11 Einträge laden; fehlende family_id/ungültiges Datum abgelehnt; Filter −58 ohne Segmentata.
2. **Roster + Verluste (3 h, nach 1):** soldier_uid, Frontverluste, Nachrücken, Slot-Sortierung, Save-Schema 3 + Migration. Abnahme: ≥70 % Verluste aus vorderen 2 Reihen; Mitgliedsschritt ≤0,53 m/Step; alte 67 Checks grün. Risiko world_model.gd:313.
3. **Moral/Rally (2 h):** Rally bei Moral 20 bleibt Flucht; ≥40 + 5 s → bereit; Ansteckung −8.
4. **Befehle (3 h):** fall_back 10 ± 0,3 m, Blick ± 0,1 rad; Pila verbraucht genau 1; ungültige Befehle atomar abgelehnt.
5. **Kultur-Visual + Banner (3 h):** Germanen-Verband rendert unit_germanic_*; ≤ 8 Fern-Batches; Bildpaar. Risiko fehlende Clips → idle-Fallback, Motion-Gate.
6. **HUD-Karten/Befehlsleiste (3 h):** Ziele ≥ 9 mm bei 368/422 ppi simuliert.
7. **LOD/Zähler/Skala 64/256 (3–4 h):** headless Logik; GPU-Werte Fold7 BLOCKED.
8. **Roster-Schnittstelle KI/Überfall (3 h, nach KI-Merge).**
9. Später: Spielerfigur im Kommandotrupp mit Kamerawechsel; Kavallerie erst nach mounted_units-Gate.

## 5. Owner-Entscheidungen
1. Talgefecht als Rom vs. germanische Gruppe 58 v. umbenennen oder fiktiv lassen?
2. Axt-Schild-Kämpfer als Designannahme zulassen?
3. Spieler kommandiert erst ab Rang – Talgefecht als Demo/Erwachsenenkapitel?
4. Nahbereich Einzeltreffer (Bannerlord-artig) oder weiter aggregiert?
5. Angriffsgleiten 0,1675 m akzeptieren oder neu choreografieren?
6. Kapiteljahre der Zeitsprünge (z. B. 58/52/49/30 v./9 n.)?
7. AGENTS.md „100 n. Chr.“ an Lead-Entscheid anpassen.
8. Fold7-Budgets nach erster Messung freigeben.
