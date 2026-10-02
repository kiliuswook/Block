extends RefCounted
## 고양이 파츠 카탈로그 — 컨셉 시트(Char01~Char06)의 레이어 구성을 그대로 옮긴 것.
##
## 모든 고양이는 "파츠 묶음"일 뿐이다. CHARS가 디자인된 6마리의 기본 파츠와
## 해금 단계(키캡 도감을 한 바퀴 완성할 때마다 1st → 2nd → 3rd 파츠)를 담고,
## PARTS는 그 파츠들을 커스터마이저에서 자유롭게 갈아끼우는 목록이다.
## 커스터마이징은 캐릭터마다 따로 저장된다 — GameState.cat_custom[cat_id]에
## {부위 key: 옵션 index}로 손댄 부위만 담기고, apply_sel()이 그 캐릭터의
## 기본 파츠 위에 덮어쓴 뒤 build_skin()이 CatArt가 읽는 skin으로 바꾼다.
## 스타일 옵션의 "r"은 희귀도(0 일반~3 전설, 표시용), "d"는 플레이버 텍스트.
## (class_name 없이 preload로 참조 — 전역 클래스 캐시 갱신 불필요)

## 시트 파츠 배치표 — 나만의 캐릭터가 어떤 레이어를 빌릴 수 있는지 확인한다.
const CatLayouts := preload("res://core/scripts/cat_layouts.gd")
## 히든 파츠 세트 배치표 — 옵션의 "src"가 세트 id(hidden_a01 …)를 가리킬 수 있다.
const HiddenLayouts := preload("res://core/scripts/hidden_layouts.gd")
## 신규 냥이 10종(char07~16)의 배치표 — tools/gen_cat_layers.py 자동 생성.
const GenLayouts := preload("res://core/scripts/gen_layouts.gd")

const RARITY_NAMES: Array[String] = ["CAT_RARITY_0", "CAT_RARITY_1",
		"CAT_RARITY_2", "CAT_RARITY_3"]
const RARITY_COLS: Array[Color] = [
	Color(1, 1, 1, 0.75), Color(0.45, 0.8, 1.0),
	Color(0.78, 0.55, 1.0), Color(1.0, 0.85, 0.35),
]

## 팔레트 — 시트가 실제로 쓰는 색만 담는다. 캐릭터가 늘면 그 냥이의 색을
## 여기에 한 줄 더 붙이는 것으로 커스터마이징 선택지가 함께 늘어난다.
const BODY_COLS: Array[Color] = [  # Cat_Body_SkinFill
	Color("fbf6ee"), Color("2f2c33"), Color("f0932b"),
	Color("f0e2d0"), Color("aeb6c2"),
	# 신규 10종 (char07~16) — 흰 몸(화가·비·젖소)은 위의 fbf6ee를 같이 쓴다
	Color("fdecad"), Color("c48a41"), Color("8fa6c2"), Color("2d3543"),
	Color("fddae2"), Color("d6c7ed"), Color("f0c164"),
]
const EAR_COLS: Array[Color] = [  # Cat_Body_Pattern / Cat_Tail_Pattern (귀·꼬리)
	Color("e8d9c8"), Color("f3b53f"), Color("26232c"), Color("d0781c"),
	Color("f0e2d8"), Color("5a4038"), Color("7e8694"),
]
const PATTERN_COLS: Array[Color] = [  # 같은 Pattern 레이어의 무늬 몫
	Color("fbf6ee"), Color("d0781c"), Color("6b4a3a"), Color("7e8694"),
]
const EYE_COLS: Array[Color] = [  # Cat_Eyes_Color
	Color("241f28"), Color("f0c53a"),
]
const PAD_COLS: Array[Color] = [  # Cat_Feet_Pawpad
	Color("fdfbf8"), Color("fe856d"), Color("fe9883"), Color("fdb3a2"),
	Color("d2a08c"),
	Color("fb6ba1"), Color("f38088"), Color("fd9ea4"),  # 신규 10종
]
const CHEEK_COLS: Array[Color] = [Color("feb8ad")]  # Cat_Cheek
const WHISKER_COLS: Array[Color] = [Color("2c2a33")]  # Cat_Whiskers
const MOUTH_COLS: Array[Color] = [  # Cat_Mouse
	Color("2c2a33"), Color("eb6000"), Color("f39e63"), Color("6e5546"),
]
const NOSE_COLS: Array[Color] = [Color("e58a86")]  # Cat_Nose

## 부위 목록 — 컨셉 시트의 레이어 슬롯과 1:1이다. 시트에 없는 슬롯은 만들지 않고,
## 시트에 없는 모양은 옵션으로 넣지 않는다 (그림이 없으면 고를 수 없다).
## 슬롯 순서 = 시트의 레이어 순서(뒤 → 앞).
## type "color"는 cols 팔레트에서, "style"은 opts에서 고른다. index 0이 기본값.
## 옵션의 "r"은 희귀도(0 일반~3 전설, 표시용), "d"는 플레이버 텍스트.
## "u": true = **유니크 파츠** — 골드로는 살 수 없고 통조림 캔으로만 산다
## (캔은 주간 랭킹 보상으로만 들어온다). 판정은 is_unique_option().
const PARTS: Array[Dictionary] = [
	# --- Prop_Back ------------------------------------------------------------
	{"key": "back", "name": "CAT_PART_BACK", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "등은 가볍게."},
		{"id": "pillow", "src": "char04", "name": "베개", "r": 1, "d": "Char04가 늘 베고 다니는 베개."},
		{"id": "pizza_box", "src": "hidden_d01", "hidden": true, "name": "피자 상자", "r": 1, "d": "히든 · 뚜껑 열린 피자 한 판."},
		{"id": "pizza_box_side", "src": "hidden_d02", "hidden": true, "name": "옆으로 든 피자 상자", "r": 1, "d": "히든 · 배달 중인 피자 상자."},
		{"id": "pizza_box_open", "src": "hidden_d03", "hidden": true, "name": "활짝 연 피자 상자", "r": 1, "d": "히든 · 한 조각 빈 피자 상자."},
		{"id": "katana", "src": "char10", "name": "카타나", "r": 2, "d": "Char10의 2nd 파츠."},
		{"id": "umbrella", "src": "char15", "name": "노란 우산", "r": 1, "d": "Char15의 2nd 파츠."}]},
	# --- Cat_Tail (해금 3단계 파츠) ---------------------------------------------
	{"key": "tail", "name": "CAT_PART_TAIL", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "꼬리는 아직 자라는 중."},
		{"id": "curl", "src": "char01", "name": "말린 꼬리", "r": 1, "d": "Char01·02·04·05의 3rd 파츠."},
		{"id": "ring", "src": "char03", "name": "고리 꼬리", "r": 1, "d": "Char03·06의 3rd 파츠."},
		{"id": "fluffy", "src": "char07", "name": "복슬 꼬리", "r": 1, "d": "Char07의 3rd 파츠."},
		{"id": "tabby_ring", "src": "char08", "name": "태비 꼬리", "r": 1, "d": "Char08의 3rd 파츠."},
		{"id": "blue_curl", "src": "char09", "name": "블루 말린 꼬리", "r": 1, "d": "Char09의 3rd 파츠."},
		{"id": "zigzag", "src": "char10", "name": "지그재그 꼬리", "r": 1, "d": "Char10의 3rd 파츠."},
		{"id": "calico", "src": "char11", "name": "삼색 줄 꼬리", "r": 1, "d": "Char11의 3rd 파츠."},
		{"id": "ribbon", "src": "char12", "name": "리본 꼬리", "r": 1, "d": "Char12의 3rd 파츠."},
		{"id": "s_curl", "src": "char13", "name": "S자 꼬리", "r": 1, "d": "Char13의 3rd 파츠."},
		{"id": "spotted", "src": "char14", "name": "반점 꼬리", "r": 1, "d": "Char14의 3rd 파츠."},
		{"id": "gray_curl", "src": "char15", "name": "회색 말린 꼬리", "r": 1, "d": "Char15의 3rd 파츠."},
		{"id": "tuft", "src": "char16", "name": "술 꼬리", "r": 1, "d": "Char16의 3rd 파츠."}]},
	# --- Cat_Body -------------------------------------------------------------
	{"key": "body", "name": "CAT_PART_BODY", "type": "color", "cols": BODY_COLS},
	{"key": "ear_shape", "name": "CAT_PART_EAR_SHAPE", "type": "style", "opts": [
		{"id": "round", "src": "char04", "name": "동글 귀", "d": "Char04·05·06의 둥근 실루엣."},
		{"id": "folded", "src": "char01", "name": "접힌 귀", "r": 1, "d": "Char01의 노란 접힌 귀."},
		{"id": "pointy", "src": "char03", "name": "쫑긋 귀", "d": "Char02·03의 뾰족 귀."},
		{"id": "baker_body", "src": "char07", "name": "제빵사냥 귀", "d": "Char07의 몸 실루엣."},
		{"id": "pirate_body", "src": "char08", "name": "해적 선장냥 귀", "d": "Char08의 몸 실루엣."},
		{"id": "space_body", "src": "char09", "name": "우주냥 귀", "d": "Char09의 몸 실루엣."},
		{"id": "ninja_body", "src": "char10", "name": "닌자냥 귀", "d": "Char10의 몸 실루엣."},
		{"id": "painter_body", "src": "char11", "name": "화가냥 귀", "d": "Char11의 몸 실루엣."},
		{"id": "strawberry_body", "src": "char12", "name": "딸기우유냥 귀", "d": "Char12의 몸 실루엣."},
		{"id": "prince_body", "src": "char13", "name": "왕자냥 귀", "d": "Char13의 몸 실루엣."},
		{"id": "summer_body", "src": "char14", "name": "여름휴가냥 귀", "d": "Char14의 몸 실루엣."},
		{"id": "rainy_body", "src": "char15", "name": "비 오는 날냥 귀", "d": "Char15의 몸 실루엣."},
		{"id": "cow_body", "src": "char16", "name": "젖소냥 귀", "d": "Char16의 몸 실루엣."}]},
	{"key": "ear", "name": "CAT_PART_EAR", "type": "color", "cols": EAR_COLS},
	{"key": "pattern", "name": "CAT_PART_PATTERN", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "순수 단색 원단."},
		{"id": "tabby_head", "src": "char03", "name": "이마 태비", "d": "Char03·06의 줄무늬."},
		{"id": "tuxedo_face", "src": "char02", "name": "턱시도 얼굴", "r": 1, "d": "Char02의 흰 얼굴."},
		{"id": "siamese", "src": "char05", "name": "샴 마스크", "r": 1, "d": "Char05의 짙은 얼굴."},
		{"id": "baker_pattern", "src": "char07", "name": "캐러멜 태비", "r": 1, "d": "Char07의 무늬."},
		{"id": "pirate_pattern", "src": "char08", "name": "갈색 태비", "r": 1, "d": "Char08의 무늬."},
		{"id": "space_pattern", "src": "char09", "name": "블루그레이 귀", "r": 1, "d": "Char09의 무늬."},
		{"id": "painter_pattern", "src": "char11", "name": "삼색 얼룩", "r": 1, "d": "Char11의 무늬."},
		{"id": "strawberry_pattern", "src": "char12", "name": "딸기 귀", "r": 1, "d": "Char12의 무늬."},
		{"id": "prince_pattern", "src": "char13", "name": "라일락 귀", "r": 1, "d": "Char13의 무늬."},
		{"id": "summer_pattern", "src": "char14", "name": "표범 반점", "r": 1, "d": "Char14의 무늬."},
		{"id": "rainy_pattern", "src": "char15", "name": "회색 턱시도", "r": 1, "d": "Char15의 무늬."},
		{"id": "cow_pattern", "src": "char16", "name": "젖소 반점", "r": 1, "d": "Char16의 무늬."}]},
	{"key": "pattern_col", "name": "CAT_PART_PATTERN_COL", "type": "color",
		"cols": PATTERN_COLS},
	# --- Cat_Prop_Belly / Cat_Prop_Chest ---------------------------------------
	{"key": "hold", "name": "CAT_PART_HOLD", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "앞은 비워둔다."},
		{"id": "mug", "src": "char01", "name": "머그컵", "r": 1, "d": "Char01의 1st 파츠."},
		{"id": "tie", "src": "char02", "name": "넥타이", "r": 1, "d": "Char02의 1st 파츠."},
		{"id": "keyboard", "src": "char03", "name": "키보드", "r": 1, "d": "Char03의 2nd 파츠."},
		{"id": "lantern", "src": "char04", "name": "랜턴", "r": 2, "u": true, "d": "Char04의 2nd 파츠."},
		{"id": "orb", "src": "char05", "name": "수정 구슬", "r": 2, "u": true, "d": "Char05의 2nd 파츠."},
		{"id": "book", "src": "char06", "name": "책", "r": 1, "d": "Char06의 2nd 파츠."},
		{"id": "ramen", "src": "hidden_a01", "hidden": true, "name": "라면 그릇", "r": 1, "d": "히든 · 김 오르는 라면 한 그릇."},
		{"id": "ramen_black", "src": "hidden_a02", "hidden": true, "name": "검은 라면 그릇", "r": 1, "d": "히든 · 무늬 그릇에 담은 라면."},
		{"id": "ramen_egg", "src": "hidden_a03", "hidden": true, "name": "계란 라면", "r": 1, "d": "히든 · 반숙 달걀을 올린 라면."},
		{"id": "candy_pile", "src": "hidden_b01", "hidden": true, "name": "사탕 더미", "r": 1, "d": "히든 · 뽑아 온 사탕이 한가득."},
		{"id": "capsule_heart", "src": "hidden_b02", "hidden": true, "name": "하트 캡슐", "r": 2, "d": "히든 · 하트가 든 캡슐."},
		{"id": "capsule_star", "src": "hidden_b03", "hidden": true, "name": "별 캡슐", "r": 2, "d": "히든 · 별이 든 캡슐."},
		{"id": "pizza_slice", "src": "hidden_d01", "hidden": true, "name": "피자 한 조각", "r": 1, "d": "히든 · 치즈가 늘어나는 한 조각."},
		{"id": "pizza_mushroom", "src": "hidden_d02", "hidden": true, "name": "버섯 피자", "r": 1, "d": "히든 · 버섯 올린 한 조각."},
		{"id": "pizza_pineapple", "src": "hidden_d03", "hidden": true, "name": "파인애플 피자", "r": 1, "d": "히든 · 논쟁의 그 조각."},
		{"id": "cupcake", "src": "char07", "name": "컵케이크", "r": 1, "d": "Char07의 2nd 파츠."},
		{"id": "treasure", "src": "char08", "name": "보물 상자", "r": 1, "d": "Char08의 2nd 파츠."},
		{"id": "rocket", "src": "char09", "name": "로켓", "r": 1, "d": "Char09의 2nd 파츠."},
		{"id": "palette", "src": "char11", "name": "팔레트", "r": 1, "d": "Char11의 2nd 파츠."},
		{"id": "berry_milk", "src": "char12", "name": "딸기우유", "r": 1, "d": "Char12의 2nd 파츠."},
		{"id": "watermelon", "src": "char14", "name": "수박", "r": 1, "d": "Char14의 2nd 파츠."}]},
	{"key": "chest", "name": "CAT_PART_CHEST", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "가슴팍은 비워둔다."},
		{"id": "badge", "src": "char02", "name": "경찰 배지", "r": 2, "u": true, "d": "Char02의 1st 파츠."},
		{"id": "bowtie", "src": "char06", "name": "나비넥타이", "r": 1, "d": "Char06의 1st 파츠."},
		{"id": "cape", "src": "char13", "name": "왕실 망토", "r": 2, "d": "Char13의 2nd 파츠."},
		{"id": "lei", "src": "char14", "name": "꽃 레이", "r": 1, "d": "Char14의 1st 파츠."},
		{"id": "cowbell", "src": "char16", "name": "방울 목줄", "r": 1, "d": "Char16의 1st 파츠."}]},
	# --- Cat_Feet -------------------------------------------------------------
	{"key": "pad_col", "name": "CAT_PART_PAD_COL", "type": "color", "cols": PAD_COLS},
	# --- 얼굴 (Cheek → Whiskers → Mouse → Nose → Eyes → Deco_Forehead) ----------
	{"key": "cheek_col", "name": "CAT_PART_CHEEK_COL", "type": "color",
		"cols": CHEEK_COLS},
	{"key": "whisker", "name": "CAT_PART_WHISKER", "type": "style", "opts": [
		{"id": "basic", "src": "char01", "name": "기본", "d": "단정한 기본 수염."},
		{"id": "droop", "src": "char04", "name": "처진 수염", "d": "Char04의 나른한 수염."},
		{"id": "baker_whisker", "src": "char07", "name": "제빵사냥 수염", "d": "Char07의 수염."},
		{"id": "pirate_whisker", "src": "char08", "name": "해적 선장냥 수염", "d": "Char08의 수염."},
		{"id": "space_whisker", "src": "char09", "name": "우주냥 수염", "d": "Char09의 수염."},
		{"id": "ninja_whisker", "src": "char10", "name": "닌자냥 수염", "d": "Char10의 수염."},
		{"id": "painter_whisker", "src": "char11", "name": "화가냥 수염", "d": "Char11의 수염."},
		{"id": "strawberry_whisker", "src": "char12", "name": "딸기우유냥 수염", "d": "Char12의 수염."},
		{"id": "prince_whisker", "src": "char13", "name": "왕자냥 수염", "d": "Char13의 수염."},
		{"id": "summer_whisker", "src": "char14", "name": "여름휴가냥 수염", "d": "Char14의 수염."},
		{"id": "rainy_whisker", "src": "char15", "name": "비 오는 날냥 수염", "d": "Char15의 수염."},
		{"id": "cow_whisker", "src": "char16", "name": "젖소냥 수염", "d": "Char16의 수염."}]},
	{"key": "whisker_col", "name": "CAT_PART_WHISKER_COL", "type": "color",
		"cols": WHISKER_COLS},
	{"key": "mouth", "name": "CAT_PART_MOUTH", "type": "style", "opts": [
		{"id": "w", "src": "char01", "name": "야옹입", "d": "Char01·02·05의 기본 입."},
		{"id": "open_smile", "src": "char03", "name": "활짝 웃음", "d": "Char03의 만개한 미소."},
		{"id": "yawn", "src": "char04", "name": "하품", "d": "Char04의 새벽 3시."},
		{"id": "neutral", "src": "char06", "name": "무심", "d": "Char06의 쿨한 입."},
		{"id": "o_mouth", "src": "hidden_a01", "hidden": true, "name": "동그란 입", "r": 0, "d": "히든 · 라면 냄새에 벌어진 입."},
		{"id": "hat_mouth", "src": "hidden_a02", "hidden": true, "name": "^ 입", "r": 0, "d": "히든 · 새침한 입."},
		{"id": "noodle_mouth", "src": "hidden_a03", "hidden": true, "name": "면 먹는 입", "r": 1, "d": "히든 · 후루룩."},
		{"id": "fang_open", "src": "hidden_b01", "hidden": true, "name": "송곳니 입", "r": 1, "d": "히든 · 이를 드러낸 입."},
		{"id": "fang_small", "src": "hidden_b02", "hidden": true, "name": "작은 송곳니", "r": 1, "d": "히든 · 살짝 보이는 덧니."},
		{"id": "tongue_out", "src": "hidden_b03", "hidden": true, "name": "메롱", "r": 1, "d": "히든 · 혀를 내민 입."},
		{"id": "cat_w", "src": "hidden_d01", "hidden": true, "name": "ω 입", "r": 0, "d": "히든 · 고양이 입."},
		{"id": "smile_arc", "src": "hidden_d02", "hidden": true, "name": "방긋", "r": 0, "d": "히든 · 얌전한 미소."},
		{"id": "drool", "src": "hidden_d03", "hidden": true, "name": "침 흘리는 입", "r": 1, "d": "히든 · 피자 앞에서 참을 수 없다."},
		{"id": "baker_mouth", "src": "char07", "name": "방긋 야옹입", "d": "Char07의 입."},
		{"id": "pirate_mouth", "src": "char08", "name": "선장 야옹입", "d": "Char08의 입."},
		{"id": "space_mouth", "src": "char09", "name": "우주 야옹입", "d": "Char09의 입."},
		{"id": "ninja_mouth", "src": "char10", "name": "닌자 입", "d": "Char10의 입."},
		{"id": "painter_mouth", "src": "char11", "name": "활짝 웃는 입", "d": "Char11의 입."},
		{"id": "strawberry_mouth", "src": "char12", "name": "딸기 야옹입", "d": "Char12의 입."},
		{"id": "prince_mouth", "src": "char13", "name": "새침한 미소", "d": "Char13의 입."},
		{"id": "summer_mouth", "src": "char14", "name": "신난 입", "d": "Char14의 입."},
		{"id": "rainy_mouth", "src": "char15", "name": "o 입", "d": "Char15의 입."},
		{"id": "cow_mouth", "src": "char16", "name": "젖소 야옹입", "d": "Char16의 입."}]},
	{"key": "mouth_col", "name": "CAT_PART_MOUTH_COL", "type": "color",
		"cols": MOUTH_COLS},
	{"key": "nose_col", "name": "CAT_PART_NOSE_COL", "type": "color", "cols": NOSE_COLS},
	{"key": "eyes", "name": "CAT_PART_EYES", "type": "style", "opts": [
		{"id": "oval", "src": "char01", "name": "까만눈", "d": "Char01의 기본 — 하이라이트 2점."},
		{"id": "iris", "src": "char02", "name": "홍채눈", "r": 1, "d": "Char02의 노란 눈동자."},
		{"id": "squint", "src": "char03", "name": "><눈", "d": "Char03의 기분 최고 눈."},
		{"id": "sleep", "src": "char04", "name": "감은눈", "d": "Char04의 잠든 눈."},
		{"id": "star", "src": "char05", "name": "별눈", "r": 2, "u": true, "d": "Char05의 별 박은 눈."},
		{"id": "tired", "src": "char06", "name": "졸린눈", "d": "Char06의 반쯤 감긴 눈."},
		{"id": "ramen_sparkle", "src": "hidden_a01", "hidden": true, "name": "초롱눈", "r": 1, "d": "히든 · 라면을 본 눈."},
		{"id": "ramen_sleepy", "src": "hidden_a02", "hidden": true, "name": "졸린 눈꺼풀", "r": 1, "d": "히든 · 반쯤 내려온 눈꺼풀."},
		{"id": "ramen_squint", "src": "hidden_a03", "hidden": true, "name": "><눈 (라면)", "r": 0, "d": "히든 · 뜨거워서 감은 눈."},
		{"id": "x_squint", "src": "hidden_b01", "hidden": true, "name": "×<눈", "r": 1, "d": "히든 · 뽑기에 실패한 눈."},
		{"id": "spiral_eyes", "src": "hidden_b02", "hidden": true, "name": "빙글눈", "r": 1, "d": "히든 · 어질어질."},
		{"id": "tear_squint", "src": "hidden_b03", "hidden": true, "name": "눈물 ><눈", "r": 1, "d": "히든 · 아깝게 놓친 눈."},
		{"id": "happy_arc", "src": "hidden_d01", "hidden": true, "name": "웃는 눈", "r": 0, "d": "히든 · 기분 좋은 곡선."},
		{"id": "dot_eyes", "src": "hidden_d02", "hidden": true, "name": "점눈", "r": 0, "d": "히든 · 작은 점 눈."},
		{"id": "heart_eyes", "src": "hidden_d03", "hidden": true, "name": "하트눈", "r": 2, "d": "히든 · 피자에 반한 눈."},
		{"id": "baker_eyes", "src": "char07", "name": "^^눈", "r": 1, "d": "Char07의 눈."},
		{"id": "pirate_eyes", "src": "char08", "name": "선장 눈", "r": 1, "d": "Char08의 눈."},
		{"id": "space_eyes", "src": "char09", "name": "초록 반짝눈", "r": 1, "d": "Char09의 눈."},
		{"id": "ninja_eyes", "src": "char10", "name": "날카로운 눈", "r": 1, "d": "Char10의 눈."},
		{"id": "painter_eyes", "src": "char11", "name": "동그란 눈", "r": 1, "d": "Char11의 눈."},
		{"id": "strawberry_eyes", "src": "char12", "name": "핑크 반짝눈", "r": 1, "d": "Char12의 눈."},
		{"id": "prince_eyes", "src": "char13", "name": "반쯤 뜬 눈", "r": 1, "d": "Char13의 눈."},
		{"id": "summer_eyes", "src": "char14", "name": "윙크", "r": 1, "d": "Char14의 눈."},
		{"id": "rainy_eyes", "src": "char15", "name": "글썽눈", "r": 1, "d": "Char15의 눈."},
		{"id": "cow_eyes", "src": "char16", "name": "젖소 눈", "r": 1, "d": "Char16의 눈."}]},
	{"key": "eye_col", "name": "CAT_PART_EYE_COL", "type": "color", "cols": EYE_COLS},
	{"key": "mark", "name": "CAT_PART_MARK", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "깨끗한 이마."},
		{"id": "moon", "src": "char04", "name": "초승달", "r": 1, "d": "Char04의 이마 달."},
		{"id": "star_mark", "src": "char09", "name": "이마 별", "r": 1, "d": "Char09의 기본 파츠."},
		{"id": "paint_smudge", "src": "char11", "name": "물감 자국", "r": 1, "d": "Char11의 기본 파츠."},
		{"id": "heart_mark", "src": "char12", "name": "이마 하트", "r": 1, "d": "Char12의 기본 파츠."}]},
	# --- Prop_Face / Prop_Head --------------------------------------------------
	{"key": "face", "name": "CAT_PART_FACE", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "민낯의 자신감."},
		{"id": "sunglasses", "src": "char02", "name": "선글라스", "r": 2, "u": true, "d": "Char02의 2nd 파츠."},
		{"id": "round_glasses", "src": "char06", "name": "동글 안경", "d": "Char06의 기본 파츠."},
		{"id": "eye_patch", "src": "char08", "name": "안대", "r": 1, "d": "Char08의 기본 파츠."}]},
	{"key": "head", "name": "CAT_PART_HEAD", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "머리는 가볍게."},
		{"id": "headset", "src": "char03", "name": "게이밍 헤드셋", "r": 1, "d": "Char03의 1st 파츠."},
		{"id": "sleep_mask", "src": "char04", "name": "수면 안대", "r": 1, "d": "Char04의 1st 파츠."},
		{"id": "wizard", "src": "char05", "name": "마법사 모자", "r": 2, "u": true, "d": "Char05의 1st 파츠."},
		{"id": "orange", "src": "char01", "name": "귤", "r": 1, "d": "Char01의 2nd 파츠."},
		{"id": "egg", "src": "hidden_a01", "hidden": true, "name": "계란 프라이", "r": 1, "d": "히든 · 머리 위 계란 프라이."},
		{"id": "egg_drip", "src": "hidden_a02", "hidden": true, "name": "흘러내린 계란", "r": 1, "d": "히든 · 노른자가 흘러내린다."},
		{"id": "egg_boiled", "src": "hidden_a03", "hidden": true, "name": "반숙 달걀", "r": 1, "d": "히든 · 반으로 자른 달걀."},
		{"id": "claw", "src": "hidden_b01", "hidden": true, "name": "인형뽑기 집게", "r": 2, "d": "히든 · 머리를 노리는 집게."},
		{"id": "claw_heart", "src": "hidden_b02", "hidden": true, "name": "하트 집게", "r": 2, "d": "히든 · 분홍 하트 집게."},
		{"id": "claw_red", "src": "hidden_b03", "hidden": true, "name": "빨간 집게", "r": 2, "d": "히든 · 빨간 줄무늬 집게."},
		{"id": "box_wow", "src": "hidden_c01", "hidden": true, "name": "놀란 상자", "r": 1, "d": "히든 · 깜짝 놀란 상자 얼굴."},
		{"id": "box_smug", "src": "hidden_c02", "hidden": true, "name": "새침한 상자", "r": 1, "d": "히든 · 새침한 상자 얼굴."},
		{"id": "box_love", "src": "hidden_c03", "hidden": true, "name": "반한 상자", "r": 2, "d": "히든 · 하트 선글라스 상자 얼굴."},
		{"id": "cheese", "src": "hidden_d01", "hidden": true, "name": "치즈", "r": 1, "d": "히든 · 머리 위 치즈 한 덩이."},
		{"id": "hot_sauce", "src": "hidden_d02", "hidden": true, "name": "핫소스", "r": 1, "d": "히든 · 매운 소스 한 병."},
		{"id": "pickle_jar", "src": "hidden_d03", "hidden": true, "name": "피클 병", "r": 1, "d": "히든 · 피클 한 병."},
		{"id": "chef_hat", "src": "char07", "name": "요리사 모자", "r": 1, "d": "Char07의 1st 파츠."},
		{"id": "pirate_hat", "src": "char08", "name": "해적 삼각모", "r": 1, "d": "Char08의 1st 파츠."},
		{"id": "antenna", "src": "char09", "name": "별 더듬이", "r": 1, "d": "Char09의 1st 파츠."},
		{"id": "ninja_band", "src": "char10", "name": "닌자 머리띠", "r": 1, "d": "Char10의 1st 파츠."},
		{"id": "beret", "src": "char11", "name": "베레모", "r": 1, "d": "Char11의 1st 파츠."},
		{"id": "berry_beanie", "src": "char12", "name": "딸기 비니", "r": 1, "d": "Char12의 1st 파츠."},
		{"id": "crown", "src": "char13", "name": "왕관", "r": 2, "d": "Char13의 1st 파츠."},
		{"id": "rain_hat", "src": "char15", "name": "레인햇", "r": 1, "d": "Char15의 1st 파츠."},
		{"id": "bucket_hat", "src": "char16", "name": "데이지 벙거지", "r": 1, "d": "Char16의 2nd 파츠."}]},
]

## 커스터마이저가 보여주는 "부위" 묶음 — 냥이 몸에서 같은 자리를 가리키는
## 슬롯끼리 묶어, 모양과 색을 한 화면(같은 뎁스)에서 고르게 한다.
## at   = 냥이 중심 기준 앵커 (크기 s 단위) — 부위 클로즈업·프리뷰 마커가 쓴다.
## zoom = 클로즈업에 담을 폭 (s의 몇 배를 보여줄지 — 작을수록 크게 확대).
const GROUPS: Array[Dictionary] = [
	{"key": "g_head", "name": "CAT_PART_HEAD", "at": Vector2(0.0, -0.53),
		"zoom": 0.85, "parts": ["head"]},
	{"key": "g_ear", "name": "CAT_GROUP_EAR", "at": Vector2(-0.28, -0.62),
		"zoom": 0.62, "parts": ["ear_shape", "ear"]},
	{"key": "g_mark", "name": "CAT_GROUP_MARK", "at": Vector2(0.0, -0.31),
		"zoom": 0.34, "parts": ["mark"]},
	{"key": "g_face", "name": "CAT_PART_FACE", "at": Vector2(0.0, -0.24),
		"zoom": 0.85, "parts": ["face"]},
	{"key": "g_eyes", "name": "CAT_GROUP_EYES", "at": Vector2(0.0, -0.22),
		"zoom": 0.66, "parts": ["eyes", "eye_col"]},
	{"key": "g_nose", "name": "CAT_GROUP_NOSE", "at": Vector2(0.0, -0.15),
		"zoom": 0.26, "parts": ["nose_col"]},
	{"key": "g_mouth", "name": "CAT_GROUP_MOUTH", "at": Vector2(0.0, -0.10),
		"zoom": 0.34, "parts": ["mouth", "mouth_col"]},
	{"key": "g_whisker", "name": "CAT_GROUP_WHISKER", "at": Vector2(0.0, -0.13),
		"zoom": 1.15, "parts": ["whisker", "whisker_col"]},
	{"key": "g_cheek", "name": "CAT_GROUP_CHEEK", "at": Vector2(-0.20, -0.09),
		"zoom": 0.34, "parts": ["cheek_col"]},
	{"key": "g_body", "name": "CAT_GROUP_BODY", "at": Vector2(0.0, -0.12),
		"zoom": 1.35, "parts": ["body", "pattern", "pattern_col"]},
	{"key": "g_chest", "name": "CAT_PART_CHEST", "at": Vector2(0.14, 0.08),
		"zoom": 0.45, "parts": ["chest"]},
	{"key": "g_hold", "name": "CAT_PART_HOLD", "at": Vector2(0.0, 0.29),
		"zoom": 0.70, "parts": ["hold"]},
	{"key": "g_paw", "name": "CAT_GROUP_PAW", "at": Vector2(-0.30, 0.33),
		"zoom": 0.42, "parts": ["pad_col"]},
	{"key": "g_tail", "name": "CAT_GROUP_TAIL", "at": Vector2(0.52, 0.22),
		"zoom": 0.72, "parts": ["tail"]},
	{"key": "g_back", "name": "CAT_PART_BACK", "at": Vector2(0.02, -0.35),
		"zoom": 1.55, "parts": ["back"]},
]


## 디자인 캐릭터들 (char01~06 = 컨셉 시트, char07~16 = 신규 10종). parts = 디폴트 비주얼,
## tiers = 키캡 도감을 완성할 때마다 순서대로 붙는 1st / 2nd / 3rd 파츠.
const CHARS: Dictionary = {
	"char01": {  # 우유냥 — 접힌 노란 귀, 머그컵과 귤
		"name": "CAT_CREAM",
		"parts": {
			"body_col": Color("fbf6ee"), "ear_col": Color("f3b53f"),
			"tail_col": Color("f3b53f"), "foot_col": Color("fbf6ee"),
			"pad_col": Color("fe856d"),
			"ear": "folded", "eyes": "oval", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "w", "mouth_col": Color("2c2a33"),
			"whisker": "basic", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "none", "tail": "none",
		},
		"tiers": [{"hold": "mug"}, {"head": "orange"}, {"tail": "curl"}],
	},
	"char02": {  # 턱시도 순경냥 — 흰 얼굴, 넥타이·배지·선글라스
		"name": "CAT_BLACK",
		"parts": {
			"body_col": Color("2f2c33"), "ear_col": Color("26232c"),
			"tail_col": Color("f0e2d8"), "foot_col": Color("fbf6ee"),
			"pad_col": Color("fdfbf8"),
			"ear": "pointy", "eyes": "iris", "eye_col": Color("f0c53a"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "w", "mouth_col": Color("2c2a33"),
			"whisker": "basic", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "tuxedo_face", "pattern_col": Color("fbf6ee"), "tail": "none",
		},
		"tiers": [{"hold": "tie", "chest": "badge"}, {"face": "sunglasses"},
			{"tail": "curl"}],
	},
	"char03": {  # 치즈 게이머냥 — 태비 줄무늬, 헤드셋과 키보드
		"name": "CAT_CHEESE",
		"parts": {
			"body_col": Color("f0932b"), "ear_col": Color("d0781c"),
			"tail_col": Color("f0932b"), "foot_col": Color("fdf3e4"),
			"pad_col": Color("fdfbf8"),
			"ear": "pointy", "eyes": "squint", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "open_smile", "mouth_col": Color("eb6000"),
			"whisker": "basic", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "tabby_head", "pattern_col": Color("d0781c"), "tail": "none",
		},
		"tiers": [{"head": "headset"}, {"hold": "keyboard"}, {"tail": "ring"}],
	},
	"char04": {  # 잠꾸러기냥 — 베개와 이마 달, 수면 안대와 랜턴
		"name": "CAT_SLEEPY",
		"parts": {
			"body_col": Color("fbf6ee"), "ear_col": Color("f0e2d8"),
			"tail_col": Color("f0e2d8"), "foot_col": Color("fbf6ee"),
			"pad_col": Color("fe9883"),
			"ear": "round", "eyes": "sleep", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "yawn", "mouth_col": Color("f39e63"),
			"whisker": "droop", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "none", "mark": "moon", "back": "pillow", "tail": "none",
		},
		"tiers": [{"head": "sleep_mask"}, {"hold": "lantern"}, {"tail": "curl"}],
	},
	"char05": {  # 샴 마법냥 — 짙은 마스크, 마법사 모자와 수정 구슬
		"name": "CAT_WIZARD",
		"parts": {
			"body_col": Color("f0e2d0"), "ear_col": Color("5a4038"),
			"tail_col": Color("5a4038"), "foot_col": Color("cbb2a2"),
			"pad_col": Color("d2a08c"),
			"ear": "round", "eyes": "star", "eye_col": Color("f0c53a"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "w", "mouth_col": Color("6e5546"),
			"whisker": "basic", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "siamese", "pattern_col": Color("6b4a3a"), "tail": "none",
		},
		"tiers": [{"head": "wizard"}, {"hold": "orb"}, {"tail": "curl"}],
	},
	"char06": {  # 회색 학자냥 — 동글 안경, 나비넥타이와 책
		"name": "CAT_GRAY",
		"parts": {
			"body_col": Color("aeb6c2"), "ear_col": Color("7e8694"),
			"tail_col": Color("aeb6c2"), "foot_col": Color("fbf6ee"),
			"pad_col": Color("fdfbf8"),
			"ear": "round", "eyes": "tired", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "neutral", "mouth_col": Color("2c2a33"),
			"whisker": "basic", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "tabby_head", "pattern_col": Color("7e8694"),
			"face": "round_glasses", "tail": "none",
		},
		"tiers": [{"chest": "bowtie"}, {"hold": "book"}, {"tail": "ring"}],
	},
	# ── 신규 10종 (char07~char16) ─────────────────────────────────────────────
	# 생성 컨셉(리소스/new_chars, docs/new_cats_10.md). 파츠 레이어는 Higgsfield로 부위를
	# 떼어 내 완성 렌더에 정합한 것이다(tools/gen_cat_layers.py → gen_layouts.gd). 몸·눈·입·
	# 수염·무늬·소품이 전부 이 냥이 자신의 옵션("<id>_body" …)을 가리키므로 나만의 캐릭터에
	# "원본 냥이"로 불러오면 원본 그대로 조립된다. 색은 레이어에서 잰 값이다.
	"char07": {  # 제빵사냥 — 버터 크림 몸, 요리사 모자·컵케이크
		"name": "CAT_BAKER",
		"parts": {
			"body_col": Color("fdecad"), "ear_col": Color("c98b4f"),
			"tail_col": Color("c98b4f"), "foot_col": Color("fef6c4"),
			"pad_col": Color("fb6ba1"),
			"ear": "baker_body", "eyes": "baker_eyes", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "baker_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "baker_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "baker_pattern", "pattern_col": Color("c98b4f"), "tail": "none",
		},
		"tiers": [{"head": "chef_hat"}, {"hold": "cupcake"}, {"tail": "fluffy"}],
	},
	"char08": {  # 해적 선장냥 — 브라운 태비, 안대·삼각모·보물 상자
		"name": "CAT_PIRATE",
		"parts": {
			"body_col": Color("c48a41"), "ear_col": Color("7a4f2e"),
			"tail_col": Color("b07a4a"), "foot_col": Color("fefcef"),
			"pad_col": Color("fc9ba1"),
			"ear": "pirate_body", "eyes": "pirate_eyes", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "pirate_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "pirate_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "pirate_pattern", "pattern_col": Color("7a4f2e"), "tail": "none", "face": "eye_patch",
		},
		"tiers": [{"head": "pirate_hat"}, {"hold": "treasure"}, {"tail": "tabby_ring"}],
	},
	"char09": {  # 우주냥 — 러시안 블루, 별 더듬이·로켓
		"name": "CAT_SPACE",
		"parts": {
			"body_col": Color("8fa6c2"), "ear_col": Color("6c7a96"),
			"tail_col": Color("8d9cb8"), "foot_col": Color("fcfaf2"),
			"pad_col": Color("fda4a7"),
			"ear": "space_body", "eyes": "space_eyes", "eye_col": Color("3aa35a"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "space_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "space_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "space_pattern", "tail": "none", "mark": "star_mark",
		},
		"tiers": [{"head": "antenna"}, {"hold": "rocket"}, {"tail": "blue_curl"}],
	},
	"char10": {  # 닌자냥 — 차콜 단색, 빨간 머리띠·등 카타나
		"name": "CAT_NINJA",
		"parts": {
			"body_col": Color("2d3543"), "ear_col": Color("26232c"),
			"tail_col": Color("34364a"), "foot_col": Color("fdfaf2"),
			"pad_col": Color("fd9e95"),
			"ear": "ninja_body", "eyes": "ninja_eyes", "eye_col": Color("b8e04a"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "ninja_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "ninja_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "none", "tail": "none",
		},
		"tiers": [{"head": "ninja_band"}, {"back": "katana"}, {"tail": "zigzag"}],
	},
	"char11": {  # 화가냥 — 삼색, 베레모·팔레트
		"name": "CAT_PAINTER",
		"parts": {
			"body_col": Color("fefdf5"), "ear_col": Color("f0932b"),
			"tail_col": Color("f0932b"), "foot_col": Color("fefef6"),
			"pad_col": Color("fd9392"),
			"ear": "painter_body", "eyes": "painter_eyes", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "painter_mouth", "mouth_col": Color("eb6000"),
			"whisker": "painter_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "painter_pattern", "tail": "none", "mark": "paint_smudge",
		},
		"tiers": [{"head": "beret"}, {"hold": "palette"}, {"tail": "calico"}],
	},
	"char12": {  # 딸기우유냥 — 파스텔 핑크, 딸기 비니·딸기우유
		"name": "CAT_STRAWBERRY",
		"parts": {
			"body_col": Color("fddae2"), "ear_col": Color("e98aa4"),
			"tail_col": Color("f7c1cf"), "foot_col": Color("fddcdc"),
			"pad_col": Color("f38088"),
			"ear": "strawberry_body", "eyes": "strawberry_eyes", "eye_col": Color("e0607e"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "strawberry_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "strawberry_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "strawberry_pattern", "tail": "none", "mark": "heart_mark",
		},
		"tiers": [{"head": "berry_beanie"}, {"hold": "berry_milk"}, {"tail": "ribbon"}],
	},
	"char13": {  # 왕자냥 — 라일락, 왕관·망토
		"name": "CAT_PRINCE",
		"parts": {
			"body_col": Color("d6c7ed"), "ear_col": Color("9a82c4"),
			"tail_col": Color("cdbde6"), "foot_col": Color("fefdfc"),
			"pad_col": Color("fd9ea4"),
			"ear": "prince_body", "eyes": "prince_eyes", "eye_col": Color("7a4fc0"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "prince_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "prince_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "prince_pattern", "tail": "none",
		},
		"tiers": [{"head": "crown"}, {"chest": "cape"}, {"tail": "s_curl"}],
	},
	"char14": {  # 여름휴가냥 — 벵갈 반점, 꽃 레이·수박
		"name": "CAT_SUMMER",
		"parts": {
			"body_col": Color("f0c164"), "ear_col": Color("8a5a34"),
			"tail_col": Color("e6b872"), "foot_col": Color("fefcf1"),
			"pad_col": Color("fda4a4"),
			"ear": "summer_body", "eyes": "summer_eyes", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "summer_mouth", "mouth_col": Color("eb6000"),
			"whisker": "summer_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "summer_pattern", "pattern_col": Color("8a5a34"), "tail": "none",
		},
		"tiers": [{"chest": "lei"}, {"hold": "watermelon"}, {"tail": "spotted"}],
	},
	"char15": {  # 비 오는 날냥 — 회색·흰 바이컬러, 레인햇·우산
		"name": "CAT_RAINY",
		"parts": {
			"body_col": Color("fdfdf4"), "ear_col": Color("7e8694"),
			"tail_col": Color("9aa3ad"), "foot_col": Color("fefdf1"),
			"pad_col": Color("fc9995"),
			"ear": "rainy_body", "eyes": "rainy_eyes", "eye_col": Color("5a8ed0"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "rainy_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "rainy_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "rainy_pattern", "pattern_col": Color("fbf6ee"), "tail": "none",
		},
		"tiers": [{"head": "rain_hat"}, {"back": "umbrella"}, {"tail": "gray_curl"}],
	},
	"char16": {  # 젖소냥 — 흰 몸 + 검은 반점, 방울 목줄·벙거지
		"name": "CAT_COW",
		"parts": {
			"body_col": Color("fefdf2"), "ear_col": Color("2f2c33"),
			"tail_col": Color("fbf6ee"), "foot_col": Color("fefef5"),
			"pad_col": Color("fda49a"),
			"ear": "cow_body", "eyes": "cow_eyes", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": "cow_mouth", "mouth_col": Color("2c2a33"),
			"whisker": "cow_whisker", "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": "cow_pattern", "tail": "none",
		},
		"tiers": [{"chest": "cowbell"}, {"head": "bucket_hat"}, {"tail": "tuft"}],
	},
}

const TIER_MAX := 3


## "나만의 캐릭터"(GameState의 custom 슬롯)가 쓰는 백지 몸통 — 디자인 캐릭터가
## 아니므로 CHARS에 넣지 않는다. 여기에 사용자가 고른 파츠가 얹힌다.
const BLANK_CHAR: Dictionary = {
	"name": "CAT_MINE",
	"parts": {
		"body_col": Color("fbf6ee"), "ear_col": Color("e8d9c8"),
		"tail_col": Color("e8d9c8"), "foot_col": Color("fbf6ee"),
		"pad_col": Color("fdb3a2"),
		"ear": "pointy", "eyes": "oval", "eye_col": Color("241f28"),
		"nose": "tri", "nose_col": Color("e58a86"),
		"mouth": "w", "mouth_col": Color("2c2a33"),
		"whisker": "basic", "whisker_col": Color("2c2a33"),
		"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
		"pattern": "none", "tail": "none",
	},
	"tiers": [],
}

## 컨셉 시트 스프라이트(cat_sprite.gd)의 레이어로 표현할 수 있는 부위 — 색상뿐이다.
## 부위 key → 그 색이 칠해지는 레이어들. 여기 없는 부위(모양 교체)를 건드리면
## 스프라이트로는 그릴 수 없으므로 코드 렌더(CatArt)로 넘어간다.
const SPRITE_TINTS: Dictionary = {
	"body": ["Cat_Body_SkinFill", "Cat_Feet_SkinFill", "Cat_Tail_SkinFill"],
	"ear": ["Cat_Body_Pattern", "Cat_Tail_Pattern"],
	"pattern_col": ["Cat_Body_Pattern", "Cat_Tail_Pattern"],
	"eye_col": ["Cat_Eyes_Color"],
	"pad_col": ["Cat_Feet_Pawpad"],
	"cheek_col": ["Cat_Cheek"],
	"whisker_col": ["Cat_Whiskers"],
	"mouth_col": ["Cat_Mouse"],
	"nose_col": ["Cat_Nose"],
}


## 나만의 캐릭터는 디자인 냥이들의 **파츠 그림을 그대로 빌려** 조립된다.
## 부위 key → 그 선택이 가져오는 시트 레이어들. 옵션의 "src"가 어느 냥이의
## 그림을 쓸지 가리킨다 ("none"은 그 레이어를 아예 안 그린다).
const LAYER_SLOTS: Dictionary = {
	"ear_shape": ["Cat_Body_Outline", "Cat_Body_SkinFill"],  # 몸 실루엣(귀 포함)
	"pattern": ["Cat_Body_Pattern"],
	"eyes": ["Cat_Eyes_Base", "Cat_Eyes_Color", "Cat_Eyes_Highlight"],
	"mouth": ["Cat_Mouse"],
	"whisker": ["Cat_Whiskers"],
	"tail": ["Cat_Tail_Outline", "Cat_Tail_SkinFill", "Cat_Tail_Pattern"],
	"mark": ["Deco_Forehead"],
	"face": ["Prop_Face"],
	"head": ["Prop_Head"],
	"chest": ["Cat_Prop_Chest"],
	"hold": ["Cat_Prop_Belly"],
	"back": ["Prop_Back"],
}

## 부위로 갈라지지 않는 레이어 — 몸 실루엣을 빌려준 냥이를 따라간다.
const BASE_LAYERS: Array[String] = ["Cat_Feet_SkinFill", "Cat_Feet_Pawpad",
		"Cat_Feet_Outline", "Cat_Cheek", "Cat_Nose"]

## 레이어 → 그 색을 정하는 파츠 key. 무늬 레이어는 특수케이스라 비워 둔다
## (무늬가 있으면 pattern_col, 없으면 귀·꼬리 색이 다스린다 — 시트에선 한 레이어라서).
const MIX_TINTS: Dictionary = {
	"Cat_Body_SkinFill": "body_col",
	"Cat_Feet_SkinFill": "foot_col",
	"Cat_Tail_SkinFill": "tail_col",
	"Cat_Feet_Pawpad": "pad_col",
	"Cat_Cheek": "cheek_col",
	"Cat_Whiskers": "whisker_col",
	"Cat_Mouse": "mouth_col",
	"Cat_Nose": "nose_col",
	"Cat_Eyes_Color": "eye_col",
}


## 파츠 묶음 → {레이어 이름: 그림을 빌려올 캐릭터 id}.
static func mix_of(parts: Dictionary) -> Dictionary:
	var base := opt_src("ear_shape", str(parts.get("ear", "")))
	if base == "":
		base = "char01"
	var out := {}
	for n in BASE_LAYERS:
		_put(out, n, base)
	for slot: String in LAYER_SLOTS:
		var src := opt_src(slot, str(parts.get(_parts_key(slot), "")))
		if src == "":
			continue  # "없음" — 그 레이어는 그리지 않는다
		for n: String in (LAYER_SLOTS[slot] as Array):
			_put(out, n, src)
	return out


## 그 냐이가 실제로 가진 레이어만 담는다 (코는 char06에만, 흰자는 일부 냐이에만 있다).
static func _put(out: Dictionary, layer: String, char_id: String) -> void:
	for l: Dictionary in _layers_of(char_id):
		if str(l.n) == layer:
			out[layer] = char_id
			return


static func _layers_of(char_id: String) -> Array:
	if CatLayouts.LAYOUTS.has(char_id):
		return CatLayouts.LAYOUTS[char_id]
	if GenLayouts.LAYOUTS.has(char_id):
		return GenLayouts.LAYOUTS[char_id]
	return HiddenLayouts.LAYOUTS.get(char_id, [])


## 이 옵션이 그림을 빌려오는 캐릭터 id ("" = 없음/모름).
static func opt_src(slot: String, id: String) -> String:
	if id == "" or id == "none":
		return ""
	for opt: Dictionary in get_part(slot).get("opts", []):
		if str(opt.id) == id:
			return str(opt.get("src", ""))
	return ""


## 파츠 묶음의 색들 → 레이어 틴트 (스프라이트 믹스용).
static func mix_tints(parts: Dictionary) -> Dictionary:
	var out := {}
	for layer: String in MIX_TINTS:
		var col: Variant = parts.get(str(MIX_TINTS[layer]))
		if col != null:
			out[layer] = col
	# 무늬 레이어는 시트에서 귀·꼬리 색과 같은 한 장이다.
	var pat := str(parts.get("pattern", "none"))
	var pc: Variant = parts.get("ear_col")
	if pat != "none":
		pc = parts.get("pattern_col", pc)
	if pc != null:
		out["Cat_Body_Pattern"] = pc
	var tc: Variant = parts.get("tail_col", parts.get("ear_col"))
	if tc != null:
		out["Cat_Tail_Pattern"] = tc
	return out


## 파츠 상점: 처음부터 열려 있는 옵션 index들 (부위 key별) — 백지 몸통(BLANK_CHAR)의
## 기본값과 "없음"이다. 나머지는 전부 꾸미기 화면에서 골드로 사야 쓸 수 있다.
static var _free_opts: Dictionary = {}


static func free_options(key: String) -> Array:
	if _free_opts.is_empty():
		var base := char_selection("custom")  # 백지 몸통의 기본 선택
		for part in PARTS:
			var k := str(part.key)
			var out: Array = []
			if base.has(k):
				out.append(int(base[k]))
			if part.get("type") != "color":
				var opts: Array = part.opts
				for i in opts.size():
					if str((opts[i] as Dictionary).id) == "none" and not i in out:
						out.append(i)
			_free_opts[k] = out
	return _free_opts.get(key, [])

## 유니크 파츠인가 — 골드가 아니라 통조림 캔으로만 살 수 있는 옵션.
## 색(color)에는 유니크가 없다 (모양 옵션에만 "u": true를 단다).
static func is_unique_option(key: String, idx: int) -> bool:
	var part := get_part(key)
	if part.is_empty() or part.get("type") == "color":
		return false
	var opts: Array = part.opts
	if idx < 0 or idx >= opts.size():
		return false
	return bool((opts[idx] as Dictionary).get("u", false))


static func get_part(key: String) -> Dictionary:
	for p in PARTS:
		if p.key == key:
			return p
	return {}


## 그룹에 묶인 부위 정의들 (카탈로그에 없는 key는 건너뛴다).
static func group_parts(group: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in (group.parts as Array):
		var part := get_part(key)
		if not part.is_empty():
			out.append(part)
	return out


static func option_count(part: Dictionary) -> int:
	if part.get("type") == "color":
		return (part.cols as Array).size()
	return (part.opts as Array).size()


## 저장된 선택(sel)에서 이 부위의 인덱스 (범위 밖이면 0).
static func pick(sel: Dictionary, key: String) -> int:
	var part := get_part(key)
	if part.is_empty():
		return 0
	var i := int(sel.get(key, 0))
	return i if i >= 0 and i < option_count(part) else 0


## 디자인 캐릭터의 파츠 묶음 — tier(0~3)만큼 해금 파츠를 얹어 돌려준다.
static func char_parts(char_id: String, tier := TIER_MAX) -> Dictionary:
	var def: Dictionary = CHARS.get(char_id, BLANK_CHAR)
	var parts: Dictionary = (def.parts as Dictionary).duplicate(true)
	var tiers: Array = def.tiers
	for i in mini(maxi(tier, 0), tiers.size()):
		for k: String in (tiers[i] as Dictionary):
			parts[k] = (tiers[i] as Dictionary)[k]
	return parts


## 이 캐릭터가 tier 단계(0=1st, 1=2nd, 2=3rd)에서 새로 받는 파츠의 부위 이름 키들.
## 키캡 한 바퀴를 채웠을 때 "무엇이 열렸는지" 알리는 데 쓴다 — 옵션 이름은 카탈로그에
## 한국어로 박혀 있어 번역이 안 되므로, 번역 키가 있는 부위 이름(CAT_PART_*)만 준다.
static func tier_gain_names(char_id: String, tier: int) -> Array[String]:
	var out: Array[String] = []
	var def: Dictionary = CHARS.get(char_id, BLANK_CHAR)
	var tiers: Array = def.tiers
	if tier < 0 or tier >= tiers.size():
		return out
	var gained: Dictionary = tiers[tier]
	for bundle_key: String in gained:
		for part in PARTS:
			if _parts_key(str(part.key)) != bundle_key or part.get("type") == "color":
				continue
			var nm := str(part.name)
			if not nm in out:
				out.append(nm)
			break
	return out


## 디자인 캐릭터 → 커스터마이저 선택값(sel). "이 냥이처럼 시작하기"용.
static func char_selection(char_id: String, tier := TIER_MAX) -> Dictionary:
	var parts := char_parts(char_id, tier)
	var sel := {}
	for part in PARTS:
		var key := str(part.key)
		var want: Variant = parts.get(_parts_key(key))
		if want == null:
			continue
		if part.get("type") == "color":
			sel[key] = nearest_col(part.cols, want)
		else:
			var opts: Array = part.opts
			for i in opts.size():
				if str(opts[i].id) == str(want):
					sel[key] = i
					break
	return sel


## 커스터마이저 부위 key → 파츠 묶음 key.
static func _parts_key(key: String) -> String:
	match key:
		"body":
			return "body_col"
		"ear":
			return "ear_col"
		"ear_shape":
			return "ear"
		_:
			return key



## 파츠 묶음 → CatArt가 읽는 skin 딕셔너리.
static func skin_from_parts(parts: Dictionary) -> Dictionary:
	return {
		"body": parts.get("body_col", Color("fbf6ee")),
		"ear": parts.get("ear_col", Color("d9a05c")),
		"parts": parts,
	}


## 사용자가 손댄 부위(sel)만 캐릭터의 파츠 묶음 위에 덮어쓴다 —
## sel에 없는 부위는 그 캐릭터의 디자인 그대로 남는다.
## 몸 색은 발까지, 귀 색은 꼬리까지 함께 따라간다 (컨셉 시트의 색 연동).
static func apply_sel(parts: Dictionary, sel: Dictionary) -> Dictionary:
	var out: Dictionary = parts.duplicate(true)
	for raw: Variant in sel:
		var key := str(raw)
		var part := get_part(key)
		if part.is_empty():
			continue
		var i := pick(sel, key)
		if part.get("type") == "color":
			var col: Color = (part.cols as Array)[i]
			out[_parts_key(key)] = col
			if key == "body":
				out["foot_col"] = col.lightened(0.16)
			elif key == "ear":
				out["tail_col"] = col
		else:
			out[_parts_key(key)] = str((part.opts as Array)[i].id)
	return out


## 캐릭터 기본 파츠 + 사용자 커스터마이징 → skin 딕셔너리.
static func build_skin(char_id: String, tier: int, sel: Dictionary) -> Dictionary:
	var parts := apply_sel(char_parts(char_id, tier), sel)
	var skin := skin_from_parts(parts)
	# 디자인 냥이가 아니면(= 나만의 캐릭터) 시트 파츠 그림을 직접 조립해 그린다.
	if not CHARS.has(char_id):
		skin["mix"] = mix_of(parts)
		skin["tints"] = mix_tints(parts)
	return skin


## 이 선택을 스프라이트 레이어만으로 그릴 수 있는가 (색상 변경만 했는가).
static func sprite_safe(sel: Dictionary) -> bool:
	for key: Variant in sel:
		if not SPRITE_TINTS.has(str(key)):
			return false
	return true


## 선택값 → 스프라이트 레이어 틴트 {레이어 이름: 색}.
static func sprite_tints(sel: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in sel:
		var k := str(key)
		var part := get_part(k)
		if not SPRITE_TINTS.has(k) or part.is_empty():
			continue
		var col: Color = (part.cols as Array)[pick(sel, k)]
		for layer: String in SPRITE_TINTS[k]:
			out[layer] = col
	return out


# --- 나만의 캐릭터(커스텀 슬롯) 파츠 출처 -------------------------------------------
## "나만의 캐릭터"의 부품은 전부 디자인 냥이 6종에게서 빌려 온 것이다.
## 그래서 옵션마다 출처(어느 냥이의 몇 번째 파츠 단계인가)를 들고 있고,
## 그 냥이를 해금(+그 단계까지 성장)해야 쓸 수 있다 — 잠긴 옵션은 자물쇠로 뜬다.
## 출처가 비어 있는 옵션("없음")은 언제나 열려 있다.

## {부위 key: {옵션 index: [{"char": id, "tier": n}, ...]}} — 빈 배열 = 상시 개방.
static var _sources: Dictionary = {}


static func my_sources() -> Dictionary:
	if not _sources.is_empty():
		return _sources
	var out := {}
	for part in PARTS:
		var key := str(part.key)
		out[key] = {}
		# "없음"은 어느 냥이의 것도 아니다 — 늘 고를 수 있어야 원상복구가 된다.
		if part.get("type") != "color":
			var opts: Array = part.opts
			for i in opts.size():
				if str(opts[i].id) == "none":
					out[key][i] = []
		_mark_hidden_open(out, part)
	for char_id: String in CHARS:
		# 파츠 레이어가 있는 냥이만 재료를 빌려 줄 수 있다.
		if not CatLayouts.LAYOUTS.has(char_id) and not GenLayouts.LAYOUTS.has(char_id):
			continue
		var def: Dictionary = CHARS[char_id]
		_collect_sources(out, char_id, 0, def.parts)
		var tiers: Array = def.tiers
		for t in tiers.size():
			_collect_sources(out, char_id, t + 1, tiers[t])
	_sources = out
	return out


## 히든 파츠("hidden": true)는 어느 디자인 냥이의 것도 아니다 — 출처 없이 올려
## 처음부터 목록에 서고, 다른 파츠처럼 골드로 산다 (GameState.part_unlocked 참조).
static func _mark_hidden_open(out: Dictionary, part: Dictionary) -> void:
	if part.get("type") == "color":
		return
	var opts: Array = part.opts
	for i in opts.size():
		if bool((opts[i] as Dictionary).get("hidden", false)):
			out[str(part.key)][i] = []


## 파츠 묶음 하나(기본 파츠 또는 해금 단계 하나)를 출처표에 적는다.
static func _collect_sources(out: Dictionary, char_id: String, tier: int,
		parts: Dictionary) -> void:
	for part in PARTS:
		var key := str(part.key)
		var want: Variant = parts.get(_parts_key(key))
		if want == null:
			continue
		var idx := -1
		if part.get("type") == "color":
			idx = nearest_col(part.cols, want)
		else:
			var opts: Array = part.opts
			for i in opts.size():
				if str(opts[i].id) == str(want):
					idx = i
					break
		if idx < 0:
			continue
		var slot: Dictionary = out[key]
		if not slot.has(idx):
			slot[idx] = [{"char": char_id, "tier": tier}]
		elif not (slot[idx] as Array).is_empty():
			(slot[idx] as Array).append({"char": char_id, "tier": tier})


## 이 부위에서 나만의 캐릭터가 쓸 수 있는 옵션 index들 (잠긴 것 포함, 오름차순).
static func my_options(key: String) -> Array:
	var slot: Dictionary = my_sources().get(key, {})
	var out: Array = slot.keys()
	out.sort()
	return out


## 이 옵션의 출처 목록 ([] = 상시 개방, 없는 옵션이면 null).
static func option_sources(key: String, idx: int) -> Variant:
	var slot: Dictionary = my_sources().get(key, {})
	return slot.get(idx)


## 팔레트에서 가장 가까운 색의 index.
static func nearest_col(cols: Array, want: Color) -> int:
	var best := 0
	var best_d := 1e9
	for i in cols.size():
		var c: Color = cols[i]
		var d: float = absf(c.r - want.r) + absf(c.g - want.g) + absf(c.b - want.b)
		if d < best_d:
			best_d = d
			best = i
	return best
