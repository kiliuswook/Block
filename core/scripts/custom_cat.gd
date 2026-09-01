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
## [임시 · 진짜 파츠 아트가 나오면 제거] 부위마다 5~6개씩 더 얹은 임시 파츠 카탈로그.
const TempParts := preload("res://core/scripts/temp_parts.gd")

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
const PARTS: Array[Dictionary] = [
	# --- Prop_Back ------------------------------------------------------------
	{"key": "back", "name": "CAT_PART_BACK", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "등은 가볍게."},
		{"id": "pillow", "src": "char04", "name": "베개", "r": 1, "d": "Char04가 늘 베고 다니는 베개."}]},
	# --- Cat_Tail (해금 3단계 파츠) ---------------------------------------------
	{"key": "tail", "name": "CAT_PART_TAIL", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "꼬리는 아직 자라는 중."},
		{"id": "curl", "src": "char01", "name": "말린 꼬리", "r": 1, "d": "Char01·02·04·05의 3rd 파츠."},
		{"id": "ring", "src": "char03", "name": "고리 꼬리", "r": 1, "d": "Char03·06의 3rd 파츠."}]},
	# --- Cat_Body -------------------------------------------------------------
	{"key": "body", "name": "CAT_PART_BODY", "type": "color", "cols": BODY_COLS},
	{"key": "ear_shape", "name": "CAT_PART_EAR_SHAPE", "type": "style", "opts": [
		{"id": "round", "src": "char04", "name": "동글 귀", "d": "Char04·05·06의 둥근 실루엣."},
		{"id": "folded", "src": "char01", "name": "접힌 귀", "r": 1, "d": "Char01의 노란 접힌 귀."},
		{"id": "pointy", "src": "char03", "name": "쫑긋 귀", "d": "Char02·03의 뾰족 귀."}]},
	{"key": "ear", "name": "CAT_PART_EAR", "type": "color", "cols": EAR_COLS},
	{"key": "pattern", "name": "CAT_PART_PATTERN", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "순수 단색 원단."},
		{"id": "tabby_head", "src": "char03", "name": "이마 태비", "d": "Char03·06의 줄무늬."},
		{"id": "tuxedo_face", "src": "char02", "name": "턱시도 얼굴", "r": 1, "d": "Char02의 흰 얼굴."},
		{"id": "siamese", "src": "char05", "name": "샴 마스크", "r": 1, "d": "Char05의 짙은 얼굴."}]},
	{"key": "pattern_col", "name": "CAT_PART_PATTERN_COL", "type": "color",
		"cols": PATTERN_COLS},
	# --- Cat_Prop_Belly / Cat_Prop_Chest ---------------------------------------
	{"key": "hold", "name": "CAT_PART_HOLD", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "앞은 비워둔다."},
		{"id": "mug", "src": "char01", "name": "머그컵", "r": 1, "d": "Char01의 1st 파츠."},
		{"id": "tie", "src": "char02", "name": "넥타이", "r": 1, "d": "Char02의 1st 파츠."},
		{"id": "keyboard", "src": "char03", "name": "키보드", "r": 1, "d": "Char03의 2nd 파츠."},
		{"id": "lantern", "src": "char04", "name": "랜턴", "r": 2, "d": "Char04의 2nd 파츠."},
		{"id": "orb", "src": "char05", "name": "수정 구슬", "r": 2, "d": "Char05의 2nd 파츠."},
		{"id": "book", "src": "char06", "name": "책", "r": 1, "d": "Char06의 2nd 파츠."}]},
	{"key": "chest", "name": "CAT_PART_CHEST", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "가슴팍은 비워둔다."},
		{"id": "badge", "src": "char02", "name": "경찰 배지", "r": 2, "d": "Char02의 1st 파츠."},
		{"id": "bowtie", "src": "char06", "name": "나비넥타이", "r": 1, "d": "Char06의 1st 파츠."}]},
	# --- Cat_Feet -------------------------------------------------------------
	{"key": "pad_col", "name": "CAT_PART_PAD_COL", "type": "color", "cols": PAD_COLS},
	# --- 얼굴 (Cheek → Whiskers → Mouse → Nose → Eyes → Deco_Forehead) ----------
	{"key": "cheek_col", "name": "CAT_PART_CHEEK_COL", "type": "color",
		"cols": CHEEK_COLS},
	{"key": "whisker", "name": "CAT_PART_WHISKER", "type": "style", "opts": [
		{"id": "basic", "src": "char01", "name": "기본", "d": "단정한 기본 수염."},
		{"id": "droop", "src": "char04", "name": "처진 수염", "d": "Char04의 나른한 수염."}]},
	{"key": "whisker_col", "name": "CAT_PART_WHISKER_COL", "type": "color",
		"cols": WHISKER_COLS},
	{"key": "mouth", "name": "CAT_PART_MOUTH", "type": "style", "opts": [
		{"id": "w", "src": "char01", "name": "야옹입", "d": "Char01·02·05의 기본 입."},
		{"id": "open_smile", "src": "char03", "name": "활짝 웃음", "d": "Char03의 만개한 미소."},
		{"id": "yawn", "src": "char04", "name": "하품", "d": "Char04의 새벽 3시."},
		{"id": "neutral", "src": "char06", "name": "무심", "d": "Char06의 쿨한 입."}]},
	{"key": "mouth_col", "name": "CAT_PART_MOUTH_COL", "type": "color",
		"cols": MOUTH_COLS},
	{"key": "nose_col", "name": "CAT_PART_NOSE_COL", "type": "color", "cols": NOSE_COLS},
	{"key": "eyes", "name": "CAT_PART_EYES", "type": "style", "opts": [
		{"id": "oval", "src": "char01", "name": "까만눈", "d": "Char01의 기본 — 하이라이트 2점."},
		{"id": "iris", "src": "char02", "name": "홍채눈", "r": 1, "d": "Char02의 노란 눈동자."},
		{"id": "squint", "src": "char03", "name": "><눈", "d": "Char03의 기분 최고 눈."},
		{"id": "sleep", "src": "char04", "name": "감은눈", "d": "Char04의 잠든 눈."},
		{"id": "star", "src": "char05", "name": "별눈", "r": 2, "d": "Char05의 별 박은 눈."},
		{"id": "tired", "src": "char06", "name": "졸린눈", "d": "Char06의 반쯤 감긴 눈."}]},
	{"key": "eye_col", "name": "CAT_PART_EYE_COL", "type": "color", "cols": EYE_COLS},
	{"key": "mark", "name": "CAT_PART_MARK", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "깨끗한 이마."},
		{"id": "moon", "src": "char04", "name": "초승달", "r": 1, "d": "Char04의 이마 달."}]},
	# --- Prop_Face / Prop_Head --------------------------------------------------
	{"key": "face", "name": "CAT_PART_FACE", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "민낯의 자신감."},
		{"id": "sunglasses", "src": "char02", "name": "선글라스", "r": 2, "d": "Char02의 2nd 파츠."},
		{"id": "round_glasses", "src": "char06", "name": "동글 안경", "d": "Char06의 기본 파츠."}]},
	{"key": "head", "name": "CAT_PART_HEAD", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "머리는 가볍게."},
		{"id": "headset", "src": "char03", "name": "게이밍 헤드셋", "r": 1, "d": "Char03의 1st 파츠."},
		{"id": "sleep_mask", "src": "char04", "name": "수면 안대", "r": 1, "d": "Char04의 1st 파츠."},
		{"id": "wizard", "src": "char05", "name": "마법사 모자", "r": 2, "d": "Char05의 1st 파츠."},
		{"id": "orange", "src": "char01", "name": "귤", "r": 1, "d": "Char01의 2nd 파츠."}]},
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


## 컨셉 시트의 디자인 캐릭터들. parts = 디폴트 비주얼,
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
}

const TIER_MAX := 3


# ══════════════════════════════════════════════════════════════════════════════
# [임시 · 진짜 아트가 나오면 통째로 제거] 임시 캐릭터 char07 ~ char30
# ------------------------------------------------------------------------------
# 목표는 디자인 캐릭터 30종인데 컨셉 시트에는 아직 6종(char01~06)뿐이다.
# 나머지 24마리는 "시트 파츠를 빌려 색만 갈아 끼운" 임시 조합이다 — 시트 그림이
# 없으니 CatSprite.has()가 거짓이고, build_skin()이 나만의 캐릭터와 같은
# 파츠 믹스(skin["mix"]) 경로로 그린다.
#
# ※ 제거할 때: 이 블록(TEMP_* / temp_chars / all_chars)과
#    GameState.CATS의 "[임시]" 표시 구간, shared/locale/content.csv의
#    CAT_TMP* 줄을 지우고 all_chars() 호출부를 CHARS로 되돌리면 된다.
# ※ my_sources()는 일부러 CHARS만 훑는다 — 임시 캐릭터가 나만의 캐릭터의
#    파츠 해금 출처로 새지 않게 하려는 것이다.
# ══════════════════════════════════════════════════════════════════════════════

const TEMP_FIRST := 7
const TEMP_LAST := 30

## 임시 캐릭터 한 줄 = 색 + 시트에 이미 있는 모양 옵션 조합.
## b 몸 · e 귀/꼬리 · p 젤리 · ear 귀 모양 · ey 눈 · ec 눈 색 · m 입 · mc 입 색
## · w 수염 · pt 무늬 · pc 무늬 색 · x 추가 파츠 · t 해금 3단계.
const TEMP_DEFS: Array[Dictionary] = [
	{"b": "a9dcc3", "e": "5fae8e", "p": "fdb3a2", "ear": "round", "ey": "oval",
		"m": "w", "pt": "none", "x": {},
		"t": [{"chest": "bowtie"}, {"head": "orange"}, {"tail": "curl"}]},
	{"b": "cfc0e8", "e": "8f77c4", "p": "d2a08c", "ear": "pointy", "ey": "star",
		"ec": "f0c53a", "m": "neutral", "mc": "6e5546", "pt": "tabby_head",
		"pc": "8f77c4", "x": {},
		"t": [{"head": "wizard"}, {"hold": "orb"}, {"tail": "ring"}]},
	{"b": "ffd9c2", "e": "f3a06a", "p": "fe856d", "ear": "folded", "ey": "iris",
		"ec": "f0c53a", "m": "open_smile", "mc": "eb6000", "pt": "none", "x": {},
		"t": [{"hold": "mug"}, {"head": "orange"}, {"tail": "curl"}]},
	{"b": "bcd8f2", "e": "6f9fd0", "p": "fdfbf8", "ear": "round", "ey": "sleep",
		"m": "yawn", "mc": "f39e63", "w": "droop", "pt": "none",
		"x": {"back": "pillow"},
		"t": [{"head": "sleep_mask"}, {"hold": "lantern"}, {"tail": "curl"}]},
	{"b": "4a4750", "e": "26232c", "p": "fdfbf8", "ear": "pointy", "ey": "iris",
		"ec": "f0c53a", "m": "w", "pt": "tuxedo_face", "pc": "fbf6ee", "x": {},
		"t": [{"hold": "tie"}, {"face": "sunglasses"}, {"tail": "curl"}]},
	{"b": "f6a8bb", "e": "d76b8a", "p": "fe9883", "ear": "round", "ey": "squint",
		"m": "open_smile", "mc": "eb6000", "pt": "none", "x": {"mark": "moon"},
		"t": [{"chest": "bowtie"}, {"head": "headset"}, {"tail": "ring"}]},
	{"b": "c9a37a", "e": "8e6a4a", "p": "d2a08c", "ear": "folded", "ey": "tired",
		"m": "neutral", "pt": "tabby_head", "pc": "8e6a4a",
		"x": {"face": "round_glasses"},
		"t": [{"hold": "book"}, {"chest": "bowtie"}, {"tail": "ring"}]},
	{"b": "7fc9c4", "e": "3f8f8f", "p": "fdfbf8", "ear": "pointy", "ey": "oval",
		"m": "w", "pt": "siamese", "pc": "3f8f8f", "x": {},
		"t": [{"head": "headset"}, {"hold": "keyboard"}, {"tail": "ring"}]},
	{"b": "f7e08a", "e": "d9b53f", "p": "fe856d", "ear": "round", "ey": "star",
		"ec": "f0c53a", "m": "open_smile", "mc": "eb6000", "pt": "none", "x": {},
		"t": [{"hold": "mug"}, {"head": "orange"}, {"tail": "curl"}]},
	{"b": "9c6f9e", "e": "6b4470", "p": "d2a08c", "ear": "pointy", "ey": "iris",
		"ec": "f0c53a", "m": "neutral", "mc": "6e5546", "w": "droop",
		"pt": "siamese", "pc": "6b4470", "x": {},
		"t": [{"head": "wizard"}, {"hold": "orb"}, {"tail": "curl"}]},
	{"b": "fdfdfd", "e": "cfd8e3", "p": "fdb3a2", "ear": "round", "ey": "sleep",
		"m": "yawn", "mc": "f39e63", "w": "droop", "pt": "none",
		"x": {"back": "pillow"},
		"t": [{"head": "sleep_mask"}, {"hold": "lantern"}, {"tail": "curl"}]},
	{"b": "f2854a", "e": "c05a24", "p": "fe9883", "ear": "pointy", "ey": "squint",
		"m": "open_smile", "mc": "eb6000", "pt": "tabby_head", "pc": "c05a24",
		"x": {},
		"t": [{"head": "headset"}, {"hold": "keyboard"}, {"tail": "ring"}]},
	{"b": "8fbf5a", "e": "5c8a30", "p": "fdb3a2", "ear": "folded", "ey": "oval",
		"m": "w", "pt": "none", "x": {"mark": "moon"},
		"t": [{"hold": "mug"}, {"chest": "bowtie"}, {"tail": "curl"}]},
	{"b": "3b4a6b", "e": "22304a", "p": "fdfbf8", "ear": "pointy", "ey": "star",
		"ec": "f0c53a", "m": "neutral", "pt": "tuxedo_face", "pc": "fbf6ee",
		"x": {"face": "sunglasses"},
		"t": [{"hold": "tie"}, {"chest": "badge"}, {"tail": "curl"}]},
	{"b": "ff9d8a", "e": "d96a55", "p": "fe856d", "ear": "round", "ey": "iris",
		"ec": "f0c53a", "m": "open_smile", "mc": "eb6000", "pt": "none", "x": {},
		"t": [{"chest": "bowtie"}, {"head": "orange"}, {"tail": "ring"}]},
	{"b": "c8cdd4", "e": "949aa4", "p": "fdfbf8", "ear": "round", "ey": "tired",
		"m": "neutral", "w": "droop", "pt": "tabby_head", "pc": "949aa4",
		"x": {"face": "round_glasses"},
		"t": [{"hold": "book"}, {"head": "sleep_mask"}, {"tail": "ring"}]},
	{"b": "7a6fd0", "e": "4d43a0", "p": "d2a08c", "ear": "pointy", "ey": "star",
		"ec": "f0c53a", "m": "w", "mc": "6e5546", "pt": "siamese", "pc": "4d43a0",
		"x": {},
		"t": [{"head": "wizard"}, {"hold": "orb"}, {"tail": "curl"}]},
	{"b": "fdf0a8", "e": "e8c74a", "p": "fe9883", "ear": "folded", "ey": "squint",
		"m": "open_smile", "mc": "eb6000", "pt": "none", "x": {},
		"t": [{"hold": "mug"}, {"head": "headset"}, {"tail": "ring"}]},
	{"b": "8a5a3c", "e": "5e3a24", "p": "d2a08c", "ear": "round", "ey": "oval",
		"m": "w", "pt": "tabby_head", "pc": "5e3a24", "x": {},
		"t": [{"hold": "book"}, {"chest": "bowtie"}, {"tail": "curl"}]},
	{"b": "5aa8d8", "e": "2f6f9e", "p": "fdfbf8", "ear": "pointy", "ey": "iris",
		"ec": "f0c53a", "m": "neutral", "pt": "siamese", "pc": "2f6f9e", "x": {},
		"t": [{"head": "headset"}, {"hold": "keyboard"}, {"tail": "ring"}]},
	{"b": "ffd4e2", "e": "ec9ab6", "p": "fdb3a2", "ear": "folded", "ey": "sleep",
		"m": "yawn", "mc": "f39e63", "w": "droop", "pt": "none",
		"x": {"mark": "moon"},
		"t": [{"head": "sleep_mask"}, {"hold": "lantern"}, {"tail": "curl"}]},
	{"b": "a8a45c", "e": "6f6c30", "p": "d2a08c", "ear": "round", "ey": "tired",
		"m": "neutral", "pt": "tabby_head", "pc": "6f6c30",
		"x": {"face": "round_glasses"},
		"t": [{"hold": "book"}, {"chest": "bowtie"}, {"tail": "ring"}]},
	{"b": "d8f26a", "e": "9ac02e", "p": "fe856d", "ear": "pointy", "ey": "star",
		"ec": "f0c53a", "m": "open_smile", "mc": "eb6000", "pt": "none", "x": {},
		"t": [{"head": "wizard"}, {"hold": "orb"}, {"tail": "curl"}]},
	{"b": "2e3350", "e": "1b1f36", "p": "fdfbf8", "ear": "round", "ey": "star",
		"ec": "f0c53a", "m": "w", "w": "droop", "pt": "siamese", "pc": "1b1f36",
		"x": {"mark": "moon"},
		"t": [{"head": "wizard"}, {"face": "sunglasses"}, {"tail": "ring"}]},
]

static var _temp_chars: Dictionary = {}


## 임시 캐릭터 정의 {char id: CHARS와 같은 모양}. TEMP_DEFS 한 줄을 CHARS 항목으로
## 부풀린다 — 적어 두지 않은 자리는 전부 기본값(코·볼·발바닥 모양 등)이다.
static func temp_chars() -> Dictionary:
	if not _temp_chars.is_empty():
		return _temp_chars
	var out := {}
	for i in TEMP_DEFS.size():
		var d: Dictionary = TEMP_DEFS[i]
		var no := TEMP_FIRST + i
		var parts := {
			"body_col": Color(str(d.b)), "ear_col": Color(str(d.e)),
			"tail_col": Color(str(d.e)), "foot_col": Color("fbf6ee"),
			"pad_col": Color(str(d.p)),
			"ear": str(d.ear), "eyes": str(d.ey),
			"eye_col": Color(str(d.get("ec", "241f28"))),
			"nose": "tri", "nose_col": Color("e58a86"),
			"mouth": str(d.m), "mouth_col": Color(str(d.get("mc", "2c2a33"))),
			"whisker": str(d.get("w", "basic")), "whisker_col": Color("2c2a33"),
			"cheek": "pink", "cheek_col": Color("feb8ad"), "feet": "beans",
			"pattern": str(d.pt), "tail": "none",
		}
		if str(d.pt) != "none":
			parts["pattern_col"] = Color(str(d.get("pc", d.e)))
		for k: String in (d.x as Dictionary):
			parts[k] = (d.x as Dictionary)[k]
		out["char%02d" % no] = {
			"name": "CAT_TMP%02d" % no, "parts": parts, "tiers": d.t,
		}
	_temp_chars = out
	return out


## 디자인 캐릭터 + 임시 캐릭터. 파츠를 읽는 쪽은 이걸 쓴다
## (임시 캐릭터를 지우면 이 함수도 CHARS 하나로 돌아간다).
static func all_chars() -> Dictionary:
	var out := CHARS.duplicate()
	out.merge(temp_chars())
	return out

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
	for l: Dictionary in CatLayouts.LAYOUTS.get(char_id, []):
		if str(l.n) == layer:
			out[layer] = char_id
			return


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


# ══════════════════════════════════════════════════════════════════════════════
# [임시 · temp_parts.gd와 함께 제거] 정식 카탈로그 + 임시 파츠
# 임시 옵션·임시 색은 기존 목록 **뒤에** 붙는다 — 저장된 index가 밀리지 않는다.
# 제거할 때: parts_all()/groups_all() 호출부를 PARTS/GROUPS로 되돌리면 된다.
# ══════════════════════════════════════════════════════════════════════════════

static var _parts_all: Array[Dictionary] = []
static var _groups_all: Array[Dictionary] = []


## 커스터마이저가 실제로 늘어놓는 부위 목록 = PARTS + 임시 파츠.
static func parts_all() -> Array[Dictionary]:
	if not _parts_all.is_empty():
		return _parts_all
	var out: Array[Dictionary] = []
	for part in PARTS:
		var p: Dictionary = part.duplicate(true)
		var key := str(p.key)
		if p.get("type") == "color":
			if TempParts.COLORS.has(key):
				var cols: Array = (p.cols as Array).duplicate()
				for hex: String in (TempParts.COLORS[key] as Array):
					cols.append(Color(hex))
				p["cols"] = cols
		elif TempParts.STYLES.has(key):
			var opts: Array = (p.opts as Array).duplicate(true)
			for opt: Dictionary in (TempParts.STYLES[key] as Array):
				opts.append(opt.duplicate(true))
			p["opts"] = opts
		out.append(p)
	# 정식 카탈로그에 아예 없던 부위 (목 소품 · 코 모양).
	for np in TempParts.NEW_PARTS:
		var p: Dictionary = np.duplicate(true)
		var opts: Array = (p.base as Array).duplicate(true)
		p.erase("base")
		for opt: Dictionary in (TempParts.STYLES.get(str(p.key), []) as Array):
			opts.append(opt.duplicate(true))
		p["opts"] = opts
		out.append(p)
	_parts_all = out
	return _parts_all


## 커스터마이저 부위 묶음 = GROUPS + 임시 부위 자리.
static func groups_all() -> Array[Dictionary]:
	if not _groups_all.is_empty():
		return _groups_all
	var out: Array[Dictionary] = []
	for g in GROUPS:
		var d: Dictionary = g.duplicate(true)
		# 코 모양은 코 색과 같은 묶음에 앉힌다.
		if str(d.key) == "g_nose":
			(d.parts as Array).append("nose")
		out.append(d)
		for ex in TempParts.GROUPS_EXTRA:
			if str(ex.get("after", "")) == str(d.key):
				var e: Dictionary = ex.duplicate(true)
				e.erase("after")
				out.append(e)
	_groups_all = out
	return _groups_all


## 이 부위가 임시 파츠로 새로 생긴 자리인가 (출처표에 출처 없이 오른다).
static func _is_temp_part(key: String) -> bool:
	for np in TempParts.NEW_PARTS:
		if str(np.key) == key:
			return true
	return false


## [임시] 임시 파츠·임시 색은 빌려 온 냥이가 없다 — 출처표에 출처 없이 올린다.
## (실제 해금은 골드 구매다 — GameState.part_unlocked 참조.)
static func _mark_temp_open(out: Dictionary, part: Dictionary) -> void:
	var key := str(part.key)
	if part.get("type") == "color":
		var base := 0
		for o in PARTS:
			if str(o.key) == key:
				base = (o.cols as Array).size()
		for i in range(base, (part.cols as Array).size()):
			out[key][i] = []
		return
	var opts: Array = part.opts
	for i in opts.size():
		if _is_temp_part(key) or TempParts.owns(key, str(opts[i].id)):
			out[key][i] = []



## 파츠 상점: 처음부터 열려 있는 옵션 index들 (부위 key별) — 백지 몸통(BLANK_CHAR)의
## 기본값과 "없음"이다. 나머지는 전부 꾸미기 화면에서 골드로 사야 쓸 수 있다.
static var _free_opts: Dictionary = {}


static func free_options(key: String) -> Array:
	if _free_opts.is_empty():
		var base := char_selection("custom")  # 백지 몸통의 기본 선택
		for part in parts_all():
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

static func get_part(key: String) -> Dictionary:
	for p in parts_all():
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
	var def: Dictionary = all_chars().get(char_id, BLANK_CHAR)
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
	var def: Dictionary = all_chars().get(char_id, BLANK_CHAR)
	var tiers: Array = def.tiers
	if tier < 0 or tier >= tiers.size():
		return out
	var gained: Dictionary = tiers[tier]
	for bundle_key: String in gained:
		for part in parts_all():
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
	for part in parts_all():
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
	# 디자인 냥이가 아니면(= 나만의 캐릭터, 그리고 아직 시트가 없는 임시 캐릭터)
	# 시트 파츠 그림을 직접 조립해 그린다.
	# [임시] 몸 실루엣을 바꾸는 임시 파츠(귀 모양)를 골랐으면 시트 조립을 포기하고
	# 코드 렌더러에 맡긴다 — 시트에는 그 실루엣 그림이 없다.
	if not CHARS.has(char_id) and not TempParts.forces_code_render(parts):
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
	for part in parts_all():
		var key := str(part.key)
		out[key] = {}
		# "없음"은 어느 냥이의 것도 아니다 — 늘 고를 수 있어야 원상복구가 된다.
		if part.get("type") != "color":
			var opts: Array = part.opts
			for i in opts.size():
				if str(opts[i].id) == "none":
					out[key][i] = []
		_mark_temp_open(out, part)  # [임시] 임시 파츠는 빌려 온 냥이가 없다
	for char_id: String in CHARS:
		var def: Dictionary = CHARS[char_id]
		_collect_sources(out, char_id, 0, def.parts)
		var tiers: Array = def.tiers
		for t in tiers.size():
			_collect_sources(out, char_id, t + 1, tiers[t])
	_sources = out
	return out


## 파츠 묶음 하나(기본 파츠 또는 해금 단계 하나)를 출처표에 적는다.
static func _collect_sources(out: Dictionary, char_id: String, tier: int,
		parts: Dictionary) -> void:
	for part in parts_all():
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
