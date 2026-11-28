# Freigabe und Prüfperspektiven
- **Godot Architect (simuliert):** Jeder neue Adapter benennt Zustandseigentümer, Felder und Aufrufer. Kein zweiter Autoload für Missions-, Eigentums-, Welt- oder Wirtschaftsdaten.
- **Bug-Hunter/QA (simuliert):** Fehlende Felder, unzulässige Reihenfolge, späte doppelte Ereignis-ID, beschädigte Referenz, Abbruch und erneut geladenen Save negativ prüfen. Alte Schwellen behalten. Datenquelle und Rohlogs müssen zum getesteten Commit gehören.
- **Lead Integrator (simuliert):** Register und offene Drafts erneut lesen, beim letzten gemeinsamen Elternstand integrieren, Architekturindex deterministisch erneuern, Engine- und Regressionstests sowie die tatsächlich berührten visuellen Gates auf demselben Head ausführen.

ENGINE_PASS benennt nur den getesteten Vertrag. REVIEW_PENDING gilt für offene Gestaltungs-/Integrationsfragen; DEVICE_PENDING für echte Hardware. ACCEPTED ist keine automatische Folge eines grünen CI-Laufs. Keine ungeprüften Merges, Produktivschlüssel, Store-Veröffentlichung oder privaten Rohquellen. Keine kostenpflichtigen Aufträge.
