# LEGIO AETERNA – Story-QA und Integrationsübergabe (26.11.2026)

## Basis und Zusammenführung
- Laufzeitbasis: `4209e5504e857f31d76a79cff18676ed743de7db` (#130).
- Regression: `fdd5f75b6734d9cf5741e6ba79d1dc546e6dfc86` (#132); alle fünf Gruppen sind in der neueren Basis bereits registriert. Die drei spezifischen PASS-Signale werden übernommen, ohne neuere Gruppen zu duplizieren oder zu entfernen.
- Der Integrationscommit behält beide Eltern. Kein Merge nach main; keine private Modellressource und keine Signierschlüssel werden veröffentlicht.
- Prüfung bleibt strikt: Prozessstatus, GDScript-Fehler, Erfolgssignal. Der Motion- und Sprachfreigabevertrag bleibt unverändert.

## Verfügbarer Android-Prüfbau (vor diesem Integrationscommit)
- Quelle: `4209e5504e857f31d76a79cff18676ed743de7db`.
- [CI 45813814923](https://github.com/Ullmann27/Imperathen/actions/runs/45813814923)
- [QA-Artefakt 15115735137](https://github.com/Ullmann27/Imperathen/actions/runs/45813814923/artifacts/15115735137)
- Paket: at.heinz.imperathen.qa, versionCode 8, 462362870 Byte.
- SHA-256 APK: 95977745a17a89d9e0d4d08d89bc6c52f87e5f90c8a7df188d0f2da92bc56daf.
- Separates temporäres QA-Zertifikat; keine Produktionsaktualisierung. Eine zuvor installierte QA-App kann ein anderes Zertifikat haben. Vor einer Deinstallation Spielstände sichern, wenn möglich.
- Statische APK- und Signaturprüfung erfolgreich; keine physische Installations-, Laufzeit-, Wärme- oder Grafikfreigabe.
- Dieser Integrationscommit braucht einen eigenen CI-Nachweis; das obige Paket gehört ausschließlich zur Laufzeitbasis.

## Erste manuelle Story-Abnahme am Fold7
1. Neuinstallation bzw. Start ohne alten Spielstand; Hauptmenü, Video, Ton, Touch und Prolog prüfen.
2. I-01: Drei Becher, Entscheidung, Julia/Silvanus, sichtbarer Becher, fehlende Tonzeilen dokumentieren.
3. I-03/I-04: Marcus kennenlernen und einladen, Silvanus ansprechen, Gefolge bedienen, gemeinsam Holz holen, Schmiedetafel übergeben, speichern und neu laden.
4. Markt: nach I-01 über Kampagnenpause, mit ausreichenden regulär erworbenen Denaren zum Bäcker, Brot kaufen, Rückkehr, Save/Reload. Einen mittellosen Start nicht mit einer Testfixture verwechseln.
5. I-09 bis I-14: beide Familienwege separat mit neuem Spielstand; Tod, Folgegespräche, Schwur, Karrierewahl und persistente Begleiter prüfen.
6. Talgefecht separat vom Kampagnenstand; Aufstellung, Befehle, Reiter, Rückkehr.
7. Alle vier Grafikprofile unter gleichen Szenen vergleichen; Fold7-Frametimes, Wärme und Abbrüche über längeren echten Spielbetrieb erfassen.

## Offene Freigabeblocker
- Sieben passende I-01-Aufnahmen einschließlich Julia-Besetzung fehlen laut #131. Unvertonte Zeilen bleiben als korrekte Untertitel erkennbar; kein Schein-PASS.
- #131 dokumentiert 395 Motion-Befunde bei 70 Modellen auf seiner APK-Revision; nicht auf diese Revision übertragen, neu messen.
- Fußgleiten, Sohlenkontakt, Armoberfläche und Markt-Draw-Call-Budget; echte Render- und Geräteabnahme weiterhin offen.
- Private Original- und Derivatmodelle können außerhalb der öffentlichen GitHub-Basis liegen. Öffentliche CI ersetzt keine private Vollabnahme.
- Weitere 113 Missionsabschnitte sind nicht automatisch vollständig ausgeführt, nur weil sie in der Chronik stehen.

## Reproduktion
```sh
python3 tools/check_prototype.py --only import party_transactions party_world party_ui party_city valley_muster --keep-going --report /tmp/legio-story-qa
```
Separat vollständige Regression und Motion-Gate auf unveränderter Quelle laufen lassen. Stadt- und Kollisionsassets müssen vorhanden/importiert sein. Keinen fehlgeschlagenen Test durch eine geringere Schwelle oder einen ignorierten Exit ersetzen.
