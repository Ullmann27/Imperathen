# Unreal-Projektbasis

Diese C++-Projektbasis bereitet den nativen Einstieg von IMPERATHEN vor. Sie enthält ein Runtime-Modul, Game- und Editor-Ziele, einen GameMode mit prozeduralem Stadtblockout, einen überspringbaren Slate-Vorspann, Hauptmenü, Einstellungen und einen kleinen Dorfablauf mit eigenem SaveGame.

**Prüfstatus:** Die Engine ist in der aktuellen Arbeitsumgebung nicht installiert. UnrealHeaderTool, UnrealBuildTool, Editorstart, Cook und Paketierung wurden hier nicht ausgeführt. Der unabhängige C++-Regelkern wird mit dem vorhandenen C++-Compiler tatsächlich kompiliert und ausgeführt. Die Browser-Vorschau unter `preview/` ist separat lauffähig; ihr Spielstandformat wird nicht als Unreal-kompatibel ausgegeben.

## Auf einer vorhandenen Unreal-Installation

1. Eine vorhandene Unreal-5-Installation ab 5.4 mit C++-Toolchain auswählen. Die Projektdatei lässt `EngineAssociation` absichtlich frei; damit wird keine hier nicht geprüfte Patchversion als feststehend ausgegeben. `BuildSettingsVersion.V5` setzt einen ausreichend neuen UnrealBuildTool voraus.
2. `Imperathen.uproject` dieser Installation zuordnen und Projektdateien erzeugen.
3. Das Ziel `ImperathenEditor` in `Development Editor` für den vorhandenen Rechner kompilieren. Echte Compilerfehler zuerst beheben und die verwendete Version dokumentieren.
4. Das Projekt öffnen. Als erster Startlevel ist der Engine-Level `/Engine/Maps/Entry` konfiguriert; der GameMode baut den Hintergrund beim Spielstart aus Engine-Basisformen auf. Kein erfundener `.umap`-Binärinhalt ist eingecheckt.
5. Play in Editor starten. Intro überspringen und normal ablaufen lassen, neues Leben anlegen, alle drei Aktionen ausführen, zurückkehren und erneut laden.
6. Vor einem verteilbaren Build den Startlevel als Projekt-Map speichern, Cook-Referenzen prüfen und einen echten gepackten Start testen. Die vorhandene Packaging-Konfiguration ist eine Ausgangsbasis, kein ausgeliefertes Paket.

Keine neue Engine-Version, Lizenzannahme, kostenpflichtige Maschine oder Download wurde durch diese Lieferung ausgelöst.

## Inhalt und Grenzen

`EntryProgress.h` ist unabhängig von Unreal. Es erzwingt die endliche Reihenfolge Holz → Unterstand → Marcus, Ressourcen 0 → 6 → 2 → 0 und Vertrauen 0 → 10. Wiederholte Handlungen geben keine weitere Belohnung. Alle drei Handlungen liegen am ersten Tag; Alter und späterer Karriereweg werden nicht stillschweigend festgelegt.

Die native Ansicht besitzt eine eigene SaveGame-Klasse mit Formatversion. Vor einem Ersatz wird der vorherige gültige Stand in einem getrennten Slot gesichert. Eine Wiederherstellung ist ausdrücklich zu bestätigen und archiviert den bisherigen Inhalt zusätzlich. Ein beschädigter oder nicht unterstützter Stand startet keine neue Partie. Dateisystemabbruch und Plattform-Verhalten müssen auf der gewählten Engine/Plattform geprüft werden; die synchrone SaveGame-API ist keine behauptete universelle Mehrdatei-Transaktion.

Die Browser-Vorschau besitzt zusätzliche Journal- und Schadenserkennungsfunktionen. Eine gemeinsame vollständige Save-Spezifikation und Migration zwischen den beiden Vorstufen ist noch nicht implementiert. Die native Grafik ist ein eigener geometrischer Blockout, kein finales römisches Assetset. Native Audioausgabe, frei steuerbare Spielfigur, Kampf und Stadtbausimulation sind spätere Aufgaben.

## Referenzen für den nächsten Engine-Bearbeiter

- [Epic: C++-Spielprojekte kompilieren](https://dev.epicgames.com/documentation/en-us/unreal-engine/compiling-game-projects-in-unreal-engine-using-cplusplus)
- [Epic: Build-Ziele](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-build-tool-target-reference)
- [Epic: Slate im Spiel](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-slate-in-game)
- [Epic: Speichern und Laden](https://dev.epicgames.com/documentation/en-us/unreal-engine/saving-and-loading-your-game-in-unreal-engine)

Die Quellen wurden am 22.11.2026 für die API-Ausrichtung gelesen. Dokumentation ersetzt keinen Engine-Build.
