# Independent review: Nemotron frame pacing, candidate implementation

Base e1a374f6b40ea16801ea2dc616266eba24c314d1; Nemotron job 140491445117 in run 45994735047.
Confirmed from the production source: frame wall intervals were collected each
process callback, but GPU and render-CPU timing was read once per second; a
single GPU observation then drove a rolling frame-time window. The model's
proposed diff did not clear the ring buffer after each normal decision and
contained undefined names and tests incompatible with its changed thresholds.

This patch keeps the existing 30/60 FPS caps, four graphics profiles,
3/12/5 decision thresholds, minimum scale, native UI, and public policy
signature. It separates one-second diagnostic intervals from disjoint
two-second governor windows, with bounded collection, minimum 80% timing
coverage, and conservative behavior when observations are unavailable.
A clearly under-budget observed GPU holds resolution during frame-wall pressure;
this does not prove a CPU bottleneck. GPU measurements are latest reported
observations, not matched unique GPU-frame IDs. No unmeasured thermal value
or CPU time inferred from subtraction is reported. Recovery still requires
observed GPU headroom as in the existing contract. No renderer switch.

Existing deterministic policy/lifecycle tests are retained, with extra
coverage, percentile, disjoint-window and 30 FPS assertions. The debug
Android one-second ADB telemetry contract remains. No claimed physical
Fold7 FPS, thermal benefit, visual approval, or APK release. Full Godot
and real-device validation remains mandatory.