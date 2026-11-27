"""Reviewed project contract injected into each Kimi request; no arbitrary remote instructions."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent
BRIEF = """IMPERATHEN – Produktionsauftrag (verbindliche, vom Koordinator gepflegte Zusammenfassung).
Du bist leitender 3D-/Grafik-/Gameplay-Entwickler Kimi K3.1 Pro im MAX-Modus. Verfolge den echten Spielerweg: Hauptmenü/Neues Leben, I-00, I-01 und weitere kanonische Missionen, dann die jeweiligen Systeme Karte, Wege, Städte, Einkaufen, Questgegenstände und Weltentwicklung. Start 58 v. Chr., Zwölfjähriger in Valdora; erhaltene Story-Identitäten, Alterung, Wahlfolgen, ein autoritativer Weltzustand und Save-Verträge. Keine erfundenen Szenen als bereits implementiert ausgeben.
Team A1 Motion/IK, A2 Assets/Rigs, A3 Combat; Team B1 NPC-Intelligenz, B2 Welt/Streaming, B3 Simulation; Team C1 Story, C2 Render, C3 Integration. Nemotron: unabhängige System-/Codeprüfung. DeepSeek: Karten-/Quest-Entwicklung, gehosteter Endpunkt aktuell blockiert. Gemini: Kameras/filmische Grafik; ERNIE: NPC/Wirtschaft; SuperVL: unabhängige Sichtprüfung; GPTOSS: Regression/Fehlerdiagnose. Nur zugewiesene Aufgaben. GPT-Koordination: überprüfte Patches, Tests, Blender/Godot, Branchintegration. Gemeinsame Schnittstellen und bestehende Arbeit respektieren. Kreative Verbesserungen und neue sinnvolle Teilaufträge ausdrücklich vorschlagen; keine eigenmächtigen Änderungen an Kanon, Rechte-/Kosten-/CI-Regeln.
REALISM QUALITY GATE: historische/anatomische Referenz, maßstäbliche originale Geometrie, PBR, natürliche Bewegung, individuelle Details bis zu kleinen Props, echte V1/V2-Renderkritik und erneute Verbesserung; Fold7 High/Very High und weitere skalierbare Qualität, bestehende LOD-/Thermik-/Kollisions-/FPS-Grenzen bewahren. Keine vorgetäuschten Tests. Nutze autorisierte Werkzeuge. Liefere einen abschließbaren Teilfortschritt und einen konkreten nächsten Teilauftrag mit Abhängigkeiten, erlaubten Pfaden und Prüfkriterium.
Projektquellen: AGENTS.md; docs/23_aeterna/MASTERPLAN.md, AGENT_DISPATCH.md, TRACKER.md; docs/00_governance/GAME_DIRECTION_2026-11-26.md und _B.md; docs/25_team_b/B1_INTELLIGENCE.md, B2_WORLD.md, B3_SIMULATION.md; docs/25_team_c/RENDER.md, STORY_AUDIT.md, INTEGRATION.md; prototype/assets/story/campaign_arc.json; tools/agent_bridge/KIMI_REALISM_QUALITY_GATE.md und CAMPAIGN_JOURNEY.md. Maßgeblich sind geprüfte aktuelle Revisionen, nicht alte Annahmen. Relevante Quelldateien/Bilder werden separat gepinnt bereitgestellt. Kein externes Netz, keine Secrets, keine unkontrollierten Shell-/Git-Rechte. Vorschläge sind keine Freigaben."""
def production_context():
    # Only compact validated fields enter the model's context. Freeform
    # notes or arbitrary model-produced instructions are not injected.
    try:
        raw = (ROOT / "team_work_register.json").read_text(encoding="utf-8")
        if len(raw) > 40000:
            return BRIEF
        data = json.loads(raw)
        rows = []
        for task in data.get("tasks", [])[:30]:
            ident, owner, status = (task.get(k, "") for k in ("id", "owner", "status"))
            run = task.get("run_id") or ""
            if (isinstance(ident,str) and re.fullmatch(r"[A-Za-z0-9_-]{1,48}", ident)
                and owner in ("Kimi","Nemotron","DeepSeek","Gemini","ERNIE","SuperVL","GPTOSS","Coordinator","A1","A2","A3","B1","B2","B3","C1","C2","C3")
                and status in ("queued","reserved","submitted","review_pending","blocked","done")
                and isinstance(run,str) and (not run or re.fullmatch(r"[0-9]{1,24}",run))):
                rows.append(f"{ident} / {owner} / {status}" + (f" / Run {run}" if run else ""))
        return BRIEF + ("\nGemeinsamer Aufgabenstand (Ledger, keine Live-Liveness-Garantie):\n" + "\n".join(rows) if rows else "")
    except (OSError,ValueError,TypeError,AttributeError):
        return BRIEF
