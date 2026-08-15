extends Node
## Localization service: the supported locale list, locale selection/persistence
## and the fallback-aware lookup helper.
##
## Translations live in shared/locale/*.csv (imported as .translation and
## registered in project.godot). See .claude/skills/i18n/SKILL.md for the rules —
## the short version: no user-facing string literals in code, and text drawn with
## draw_string() must be wrapped in tr() by hand (Godot only auto-translates
## Control.text).

## Steam release target: 13 locales. Order is the order shown in the language
## picker. "native" is the language's own name — never translate these.
const LOCALES: Array[Dictionary] = [
	{"code": "en", "native": "English"},
	{"code": "ko", "native": "한국어"},
	{"code": "zh_CN", "native": "简体中文"},
	{"code": "ja", "native": "日本語"},
	{"code": "ru", "native": "Русский"},
	{"code": "es_MX", "native": "Español (LatAm)"},
	{"code": "de", "native": "Deutsch"},
	{"code": "fr", "native": "Français"},
	{"code": "pt_BR", "native": "Português (BR)"},
	{"code": "tr", "native": "Türkçe"},
	{"code": "pl", "native": "Polski"},
	{"code": "it", "native": "Italiano"},
	{"code": "zh_TW", "native": "繁體中文"},
]

const FALLBACK := "en"
## Pseudo-locale for layout testing (~1.8x length + accents). Not shipped —
## hidden from the picker unless the build is a debug build.
const PSEUDO := "en_XA"

signal locale_changed


func _ready() -> void:
	# Dev override: `--locale=de` / `--locale=en_XA` (pseudo). Not persisted, so
	# a layout-test run does not overwrite the player's real choice.
	var forced := _locale_arg()
	if forced != "":
		TranslationServer.set_locale(forced)
		locale_changed.emit()
		return
	apply(GameState.locale)


func _locale_arg() -> String:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--locale="):
			return arg.split("=", true, 1)[1]
	return ""


## Locale codes offered in the settings picker.
func codes() -> PackedStringArray:
	var out := PackedStringArray()
	for l: Dictionary in LOCALES:
		out.append(str(l.code))
	if OS.is_debug_build():
		out.append(PSEUDO)
	return out


func native_name(code: String) -> String:
	for l: Dictionary in LOCALES:
		if l.code == code:
			return str(l.native)
	return "Pseudo (layout test)" if code == PSEUDO else code


func is_supported(code: String) -> bool:
	return code in codes()


## Best supported locale for the player's system, e.g. "zh" -> "zh_CN".
## Falls back to English for the 180-odd languages we do not ship.
func detect() -> String:
	var full := TranslationServer.standardize_locale(OS.get_locale())
	for l: Dictionary in LOCALES:
		if l.code == full:
			return str(l.code)
	# No exact match: fall back to the language part ("pt_PT" -> "pt_BR").
	var lang := full.split("_")[0]
	for l: Dictionary in LOCALES:
		if str(l.code).split("_")[0] == lang:
			return str(l.code)
	return FALLBACK


## Applies a locale (empty string = auto-detect) and persists the choice.
func apply(code: String) -> void:
	var target := code if is_supported(code) else detect()
	TranslationServer.set_locale(target)
	if GameState.locale != code:
		GameState.locale = code
		GameState.save_game()
	locale_changed.emit()


## tr() with an explicit fallback for keys that are not in the CSVs yet.
## Godot returns the key itself when nothing matches, which would put
## "CAT_EYES_ROUND" on screen — this returns the supplied text instead.
## Only for content mid-migration; new strings belong in a CSV.
func t(key: String, fallback: String) -> String:
	var out := tr(key)
	return fallback if out == key else out
