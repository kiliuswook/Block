extends Control
## 세로 화면 아래 터치 존의 바닥판(데크). 우물과 용암이 이 뒤까지 내려오므로
## 불투명하게 깔고, 위 하늘보다 한 톤 깊은 파랑 + 발바닥 무늬 + 두꺼운 잉크
## 윗선으로 "조작대"처럼 보이게 한다. 버튼(흰 카드)이 그 위에서 도드라진다.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const TOP := Color("6fb5e2")
const BOTTOM := Color("4f9bd0")
const PAW := Color(1.0, 1.0, 1.0, 0.10)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size,
			Vector2(0.0, size.y)]), PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260903
	var cols := maxi(4, int(size.x / 170.0))
	var rows := maxi(2, int(size.y / 170.0))
	for gy in rows + 1:
		for gx in cols + 1:
			var jitter := Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-40.0, 40.0))
			var at := Vector2((gx + 0.5) * size.x / cols, (gy + 0.5) * size.y / rows) + jitter
			UiKit.paw(self, at, rng.randf_range(20.0, 30.0), PAW, rng.randf_range(-0.5, 0.5))
	# 윗선: 잉크 + 그 아래 흰 하이라이트 한 줄 (빛은 위에서).
	draw_rect(Rect2(0.0, 0.0, size.x, 6.0), UiKit.INK)
	draw_rect(Rect2(0.0, 6.0, size.x, 3.0), Color(1.0, 1.0, 1.0, 0.45))
