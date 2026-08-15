extends SceneTree
## Locale CSV maintenance. Run headless:
##   godot --headless --path E:\Game\Block --script res://tools/locale_tool.gd
##
## Does two things to every shared/locale/*.csv:
##  1. Drops locale columns that are still completely empty. Godot's CSV
##     importer refuses to emit a .translation for an all-empty column (it
##     errors with "bucket_table_size == 0"), so a column only earns its place
##     once it holds at least one translation. Adding a language = adding a
##     column with content; partly-filled columns are fine and fall back to en.
##  2. Rebuilds the `en_XA` pseudo-locale column from `en` — ~1.8x length with
##     accented letters, for catching layout overflow before translators
##     deliver. Placeholders like {gold} are left untouched.

const LOCALE_DIR := "res://shared/locale"
const PSEUDO := "en_XA"
const KEEP := ["keys", "en", "ko"]  # never dropped, even when empty

## Accented look-alikes so pseudo text stays readable while exercising the
## font fallback — a tofu box here means a missing glyph range.
const MAP := {
	"a": "à", "b": "ƀ", "c": "ç", "d": "ð", "e": "é", "f": "ƒ", "g": "ğ",
	"h": "ĥ", "i": "ï", "j": "ĵ", "k": "ķ", "l": "ł", "m": "ɱ", "n": "ń",
	"o": "ô", "p": "þ", "q": "ɋ", "r": "ř", "s": "ş", "t": "ţ", "u": "ü",
	"v": "ṽ", "w": "ŵ", "x": "ẋ", "y": "ÿ", "z": "ż",
	"A": "Å", "B": "Ɓ", "C": "Ç", "D": "Ð", "E": "É", "F": "Ƒ", "G": "Ğ",
	"H": "Ĥ", "I": "Ï", "J": "Ĵ", "K": "Ķ", "L": "Ł", "M": "Ṁ", "N": "Ń",
	"O": "Ô", "P": "Þ", "Q": "Ɋ", "R": "Ř", "S": "Ş", "T": "Ţ", "U": "Ü",
	"V": "Ṽ", "W": "Ŵ", "X": "Ẋ", "Y": "Ÿ", "Z": "Ż",
}


func _init() -> void:
	for name in DirAccess.get_files_at(LOCALE_DIR):
		if name.ends_with(".csv"):
			_convert(LOCALE_DIR.path_join(name))
	quit()


func _convert(path: String) -> void:
	var rows := _read(path)
	if rows.size() < 2:
		push_error("locale_tool: %s has no rows" % path)
		return
	var header: PackedStringArray = rows[0]
	var body := rows.slice(1)

	# Which columns carry at least one non-empty cell?
	var used := {}
	for row: PackedStringArray in body:
		for i in mini(row.size(), header.size()):
			if row[i].strip_edges() != "":
				used[header[i]] = true

	var cols: Array[String] = []
	for i in header.size():
		var col := header[i]
		if col == PSEUDO:
			continue  # regenerated below, always last
		if col in KEEP or used.has(col):
			cols.append(col)
	cols.append(PSEUDO)

	var en_idx := header.find("en")
	var out: Array[PackedStringArray] = [PackedStringArray(cols)]
	for row: PackedStringArray in body:
		var line := PackedStringArray()
		for col in cols:
			if col == PSEUDO:
				line.append(_pseudo(row[en_idx] if en_idx < row.size() else ""))
			else:
				var i := header.find(col)
				line.append(row[i] if i >= 0 and i < row.size() else "")
		out.append(line)
	_write(path, out)
	var dropped := header.size() - cols.size()
	print("%s: %d keys, %d columns%s" % [path.get_file(), body.size(), cols.size(),
			"  (dropped %d empty)" % dropped if dropped > 0 else ""])


## Accents every letter and pads to ~1.8x, so a string that only just fits in
## English visibly overflows. Text inside {} is a placeholder — left alone.
func _pseudo(src: String) -> String:
	if src.strip_edges() == "":
		return ""
	var out := ""
	var in_ph := false
	for c in src:
		if c == "{":
			in_ph = true
		elif c == "}":
			in_ph = false
		out += c if in_ph or c == "}" else str(MAP.get(c, c))
	# Pad per line so multi-line blocks keep their shape.
	var lines := out.split("\n")
	for i in lines.size():
		var pad := int(lines[i].length() * 0.8)
		lines[i] = "[%s%s]" % [lines[i], "" if pad < 2 else " " + "—".repeat(pad)]
	return "\n".join(lines)


func _read(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("locale_tool: cannot read %s" % path)
		return rows
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() == 1 and line[0] == "":
			continue  # trailing newline
		rows.append(line)
	return rows


func _write(path: String, rows: Array[PackedStringArray]) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("locale_tool: cannot write %s" % path)
		return
	for row in rows:
		f.store_csv_line(row)
