# Audio – Lizenz- und Herkunftsregister

Stand: 26.11.2026 · Branch `feat/voices-lipsync-sfx-20261126`

Alle Modelle liefen **lokal** (CPU, Container ohne GPU). Es wurde kein kostenpflichtiger Dienst genutzt, keine Stimme einer realen Person geklont und kein Schauspieler imitiert. Gewichte liegen **nicht** im Repository; sie werden über die gepinnte Revision von Hugging Face geladen.

## 1. Eingesetzte Modelle (Ausgaben im Repository)

| Zweck | Modell | Lizenz (Fundstelle) | Revision | Gewichte SHA-256 (LFS-OID) |
|---|---|---|---|---|
| Stimmentwurf aus Textbeschreibung | [Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign) | Apache-2.0 (Model Card, Front Matter `license: apache-2.0`) | `5ecdb67327fd37bb2e042aab12ff7391903235d3` | `model.safetensors` 391e8db219f292c515297cdceeb43e4eae67cdde35fa57e79a6a8a532fca0522; `speech_tokenizer/model.safetensors` 836b7b357f5ea43e889936a3709af68dfe3751881acefe4ecf0dbd30ba571258 |
| Sprechen aller Zeilen mit dem entworfenen (synthetischen) Sprecher | [Qwen/Qwen3-TTS-12Hz-1.7B-Base](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-Base) | Apache-2.0 (Model Card) | `fd4b254389122332181a7c3db7f27e918eec64e3` | `model.safetensors` 38fc7fc51c5e776e840414b6fd443962e9411b9654888fd7913e4da643cb857c; Tokenizer wie oben |
| Inferenzpaket | [`qwen-tts` 0.1.1](https://github.com/QwenLM/Qwen3-TTS) | Apache-2.0 (PyPI-Metadaten) | PyPI 0.1.1 | – |

Arbeitsweise „Voice Design then Clone“ laut [Qwen3-TTS-README, Abschnitt „Voice Design then Clone“](https://github.com/QwenLM/Qwen3-TTS#voice-design-then-clone): Der VoiceDesign-Checkpoint erzeugt aus einer **deutschen Personenbeschreibung** einen Referenzsatz; der Base-Checkpoint verwendet ausschließlich diesen synthetischen Satz als Stimmprompt. Es gibt keine menschliche Referenzaufnahme.

Qwen3-TTS bettet nach Model Card und README kein Wasserzeichen ein. Die Trainingsdaten sind in der Model Card nicht offengelegt; das ist ein verbleibendes Herkunftsrisiko des Modells, nicht der Projektdaten (siehe Abschnitt 5).

## 2. Werkzeuge für Prüfung, Ausrichtung und Messung (keine Ausgabe im Spiel enthalten)

| Zweck | Werkzeug | Lizenz | Version/Revision | SHA-256 |
|---|---|---|---|---|
| Phonem-Erkennung für die erzwungene Ausrichtung (CTC) | [facebook/wav2vec2-xlsr-53-espeak-cv-ft](https://huggingface.co/facebook/wav2vec2-xlsr-53-espeak-cv-ft) | Apache-2.0 (Hub-Tag `license:apache-2.0`) | `2c733782da5604684829819a5eb744c193fe9398` | `pytorch_model.bin` 04366b6c8d24099ef313cf02f0e58d26f5dddfda16edbfc8eb2c713d94a9f551 |
| Verständlichkeitsprüfung (ASR-Rücklauf, Wortfehlerrate) | [openai/whisper-small](https://huggingface.co/openai/whisper-small) | Apache-2.0 (Hub-Tag) | `973afd24965f72e36ca33b3055d56a652f456b4d` | `model.safetensors` 1d7734884874f1a1513ed9aa760a4f8e97aaa02fd6d93a3a85d27b2ae9ca596b |
| Deutsche Phonemisierung | eSpeak NG (Ubuntu-Paket) | GPL-3.0-or-later | 1.51+dfsg-12build1 | Paket aus Ubuntu-Archiv |
| F0/Formanten, PSOLA-Altersverschiebung | Praat über [parselmouth](https://github.com/YannickJadoul/Parselmouth) | GPL-3.0 | 0.4.7 | – |
| Lautheit BS.1770 | [pyloudnorm](https://github.com/csteinmetz1/pyloudnorm) | MIT | 0.2.0 | – |
| Ogg-Vorbis-Kodierung | FFmpeg mit libvorbis | LGPL/GPL (Werkzeug), Vorbis BSD | Ubuntu-Paket | – |

Die GPL-Werkzeuge werden nur offline als Programme ausgeführt; ihre Ausgaben (Phonemfolgen, Messwerte, transformierte Audiodaten) unterliegen nicht der GPL, und es wird kein GPL-Code ins Spiel übernommen.

## 3. Eigene Erzeugnisse im Repository

| Pfad | Herkunft | Lizenz |
|---|---|---|
| `prototype/assets/audio/voice/lines/*.ogg` | Ausgabe von Qwen3-TTS (Abschnitt 1), Skript `tools/audio/generate_voices.py`, Seeds und SHA-256 je Zeile in `prototype/assets/audio/voice/manifest.json` | Projektlizenz; Apache-2.0 beschränkt Modellausgaben nicht |
| `prototype/assets/audio/voice/visemes/*.json` | `tools/audio/align_visemes.py` | Projektlizenz |
| `prototype/assets/audio/sfx/**/*.wav` | **Eigene prozedurale Synthese** (`tools/audio/synth_sfx.py`, Seeds und SHA-256 in `sfx_manifest.json`), keine Aufnahmen Dritter | Projektlizenz |
| `tools/audio/*.py`, `prototype/scripts/audio/*.gd` | Eigener Code | Projektlizenz |

## 4. Geprüfte und nicht gewählte Kandidaten

| Kandidat | Ergebnis der Prüfung | Entscheidung |
|---|---|---|
| [ResembleAI/chatterbox](https://huggingface.co/ResembleAI/chatterbox) (Multilingual) | MIT, Deutsch gelistet; README „Built-in PerTh Watermarking“: jede Ausgabe trägt ein unhörbares Wasserzeichen. Zero-Shot über Referenzaufnahme. | Nicht gewählt: Für unterscheidbare Figuren wären CC0-Referenzstimmen nötig; VoiceDesign erzeugt Figuren direkt aus Beschreibungen. Wasserzeichen wäre lizenzrechtlich kein Hindernis. |
| Piper + Thorsten-Voice | Thorsten-Datensatz CC0; nur ein erwachsener männlicher Sprecher (plus Emotionsvariante). | Nicht gewählt für Besetzung (eine Stimme für 15 Figuren), bleibt Ausweichoption für den Erzähler. |
| [Zyphra/Zonos-v0.1-transformer](https://huggingface.co/Zyphra/Zonos-v0.1-transformer) | Apache-2.0 (Hub-Tag); Stimme nur über Referenzaufnahme, kein Entwurf aus Beschreibung. Nicht lokal getestet. | Nicht gewählt (gleiche Referenzfrage wie Chatterbox). |
| [hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) | Apache-2.0; Hub-Metadaten nennen nur Englisch (`language: en`). | Ausgeschlossen. |
| [SWivid/F5-TTS](https://huggingface.co/SWivid/F5-TTS), [coqui/XTTS-v2](https://huggingface.co/coqui/XTTS-v2) | Hub-Tags: `cc-by-nc-4.0` bzw. `coqui-public-model-license` (nicht kommerziell). | Ausgeschlossen. |
| Kenney „Impact Sounds“ (CC0) | Website liefert aus dieser Umgebung HTTP 403. | Nicht geladen; eigene Synthese stattdessen. |
| Sonniss GDC Bundles | Lizenz verbietet Weitergabe als Rohdateien. | Ausgeschlossen (öffentliches Repository). |
| [Rhubarb Lip Sync](https://github.com/DanielSWolf/rhubarb-lip-sync) | MIT; Standard-Erkenner (PocketSphinx) ist englisch, der sprachunabhängige „phonetic“-Modus nutzt den bekannten Text nicht und liefert nur 9 Mundformen. | Nicht gewählt; textgebundene CTC-Ausrichtung auf deutsche eSpeak-Phoneme stattdessen. |

## 5. Verbleibende Herkunftsrisiken

- Qwen3-TTS: Trainingsdaten nicht offengelegt. Die Apache-2.0-Lizenz deckt Nutzung und Weitergabe der Ausgaben, beantwortet aber keine Frage nach der Datenherkunft. Wer das ausschließen will, braucht Aufnahmen mit eigenen Sprechern (siehe Eigentümerentscheidung im Bericht).
- Die Ähnlichkeit einer entworfenen Stimme mit einer realen Person ist nicht vollständig auszuschließen; es wurde keine reale Person beschrieben oder referenziert, und die Beschreibungen nennen nur Alter, Rolle und Klangeigenschaften (`tools/audio/voice_cast.json`).
