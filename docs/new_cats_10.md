# 신규 디자인 냥이 10종 (char07 ~ char16) — 컨셉안

> 2026-09-29 · Higgsfield(GPT Image 2.5)로 생성한 **컨셉 이미지**. 아트 전달용 초안이며 게임에 바로 들어가는 에셋이 아니다.
> 그림: `리소스/new_chars/charNN_*.png`(4단계 한 장) · `리소스/new_chars/tiers/charNN_tT.png`(단계별 크롭) · 한눈에 보기 `리소스/new_chars/_overview.png`
> Higgsfield 프로젝트: "Cat-Tris 신규 캐릭터 10종"(재생성 전 초안은 `리소스/new_chars/_rejected/`)

## 기존 규칙 그대로

- 패널 4장 = **Default → 1st → 2nd → 3rd Parts** (`CHARS[..].tiers`, 키캡 A~Z 한 바퀴마다 하나씩)
- 3rd는 기존 6종처럼 **꼬리**(`Cat_Tail_*`)로 통일
- 기본 골격(몸통 외곽선·앞발·젤리·볼·수염·코)은 공통, 캐릭터마다 달라지는 것은 아래 표의 레이어뿐이다

## 파츠 구성표

레이어 이름은 `CATTRIS_Char_Sheet.png`의 열을 따르고, `키`는 `custom_cat.gd`의 `PARTS` 부위다. **굵게 = 카탈로그에 새로 붙는 옵션.**

| id | 이름(안) | 몸통 / 무늬 | 눈 · 입 | Default 소품 | 1st | 2nd | 3rd (꼬리) |
|---|---|---|---|---|---|---|---|
| char07 | 제빵사냥 | 버터 크림 `#f6dcaa`, 귀·이마 카라멜 `#c98b4f` (tabby_head) | **^^ 웃는눈** · w | — | Prop_Head **요리사 모자** | Cat_Prop_Belly **컵케이크** | **복슬 말린 꼬리** (카라멜) |
| char08 | 해적 선장냥 | 브라운 태비 `#b07a4a` / 줄 `#7a4f2e` | oval(한쪽) · w | Prop_Face **안대** | Prop_Head **해적 삼각모** | Cat_Prop_Belly **보물 상자** | ring (태비 줄무늬) |
| char09 | 우주냥 (러시안 블루) | 블루그레이 `#8d9cb8`, 귀 `#6c7a96` | **초록 반짝눈** · w | Deco_Forehead **별** | Prop_Head **별 더듬이 머리띠** | Cat_Prop_Belly **로켓** | curl |
| char10 | 닌자냥 | 차콜 네이비 `#34364a` (단색) | **날카로운 눈(연두)** · 일자입 | — | Prop_Head **빨간 머리띠** | Prop_Back **카타나** | **지그재그 꼬리** |
| char11 | 화가냥 (삼색) | 흰 `#fbf6ee` + 귀 주황 `#f0932b`/검정 `#2f2c33` (**삼색 패치**) | oval · open_smile | Deco_Forehead **볼 물감 자국** | Prop_Head **베레모** | Cat_Prop_Belly **팔레트·붓** | **삼색 줄 꼬리** |
| char12 | 딸기우유냥 | 파스텔 핑크 `#f7c1cf`, 귀·발 `#e98aa4` | **핑크 반짝눈** · w | Deco_Forehead **하트** | Prop_Head **딸기 비니** | Cat_Prop_Belly **딸기우유 팩** | curl + **리본** |
| char13 | 왕자냥 | 라일락 `#cdbde6`, 귀 `#9a82c4` | **반쯤 뜬 보라눈** · 미소 | — | Prop_Head **왕관** | Prop_Back **망토** (+가슴 브로치) | **S자 꼬리** |
| char14 | 여름휴가냥 (벵갈) | 샌디 골드 `#e6b872` + **표범 반점** `#8a5a34` | **윙크** · 벌린 입 | — | Cat_Prop_Chest **꽃 레이** | Cat_Prop_Belly **수박** | 반점 꼬리 (끝 짙게) |
| char15 | 비 오는 날냥 | 회색 `#9aa3ad` + 흰 얼굴 (tuxedo_face 계열, 회색) | **글썽눈(하늘)** · o입 | — | Prop_Head **노란 레인햇** | Prop_Back **노란 우산** | curl (회색) |
| char16 | 젖소냥 | 흰 `#fbf6ee` + **젖소 반점** `#2f2c33`, 짝짝이 귀 | 점눈 · w, **큰 분홍 코** | — | Cat_Prop_Chest **방울 목줄** | Prop_Head **벙거지 모자(데이지)** | **반점+술 꼬리** |

### 카탈로그에 늘어날 것 (아트가 레이어로 나오면 `PARTS`에 한 줄씩)

- **head** +9: 요리사 모자 · 해적 삼각모 · 별 더듬이 · 닌자 머리띠 · 베레모 · 딸기 비니 · 왕관 · 레인햇 · 벙거지
- **hold** +6: 컵케이크 · 보물 상자 · 로켓 · 팔레트 · 딸기우유 · 수박
- **back** +3: 카타나 · 망토 · 우산 / **chest** +2: 꽃 레이 · 방울 목줄 / **face** +1: 안대
- **mark** +3: 별 · 하트 · 물감 자국
- **eyes** +7: ^^ · 초록 반짝 · 날카로운 · 핑크 반짝 · 반쯤 뜬 · 윙크 · 글썽
- **pattern** +3: 삼색 패치 · 표범 반점 · 젖소 반점 (+ 회색 턱시도는 기존 `tuxedo_face` 색 변경으로)
- **tail** 모양 +4: 복슬 · 지그재그 · S자 · 술 꼬리 (리본은 별도 레이어로 뺄지 아트와 협의)
- 팔레트: `BODY_COLS` +8 · `EAR_COLS`/`PATTERN_COLS` 몇 줄 · `EYE_COLS` 초록/연두/핑크/보라/하늘

### 유니크 후보

기존 규칙(희귀도 r=2 + `"u": true` = 캔 전용)을 따른다면 **왕관 · 망토 · 카타나 · 로켓** 정도가 캔 파츠 후보다 — 기획 확인 필요.

## 게임 적용 (2026-09-29)

게임에 들어갔다 — 임시 캐릭터 24종을 지우고 `GameState.CATS`에 10종(`baker`·`pirate`·`space`·`ninja`·`painter`·`strawberry`·`prince`·`summer`·`rainy`·`cow`)을 붙였다. 그림은 `tools/import_gen_cats.py`가 이 컨셉을 **완성 렌더로만** 옮긴 것이다(CLAUDE.md "신규 디자인 냥이 10종").

## 남은 일

1. ~~아트 재작업~~ → **2026-09-29 Higgsfield로 레이어 분리 완료** (`tools/gen_cat_layers.py`, CLAUDE.md "신규 디자인 냥이 10종"). 위 "카탈로그에 늘어날 것"은 냥이마다 자기 옵션으로 `PARTS`에 붙었다(망토는 몸 앞으로 오는 털 장식 때문에 `Prop_Back`이 아니라 `Cat_Prop_Chest`로 갔다). 아트가 나중에 시트 형식으로 정식 레이어를 주면 `extract_cat_sheet.py` 경로로 바꾸면 된다.
2. 능력치(`stats`)·특성(`trait`)은 가안이다 — 밸런스 확인 필요.
3. 영어 이름·소개는 가안(content.csv), 나머지 언어는 번역 대기.
4. IP 주의: 닌자 머리띠 초안에 특정 애니 마크가 들어가 재생성했고, 젖소냥 밀짚모자도 특정 캐릭터와 겹쳐 벙거지로 바꿨다. 아트 재작업 때도 같은 점을 봐 줄 것.
5. 우주냥 더듬이 별의 빛 번짐 가장자리에 마젠타 기운이 살짝 남아 있다 (크로마키 한계).
