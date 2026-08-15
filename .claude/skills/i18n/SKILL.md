---
name: i18n
description: 13개국어 로컬라이제이션 규칙. 사용자에게 보이는 텍스트를 추가/수정하거나 UI·메뉴·팝업·컨텐츠 문구를 만들 때 반드시 참조. 하드코딩 금지 규칙, 번역 키 명명, CSV 워크플로, 폰트·레이아웃 대응, 스팀 스토어 언어 설정 포함.
---

# Cat-Tris 다국어 지원 규칙 (목표: 13개국어)

스팀 출시 기준 **13개국어**를 지원한다.
**사용자에게 보이는 문자열을 새로 넣는 모든 작업은, 그 문자열이 13개국어로 나갈 수 있는 상태여야 완료다.**

## 지원 언어 (확정 13종)

| # | 언어 | Godot 로케일 | 스팀 표기 | 티어 |
|---|---|---|---|---|
| 1 | English | `en` | English | 1 |
| 2 | 한국어 | `ko` | Korean | 1 |
| 3 | 简体中文 | `zh_CN` | Simplified Chinese | 1 |
| 4 | 日本語 | `ja` | Japanese | 1 |
| 5 | Русский | `ru` | Russian | 1 |
| 6 | Español (LatAm) | `es_MX` | Spanish - Latin America | 2 |
| 7 | Deutsch | `de` | German | 2 |
| 8 | Français | `fr` | French | 2 |
| 9 | Português (BR) | `pt_BR` | Portuguese - Brazil | 2 |
| 10 | Türkçe | `tr` | Turkish | 2 |
| 11 | Polski | `pl` | Polish | 2 |
| 12 | Italiano | `it` | Italian | 3 |
| 13 | 繁體中文 | `zh_TW` | Traditional Chinese | 3 |

- **스페인어는 LatAm 하나만** (es_ES 별도 추가 금지 — 유지비만 늘고 매출 차이 없음).
- 티어는 *번역 투입 순서*일 뿐, **코드는 처음부터 13종 전부를 전제로 작성**한다. 미번역 언어는 영어로 폴백된다.
- 14번째 후보(Українська `uk`)는 출시 후 판단. 그 전엔 목록을 늘리지 않는다.

## 철칙 1: 사용자에게 보이는 문자열을 코드에 박지 않는다

```gdscript
# 금지
label.text = "게임 시작"
draw_string(font, pos, "최고 기록")

# 올바름
label.text = tr("MENU_PLAY")
draw_string(font, pos, tr("HUD_BEST"))
```

**예외 (tr() 불필요):**
- 디버그/로그 출력, `push_error`, 테스트 스크립트(`tests/`)
- 숫자·기호만인 문자열 (`"%d"`, `"×"`, `"⚙"`)
- 저장 키·모드 식별자 등 내부 문자열 (`"classic"`, `"endless"`) — **이건 절대 번역하지 말 것**. 번역 대상은 화면 표시용 라벨뿐이고, `GameState.mode` 같은 내부 값과는 분리한다.

## 철칙 2: `_draw()`의 텍스트는 자동 번역되지 않는다

Godot은 Control 노드의 `text` 프로퍼티만 자동 번역한다.
Cat-Tris는 UI 상당수를 `_draw()`로 직접 그리므로(`title.gd`, `escape_board.gd`, `ui_kit.gd`, `cat_customizer.gd`, `touch_button.gd`) **`draw_string`/`block_text`에 넘기는 문자열은 반드시 손으로 `tr()`을 감싼다.**

`ui_kit.gd`의 블록 폰트(`GLYPHS`, 3×5)는 **ASCII 전용**이다.
- 블록 폰트로 그리는 곳(로고, 강조 라벨)에는 **번역 대상 문구를 넣지 말 것.** 게임 타이틀 "CAT-TRIS"처럼 언어 무관한 고유명사만 허용.
- 새로 블록 텍스트를 쓰고 싶은데 번역이 필요하다면 → 일반 폰트 `draw_string`으로 바꾼다.

## 철칙 3: 번역 파일 구조

```
shared/locale/
  ui.csv        # 메뉴·HUD·설정·팝업 (핵심, 우선 번역)
  content.csv   # 캐릭터·상점·모드 설명
  flavor.csv    # custom_cat.gd 부위 이름/플레이버 등 대량 저빈도 텍스트
```

- CSV 헤더: `keys,en,ko,<번역이 실제로 들어간 로케일들>,en_XA`
- **소스 언어는 `en`** (번역 외주 시 영어 기준이 단가·품질 모두 유리). `ko`는 원문 보존용으로 나란히 유지.
- **⚠ 완전히 빈 로케일 열은 넣지 말 것.** Godot의 CSV 임포터는 메시지가 하나도 없는 열에 대해 `.translation`을 만들지 않고 `bucket_table_size == 0` 에러만 뱉는다. **열은 번역이 하나라도 채워질 때 추가**한다. 일부만 채워진 열은 정상이며, 빈 칸은 `en`으로 폴백된다 (검증 완료).
- 열 목록에 없는 로케일(`de`, `fr` …)도 `TranslationServer.set_locale()`은 그대로 받고 `en`으로 폴백하므로, **언어 선택 UI에는 처음부터 13종을 다 노출해도 안전하다.**
- Godot이 `.csv`를 CSV Translation으로 임포트 → `shared/locale/<파일>.<로케일>.translation`이 CSV 옆에 생성됨 → `project.godot`의 `internationalization/locale/translations`에 등록. `locale/fallback="en"`.
- 파일/열을 새로 만들면 등록도 함께. 등록 안 하면 조용히 키 문자열이 그대로 화면에 나온다.

### 유지보수 도구

```powershell
# 빈 로케일 열 정리 + en_XA 의사 로케일 열 재생성
& "<godot>" --headless --path E:\Game\Block --script res://tools/locale_tool.gd
# 그 다음 반드시 재임포트
& "<godot>" --headless --path E:\Game\Block --import
```
CSV를 손댔으면 **항상 이 두 줄을 순서대로** 돌린다.

### 키 명명 규칙

`영역_의미` 대문자 스네이크. 영역 접두사는 고정:

| 접두사 | 범위 |
|---|---|
| `MENU_` | 타이틀 메뉴, 모드 선택 |
| `HUD_` | 인게임 표시 (SCORE, LEVEL, LINES…) |
| `SET_` | 설정 패널 |
| `POP_` | 사망/일시정지/결과 팝업 |
| `CHAR_` | 캐릭터·스킨 이름·해금 조건 |
| `SHOP_` | 상점·재화 |
| `RANK_` | 랭킹 |
| `CAT_` | 냥이 크리에이터 부위·옵션 |
| `TUT_` | 조작 안내·힌트 |

키에 최종 문구를 넣지 말 것 (`MENU_게임시작` ✗ → `MENU_PLAY` ✓).

### 플레이스홀더

```gdscript
# CSV: "POP_RESULT_GOLD" -> "Earned {gold} gold"
tr("POP_RESULT_GOLD").format({"gold": amount})
```
`%d`/`%s` 위치 인자 대신 **이름 있는 `{}` + `format()`**을 쓴다. 언어마다 어순이 바뀌므로 위치 인자는 번역자가 순서를 못 바꾼다.

복수형(1 line / 2 lines)은 러시아어·폴란드어에서 3형태라 규칙이 복잡하다. **가급적 "LINES: 3"처럼 숫자를 라벨과 분리**해 복수형 자체를 피한다. 불가피하면 `tr_n()` 사용.

## 철칙 4: 폰트

기본 폰트는 `shared/assets/fonts/ui_font.tres` (`FontVariation`) — `project.godot`의 `gui/theme/custom_font`가 이걸 가리킨다.

번들 폰트 `NotoSansKR-Regular.otf`의 실측 커버리지:

| 커버함 | **빠짐** |
|---|---|
| 라틴, 키릴(ru), 한글, 가나, 기호(◆ ▶ ★) | 터키어 `ğ`, 폴란드어 `ł`, **간체 전용 한자**, 의사 로케일 악센트 |

빠진 글리프는 `ui_font.tres`의 **`fallbacks` 배열**(SystemFont 2단: 라틴/키릴 → CJK)이 OS 폰트에서 메운다.

- **단일 폰트로 13개국어를 다 덮으려 하지 말 것.** 반드시 폴백 체인.
- **SystemFont 폴백은 데스크톱(=스팀) 전제다.** 웹·안드로이드는 시스템 폰트를 못 쓰므로, 그 타깃에서 CJK를 지원하게 되면 Noto Sans SC/TC/JP `.otf`를 **FontFile 폴백으로 번들**해야 한다.
- **웹 빌드 용량 주의** — CJK 폰트는 파일당 5~10MB+다. 웹(GitHub Pages)은 한/영만 노출하고 CJK 폰트를 익스포트에서 제외하는 방향을 우선 검토. 스팀 빌드는 용량 제약이 사실상 없다.
- 폰트를 추가/교체했으면 **각 언어 대표 문자열로 실제 렌더 확인**(두부 `□` 없는지):
  `English / 한국어 / 简体中文 / 繁體中文 / 日本語 / Русский / Türkçe ığş / Polski łąę`
  의사 로케일(`--locale=en_XA`)이 악센트 문자를 잔뜩 쓰므로 **폴백 점검을 겸한다.**

## 철칙 5: 레이아웃은 텍스트가 길어질 것을 전제한다

한국어 대비 길이 배율(대략): 독일어 ×1.8, 러시아어 ×1.6, 프랑스어/스페인어 ×1.5, 영어 ×1.3, 중/일 ×0.9.

이미 걸려 있는 안전장치 (새로 만들 때 이걸 쓰면 된다):

- **버튼**: `UiKit.style_button()`이 `clip_text = true`를 건다 → 긴 번역이 버튼 밖으로 자라지 않는다. `btn_primary`/`btn_card`/`btn_ghost`/`btn_chip` 전부 여기를 거치므로 자동 적용.
- **`_draw()` 텍스트**: `UiKit.fit_size(font, text, width, size)`로 폭에 맞게 글자 크기를 줄인다. `UiKit.center_text()`/`center_text_outlined()`/`title.gd`의 `_draw_center_text()`는 이미 내장.
- **새로 `draw_string`을 쓸 때는 반드시 `fit_size`를 거칠 것.** 고정 좌표에 그냥 찍으면 독일어에서 화면 밖으로 나간다.

그 외:
- 버튼/라벨 폭을 **문자열 길이로 계산하지 말고** 레이아웃 비율로 잡는다 (`title.gd`의 `_compute_layout()` 방식 유지).
- 모바일 세로 화면은 가로폭이 좁아 **오버플로가 먼저 터진다** — `/platform-split` 체크리스트와 함께 확인.

## 철칙 6: 언어 선택 (구현됨 — `core/autoload/i18n.gd`, autoload `I18n`)

`I18n`이 로케일 목록·판별·적용·저장을 전부 소유한다. 새 코드는 `TranslationServer`를 직접 만지지 말고 `I18n`을 쓸 것.

| API | 용도 |
|---|---|
| `I18n.LOCALES` | 13종 정의 (`code` + `native` 자기 표기) |
| `I18n.codes()` | 선택 UI에 노출할 코드 목록 (디버그 빌드에서만 `en_XA` 포함) |
| `I18n.native_name(code)` | "한국어" / "简体中文" — **현재 언어로 번역하지 말 것** |
| `I18n.detect()` | OS 로케일 → 지원 로케일 (`pt_PT` → `pt_BR`, 미지원 → `en`) |
| `I18n.apply(code)` | 적용 + `GameState.locale` 저장 (`""` = 자동 판별) |
| `I18n.t(key, fallback)` | CSV에 아직 없는 키를 원문으로 표시 — **마이그레이션 중 컨텐츠 전용**, 새 문자열엔 쓰지 말 것 |

- 저장은 `GameState.locale`(save.json). `reset_all()`은 언어를 지우지 않는다 (볼륨·닉네임과 동일).
- **언어 선택은 타이틀 설정에서만 노출**한다 (`settings_panel.open(on_title)`). 변경 시 `reload_current_scene()`으로 씬을 새로 열어 모든 문자열을 다시 읽는데, 인게임에서 하면 진행 중인 판이 날아간다.
- 스팀 빌드는 스팀 클라이언트 언어를 우선 존중 (`Platform` 추상화 경유 — 게임 코드에서 GodotSteam 직접 호출 금지). **아직 미구현.**

### 개발용 로케일 강제

```powershell
& "<godot>" --path E:\Game\Block -- --locale=de       # 특정 언어로 실행
& "<godot>" --path E:\Game\Block -- --locale=en_XA    # 의사 로케일 (레이아웃 점검)
& "<godot>" --path E:\Game\Block res://tests/visual_capture.tscn -- --locale=en_XA
```
`--locale`은 **저장되지 않는다** — 레이아웃 테스트가 플레이어의 실제 선택을 덮어쓰지 않는다.

## 스팀 스토어 쪽 (게임 내 번역과 별개)

- Steamworks의 **Supported Languages**에 위 13종을 등록하되, 실제로 넣은 것만 체크한다. 거짓 체크는 환불·부정 리뷰로 직결.
  - 체크 항목은 Interface / Full Audio / Subtitles 3종. Cat-Tris는 음성이 없으므로 **Interface만** 체크.
- **스토어 페이지 설명·스크린샷 캡션은 13종 전부 채운다.** 게임 내 번역보다 노출·전환 기여가 크고, 게임 내 번역이 티어 2·3에 도달하기 전에도 먼저 할 수 있다.
- 업적(Achievement) 이름/설명도 Steamworks에서 언어별로 입력한다 — 게임 CSV와 별도 관리이니 업적을 추가하면 양쪽 모두 갱신.

## 작업 체크리스트 (문자열이 생기거나 바뀌면 필수)

- [ ] 새 사용자 문자열이 **CSV에 키로 등록**되었나? (코드에 리터럴이 남지 않았나)
- [ ] `_draw()` 텍스트에 `tr()`을 손으로 감쌌나?
- [ ] 블록 폰트(`ui_kit.block_text`)에 번역 대상 문구를 넣지 않았나?
- [ ] 어순이 바뀌는 문장에 `{이름}` 플레이스홀더 + `format()`을 썼나?
- [ ] 최소 `en`·`ko` 두 열을 채웠나? (나머지는 빈칸 → 영어 폴백, 허용)
- [ ] 긴 번역(독일어 ×1.8)으로 레이아웃이 깨지지 않나? — 아래 의사 로케일 테스트
- [ ] 모바일 세로에서도 확인했나? (`/platform-split`)

### 의사 로케일(pseudo-locale) 테스트

번역이 도착하기 전에 레이아웃 파손을 잡는 가장 싼 방법. `en_XA` 열은 `tools/locale_tool.gd`가 `en`에서 자동 생성한다 (**손으로 채우지 말 것** — 다음 실행 때 덮어써진다). 영어를 악센트 문자로 바꾸고 1.8배로 늘린다:

```
"Settings" -> "[Şéţţïńğş ——————]"
```

```powershell
& "<godot>" --headless --path E:\Game\Block --script res://tools/locale_tool.gd  # 재생성
& "<godot>" --headless --path E:\Game\Block --import
& "<godot>" --path E:\Game\Block res://tests/visual_capture.tscn -- --locale=en_XA
```
`.tmp_shots/`를 눈으로 확인:
- 버튼 밖으로 글자가 나가면 → `UiKit.style_button`을 안 거친 버튼이다.
- `_draw()` 텍스트가 화면 밖으로 나가면 → `UiKit.fit_size`를 안 거쳤다.
- 두부(`□`)가 보이면 → 폰트 폴백 누락.
- `MENU_PLAY` 같은 **키가 그대로 보이면** → CSV 누락이거나, 코드가 그 라벨을 나중에 덮어써서 자동 번역이 끊긴 것(모드 버튼이 실제로 이 함정에 걸렸다 — 라벨을 재조립하는 코드는 키를 코드에 따로 들고 있어야 한다).

## 현재 상태 / 남은 마이그레이션

**인프라 완료** — CSV 3종(ui/content/flavor), `I18n` autoload, 설정의 언어 선택, 폰트 폴백, `locale_tool.gd`, `--locale` 강제, 레이아웃 안전장치(`clip_text`/`fit_size`).

**마이그레이션 완료** (en/ko 양쪽 채움):

| 파일 | 비고 |
|---|---|
| `settings_panel.gd` / `death_popup.gd` / `main.gd` / `title.gd` | UI 전체 |
| `game_state.gd` | CATS·ACCESSORIES·BOOSTS의 `name`/`trait`/`desc`가 **키 문자열**로 바뀜 (`"CAT_CREAM"` 등) — 표시할 때 `tr()`로 감쌀 것 |
| `ranks.gd` | 기간·점수 표기 |
| `cat_customizer.gd` | 크리에이터 UI |
| `custom_cat.gd` | `PARTS[].name`·`RARITY_NAMES`만 (부위 카테고리) |
| `title.tscn` / `main.tscn` / `main_mobile.tscn` | Control `text`는 자동 번역, TouchButton `label`은 `touch_button.gd`가 `tr()` 처리 |

**남은 것:**

| 대상 | 양 | 우선순위 |
|---|---|---|
| `custom_cat.gd`의 옵션 `name`/`d` (부위 ~121종 + 플레이버) | ~240 | 낮음 — `flavor.csv`로. 키 규칙 `CAT_<PART>_<ID>` / `..._D` |
| `story_stages.gd` | 60 | 보류 (메뉴에서 내린 모드) |
| `ranks.gd`의 `MOCK_NAMES` | 24 | 안 함 — 가짜 플레이어 닉네임이라 번역 대상 아님 |
| Tier 1~3 실제 번역 (en/ko 외 11종) | 165키 × 11 | 외주 |

**신규 작업 규칙: 마이그레이션이 끝나지 않았어도, 새로 건드리는 파일의 문자열은 그 자리에서 CSV로 옮긴다.** 기존 하드코딩을 남긴 채 새 하드코딩을 더하지 말 것.

### 번역 열 추가 절차 (예: 독일어가 도착했을 때)

1. `shared/locale/*.csv`에 `de` 열 추가 + 값 채우기 (일부만 채워도 됨)
2. `--script res://tools/locale_tool.gd` → `--import`
3. `project.godot`의 `locale/translations`에 `<파일>.de.translation` 3개 등록
4. `-- --locale=de`로 실행해 레이아웃 확인 (독일어가 가장 길다)
5. Steamworks의 Supported Languages에 German 체크

## 흔한 실수

- `_draw()` 텍스트에 `tr()` 누락 → 개발 중엔 한국어로 잘 보여서 끝까지 안 걸린다.
- 내부 식별자(`"classic"`, `"endless"`, save.json 키)를 번역 → 저장 데이터·랭킹 보드가 깨진다.
- CSV를 만들고 `project.godot`에 등록을 안 함 → 화면에 `MENU_PLAY` 같은 키가 그대로 노출.
- **완전히 빈 로케일 열을 CSV에 추가** → `.translation`이 아예 생성되지 않고 `bucket_table_size == 0` 에러만 난다.
- **씬의 `text`를 코드가 나중에 덮어씀** → 자동 번역이 끊겨 키가 그대로 보인다. 라벨을 재조립하는 코드(번호 붙이기 등)는 **키를 코드에 따로 들고** `tr()`을 직접 부를 것.
- `locale_tool.gd`를 돌리고 `--import`를 빼먹음 → 번역이 갱신되지 않는다.
- 폰트 폴백 없이 언어만 추가 → 중국어/일본어/러시아어에서 전부 두부(`□`).
- 버튼 폭을 한국어 기준으로 고정 → 독일어에서 글자가 버튼 밖으로 나감.
- 스팀 Supported Languages에 미번역 언어를 체크 → "번역이 없다"는 부정 리뷰.
- CSV를 UTF-8 BOM 없이/있이 섞어 저장 → 임포트 시 글자 깨짐. **UTF-8로 통일.**
