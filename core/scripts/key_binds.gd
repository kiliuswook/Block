extends RefCounted
## 키보드·게임패드 바인딩 표와 저장/적용.
##
## class_name 없이 preload로 쓴다:
##     const KeyBinds := preload("res://core/scripts/key_binds.gd")
##
## 저장은 GameState.keybinds / GameState.padbinds (save.json).
## 키는 `<액션>#<슬롯>` 문자열 — 슬롯은 그 액션에 달린 **키 이벤트 중 몇 번째**인가다.
## 한 액션이 두 좌석을 겸하는 자리가 있어서(예: rotate_cw = X(싱글) + .(2P))
## 슬롯까지 있어야 행을 구분할 수 있다.

# --- 행 정의 ------------------------------------------------------------------
# {"act": 액션 이름, "slot": 키 이벤트 인덱스, "label": 번역 키}

## 싱글 플레이 조작 (기본 액션 세트).
const SINGLE := [
	{"act": "move_left", "slot": 0, "label": "SET_ACT_MOVE_LEFT"},
	{"act": "move_right", "slot": 0, "label": "SET_ACT_MOVE_RIGHT"},
	{"act": "jump", "slot": 1, "label": "SET_ACT_JUMP"},
	{"act": "dash", "slot": 0, "label": "SET_ACT_DASH"},
	{"act": "soft_drop", "slot": 0, "label": "SET_ACT_SOFT_DROP"},
	{"act": "rotate_ccw", "slot": 0, "label": "SET_ACT_ROT_CCW"},
	{"act": "rotate_cw", "slot": 0, "label": "SET_ACT_ROT_CW"},
	{"act": "pause", "slot": 0, "label": "SET_ACT_PAUSE"},
]

## 분할 화면 왼쪽 좌석(1P) — 좌석 배치가 곧 키보드 배치라 `p2_*` 액션이 왼쪽이다.
const P1 := [
	{"act": "p2_left", "slot": 0, "label": "SET_ACT_MOVE_LEFT"},
	{"act": "p2_right", "slot": 0, "label": "SET_ACT_MOVE_RIGHT"},
	{"act": "p2_jump", "slot": 0, "label": "SET_ACT_JUMP"},
	{"act": "p2_dash", "slot": 0, "label": "SET_ACT_DASH"},
	{"act": "p2_drop", "slot": 0, "label": "SET_ACT_SOFT_DROP"},
	{"act": "p2_rot_ccw", "slot": 0, "label": "SET_ACT_ROT_CCW"},
	{"act": "p2_rot_cw", "slot": 0, "label": "SET_ACT_ROT_CW"},
]

## 분할 화면 오른쪽 좌석(2P) — 기본 액션의 두 번째 키 자리를 쓴다.
## 이동·대시·낙하는 키가 하나뿐이라 싱글과 같은 자리를 공유한다 (기획서도 동일).
const P2 := [
	{"act": "move_left", "slot": 0, "label": "SET_ACT_MOVE_LEFT"},
	{"act": "move_right", "slot": 0, "label": "SET_ACT_MOVE_RIGHT"},
	{"act": "jump", "slot": 0, "label": "SET_ACT_JUMP"},
	{"act": "dash", "slot": 0, "label": "SET_ACT_DASH"},
	{"act": "soft_drop", "slot": 0, "label": "SET_ACT_SOFT_DROP"},
	{"act": "rotate_ccw", "slot": 1, "label": "SET_ACT_ROT_CCW"},
	{"act": "rotate_cw", "slot": 1, "label": "SET_ACT_ROT_CW"},
]

## 게임패드 행. `fixed`는 재설정 불가(스틱·D-pad 이동).
const PAD := [
	{"act": "", "label": "SET_ACT_MOVE", "fixed": true},
	{"act": "jump", "label": "SET_ACT_JUMP"},
	{"act": "dash", "label": "SET_ACT_DASH"},
	{"act": "soft_drop", "label": "SET_ACT_SOFT_DROP"},
	{"act": "rotate_ccw", "label": "SET_ACT_ROT_CCW"},
	{"act": "rotate_cw", "label": "SET_ACT_ROT_CW"},
	{"act": "pause", "label": "SET_ACT_PAUSE"},
]

## 패드 기본값. {"t": "b" 버튼 / "a" 축, "i": 인덱스}
const PAD_DEFAULTS := {
	"jump": {"t": "b", "i": JOY_BUTTON_A},
	"dash": {"t": "b", "i": JOY_BUTTON_X},
	"soft_drop": {"t": "a", "i": JOY_AXIS_TRIGGER_RIGHT},
	"rotate_ccw": {"t": "b", "i": JOY_BUTTON_LEFT_SHOULDER},
	"rotate_cw": {"t": "b", "i": JOY_BUTTON_RIGHT_SHOULDER},
	"pause": {"t": "b", "i": JOY_BUTTON_START},
}

## 항상 붙는 패드 이동 바인딩 (기획서의 "LS + D-pad (고정)").
const PAD_FIXED := {
	"move_left": [{"t": "a", "i": JOY_AXIS_LEFT_X, "d": -1},
			{"t": "b", "i": JOY_BUTTON_DPAD_LEFT}],
	"move_right": [{"t": "a", "i": JOY_AXIS_LEFT_X, "d": 1},
			{"t": "b", "i": JOY_BUTTON_DPAD_RIGHT}],
	"soft_drop": [{"t": "b", "i": JOY_BUTTON_DPAD_DOWN}],
}

## 재설정으로 잡을 수 없는 키 (창 조작·되돌리기용).
const RESERVED := [KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6,
	KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]

## 프로젝트 기본 키 — 처음 apply_all() 때 InputMap 원본에서 한 번만 읽어 캐시한다.
static var _defaults: Dictionary = {}


## 행 하나의 저장 키.
static func slot_key(row: Dictionary) -> String:
	return "%s#%d" % [row.act, row.slot]


## 모든 행의 기본 키코드 {슬롯 키: physical_keycode}.
static func defaults() -> Dictionary:
	if _defaults.is_empty():
		for row: Dictionary in SINGLE + P1 + P2:
			var k := slot_key(row)
			if not _defaults.has(k):
				_defaults[k] = _read_key(str(row.act), int(row.slot))
	return _defaults


## 저장된 바인딩(없으면 기본값)에서 이 행의 키코드.
static func code_of(binds: Dictionary, row: Dictionary) -> int:
	var k := slot_key(row)
	return int(binds.get(k, defaults().get(k, 0)))


## 저장된 바인딩(없으면 기본값)에서 이 액션의 패드 버튼.
static func pad_of(pads: Dictionary, act: String) -> Dictionary:
	var v: Variant = pads.get(act, PAD_DEFAULTS.get(act, {}))
	return v if v is Dictionary else {}


## 저장된 키·패드 바인딩을 InputMap에 통째로 반영한다.
## GameState가 세이브를 읽은 직후 한 번, 설정에서 바꿀 때마다 다시 부른다.
static func apply_all(binds: Dictionary, pads: Dictionary) -> void:
	var d := defaults()  # 먼저 원본을 캐시 (덮어쓰기 전에!)
	for k: String in d:
		var parts := k.split("#")
		_set_key(parts[0], int(parts[1]), int(binds.get(k, d[k])))
	for act: String in PAD_DEFAULTS:
		_clear_pad(act)
	for act: String in PAD_FIXED:
		_clear_pad(act)
	for act: String in PAD_FIXED:
		for b: Dictionary in PAD_FIXED[act]:
			_add_pad(act, b)
	for act: String in PAD_DEFAULTS:
		var b := pad_of(pads, act)
		if not b.is_empty():
			_add_pad(act, b)


# --- 표시용 이름 --------------------------------------------------------------


## 키캡에 찍을 짧은 이름. 언어와 무관한 기호/영문이라 번역하지 않는다.
static func key_name(code: int) -> String:
	match code:
		0:
			return "—"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_SPACE:
			return "SPACE"
		KEY_SHIFT:
			return "SHIFT"
		KEY_CTRL:
			return "CTRL"
		KEY_ALT:
			return "ALT"
		KEY_ENTER:
			return "ENTER"
		KEY_TAB:
			return "TAB"
		KEY_BACKSPACE:
			return "BACK"
		KEY_COMMA:
			return ","
		KEY_PERIOD:
			return "."
		KEY_SLASH:
			return "/"
		KEY_SEMICOLON:
			return ";"
	var s := OS.get_keycode_string(code)
	return s.to_upper() if s != "" else "?"


## 패드 버튼 이름 (A / X / LB / RT / …).
static func pad_name(b: Dictionary) -> String:
	if b.is_empty():
		return "—"
	if str(b.get("t", "b")) == "a":
		match int(b.get("i", 0)):
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "LS"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "RS"
		return "AXIS"
	match int(b.get("i", 0)):
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return "≡"
		JOY_BUTTON_START:
			return "≡"
		JOY_BUTTON_LEFT_STICK:
			return "LS"
		JOY_BUTTON_RIGHT_STICK:
			return "RS"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_UP:
			return "↑"
		JOY_BUTTON_DPAD_DOWN:
			return "↓"
		JOY_BUTTON_DPAD_LEFT:
			return "←"
		JOY_BUTTON_DPAD_RIGHT:
			return "→"
	return "B%d" % int(b.get("i", 0))


# --- InputMap 조작 ------------------------------------------------------------


static func _read_key(act: String, slot: int) -> int:
	if not InputMap.has_action(act):
		return 0
	var n := 0
	for e: InputEvent in InputMap.action_get_events(act):
		if e is InputEventKey:
			if n == slot:
				return (e as InputEventKey).physical_keycode
			n += 1
	return 0


static func _set_key(act: String, slot: int, code: int) -> void:
	if not InputMap.has_action(act) or code == 0:
		return
	var out: Array[InputEvent] = []
	var n := 0
	var done := false
	for e: InputEvent in InputMap.action_get_events(act):
		if e is InputEventKey:
			if n == slot:
				out.append(_key_event(code))
				done = true
			else:
				out.append(e)
			n += 1
		else:
			out.append(e)
	if not done:
		out.append(_key_event(code))
	InputMap.action_erase_events(act)
	for e: InputEvent in out:
		InputMap.action_add_event(act, e)


static func _key_event(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _clear_pad(act: String) -> void:
	if not InputMap.has_action(act):
		return
	for e: InputEvent in InputMap.action_get_events(act):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			InputMap.action_erase_event(act, e)


static func _add_pad(act: String, b: Dictionary) -> void:
	if not InputMap.has_action(act):
		return
	if str(b.get("t", "b")) == "a":
		var m := InputEventJoypadMotion.new()
		m.axis = int(b.get("i", 0))
		m.axis_value = float(b.get("d", 1))
		InputMap.action_add_event(act, m)
	else:
		var j := InputEventJoypadButton.new()
		j.button_index = int(b.get("i", 0))
		InputMap.action_add_event(act, j)
