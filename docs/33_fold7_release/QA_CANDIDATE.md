# IMPERATHEN – Android-Fold7-Abnahmestand

Stand: 25. November 2026. Dieser Zweig baut nicht lediglich eine kleine
Blender-Vorschau, sondern das vorhandene Godot-4.7.2-Spiel mit realer
RomanCity-Stadtgeometrie. **Nichts davon ist bereits automatisch eine
vollständig hardwarefreigegebene Android-Version.**

## Was im Kandidaten tatsächlich angeschlossen ist

- Der bestehende Blender-Stadtgenerator erzeugt die **240 nummerierten
  Wohnhausinstanzen** und 63 echte Marktstände in
  `assets/world/roman_city_test.glb`, mit einer separaten
  `roman_city_collision.glb`.
- **Forum:** Die Haupt-GLB enthält bereits `Forum_Piazza` und
  `Forum_Worn_Stonework`. In `CityExploration` wird deshalb **keine
  doppelte externe Forum-GLB** mehr gerendert; dies vermeidet Z-Fighting
  und unnötige Drawcalls.
- **Bewohner:** Die zwölf nachvollziehbar auf der Hauptstraße
  verteilten `CityGuest`-Figuren werden vom vorhandenen
  `CityIdleCrowd` abhängig vom Grafikprofil nachgeladen.
  Vorhandene `CityAmbientPeople` erzeugen die physikalisch bewegten
  Markt-Händler-/Besucherpaare. Die statischen Crowd-Figuren sind
  **keine** neuen frei sprechenden NPC-Persönlichkeiten; diese
  Unterscheidung ist im Layoutvertrag festgehalten.
- **Details:** Echte Portal- und Helm-GLBs, Pflaster, PBR-Materialien,
  Gebäude-Instanzen, Schilder, kaufbare Händler und der Jugendspieler
  stammen aus dem bereits geprüften Stadtzweig.
- **Privater Meshy-Tempel:** Originaltask
  `629bd668-c5ed-4057-bd6d-c02322c80e4e` ist vorhanden, aber
  durch Meshy als privates texturiertes Modell ausgewiesen.
  `tools/world/prepare_private_temple.py` importiert den
  bereitgestellten **Original-GLB** in Blender, misst den Weltmaßstab,
  passt ihn mit *einheitlicher* Skalierung an das reservierte
  **44×46-m-Grundstück** und maximal 30 m Höhe an und erstellt drei
  geprüfte GLB-LOD-Stufen.
  Das private Downloadtoken/Originalmesh wird nie eingecheckt. Die
  CI übernimmt es nur, falls ein **geschütztes** Repository-Secret
  `IMPERATHEN_PRIVATE_MESHY_TEMPLE_URL` (gültiger, signierter Link)
  tatsächlich hinterlegt ist. Ohne Secret bleibt der Tempel im
  Paketbericht als **nicht vorhanden** ausgewiesen.

## Bauen und testen

`.github/workflows/fold7-city-apk.yml` bietet zwei unabhängige Jobs:

1. **Android QA:** echte GLBs erzeugen, alle regulären Projekt- und
   Motion-Gate-Tests, CityRealAsset, CityRealWalk und Crowd-Layout prüfen,
   dann offizielles Android-ARM64-Debug-APK exportieren und mit `aapt`,
   `apksigner`, Hashing und ABI-/Ressourcenvalidierung prüfen.
2. **Visuelle Referenzen:** Drei feste Orte (Markt, Forum, Fassaden)
   jeweils in **Hoch** und **Sehr Hoch** mit Godot unter echtem
   Xvfb/OpenGL rendern. Die sechs originalen PNG-Framebuffer werden
   als Artefakte veröffentlicht, nicht als KI-generierte Zielbilder
   oder physische Fold7-FPS-Messwerte. Bildvergleich durch einen
   Menschen bleibt Bestandteil der Abnahme.

Die Pipeline baut im Normalfall `at.heinz.imperathen.qa`
mit eigener **temporärer QA-Signatur**. Das ist eine echte
installierbare Test-App mit eigenem Speicher, die die bereits
installierte `at.heinz.imperathen` **nicht** ersetzt.

Ein **Update der Original-App** kann ausschließlich dann
produziert werden, wenn sämtliche vier Repository-Secrets gesetzt sind:

- `IMPERATHEN_UPDATE_KEYSTORE_B64` – der bereits verwendete
  private Android-JKS-Keystore, niemals im Quelltext
- `IMPERATHEN_UPDATE_SIGNER_SHA256` – geprüfter SHA-256-Fingerabdruck
  des Zertifikats der tatsächlich installierten App
- `IMPERATHEN_UPDATE_KEY_ALIAS` – Schlüssel-Alias
- `IMPERATHEN_UPDATE_KEY_PASSWORD` – Passwort

Das Bauprogramm verifiziert den Fingerabdruck mittels `apksigner`.
**Ein neuer zufälliger Debug-Schlüssel gilt nicht als identischer
Signer.** Ohne passende Bestätigung wird nur die separate QA-App
veröffentlicht; der ursprüngliche Paketname bleibt unverändert.

## Physischer 20-Minuten-Test

Ohne vom Nutzer autorisierten ADB-Zugriff auf das **tatsächliche**
SM-F966B-Gerät kann ChatGPT keine reale 20-Minuten-Messung liefern.
`tools/fold7_physical_qa.py` ist die reproduzierbare Abnahmehilfe:

```bash
python3 tools/fold7_physical_qa.py \
  --serial GERAETE_SERIAL --profile high \
  --seconds 1200 --output fold7-high-evidence
```

Die Abnahme verweigert Emulatoren, andere Modelle, kürzere
Laufzeiten und nicht durchgehend vorhandene App-Prozesse. Sie nimmt
nur tatsächlich geloggte P50/P95/P99-Bildzeiten, Render-GPU-Zeiten
(wenn vorhanden), RAM/PSS und Android-`thermalservice`-Status auf.
Die Akkutemperatur wird ausdrücklich nicht als GPU-Temperatur
ausgegeben. Ein zweiter Lauf in `very_high` ist erforderlich.

Der Nutzer startet und bedient die App währenddessen auf dem
echten Fold7. Vor einer Installation müssen Original-Paketname und
Signatur geprüft sein; die separate QA-App erlaubt gefahrloses
Testen neben dem bereits installierten Spiel.

## Nicht als fertig ausgegeben

- Ein fehlendes privates Tempelasset oder eine ungeprüfte 44×46-m-
  Größenanpassung ist **kein** verifizierter historischer Stadttempel.
- Der GUI-Renderer-Test in CI ist ein Mesa/Linux-Vergleich, keine
  Adreno-830-Frametime-Messung.
- Fehlende Sicherheits- oder Motion-Gates dürfen nicht durch
  bloßes Umbenennen eines Build-Artefaktes umgangen werden.
- Neu erzeugte Quell-/Stadt- und Testobjekte bleiben zunächst im
  Arbeitszweig; `main` wird nicht automatisch verändert.
- Bestehende APK-Signaturen und der Speicher der installierten
  Original-App dürfen nicht überschrieben werden.

**Freigabe:** erst nach erfolgreich realem Build, statischem
APK-Nachweis, Installationstest, Signaturprüfung und echtem
Fold7-Langzeittest. Sonst Status: `QA_CANDIDATE_ONLY`.
