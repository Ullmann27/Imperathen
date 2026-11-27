# NVIDIA Nemotron development bridge

NVIDIA NIM: https://build.nvidia.com/nvidia/nemotron-3-ultra-550b-a55b
API: https://build.nvidia.com/nvidia/nemotron-3-ultra-550b-a55b/apireference

1. Generate an NVIDIA Build API key. Never paste it into a public issue, chat, request JSON or source file.
2. Open https://github.com/Ullmann27/Imperathen/settings/secrets/actions/new
   and save an Actions secret named IMPERATHEN_ROME_NVIDIA or IMPERATHEN_NVIDIA. The bridge also accepts
   spelling variants IMPERATEN_ROME_NVIDIA, IMPERATEN_NVIDIA, IMPERATHENROME_NVIDIA,
   IMPERATENROME_NVIDIA, and the previously used IMPERATUM_NVIDIA or NVIDIA_API_KEY.
   Only the first populated secret is used. No credential value is logged.
3. Rerun the NVIDIA Nemotron engineering bridge job if its initial connection
   failed because no secret was set. Subsequent questions update request.json
   on the dedicated branch; its push triggers the bridge. No main merge.
4. Read answer.md and receipt.json in the artifact or NVIDIA_ANSWER lines in the job log.
   The response is untrusted proposed engineering work; review the patch, implement on a
   separate task branch, run Godot regressions and inspect real images. Never execute model output blindly.

The repository and CI logs/artifacts are public. Only explicitly selected, allowlisted
public source files at an immutable revision are sent to NVIDIA. No game saves,
private user information, secrets or binary assets are sent. API access is subject
to NVIDIA account terms and quotas; no paid endpoint or automatic retry is configured.
The response is not an implementation or verified device result until independently validated.
No API request is issued before a secret is supplied. This is not an in-game NPC service.
