extends RefCounted
## A bounded, versioned district checkpoint inside the ordinary campaign envelope.
## The immutable string can be shared cheaply by village transaction candidates.
const Life := preload("res://scripts/domain/city_life.gd")
const MAX_RAW := 16 * 1024 * 1024
const MAX_ENCODED := 2 * 1024 * 1024

static func pack_city(state: Dictionary, generation: int, opening_denarii: int) -> Dictionary:
	var raw := JSON.stringify(state, "", true, true).to_utf8_buffer()
	if raw.is_empty() or raw.size() > MAX_RAW:
		return {}
	var encoded := Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_ZSTD))
	if encoded.is_empty() or encoded.length() > MAX_ENCODED:
		return {}
	return {"version": 1, "generation": generation, "opening_denarii": opening_denarii, "bytes": raw.size(), "zstd": encoded}

static func valid_header(record: Variant) -> bool:
	if not record is Dictionary or record.size() != 5 or record.get("version") != 1:
		return false
	if typeof(record.get("opening_denarii")) not in [TYPE_INT, TYPE_FLOAT] or float(record.opening_denarii) != floorf(float(record.opening_denarii)) or absf(float(record.opening_denarii)) > 1.0e10:
		return false
	for key: String in ["generation", "bytes"]:
		var value: Variant = record.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or float(value) != floorf(float(value)) or value < 1:
			return false
	return record.generation < 9007199254740991 and record.bytes <= MAX_RAW and record.get("zstd") is String and not record.zstd.is_empty() and record.zstd.length() <= MAX_ENCODED

static func unpack_city(record: Variant) -> Dictionary:
	if not valid_header(record):
		return {}
	var compressed := Marshalls.base64_to_raw(record.zstd)
	if compressed.is_empty():
		return {}
	var raw := compressed.decompress(int(record.bytes), FileAccess.COMPRESSION_ZSTD)
	if raw.size() != int(record.bytes):
		return {}
	var state: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not Life.validate(state).is_empty():
		return {}
	return state
