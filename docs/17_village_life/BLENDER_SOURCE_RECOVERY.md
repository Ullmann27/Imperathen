# Wiederherstellung der bearbeitbaren Figurenquellen

23. November 2026 · `feature/village-life-delivery-20261123`

## Befund und Änderung

Beim Wiederaufnehmen des unterbrochenen Uploads enthielt Quellstand
`c9bc6e72aae939eab828e86058ec22be883739a6` alle 28 Frontier-GLB-Exporte,
aber nur eine der sieben in
[`provenance.json`](../../art/frontier_people/provenance.json) aufgeführten
Blenderquellen: `civilian_man.blend`. Sechs bearbeitbare Originaldateien fehlten.

Die fehlenden Dateien wurden aus der erhaltenen lokalen Arbeitskopie der
vorherigen Figurenproduktion wiederhergestellt. Vor und nach dem Kopieren wurde
ihre SHA-256-Prüfsumme mit dem bereits im Repository vorhandenen Herkunftsregister
abgeglichen. Bestehende Dateien wurden nicht überschrieben. Die Wiederherstellung
umfasst **70.236.584 Bytes** und verwendet unveränderte Originaldateien; es fand
keine neue Modellgenerierung statt.

| Wiederhergestellte Datei unter `art/frontier_people/` | Bytes | SHA-256 laut bestehendem Register und tatsächlicher Datei |
| --- | ---: | --- |
| `archer.blend` | 11.332.000 | `e96a8e58d65ba7042b5c6aae013b10f3419e0118ccd15b14b716c13b0a3f069b` |
| `civilian_woman.blend` | 11.940.470 | `7a5743a7c15694e4d33d3a0e277515def2fcfe9342c353c3c0c830dfe068835e` |
| `elder.blend` | 12.983.176 | `75153c7f3922567fb2b03dcd1a6f3f179b6d95a07b7f77c9460940c4e0e6b826` |
| `legionary.blend` | 11.305.095 | `abd5ec1fbe10ac4f28cbc789806e0f198980ba776b0194c5b917ae8ef4e882ef` |
| `officer.blend` | 11.340.286 | `80cb42ed0ad80ce38c3c1f5d069dab5878b851b1ed72bca93952b50e5f4b7e74` |
| `spearman.blend` | 11.335.557 | `6a1e7df1656811da8f2b7e23e1e11d386f546a9748e70eee82e33632ced20cd2` |

## Tatsächlich geprüfte Zuordnung

- Alle **7 von 7** Blenderquellen stimmen nun mit `blend_sources` im bereits
  vorhandenen Herkunftsregister überein. Die zuvor vorhandene Datei
  `civilian_man.blend` blieb unverändert.
- Alle **28 von 28** produktiven Frontier-GLBs stimmen mit ihren SHA-256-Werten
  aus [`build_report.json`](../../art/frontier_people/build_report.json) überein.
  Es wurde kein GLB neu exportiert oder ersetzt.
- Herkunftsregister, Buildbericht, Figurengenerator, Hero-Blenderquelle und
  Ausrüstungsgenerator sind in der erhaltenen Arbeitskopie und im aktuellen
  Checkout byteidentisch. Insbesondere entspricht die Heroquelle dem bereits
  protokollierten Hash
  `e7ebd5f7c0b84eff67694b35697187615085fc26a75468590b4a585d1252c63e`.
- Beim Inventarvergleich waren alle **36** bereits vorhandenen Blenderdateien
  identisch zur erhaltenen Arbeitskopie. Wiederhergestellt wurden ausschließlich
  die sechs fehlenden, im Herkunftsregister ausdrücklich benannten Quellen.

Die sieben Modelle sind damit wieder als vollständige Quellenserie für die
bestehende Blender-Pipeline verfügbar. Herkunft, Nutzungsnachweise und bekannte
Darstellungsgrenzen bleiben in
[`art/frontier_people/README.md`](../../art/frontier_people/README.md) beschrieben.
Dieser Dateiabgleich belegt die vollständige Sicherung der Originalquellen;
er ist kein neuer Renderlauf, Android-Laufzeittest oder Leistungsnachweis.

## Unabhängige Nachprüfung des gespeicherten Quellstands

Der GitHub-Baum von Commit
`f60fd4e1b5ff8a0ed9b21861bc8515ca64da33b8` wurde erneut abgefragt und mit
neu berechneten Git-Blob-IDs und Dateigrößen der erhaltenen Originaldateien
verglichen. Alle **75 geprüften Dateien** stimmen überein: sämtliche **42
Blenderdateien** des Quellstands, die **28 Frontier-GLBs** und **fünf
Herkunfts-/Buildregister beziehungsweise Generatorskripte**. Die zusätzlichen
SHA-256-Prüfungen der sieben Frontier-Blenderquellen und der 28 Frontier-GLBs
stimmen ebenfalls mit den bestehenden Registern überein; es gab keine
Abweichung. Damit ist die Sicherung auch dem tatsächlich gespeicherten
Repositorybaum zugeordnet.
