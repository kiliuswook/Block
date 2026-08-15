extends RefCounted
## 나만의 냥이(커스텀 캐릭터) 부위 카탈로그.
## 선택값은 GameState.custom_cat({부위 key: 옵션 index})에 저장되고,
## build_skin()이 Player.paint_cat이 읽는 skin 딕셔너리로 변환한다.
## 스타일 옵션의 "r"은 희귀도(0 일반~3 전설, 표시용), "d"는 플레이버 텍스트.
## (class_name 없이 preload로 참조 — 전역 클래스 캐시 갱신 불필요)

const RARITY_NAMES: Array[String] = ["CAT_RARITY_0", "CAT_RARITY_1",
		"CAT_RARITY_2", "CAT_RARITY_3"]
const RARITY_COLS: Array[Color] = [
	Color(1, 1, 1, 0.75), Color(0.45, 0.8, 1.0),
	Color(0.78, 0.55, 1.0), Color(1.0, 0.85, 0.35),
]

const BODY_COLS: Array[Color] = [
	Color("f4e3c8"), Color("f5b352"), Color("a06a42"), Color("3a3540"),
	Color("f2f1ec"), Color("aeb6c2"), Color("f6cdd8"), Color("bfe8d5"),
	Color("a8d4f0"), Color("cfc0ea"), Color("f4e97e"), Color("5a5560"),
	Color("d97742"), Color("6e4a30"), Color("c8e87e"), Color("f0937a"),
	Color("6fc8c0"), Color("3c4668"),
]
const EAR_COLS: Array[Color] = [
	Color("d9a05c"), Color("e08a3c"), Color("6b4226"), Color("26232c"),
	Color("d8d4cc"), Color("7e8694"), Color("e08ea6"), Color("6fbf9a"),
	Color("5a9ad0"), Color("9a85c8"), Color("d0b84a"), Color("3c3844"),
	Color("b05a28"), Color("4a3020"), Color("8fb84a"), Color("c86048"),
	Color("3f8f88"), Color("2a3350"),
]
const EYE_COLS: Array[Color] = [
	Color("2a2230"), Color("6b4226"), Color("d09030"), Color("4a9a58"),
	Color("4a6fb8"), Color("c85a78"), Color("b8433f"), Color("7a55b0"),
	Color("5ac8c8"), Color("e07830"), Color("d8d8e0"), Color("305038"),
]
const PATTERN_COLS: Array[Color] = [
	Color("8a5a3c"), Color("2c2833"), Color("f2f1ec"), Color("e08a3c"),
	Color("7e8694"), Color("e08ea6"), Color("6fbf9a"), Color("f2c94c"),
	Color("4a6fb8"), Color("7a55b0"), Color("b8433f"), Color("3a5a40"),
]
const NOSE_COLS: Array[Color] = [
	Color("e58a86"), Color("8a5a3c"), Color("2c2833"), Color("c85a78"),
	Color("f2c94c"), Color("6fbf9a"),
]

## 부위 목록. type "color"는 cols 팔레트에서, "style"은 opts에서 고른다.
## index 0이 기본값 — 스타일 부위는 0번을 무난한 기본 모양으로 둔다.
const PARTS: Array[Dictionary] = [
	{"key": "body", "name": "CAT_PART_BODY", "type": "color", "cols": BODY_COLS},
	{"key": "ear", "name": "CAT_PART_EAR", "type": "color", "cols": EAR_COLS},
	{"key": "eyes", "name": "CAT_PART_EYES", "type": "style", "opts": [
		{"id": "round", "name": "동글눈", "d": "가장 순수한 눈망울."},
		{"id": "sparkle", "name": "반짝눈", "r": 1, "d": "눈에 우주가 담겼다."},
		{"id": "happy", "name": "웃는눈", "d": "세상 만사가 즐겁다."},
		{"id": "sleepy", "name": "조는눈", "d": "5분만 더..."},
		{"id": "wink", "name": "윙크", "r": 1, "d": "심쿵 주의."},
		{"id": "star", "name": "별눈", "r": 2, "d": "밤하늘을 훔쳐온 눈."},
		{"id": "heart", "name": "하트눈", "r": 2, "d": "사랑에 빠졌다냥."},
		{"id": "dot", "name": "점눈", "d": "미니멀리즘의 극치."},
		{"id": "angry", "name": "부릅눈", "d": "오늘은 참지 않는다."},
		{"id": "sad", "name": "시무룩눈", "d": "간식을 뺏겼다..."},
		{"id": "surprised", "name": "놀란눈", "r": 1, "d": "세상에 이런 일이!"},
		{"id": "closed", "name": "감은눈", "d": "마음의 눈으로 본다."},
		{"id": "glare", "name": "째려눈", "r": 1, "d": "레이저 발사 직전."},
		{"id": "cross", "name": "어질눈", "r": 1, "d": "방금 세탁기에서 나옴."},
		{"id": "uwu", "name": "야무진눈", "r": 1, "d": ">ㅅ< 그 자체."},
		{"id": "big", "name": "왕눈", "r": 1, "d": "동공에 은하수 탑재."},
		{"id": "moon", "name": "초승달눈", "r": 2, "d": "달빛을 머금었다."},
		{"id": "diamond", "name": "보석눈", "r": 3, "d": "감정가 측정 불가."},
		{"id": "spiral", "name": "빙글눈", "r": 2, "d": "최면에 걸릴지도."},
		{"id": "lash", "name": "속눈썹눈", "r": 2, "d": "메이크업 3시간 소요."}]},
	{"key": "eye_col", "name": "CAT_PART_EYE_COL", "type": "color", "cols": EYE_COLS},
	{"key": "nose", "name": "CAT_PART_NOSE", "type": "style", "opts": [
		{"id": "tri", "name": "세모코", "d": "정석 중의 정석."},
		{"id": "heart", "name": "하트코", "r": 1, "d": "숨쉴 때마다 사랑 발사."},
		{"id": "dot", "name": "점코", "d": "겸손한 코."},
		{"id": "square", "name": "네모코", "r": 1, "d": "각진 인생."},
		{"id": "oval", "name": "길쭉코", "d": "냄새 감지력 2배(주장)."},
		{"id": "clover", "name": "클로버코", "r": 2, "d": "행운이 스며든다."},
		{"id": "shine", "name": "반짝코", "r": 2, "d": "코가 24K."},
		{"id": "none", "name": "없음", "d": "코는 마음속에 있다."}]},
	{"key": "nose_col", "name": "CAT_PART_NOSE_COL", "type": "color", "cols": NOSE_COLS},
	{"key": "mouth", "name": "CAT_PART_MOUTH", "type": "style", "opts": [
		{"id": "w", "name": "야옹입", "d": "클래식 그 자체."},
		{"id": "smile", "name": "미소", "d": "온화함 만렙."},
		{"id": "neutral", "name": "무심", "d": "쿨내 진동."},
		{"id": "meow", "name": "야옹!", "r": 1, "d": "성대 풀가동."},
		{"id": "tongue", "name": "메롱", "r": 1, "d": "약오르지롱."},
		{"id": "frown", "name": "뾰로통", "d": "츄르 내놔."},
		{"id": "grin", "name": "씨익", "r": 1, "d": "뭔가 꾸미고 있다."},
		{"id": "fang", "name": "송곳니", "r": 2, "d": "야생의 흔적."},
		{"id": "pout", "name": "오물입", "r": 1, "d": "오물오물."},
		{"id": "zigzag", "name": "덜덜입", "r": 1, "d": "월요일을 마주한 표정."},
		{"id": "whistle", "name": "휘파람", "r": 2, "d": "시치미 뚝."},
		{"id": "drool", "name": "침흘림", "r": 1, "d": "츄르 목격 직후."}]},
	{"key": "whisker", "name": "CAT_PART_WHISKER", "type": "style", "opts": [
		{"id": "basic", "name": "기본", "d": "단정한 기본 수염."},
		{"id": "long", "name": "긴 수염", "d": "연륜의 상징."},
		{"id": "droop", "name": "처진 수염", "d": "나른한 오후."},
		{"id": "curl", "name": "곱슬", "r": 1, "d": "파마 시술 완료."},
		{"id": "up", "name": "치켜 수염", "d": "자신감 상승."},
		{"id": "zig", "name": "지그재그", "r": 1, "d": "감전된 게 아니다."},
		{"id": "thick", "name": "굵은 수염", "r": 1, "d": "수염에 진심."},
		{"id": "single", "name": "외수염", "d": "하나면 충분하다."},
		{"id": "spark", "name": "전기 수염", "r": 3, "d": "정전기 충전 완료."},
		{"id": "none", "name": "없음", "d": "면도 완료."}]},
	{"key": "pattern", "name": "CAT_PART_PATTERN", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "순수 단색 원단."},
		{"id": "stripes", "name": "이마 줄무늬", "d": "야생 0.1% 함유."},
		{"id": "spots", "name": "얼룩", "d": "우유에 빠졌다 나옴."},
		{"id": "patch", "name": "눈가 반점", "d": "타고난 아이패치."},
		{"id": "tuxedo", "name": "턱시도", "r": 1, "d": "격식 있는 냥이."},
		{"id": "socks", "name": "양말", "r": 1, "d": "4켤레 상시 착용."},
		{"id": "forehead", "name": "얼룩 이마", "d": "삼색이의 유산."},
		{"id": "tabby", "name": "고등어", "r": 1, "d": "고등어 등급 A+."},
		{"id": "tiger", "name": "호랑이", "r": 2, "d": "어흥(이라고 해봄)."},
		{"id": "cow", "name": "젖소", "r": 1, "d": "음메...가 아니라 야옹."},
		{"id": "heart_patch", "name": "하트 무늬", "r": 2, "d": "심장이 두 개."},
		{"id": "star_patch", "name": "별 무늬", "r": 2, "d": "별자리 인증 완료."},
		{"id": "lightning", "name": "번개 무늬", "r": 2, "d": "속도의 증표."},
		{"id": "half", "name": "반반", "r": 2, "d": "반반 무마니."},
		{"id": "diamond", "name": "다이아 무늬", "r": 3, "d": "럭셔리 그 자체."},
		{"id": "belly", "name": "둥근 배", "d": "배부터 만지고 싶다."}]},
	{"key": "pattern_col", "name": "CAT_PART_PATTERN_COL", "type": "color", "cols": PATTERN_COLS},
	{"key": "tail", "name": "CAT_PART_TAIL", "type": "style", "opts": [
		{"id": "curl", "name": "말린 꼬리", "d": "기분 좋음의 표준."},
		{"id": "up", "name": "쭉 편 꼬리", "d": "당당한 직립 꼬리."},
		{"id": "fluffy", "name": "복슬 꼬리", "r": 1, "d": "이불 대용 가능."},
		{"id": "stub", "name": "짧은 꼬리", "d": "귀여움 응축형."},
		{"id": "zigzag", "name": "번개 꼬리", "r": 1, "d": "찌릿찌릿."},
		{"id": "long", "name": "긴 꼬리", "r": 1, "d": "우아함이 흐른다."},
		{"id": "double", "name": "쌍꼬리", "r": 3, "d": "요괴 냥이 설화의 주인공."},
		{"id": "heart", "name": "하트 꼬리", "r": 2, "d": "끝까지 사랑스럽다."},
		{"id": "star", "name": "별 꼬리", "r": 2, "d": "유성 꼬리 아님."},
		{"id": "flame", "name": "불꽃 꼬리", "r": 3, "d": "앉을 때 조심."},
		{"id": "straight", "name": "빳빳 꼬리", "d": "기분 최상급 신호."},
		{"id": "question", "name": "물음표 꼬리", "r": 2, "d": "영원한 미스터리."},
		{"id": "ring", "name": "고리 꼬리", "r": 1, "d": "래쿤 아님."},
		{"id": "none", "name": "없음", "d": "밸런스 조정의 희생양."}]},
	{"key": "paws", "name": "CAT_PART_PAWS", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "발은 소중하니까 숨김."},
		{"id": "paws", "name": "앞발", "d": "까꿍, 앞발 등장."},
		{"id": "beans", "name": "젤리 발바닥", "r": 1, "d": "말랑함 보증."},
		{"id": "mittens", "name": "흰 장갑", "r": 1, "d": "격조 높은 장갑."},
		{"id": "boots", "name": "부츠", "r": 1, "d": "장화 신은 냥이."},
		{"id": "heart_beans", "name": "하트 젤리", "r": 2, "d": "발바닥까지 사랑."},
		{"id": "star_beans", "name": "별 젤리", "r": 2, "d": "밟히면 소원 성취."}]},
	{"key": "blush", "name": "CAT_PART_BLUSH", "type": "style", "opts": [
		{"id": "pink", "name": "핑크", "d": "은은한 홍조."},
		{"id": "peach", "name": "피치", "d": "복숭아 두 조각."},
		{"id": "big", "name": "큼직", "r": 1, "d": "부끄러움 최대 출력."},
		{"id": "line", "name": "빗금", "d": "수줍음 3단계."},
		{"id": "heart", "name": "하트 볼", "r": 2, "d": "볼에도 사랑이."},
		{"id": "star", "name": "별 볼", "r": 2, "d": "볼이 반짝반짝."},
		{"id": "blue", "name": "새파람", "r": 1, "d": "기가 막힌 상황."},
		{"id": "none", "name": "없음", "d": "포커페이스."}]},
	{"key": "mark", "name": "CAT_PART_MARK", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "깨끗한 이마."},
		{"id": "star", "name": "별", "r": 1, "d": "선택받은 냥이의 증표."},
		{"id": "moon", "name": "초승달", "r": 1, "d": "세일러 냥."},
		{"id": "heart", "name": "하트", "r": 1, "d": "이마로 고백한다."},
		{"id": "freckles", "name": "주근깨", "d": "귀여움 촘촘 배치."},
		{"id": "diamond", "name": "다이아", "r": 2, "d": "이마에 박은 재산."},
		{"id": "lightning", "name": "번개", "r": 2, "d": "마법 냥이 학교 출신."},
		{"id": "cross", "name": "십자", "r": 1, "d": "분노 게이지 표시등."},
		{"id": "dot", "name": "점", "d": "매력 점 하나."},
		{"id": "third_eye", "name": "제3의 눈", "r": 3, "d": "진실이 보인다..."},
		{"id": "band", "name": "반창고", "d": "격투의 흔적."},
		{"id": "clover", "name": "클로버", "r": 2, "d": "네잎은 아니지만 행운."}]},
	{"key": "extra", "name": "CAT_PART_EXTRA", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "민낯의 자신감."},
		{"id": "glasses", "name": "뿔테 안경", "d": "지성 +5 (기분상)."},
		{"id": "round_glasses", "name": "동글 안경", "d": "순한 맛 지성파."},
		{"id": "sunglasses", "name": "선글라스", "r": 2, "d": "빛이 너무 밝다."},
		{"id": "heart_glasses", "name": "하트 안경", "r": 2, "d": "세상이 사랑으로 보인다."},
		{"id": "star_glasses", "name": "별 안경", "r": 2, "d": "스타의 필수품."},
		{"id": "monocle", "name": "외알 안경", "r": 2, "d": "교양이 흘러넘친다."},
		{"id": "eyepatch", "name": "안대", "r": 2, "d": "봉인된 힘."},
		{"id": "mask", "name": "마스크", "d": "감기 조심."},
		{"id": "mustache", "name": "콧수염", "r": 1, "d": "신사의 품격."},
		{"id": "fish", "name": "붕어 간식", "r": 1, "d": "비상식량 상시 휴대."},
		{"id": "tear", "name": "눈물", "d": "감동 중."},
		{"id": "sweat", "name": "진땀", "d": "마감 직전."},
		{"id": "scar", "name": "흉터", "r": 2, "d": "전설의 상처."}]},
]


static func get_part(key: String) -> Dictionary:
	for p in PARTS:
		if p.key == key:
			return p
	return {}


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


static func _style_id(sel: Dictionary, key: String) -> String:
	var part := get_part(key)
	return str((part.opts as Array)[pick(sel, key)].id)


## 선택값 → Player.paint_cat용 skin 딕셔너리 (body/ear + "custom" 파트).
static func build_skin(sel: Dictionary) -> Dictionary:
	return {
		"body": BODY_COLS[pick(sel, "body")],
		"ear": EAR_COLS[pick(sel, "ear")],
		"custom": {
			"eyes": _style_id(sel, "eyes"),
			"eye_col": EYE_COLS[pick(sel, "eye_col")],
			"nose": _style_id(sel, "nose"),
			"nose_col": NOSE_COLS[pick(sel, "nose_col")],
			"mouth": _style_id(sel, "mouth"),
			"whisker": _style_id(sel, "whisker"),
			"pattern": _style_id(sel, "pattern"),
			"pattern_col": PATTERN_COLS[pick(sel, "pattern_col")],
			"tail": _style_id(sel, "tail"),
			"paws": _style_id(sel, "paws"),
			"blush": _style_id(sel, "blush"),
			"mark": _style_id(sel, "mark"),
			"extra": _style_id(sel, "extra"),
		},
	}
