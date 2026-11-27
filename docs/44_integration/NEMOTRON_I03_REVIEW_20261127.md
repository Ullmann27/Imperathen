# Nemotron review 01 – independent integration decision

Source: e1a374f6b40ea16801ea2dc616266eba24c314d1. Nemotron batch run 45994735047, job
140491444966 returned its final answer successfully. Verified from the original
source: main.gd blocks subsequent childhood commands during an active water
interaction; i03_flow_test.gd issues the next command after only two frames.
The failure was observed in ARM64 candidate run 45989915599. This patch changes
only the test driver to wait for the real production completion condition before
fixture placement, with both a simulated-time and frame bound. A stalled water
action still fails the test. All normal I-03 checks are retained.

Not adopted: the proposed case-insensitive prefix change. The existing wildcard
already permits suffixes, and the known old GLB was material-batched. No evidence
establishes case mismatches. The proposed synthetic test also attempts to assign
a Dictionary to a Node3D-typed property. Prefer the actual imported GLB test in
the separate #159 recovery branch. No claim about unobserved device node names,
no percentage estimate of residual risk, no claimed visual acceptance.

The independent workflow reuses the actual original candidate artifact with
source and hash verification, runs Godot, and retains the actual test logs.
It does not stage assets or release an APK. All results remain pending until CI.
