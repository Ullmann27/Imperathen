# Stand 0 – gemeinsamer Integrationsstand

Status: **NICHT FREIGEGEBEN**. Dieser Zweig sammelt die konfliktfreien Dateiänderungen aus den Stadt-, Handels-, Welt-, Material-, Kamera- und Präsentationszweigen. Bei divergierenden Änderungen wurde der bisherige Stand beibehalten; beide Quell-SHAs stehen in `integration.json`. Dies ist ein Integrationskandidat, keine fertig verbundene oder getestete Stadt.

## Freigabekriterien

1. Privates Stadtpaket mit finalen GLBs, Crowd, Kollision und Pflaster anhand des Paketmanifests zusammenführen. Nicht blind ältere Skripte überschreiben.
2. Alle Konflikte einzeln lösen, vollständigen Import prüfen.
3. Die sechs belegten Marktorte an genau eine autoritative Handels- und Inventardomäne binden: Guthaben, Inventar, An-/Ablegen, Kauf/Verkauf, getrennte Speicherstände. Keine zweite Figur/Kamera beim Öffnen eines Shops.
4. NPC-Wege, Dialoge, Reaktionen und Innenräume im tatsächlichen Stadtrundgang integrieren, Kollision und Erreichbarkeit prüfen.
5. Fehlgeschlagene Kamera-/Bewegungsregressionen mit den finalen GLBs wiederholen; keine Ersatzfigur als Erfolg werten.
6. Stadt-, Domain- und Touchtests auf demselben Commit. APK mit bisheriger Paketkennung und kompatibler Signatur; Installation, Start, Pause, Fortsetzung, Stadtbesuch und Fold7-Laufzeit nachweisen.

`integration.json` ist ein bewusst sperrender Arbeitsnachweis. Einzelne grüne Modulworkflows sind keine gemeinsame APK-Freigabe. Keine Änderung an main.
