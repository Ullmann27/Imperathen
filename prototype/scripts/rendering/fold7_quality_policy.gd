extends RefCounted
## Sustained mobile graphics policy; only the 3D buffer changes. The selected
## quality label, UI resolution, actors, simulation and saved state do not.
## All timings are measured, never substituted with a fabricated temperature.
const P95_TARGET_MS := {"high":19.5,"very_high":37.0}
const GPU_TARGET_MS := {"high":16.67,"very_high":33.34}
const MIN_SCALE := {"high":0.70,"very_high":0.68}
const DROP_STEP := 0.06
const RAISE_STEP := 0.03
const SLOW_WINDOWS := 3
const FAST_WINDOWS := 12
const COOLDOWN_WINDOWS := 5
const MIN_SAMPLES := 45


static func recommended_profile(is_android: bool, gpu_adapter: String) -> String:
	# This is a compatible GPU-family hint, not proof of an exact phone model.
	# A saved user preference always overrides it in the UI.
	var adapter := gpu_adapter.to_lower()
	if is_android and adapter.contains("adreno") and adapter.contains("830"):
		return "high"
	return "balanced"


static func initial(profile: String) -> Dictionary:
	return {"profile":profile,"ratio":1.0,"slow":0,"fast":0,"cooldown":0,
		"windows":0,"reason":"selected_preset"}


static func adaptive(profile: String) -> bool:
	return P95_TARGET_MS.has(profile)


static func step(profile: String, previous: Dictionary, p95_frame_ms: float,
		gpu_render_ms: float, frames: int, foreground: bool) -> Dictionary:
	var next := previous.duplicate(true)
	if not adaptive(profile) or not foreground or frames < MIN_SAMPLES:
		return next
	if not is_finite(p95_frame_ms) or p95_frame_ms <= 0.0 or p95_frame_ms > 1000.0:
		return next
	if str(next.get("profile","")) != profile:
		next = initial(profile)
	var ratio := clampf(float(next.get("ratio",1.0)),float(MIN_SCALE[profile]),1.0)
	var threshold := float(P95_TARGET_MS[profile])
	var gpu_valid := is_finite(gpu_render_ms) and gpu_render_ms > 0.0
	next.windows = int(next.windows)+1
	next.cooldown = maxi(0,int(next.cooldown)-1)
	# A frame rate cap influences whole-frame time. Do not pretend that FPS
	# alone measures available GPU headroom; recovery requires real GPU time.
	var over_budget := p95_frame_ms > threshold
	over_budget = over_budget or (gpu_valid and gpu_render_ms > float(GPU_TARGET_MS[profile])*1.10)
	var recovered_headroom := gpu_valid and gpu_render_ms < float(GPU_TARGET_MS[profile])*0.64
	recovered_headroom = recovered_headroom and p95_frame_ms < threshold*1.04
	if over_budget:
		next.slow = int(next.slow)+1
		next.fast = 0
	elif recovered_headroom:
		next.fast = int(next.fast)+1
		next.slow = 0
	else:
		next.slow = 0
		next.fast = 0
	if int(next.cooldown) == 0 and int(next.slow) >= SLOW_WINDOWS and ratio > float(MIN_SCALE[profile])+0.0001:
		next.ratio = maxf(float(MIN_SCALE[profile]),ratio-DROP_STEP)
		next.cooldown = COOLDOWN_WINDOWS
		next.slow = 0
		next.fast = 0
		next.reason = "sustained_frame_pressure"
	elif int(next.cooldown) == 0 and int(next.fast) >= FAST_WINDOWS and ratio < 0.9999:
		next.ratio = minf(1.0,ratio+RAISE_STEP)
		next.cooldown = COOLDOWN_WINDOWS
		next.fast = 0
		next.slow = 0
		next.reason = "measured_gpu_headroom"
	else:
		next.ratio = ratio
	return next


static func effective_render_scale(base_scale: float, governor: Dictionary) -> float:
	return clampf(base_scale*float(governor.get("ratio",1.0)),0.25,1.0)
