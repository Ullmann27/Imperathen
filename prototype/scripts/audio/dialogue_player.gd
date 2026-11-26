extends Node
## Plays one dialogue line: voice audio, subtitle and mouth track share ONE
## clock (seconds since the line became audible).
##
## Clock: while the audio device is mixing, the clock is the stream playback
## position plus the time since the last mix minus the output latency (Godot's
## recommended audio-synchronisation formula). The audio clock only counts as
## alive once the playback position has advanced at least twice and changed
## within the last 0.25 s; otherwise (before the first mixes, or on a device
## that stalls such as the headless dummy driver) frame time continues from the
## last audio reading. The clock is monotonic per line. `line_started` (subtitle on) fires on
## the first frame of the line's clock; face drivers sample the same value later
## in that frame (this node processes first).
##
## Unvoiced lines (no manifest entry) still show their subtitle with a
## reading-time duration, so missing recordings never block the story.

const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const AudioBuses = preload("res://scripts/audio/audio_buses.gd")

signal line_started(line: Dictionary)
signal line_finished(line: Dictionary)

## Attenuation for positional voices: full level within 2 m, -6 dB/doubling.
const UNIT_SIZE := 2.0
const MAX_DISTANCE := 40.0

var face: Node = null
var current: Dictionary = {}
var clock_source := "none"

var _player: Node = null
var _frame_time := 0.0
var _last_clock := 0.0
var _started := false
var _duration := 0.0
var _latency := 0.0
var _last_pos := -1.0
var _pos_changes := 0
var _last_pos_change := 0.0
var _last_mix_clock := 0.0


func _init() -> void:
	# Advance the clock before any face driver samples it in the same frame.
	process_priority = -100


func _ready() -> void:
	AudioBuses.ensure_layout()


## Starts a line. emitter: a Node3D for positional speech, null for 2D (narrator).
## mouth_height: emitter-local height of the mouth (adult ~1.55 m, 12-year-old ~1.30 m).
## Returns the line record (voiced or unvoiced).
func play(text: String, speaker_label: String, emitter: Node3D = null, mouth_height := 1.55) -> Dictionary:
	return _start(VoiceLines.find(text), text, speaker_label, emitter, mouth_height)


## Plays a manifest line by id (barks of the NPC pool, hero age stages).
func play_line_id(line_id: String, emitter: Node3D = null, mouth_height := 1.55) -> Dictionary:
	var entry := VoiceLines.find_line_id(line_id)
	return _start(entry, str(entry.get("text", "")), str(entry.get("speaker_id", "")), emitter, mouth_height)


func _start(entry: Dictionary, text: String, speaker_label: String, emitter: Node3D, mouth_height: float) -> Dictionary:
	stop()
	current = {"text": text, "speaker": speaker_label, "voiced": not entry.is_empty(),
		"line_id": str(entry.get("line_id", "")), "speaker_id": VoiceLines.speaker_id(speaker_label)}
	_frame_time = 0.0
	_last_clock = 0.0
	_started = false
	_last_pos = -1.0
	_pos_changes = 0
	_last_pos_change = 0.0
	_last_mix_clock = 0.0
	_latency = AudioServer.get_output_latency()
	var stream: AudioStream = VoiceLines.stream_for(entry) if current.voiced else null
	if stream != null:
		_duration = stream.get_length()
		if emitter != null:
			var p3 := AudioStreamPlayer3D.new()
			p3.unit_size = UNIT_SIZE
			p3.max_distance = MAX_DISTANCE
			p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			p3.attenuation_filter_cutoff_hz = 9000.0
			p3.attenuation_filter_db = -6.0
			p3.position = Vector3(0.0, mouth_height, 0.0)
			emitter.add_child(p3)
			_player = p3
		else:
			var p2 := AudioStreamPlayer.new()
			add_child(p2)
			_player = p2
		_player.stream = stream
		_player.bus = AudioBuses.VOICE
		_player.play()
		if is_instance_valid(face):
			face.set_track(VoiceLines.viseme_track(entry), clock)
	else:
		current.voiced = false
		# Reading time ~15 characters per second, at least 2.5 s.
		_duration = maxf(2.5, text.length() / 15.0)
	# The subtitle belongs to the moment play() schedules the stream.
	# Waiting for _process can leave the first displayed frame without text.
	_started = true
	line_started.emit(current)
	return current


func stop() -> void:
	if _player != null and is_instance_valid(_player):
		_player.stop()
		_player.stream = null
		_player.queue_free()
	_player = null
	if is_instance_valid(face):
		face.clear()
	if not current.is_empty() and _started:
		line_finished.emit(current)
	current = {}
	_started = false


func set_paused(paused: bool) -> void:
	set_process(not paused)
	if is_instance_valid(_player):
		_player.stream_paused = paused
	if is_instance_valid(face):
		face.set_process(not paused)


func is_active() -> bool:
	return not current.is_empty()


## Seconds since the line became audible (negative before that).
func clock() -> float:
	if not is_processing():
		return _last_clock
	var t := _frame_time
	clock_source = "frame"
	# The dummy mixer still owns the stream for pause/resume and lifetime.
	# Its wall clock cannot pace a fixed-step simulation without audio output.
	if AudioServer.get_driver_name() != "Dummy" and is_instance_valid(_player) and _player.playing:
		var pos: float = _player.get_playback_position()
		if pos != _last_pos:
			_last_pos = pos
			_pos_changes += 1
			_last_pos_change = _frame_time
			_last_mix_clock = maxf(_last_clock, pos - _latency)
		if _pos_changes >= 2:
			var since_change := _frame_time - _last_pos_change
			if since_change < 0.25:
				t = pos + AudioServer.get_time_since_last_mix() - _latency
				clock_source = "audio"
			else:
				t = _last_mix_clock + since_change
	t = maxf(t, _last_clock)
	_last_clock = t
	return t


func _process(delta: float) -> void:
	if current.is_empty():
		return
	_frame_time += delta
	var t := clock()
	if _started and t >= _duration:
		stop()
