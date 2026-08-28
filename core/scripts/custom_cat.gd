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

const RARITY_NAMES: Array[String] = ["CAT_RARITY_0", "CAT_RARITY_1",
		"CAT_RARITY_2", "CAT_RARITY_3"]
const RARITY_COLS: Array[Color] = [
	Color(1, 1, 1, 0.75), Color(0.45, 0.8, 1.0),
	Color(0.78, 0.55, 1.0), Color(1.0, 0.85, 0.35),
]

const BODY_COLS: Array[Color] = [
	Color("fbf6ee"), Color("f4e3c8"), Color("f0932b"), Color("2f2c33"),
	Color("f2f1ec"), Color("aeb6c2"), Color("f6cdd8"), Color("bfe8d5"),
	Color("a8d4f0"), Color("cfc0ea"), Color("f4e97e"), Color("5a5560"),
	Color("f5b352"), Color("a06a42"), Color("d97742"), Color("6e4a30"),
	Color("c8e87e"), Color("f0937a"), Color("6fc8c0"), Color("3c4668"),
]
const EAR_COLS: Array[Color] = [
	Color("f3b53f"), Color("d9a05c"), Color("d0781c"), Color("26232c"),
	Color("d8d4cc"), Color("7e8694"), Color("e08ea6"), Color("6fbf9a"),
	Color("5a9ad0"), Color("9a85c8"), Color("d0b84a"), Color("3c3844"),
	Color("e08a3c"), Color("6b4226"), Color("b05a28"), Color("4a3020"),
	Color("8fb84a"), Color("c86048"), Color("3f8f88"), Color("2a3350"),
]
const EYE_COLS: Array[Color] = [
	Color("241f28"), Color("2a2230"), Color("6b4226"), Color("f0c53a"),
	Color("d09030"), Color("4a9a58"), Color("4a6fb8"), Color("c85a78"),
	Color("b8433f"), Color("7a55b0"), Color("5ac8c8"), Color("e07830"),
	Color("d8d8e0"), Color("305038"),
]
const PATTERN_COLS: Array[Color] = [
	Color("fbf6ee"), Color("d0781c"), Color("8a5a3c"), Color("2c2833"),
	Color("6b4a3a"), Color("7e8694"), Color("e08a3c"), Color("e08ea6"),
	Color("6fbf9a"), Color("f2c94c"), Color("4a6fb8"), Color("7a55b0"),
	Color("b8433f"), Color("3a5a40"),
]
const NOSE_COLS: Array[Color] = [
	Color("e58a86"), Color("f7a8a4"), Color("8a5a3c"), Color("2c2833"),
	Color("c85a78"), Color("f2c94c"), Color("6fbf9a"),
]
const PAD_COLS: Array[Color] = [
	Color("f7a8a4"), Color("e58a86"), Color("d2716d"), Color("f2c94c"),
	Color("b0a8b8"), Color("8a5a3c"),
]

## 부위 목록. type "color"는 cols 팔레트에서, "style"은 opts에서 고른다.
## index 0이 기본값 — 스타일 부위는 0번을 컨셉 시트의 기본 모양으로 둔다.
const PARTS: Array[Dictionary] = [
	{"key": "body", "name": "CAT_PART_BODY", "type": "color", "cols": BODY_COLS},
	{"key": "ear", "name": "CAT_PART_EAR", "type": "color", "cols": EAR_COLS},
	{"key": "ear_shape", "name": "CAT_PART_EAR_SHAPE", "type": "style", "opts": [
		{"id": "round", "name": "동글 귀", "d": "표준 규격 삼각 귀."},
		{"id": "folded", "name": "접힌 귀", "r": 1, "d": "Char01의 노란 접힌 귀."},
		{"id": "pointy", "name": "쫑긋 귀", "d": "소리를 놓치지 않는다."},
		{"id": "big", "name": "큰 귀", "r": 1, "d": "레이더 성능 2배."},
		{"id": "chip", "name": "짧은 귀", "d": "야무진 실루엣."},
		{"id": "tuft", "name": "링스 귀", "r": 2, "d": "귀 끝 술이 포인트."},
		{"id": "none", "name": "없음", "r": 1, "d": "귀는 마음으로 듣는다."}]},
	{"key": "eyes", "name": "CAT_PART_EYES", "type": "style", "opts": [
		{"id": "oval", "name": "까만눈", "d": "컨셉 시트 기본 — 하이라이트 2점."},
		{"id": "iris", "name": "홍채눈", "r": 1, "d": "Char02의 노란 눈동자."},
		{"id": "squint", "name": "><눈", "d": "Char03의 기분 최고 눈."},
		{"id": "sleep", "name": "감은눈", "d": "Char04의 잠든 눈."},
		{"id": "star", "name": "별눈", "r": 2, "d": "Char05의 별 박은 눈."},
		{"id": "tired", "name": "졸린눈", "d": "Char06의 반쯤 감긴 눈."},
		{"id": "round", "name": "동글눈", "d": "가장 순수한 눈망울."},
		{"id": "sparkle", "name": "반짝눈", "r": 1, "d": "눈에 우주가 담겼다."},
		{"id": "happy", "name": "웃는눈", "d": "세상 만사가 즐겁다."},
		{"id": "sleepy", "name": "조는눈", "d": "5분만 더..."},
		{"id": "wink", "name": "윙크", "r": 1, "d": "심쿵 주의."},
		{"id": "heart", "name": "하트눈", "r": 2, "d": "사랑에 빠졌다냥."},
		{"id": "dot", "name": "점눈", "d": "미니멀리즘의 극치."},
		{"id": "angry", "name": "부릅눈", "d": "오늘은 참지 않는다."},
		{"id": "sad", "name": "시무룩눈", "d": "간식을 뺏겼다..."},
		{"id": "surprised", "name": "놀란눈", "r": 1, "d": "세상에 이런 일이!"},
		{"id": "closed", "name": "지긋눈", "d": "마음의 눈으로 본다."},
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
		{"id": "w", "name": "야옹입", "d": "컨셉 시트의 기본 입."},
		{"id": "open_smile", "name": "활짝 웃음", "d": "Char03의 만개한 미소."},
		{"id": "yawn", "name": "하품", "d": "Char04의 새벽 3시."},
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
		{"id": "tabby_head", "name": "이마 태비", "d": "Char03·06의 줄무늬."},
		{"id": "tuxedo_face", "name": "턱시도 얼굴", "r": 1, "d": "Char02의 흰 가슴팍."},
		{"id": "siamese", "name": "샴 마스크", "r": 1, "d": "Char05의 짙은 얼굴."},
		{"id": "visor_face", "name": "페이스 플레이트", "r": 2, "d": "로봇냥의 얼굴 판."},
		{"id": "calico", "name": "삼색 얼룩", "r": 1, "d": "삼색이의 유산."},
		{"id": "stripes", "name": "이마 줄무늬", "d": "야생 0.1% 함유."},
		{"id": "spots", "name": "얼룩", "d": "우유에 빠졌다 나옴."},
		{"id": "patch", "name": "눈가 반점", "d": "타고난 아이패치."},
		{"id": "tuxedo", "name": "턱시도", "r": 1, "d": "격식 있는 냥이."},
		{"id": "socks", "name": "양말", "r": 1, "d": "4켤레 상시 착용."},
		{"id": "forehead", "name": "얼룩 이마", "d": "반반 이마."},
		{"id": "tabby", "name": "고등어", "r": 1, "d": "고등어 등급 A+."},
		{"id": "tiger", "name": "호랑이", "r": 2, "d": "어흥(이라고 해봄)."},
		{"id": "cow", "name": "젖소", "r": 1, "d": "음메...가 아니라 야옹."},
		{"id": "heart_patch", "name": "하트 무늬", "r": 2, "d": "심장이 두 개."},
		{"id": "star_patch", "name": "별 무늬", "r": 2, "d": "별자리 인증 완료."},
		{"id": "lightning", "name": "번개 무늬", "r": 2, "d": "속도의 증표."},
		{"id": "half", "name": "반반", "r": 2, "d": "반반 무마니."},
		{"id": "diamond", "name": "다이아 무늬", "r": 3, "d": "럭셔리 그 자체."},
		{"id": "belly", "name": "둥근 배", "d": "배부터 만지고 싶다."}]},
	{"key": "pattern_col", "name": "CAT_PART_PATTERN_COL", "type": "color",
		"cols": PATTERN_COLS},
	{"key": "paws", "name": "CAT_PART_PAWS", "type": "style", "opts": [
		{"id": "beans", "name": "젤리 발바닥", "d": "컨셉 시트의 기본 앞발."},
		{"id": "plain", "name": "민발", "d": "발바닥은 비밀."},
		{"id": "mittens", "name": "흰 장갑", "r": 1, "d": "격조 높은 장갑."},
		{"id": "socks", "name": "흰 양말", "r": 1, "d": "발끝만 하얗게."},
		{"id": "boots", "name": "부츠", "r": 1, "d": "장화 신은 냥이."},
		{"id": "heart_beans", "name": "하트 젤리", "r": 2, "d": "발바닥까지 사랑."},
		{"id": "star_beans", "name": "별 젤리", "r": 2, "d": "밟히면 소원 성취."},
		{"id": "none", "name": "없음", "d": "발은 소중하니까 숨김."}]},
	{"key": "pad_col", "name": "CAT_PART_PAD_COL", "type": "color", "cols": PAD_COLS},
	{"key": "tail", "name": "CAT_PART_TAIL", "type": "style", "opts": [
		{"id": "curl", "name": "말린 꼬리", "d": "컨셉 시트의 3rd 파츠."},
		{"id": "none", "name": "없음", "d": "아직 해금되지 않은 느낌."},
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
		{"id": "ring", "name": "고리 꼬리", "r": 1, "d": "래쿤 아님."}]},
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
		{"id": "moon", "name": "초승달", "r": 1, "d": "Char04의 이마 달."},
		{"id": "star", "name": "별", "r": 1, "d": "선택받은 냥이의 증표."},
		{"id": "heart", "name": "하트", "r": 1, "d": "이마로 고백한다."},
		{"id": "freckles", "name": "주근깨", "d": "귀여움 촘촘 배치."},
		{"id": "diamond", "name": "다이아", "r": 2, "d": "이마에 박은 재산."},
		{"id": "lightning", "name": "번개", "r": 2, "d": "마법 냥이 학교 출신."},
		{"id": "cross", "name": "십자", "r": 1, "d": "분노 게이지 표시등."},
		{"id": "dot", "name": "점", "d": "매력 점 하나."},
		{"id": "third_eye", "name": "제3의 눈", "r": 3, "d": "진실이 보인다..."},
		{"id": "band", "name": "반창고", "d": "격투의 흔적."},
		{"id": "clover", "name": "클로버", "r": 2, "d": "네잎은 아니지만 행운."}]},
	{"key": "face", "name": "CAT_PART_FACE", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "민낯의 자신감."},
		{"id": "sunglasses", "name": "선글라스", "r": 2, "d": "Char02의 2nd 파츠."},
		{"id": "round_glasses", "name": "동글 안경", "d": "Char06의 지성 담당."},
		{"id": "sleep_mask", "name": "수면 안대", "r": 1, "d": "Char04의 1st 파츠."},
		{"id": "headset", "name": "게이밍 헤드셋", "r": 1, "d": "Char03의 1st 파츠."},
		{"id": "square_glasses", "name": "뿔테 안경", "d": "지성 +5 (기분상)."},
		{"id": "visor", "name": "바이저", "r": 2, "d": "로봇냥 시야 확보."},
		{"id": "monocle", "name": "외알 안경", "r": 2, "d": "교양이 흘러넘친다."},
		{"id": "eyepatch", "name": "안대", "r": 2, "d": "봉인된 힘."},
		{"id": "mask", "name": "마스크", "d": "감기 조심."},
		{"id": "mustache", "name": "콧수염", "r": 1, "d": "신사의 품격."},
		{"id": "scar", "name": "흉터", "r": 2, "d": "전설의 상처."}]},
	{"key": "head", "name": "CAT_PART_HEAD", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "머리는 가볍게."},
		{"id": "orange", "name": "귤", "r": 1, "d": "Char01의 2nd 파츠."},
		{"id": "wizard", "name": "마법사 모자", "r": 2, "d": "Char05의 1st 파츠."},
		{"id": "ribbon", "name": "리본", "d": "머리 옆 포인트."},
		{"id": "beanie", "name": "털모자", "d": "겨울 준비 완료."},
		{"id": "cap", "name": "야구모자", "d": "챙은 언제나 옆으로."},
		{"id": "flower", "name": "꽃", "r": 1, "d": "봄을 얹었다."},
		{"id": "leaf", "name": "새싹", "d": "물 주면 자란다(거짓)."},
		{"id": "crown", "name": "왕관", "r": 3, "d": "왕이 되었다냥."},
		{"id": "tophat", "name": "실크햇", "r": 2, "d": "마술 준비 완료."},
		{"id": "halo", "name": "천사 고리", "r": 3, "d": "이미 착한 냥이."},
		{"id": "antenna", "name": "안테나", "r": 2, "d": "수신 감도 양호."}]},
	{"key": "neck", "name": "CAT_PART_NECK", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "목은 자유롭게."},
		{"id": "tie", "name": "넥타이", "r": 1, "d": "Char02의 1st 파츠."},
		{"id": "bowtie", "name": "나비넥타이", "r": 1, "d": "Char06의 1st 파츠."},
		{"id": "bell", "name": "방울", "d": "딸랑딸랑 출근."},
		{"id": "scarf", "name": "목도리", "d": "겨울 필수템."},
		{"id": "bandana", "name": "반다나", "r": 1, "d": "모험가의 표식."},
		{"id": "chain", "name": "금목걸이", "r": 2, "d": "부의 상징."}]},
	{"key": "hold", "name": "CAT_PART_HOLD", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "빈손이 제일 편하다."},
		{"id": "mug", "name": "머그컵", "r": 1, "d": "Char01의 1st 파츠."},
		{"id": "keyboard", "name": "키보드", "r": 1, "d": "Char03의 2nd 파츠."},
		{"id": "book", "name": "책", "r": 1, "d": "Char06의 2nd 파츠."},
		{"id": "orb", "name": "수정 구슬", "r": 2, "d": "Char05의 2nd 파츠."},
		{"id": "lantern", "name": "랜턴", "r": 2, "d": "Char04의 2nd 파츠."},
		{"id": "fish", "name": "생선", "d": "비상식량 상시 휴대."},
		{"id": "yarn", "name": "털실 뭉치", "d": "한 번 굴리면 못 멈춘다."},
		{"id": "controller", "name": "게임패드", "r": 2, "d": "손맛 담당."}]},
	{"key": "chest", "name": "CAT_PART_CHEST", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "가슴팍은 비워둔다."},
		{"id": "badge", "name": "경찰 배지", "r": 2, "d": "Char02의 1st 파츠."},
		{"id": "heart_pin", "name": "하트 핀", "r": 1, "d": "마음을 달고 다닌다."},
		{"id": "gem_pin", "name": "보석 핀", "r": 2, "d": "작지만 비싸다."},
		{"id": "pocket", "name": "주머니", "d": "간식 보관용."}]},
	{"key": "back", "name": "CAT_PART_BACK", "type": "style", "opts": [
		{"id": "none", "name": "없음", "d": "등은 가볍게."},
		{"id": "cape", "name": "망토", "r": 2, "d": "펄럭임 담당."},
		{"id": "wings", "name": "날개", "r": 3, "d": "점프가 아니라 비행."},
		{"id": "balloon", "name": "풍선", "r": 1, "d": "언젠가 날아간다."},
		{"id": "jetpack", "name": "제트팩", "r": 3, "d": "연료는 츄르."}]},
]

## 컨셉 시트의 디자인 캐릭터들. parts = 디폴트 비주얼,
## tiers = 키캡 도감을 완성할 때마다 순서대로 붙는 1st / 2nd / 3rd 파츠.
const CHARS: Dictionary = {
	"char01": {  # 우유냥 — 접힌 노란 귀, 머그컵과 귤
		"name": "CAT_CREAM",
		"parts": {
			"body_col": Color("fbf6ee"), "ear_col": Color("f3b53f"),
			"tail_col": Color("f3b53f"), "foot_col": Color("fbf6ee"),
			"ear": "folded", "eyes": "oval", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"), "mouth": "w",
			"whisker": "basic", "cheek": "pink", "feet": "beans",
			"pattern": "none", "tail": "none",
		},
		"tiers": [{"hold": "mug"}, {"head": "orange"}, {"tail": "curl"}],
	},
	"char02": {  # 턱시도 순경냥 — 흰 얼굴, 넥타이·배지·선글라스
		"name": "CAT_BLACK",
		"parts": {
			"body_col": Color("2f2c33"), "ear_col": Color("26232c"),
			"tail_col": Color("f2f1ec"), "foot_col": Color("fbf6ee"),
			"ear": "pointy", "eyes": "iris", "eye_col": Color("f0c53a"),
			"nose": "tri", "nose_col": Color("e58a86"), "mouth": "w",
			"whisker": "basic", "cheek": "pink", "feet": "beans",
			"pattern": "tuxedo_face", "pattern_col": Color("fbf6ee"), "tail": "none",
		},
		"tiers": [{"neck": "tie", "chest": "badge"}, {"face": "sunglasses"},
			{"tail": "curl"}],
	},
	"char03": {  # 치즈 게이머냥 — 태비 줄무늬, 헤드셋과 키보드
		"name": "CAT_CHEESE",
		"parts": {
			"body_col": Color("f0932b"), "ear_col": Color("d0781c"),
			"tail_col": Color("f0932b"), "foot_col": Color("fdf3e4"),
			"ear": "pointy", "eyes": "squint", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"), "mouth": "open_smile",
			"whisker": "basic", "cheek": "pink", "feet": "beans",
			"pattern": "tabby_head", "pattern_col": Color("d0781c"), "tail": "none",
		},
		"tiers": [{"face": "headset"}, {"hold": "keyboard"}, {"tail": "ring"}],
	},
	"char04": {  # 잠꾸러기냥 — 이마 달, 수면 안대와 랜턴
		"name": "CAT_SLEEPY",
		"parts": {
			"body_col": Color("fbf6ee"), "ear_col": Color("f0e2d8"),
			"tail_col": Color("f0e2d8"), "foot_col": Color("fbf6ee"),
			"ear": "round", "eyes": "sleep", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"), "mouth": "yawn",
			"whisker": "droop", "cheek": "pink", "feet": "beans",
			"pattern": "none", "mark": "moon", "tail": "none",
		},
		"tiers": [{"face": "sleep_mask", "mark": "none"}, {"hold": "lantern"},
			{"tail": "curl"}],
	},
	"char05": {  # 샴 마법냥 — 짙은 마스크, 마법사 모자와 수정 구슬
		"name": "CAT_WIZARD",
		"parts": {
			"body_col": Color("f0e2d0"), "ear_col": Color("5a4038"),
			"tail_col": Color("6b4a3a"), "foot_col": Color("cbb2a2"),
			"ear": "round", "eyes": "star", "eye_col": Color("f0c53a"),
			"nose": "tri", "nose_col": Color("8a5a3c"), "mouth": "w",
			"whisker": "basic", "cheek": "pink", "feet": "beans",
			"pad_col": Color("d2a08c"),
			"pattern": "siamese", "pattern_col": Color("6b4a3a"), "tail": "none",
		},
		"tiers": [{"head": "wizard"}, {"hold": "orb"}, {"tail": "curl"}],
	},
	"char06": {  # 회색 학자냥 — 동글 안경, 나비넥타이와 책
		"name": "CAT_GRAY",
		"parts": {
			"body_col": Color("aeb6c2"), "ear_col": Color("7e8694"),
			"tail_col": Color("aeb6c2"), "foot_col": Color("fbf6ee"),
			"ear": "round", "eyes": "tired", "eye_col": Color("241f28"),
			"nose": "tri", "nose_col": Color("e58a86"), "mouth": "neutral",
			"whisker": "basic", "cheek": "pink", "feet": "beans",
			"pattern": "tabby_head", "pattern_col": Color("7e8694"),
			"face": "round_glasses", "tail": "none",
		},
		"tiers": [{"neck": "bowtie"}, {"hold": "book"}, {"tail": "ring"}],
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
		"ear": "pointy", "eyes": "oval", "eye_col": Color("241f28"),
		"nose": "tri", "nose_col": Color("e58a86"), "mouth": "w",
		"whisker": "basic", "cheek": "pink", "feet": "beans",
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
	"eye_col": ["Cat_Eyes_Color"],
	"pad_col": ["Cat_Feet_Pawpad"],
}


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


## 디자인 캐릭터의 파츠 묶음 — tier(0~3)만큼 해금 파츠를 얹어 돌려준다.
static func char_parts(char_id: String, tier := TIER_MAX) -> Dictionary:
	var def: Dictionary = CHARS.get(char_id, BLANK_CHAR)
	var parts: Dictionary = (def.parts as Dictionary).duplicate(true)
	var tiers: Array = def.tiers
	for i in mini(maxi(tier, 0), tiers.size()):
		for k: String in (tiers[i] as Dictionary):
			parts[k] = (tiers[i] as Dictionary)[k]
	return parts


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
		"paws":
			return "feet"
		"blush":
			return "cheek"
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
	return skin_from_parts(apply_sel(char_parts(char_id, tier), sel))


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
