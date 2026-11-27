# NVIDIA Nemotron development bridge

NVIDIA NIM: https://build.nvidia.com/nvidia/nemotron-3-ultra-550b-a55b
API: https://build.nvidia.com/nvidia/nemotron-3-ultra-550b-a55b/apireference

1. Generate an NVIDIA Build API key. Never paste it into a public issue, chat, request JSON or source file.
2. Open https://github.com/Ullmann27/Imperathen/settings/secrets/actions/new
   and save an Actions secret named IMPERATUM_NVIDIA. The bridge does not need
   any GitHub secret other than this credential.
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
