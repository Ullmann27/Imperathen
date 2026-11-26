extends RefCounted
## PROCEDURALLY SYNTHESIZED impact sounds - placeholders pending recorded
## foley. No external audio is downloaded or bundled. Each sound is built
## deterministically from documented components (inharmonic partials for
## struck metal, band-passed noise for wood/leather, low thumps for bodies)
## so the material differences are audible and measurable now. Replace with
## licensed recordings before any release; the ids stay the same.

const RATE := 22050
const SYNTHESIZED := true
const LABEL := "synthesized placeholder pending recorded foley"
const IDS := ["metal_clang", "metal_ring", "wood_chop", "wood_crack", "leather_slap", "mail_rattle", "body_thud", "swish"]
static var _cache: Dictionary = {}


static func stream(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var samples := samples_for(id)
	if samples.is_empty():
		return null
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(int(round(samples[i] * 32767.0)), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.resource_name = id + " (" + LABEL + ")"
	_cache[id] = wav
	return wav


## Normalized mono samples (-1..1, peak 0.9).
static func samples_for(id: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var seed := 0x9e3779b9 ^ id.hash()
	match id:
		"metal_clang":
			# Struck iron: inharmonic plate/bar partials with fast high decay.
			out = _partials(0.55, [[620.0, 1.0, 0.30], [1532.0, 0.7, 0.18], [2380.0, 0.5, 0.12], [3910.0, 0.35, 0.07], [5210.0, 0.2, 0.05]])
			_add(out, _noise(0.012, seed, 0.9, 0.003), 0.6)
		"metal_ring":
			# Bronze boss: lower, longer ringing partials.
			out = _partials(0.9, [[410.0, 1.0, 0.55], [1063.0, 0.6, 0.35], [1889.0, 0.4, 0.22], [2950.0, 0.25, 0.12]])
			_add(out, _noise(0.010, seed, 0.6, 0.003), 0.5)
		"wood_chop":
			out = _bandpass(_noise(0.20, seed, 1.0, 0.045), 900.0, 1.4)
			_add(out, _partials(0.20, [[118.0, 1.0, 0.07], [690.0, 0.45, 0.04], [1130.0, 0.3, 0.03]]), 0.8)
		"wood_crack":
			out = _bandpass(_noise(0.55, seed, 1.0, 0.16), 1200.0, 1.0)
			for k in 5:
				_add_at(out, _bandpass(_noise(0.04, seed + k, 1.0, 0.012), 700.0 + 300.0 * k, 2.0), int(RATE * (0.03 + 0.07 * k)), 0.7)
			_add(out, _partials(0.3, [[95.0, 1.0, 0.12]]), 0.7)
		"leather_slap":
			out = _lowpass(_noise(0.12, seed, 1.0, 0.025), 2200.0)
			_add(out, _partials(0.12, [[180.0, 1.0, 0.05]]), 0.7)
		"mail_rattle":
			out = PackedFloat32Array()
			out.resize(int(RATE * 0.22))
			for k in 9:
				_add_at(out, _partials(0.05, [[3200.0 + 410.0 * k, 1.0, 0.012]]), int(RATE * 0.018 * k), 0.4)
			_add(out, _lowpass(_noise(0.10, seed, 1.0, 0.03), 1500.0), 0.6)
		"body_thud":
			out = _lowpass(_noise(0.16, seed, 1.0, 0.04), 700.0)
			_add(out, _partials(0.16, [[88.0, 1.0, 0.07]]), 1.0)
		"swish":
			out = _swish(0.26, seed)
		_:
			return out
	return _normalize(out, 0.9)


static func _partials(seconds: float, partials: Array) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p: Array in partials:
			v += float(p[1]) * sin(TAU * float(p[0]) * t) * exp(-t / float(p[2]))
		out[i] = v
	return out


## Deterministic white noise (LCG) with an exponential envelope.
static func _noise(seconds: float, seed: int, amplitude: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var state := seed & 0x7fffffff
	for i in n:
		state = (state * 1103515245 + 12345) & 0x7fffffff
		var white := float(state) / float(0x7fffffff) * 2.0 - 1.0
		out[i] = white * amplitude * exp(-float(i) / RATE / decay)
	return out


## Two-pole band-pass (RBJ biquad, constant peak gain).
static func _bandpass(input: PackedFloat32Array, center: float, q: float) -> PackedFloat32Array:
	var w := TAU * center / RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w) / a0
	var a2 := (1.0 - alpha) / a0
	return _biquad(input, b0, 0.0, b2, a1, a2)


static func _lowpass(input: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var w := TAU * cutoff / RATE
	var alpha := sin(w) / (2.0 * 0.707)
	var a0 := 1.0 + alpha
	var c := cos(w)
	return _biquad(input, (1.0 - c) / 2.0 / a0, (1.0 - c) / a0, (1.0 - c) / 2.0 / a0, -2.0 * c / a0, (1.0 - alpha) / a0)


static func _biquad(input: PackedFloat32Array, b0: float, b1: float, b2: float, a1: float, a2: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(input.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in input.size():
		var x := input[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Air rush of a passing blade: band-passed noise whose centre sweeps
## upward then down, under a rise/fall envelope.
static func _swish(seconds: float, seed: int) -> PackedFloat32Array:
	var noise := _noise(seconds, seed, 1.0, 100.0)
	var out := PackedFloat32Array()
	out.resize(noise.size())
	var y1 := 0.0
	var y2 := 0.0
	for i in noise.size():
		var u := float(i) / noise.size()
		var center := 500.0 + 1400.0 * sin(u * PI)
		var w := TAU * center / RATE
		var r := 0.985
		# Two-pole resonator: y[n] = 2r cos(w) y[n-1] - r^2 y[n-2] + (1-r) x[n].
		var y := 2.0 * r * cos(w) * y1 - r * r * y2 + noise[i] * (1.0 - r)
		y2 = y1
		y1 = y
		out[i] = y * sin(u * PI) * sin(u * PI)
	return out


static func _add(target: PackedFloat32Array, source: PackedFloat32Array, gain: float) -> void:
	_add_at(target, source, 0, gain)


static func _add_at(target: PackedFloat32Array, source: PackedFloat32Array, offset: int, gain: float) -> void:
	if offset + source.size() > target.size():
		target.resize(offset + source.size())
	for i in source.size():
		target[offset + i] += source[i] * gain


static func _normalize(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0
	for v in samples:
		top = maxf(top, absf(v))
	if top <= 0.0:
		return samples
	var out := PackedFloat32Array()
	out.resize(samples.size())
	for i in samples.size():
		out[i] = samples[i] * peak / top
	# 4 ms fade-out avoids a click at the end of the buffer.
	var fade := mini(out.size(), int(RATE * 0.004))
	for i in fade:
		out[out.size() - 1 - i] *= float(i) / fade
	return out


## Spectral centroid (Hz) via a coarse DFT - used by tests to verify that
## the material families differ as intended.
static func centroid(samples: PackedFloat32Array) -> float:
	var n := mini(samples.size(), 1024)
	var num := 0.0
	var den := 0.0
	for k in range(1, 128):
		var f := float(k) * RATE / 256.0
		var re := 0.0
		var im := 0.0
		for i in n:
			var phase := TAU * f * i / RATE
			re += samples[i] * cos(phase)
			im -= samples[i] * sin(phase)
		var mag := sqrt(re * re + im * im)
		num += f * mag
		den += mag
	return num / maxf(0.000001, den)
