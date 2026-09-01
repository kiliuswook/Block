extends Control
## 무한의 계단 골드러시 게이지. 평소에는 다음 러시까지 얼마나 찼는지를(줄 클리어·
## 콤보·금 캐기·발끝 세이브로만 찬다) 보여 주고, 발동 중에는 같은 바가 금색으로
## 가득 차 남은 시간만큼 줄어든다. 계기판의 다른 줄과 같이 흰 카드 위에 서므로
## 글자는 잉크/골드다 — 어두운 배경용 크림색 + 외곽선은 쓰지 않는다.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const BAR_H := 22.0
const CAPTION_H := 24.0
const TRACK := Color(UiKit.INK, 0.10)  # 흰 카드에 파 놓은 홈

var gauge := 0.0  # 0..1 — 다음 러시까지
var time_left := 0.0  # 발동 중 남은 시간 (초, 0 = 꺼짐)
var full_time := 1.0  # 발동 지속 시간 — 바의 기준
var _pulse := 0.0


func _ready() -> void:
	EventBus.goldrush_changed.connect(_on_changed)
	set_process(false)


func _on_changed(g: float, left: float) -> void:
	if left > 0.0:
		if time_left <= 0.0:
			full_time = maxf(left, 0.01)
		time_left = left
		gauge = 1.0
		set_process(true)
	else:
		time_left = 0.0
		gauge = clampf(g, 0.0, 1.0)
		set_process(false)
		_pulse = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var on := time_left > 0.0
	var font := ThemeDB.fallback_font
	var label := tr("HUD_GOLDRUSH") if on else tr("HUD_RUSH_GAUGE")
	var col := UiKit.GOLD if on else Color(UiKit.INK, 0.55)
	if on:
		# 발동 중엔 제목이 맥동한다 — 남은 10초가 눈에 띄어야 한다.
		col.a = 0.65 + 0.35 * sin(_pulse * 9.0)
	draw_string(font, Vector2(0.0, CAPTION_H - 6.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	var track := Rect2(0.0, CAPTION_H, size.x, BAR_H)
	draw_rect(track, TRACK)
	var fill := clampf(time_left / full_time, 0.0, 1.0) if on else gauge
	if fill > 0.0:
		var r := Rect2(track.position, Vector2(track.size.x * fill, track.size.y))
		draw_rect(r, UiKit.GOLD if on else UiKit.ORANGE)
		# 위에서 오는 빛: 채운 띠의 윗면만 밝힌다 (게임 전체와 같은 규칙).
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.34)),
				Color(1, 1, 1, 0.28))
	draw_rect(track, Color(UiKit.INK, 0.35), false, 2.0)
