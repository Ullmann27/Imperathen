extends RefCounted
## Independent test-walk positions, never campaign state.
const PATH := "user://imperathen_city_exploration.json"
const FORMAT := "imperathen-city-exploration"
const SPAWN := Vector3(0, 0.92, 24)
const LIMIT := 700.0
const MAX_BYTES := 4096

static func defaults() -> Dictionary:
	return {"position":SPAWN,"heading":0.0,"yaw":0.0,"pitch":-0.18,"distance":4.2,"running":false}

static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format","") != FORMAT or value.get("version",0) != 1:
		return {}
	var point: Variant = value.get("position",[])
	if not point is Array or point.size() != 3:
		return {}
	for coordinate: Variant in point:
		if not _number(coordinate):
			return {}
	var position := Vector3(point[0],point[1],point[2])
	if absf(position.x)>LIMIT or absf(position.z)>LIMIT or position.y < -0.1 or position.y > 80.0:
		return {}
	for key: String in ["heading","yaw","pitch","distance"]:
		if not _number(value.get(key)):
			return {}
	if not value.get("running") is bool:
		return {}
	if float(value.distance)<1.6 or float(value.distance)>8.0 or absf(float(value.pitch))>1.2:
		return {}
	return {"position":position,"heading":wrapf(float(value.heading),-PI,PI),
		"yaw":wrapf(float(value.yaw),-PI,PI),"pitch":clampf(float(value.pitch),-0.75,0.65),
		"distance":float(value.distance),"running":bool(value.running)}

static func read(path: String = PATH) -> Dictionary:
	for candidate: String in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate,FileAccess.READ)
		if file==null or file.get_length()>MAX_BYTES:
			continue
		var state := _decode_text(file.get_as_text())
		if not state.is_empty():
			return state
	return defaults()

static func write(state: Dictionary,path: String = PATH) -> Error:
	var point: Vector3 = state.get("position",SPAWN)
	var data := {"format":FORMAT,"version":1,"position":[point.x,point.y,point.z],
		"heading":state.get("heading",0.0),"yaw":state.get("yaw",0.0),"pitch":state.get("pitch",-0.18),
		"distance":state.get("distance",4.2),"running":state.get("running",false)}
	if decode(data).is_empty():
		return ERR_INVALID_DATA
	path = ProjectSettings.globalize_path(path)
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK:
		return error
	if _decode_text(FileAccess.get_file_as_string(temporary)).is_empty():
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		var previous := FileAccess.open(path,FileAccess.READ)
		if previous!=null and previous.get_length()<=MAX_BYTES and not _decode_text(previous.get_as_text()).is_empty():
			previous.close()
			var backup_error := DirAccess.copy_absolute(path,path+".bak.tmp")
			if backup_error!=OK:
				return backup_error
			backup_error = DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
			if backup_error!=OK:
				return backup_error
	return DirAccess.rename_absolute(temporary,path)

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _decode_text(text: String) -> Dictionary:
	var parser := JSON.new()
	return decode(parser.data) if parser.parse(text)==OK else {}
