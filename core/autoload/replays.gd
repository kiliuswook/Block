extends Node
## Replay storage: the local best-run replay per mode, plus the encoding used
## to ship replays inside leaderboard entries (var_to_bytes → gzip → base64).
## A replay is a Dictionary — see EscapeBoard.rec_export().

const DIR := "user://"


func _path(mode_key: String) -> String:
	return DIR + "replay_%s.dat" % mode_key


func save_replay(mode_key: String, data: Dictionary) -> void:
	if data.is_empty():
		return
	var f := FileAccess.open(_path(mode_key), FileAccess.WRITE)
	if f:
		f.store_var(data)


func has_replay(mode_key: String) -> bool:
	return FileAccess.file_exists(_path(mode_key))


## Deletes every saved best-run replay. Used by 설정 > 게임 초기화.
func clear_all() -> void:
	for m: String in Ranks.MODES:
		if has_replay(m):
			DirAccess.remove_absolute(_path(m))


func load_replay(mode_key: String) -> Dictionary:
	if not has_replay(mode_key):
		return {}
	var f := FileAccess.open(_path(mode_key), FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = f.get_var()
	return data if data is Dictionary else {}


## Compact wire format for leaderboard entries. "" when too big to attach.
func encode(data: Dictionary, max_b64 := 90000) -> String:
	if data.is_empty():
		return ""
	var packed := var_to_bytes(data).compress(FileAccess.COMPRESSION_GZIP)
	var b64 := Marshalls.raw_to_base64(packed)
	return b64 if b64.length() <= max_b64 else ""


func decode(b64: String) -> Dictionary:
	if b64 == "":
		return {}
	var packed := Marshalls.base64_to_raw(b64)
	if packed.is_empty():
		return {}
	var raw := packed.decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return {}
	var data: Variant = bytes_to_var(raw)
	return data if data is Dictionary else {}
