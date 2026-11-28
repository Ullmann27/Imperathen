# IMPERATHEN — zusätzliche unabhängige KI-Fachentwickler
Stand 27.11.2026. Nur öffentliche, gepinnte Spielquellen und geprüfte Renderbilder, kein automatisches Ausführen fremder Antworten. Gemeinsames versioniertes Aufgabenregister und echte GitHub-Run-IDs sind verbindlich.

| Agent | API-Modell | Zuständigkeit | Schlüssel |
| --- | --- | --- | --- |
| Gemini | gemini-4-hydrogen | filmische Kameraführung, Grafik-/Animationsanalyse, Android | IMPERATHEN_GEMINI_FREE_API_KEY |
| ERNIE | baidu/ernie-5.5-flash-preview:free | Bewohner, Wirtschaft, Weltsimulation | IMPERATHEN_OPENROUTER_API_KEY oder OPENROUTER_API_KEY |
| SuperVL | nvidia/nemotron-3.5-super-vl:free | unabhängige visuelle Qualität, echte Bildkritik | derselbe OpenRouter-Schlüssel |
| GPTOSS | openai/gpt-oss-120b | fokussierte Regressionen, Fehlerdiagnose, Code | IMPERATHEN_GROQ_FREE_API_KEY |

Schlüssel ausschließlich als GitHub Actions Secrets hinterlegen, nie im Chat oder Repository-Code. Google und Groq dürfen nur ausdrücklich für ein kostenloses, nicht zahlungspflichtiges Projekt/Konto vorgesehene Schlüssel erhalten (der Schlüsselname ist eine Freigabekonvention, keine automatisierte Rechnungsprüfung). Keinen vorhandenen generischen Google-/Groq-Schlüssel ohne Free-Tier-Nachweis übernehmen. Keine Abos oder Billing aktivieren. OpenRouter nutzt feste :free-Modell-IDs plus Nullpreisfilter; keine Modellfallbacks oder bezahlten Tools. Free-Tier-/Rate-Limits und aktuelle Bedingungen gelten. Öffentliche Projektquellen können gemäß Anbieterbedingungen verarbeitet werden; keine privaten Drehbücher, Kontodaten oder Secrets übertragen.

Jeder neue reservierte Auftrag durchläuft genau einen kurzen authentifizierten Probe-POST. Erst bei erwarteter vollständiger Antwort wird genau ein Fachauftrag gesendet. Fehlende Schlüssel, HTTP 401/403/402/410/429/5xx, Timeouts oder abgeschnittene Antworten sind offen zu dokumentieren; keine Blind-Retries, keine kostenpflichtige Route. Der GitHub-Workflow ist nicht automatisch ein funktionsfähiger Modellzugang. Unbekannte POST-Ausgänge nicht erneut abschicken. Nach Schlüsselbereitstellung nur neuen geprüften Dispatch-Commit mit eigenständiger ID und Registerreservation erstellen; bei zuvor eindeutig nicht übermittelter Anfrage kann der ursprüngliche Scope als neuer Auftrag übernommen werden. Keine workflow-Reruns ohne Prüfung. Gemischte Providerfehler dürfen unabhängige Entwicklung nicht blockieren. 

G001 (I-00 Komposition), E001 (NPC-Bedürfnisse), V001 (echte I-01-Sichtprüfung) und O001 (60 Hz Fußkontakt-Diagnose) sind bewusst disjunkte Arbeitsschwerpunkte. Kimi-/DeepSeek-Blocker und Nemotron-Arbeit unverändert erhalten. Kimi / Gemini / ERNIE / SuperVL / GPTOSS / DeepSeek dürfen jeweils nur eine offene reservierte oder abgesendete Anfrage haben; Edit-Leases bleiben über alle Modelle exklusiv. Der Koordinator prüft neue Heads, Referenzen, Testgrenzen und fachliche Qualität vor eigenem Patch, isoliertem CI- und Renderlauf. Bei Free-Tier-Kapazitätsgrenzen keine Umgehung, sondern geprüfte andere Aufgaben bearbeiten.

Offizielle Referenzen:
- https://ai.google.dev/gemini-api/docs/models/gemini-4-hydrogen
- https://ai.google.dev/gemini-api/docs/pricing
- https://openrouter.ai/baidu/ernie-5.5-flash-preview:free
- https://openrouter.ai/nvidia/nemotron-3.5-super-vl:free
- https://openrouter.ai/docs/guides/routing/provider-selection
- https://console.groq.com/docs/reasoning
- https://console.groq.com/docs/rate-limits
