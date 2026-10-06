# WonderWheel 스플래시 (Godot 4.6 공용 애드온)

앱을 시작할 때 원더휠 회사 로고를 연출과 효과음으로 보여주는 애드온입니다. 길이는 약 4.5초입니다.
세 시안 모두 관람차가 처음부터 끝까지 계속 돌아갑니다. 시안은 인스펙터의 `style` 하나로 바꿀 수 있습니다.

| style | 흐름 | 임팩트 |
|---|---|---|
| `NIGHT_LIGHTS` (A. 점등) | 어둠 속 희미한 관람차, 곤돌라 불이 하나씩 켜짐 → 깜빡이다 정전 | 한 박자 정적 후 일제히 점등 + 바퀴 뒤 폭죽 + 충격파. 이후 조명이 마키처럼 돎 |
| `SPIN_UP` (B. 가속) | 관람차가 점점 빨라져 잔상이 생기고 카메라가 조여 듦 (래칫 소리 → 버즈) | '철컥' 급제동 + 충격파 + 불꽃. 곤돌라가 관성으로 크게 흔들리다 멈춤 |
| `TWILIGHT` (C. 노을) | 돌아가는 곤돌라 클로즈업 (가까운 기계음) | 카메라가 확 빠지며 노을 앞 실루엣 공개 + 태양 광선 |

화면을 터치·클릭하거나 아무 키를 누르면 스킵됩니다 (0.5초 이후부터).

## 설치

`addons/wonderwheel_splash/` 폴더를 게임 프로젝트의 `res://addons/`에 통째로 복사하세요 (`.import` 파일 포함). 플러그인 활성화는 필요 없습니다.

## 사용법

### A. 시작 씬으로 쓰기 (권장)
1. 새 씬을 만들고 `wonderwheel_splash.tscn`을 인스턴스로 추가합니다.
2. 인스펙터에서 `Style`을 고르고, `Next Scene`에 게임의 첫 씬을 지정합니다.
3. 프로젝트 설정 → Application → Run → Main Scene을 이 씬으로 바꿉니다.

### B. 기존 씬 위에 오버레이로 쓰기
`Next Scene`을 비워 두면 연출이 끝난 뒤 서서히 사라지면서 스스로 `queue_free` 됩니다. 끝나는 시점이 필요하면 `finished` 시그널을 연결하세요.

```gdscript
var splash := preload("res://addons/wonderwheel_splash/wonderwheel_splash.tscn").instantiate()
splash.style = WonderWheelSplash.Style.TWILIGHT
splash.finished.connect(_on_splash_done)
add_child(splash)
```

## 옵션

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `style` | NIGHT_LIGHTS | 시안 선택 |
| `logo_fit` | 0.6 | 화면 짧은 변 대비 로고 크기. 가로·세로 화면 모두 자동으로 맞춤 |
| `play_sound` / `sound_volume_db` | true / -2 | 효과음 재생 여부와 음량 |
| `skippable` / `min_time_before_skip` | true / 0.5 | 스킵 허용 여부와 스킵 가능해지는 시점(초) |
| `next_scene` | "" | 끝나면 전환할 씬 |
| `free_when_finished` | true | `next_scene`이 비어 있을 때 끝나면 스스로 제거 |

## 엔진 부트 화면과 이어지게 하기 (권장)

엔진 부트 화면에서 넘어갈 때 끊겨 보이지 않게 하려면 `project.godot`에 아래를 추가하세요.

```ini
[application]
boot_splash/bg_color=Color(0, 0, 0, 1)
boot_splash/show_image=false
```

## 구성 파일

- `wonderwheel_splash.gd`: 본체 (`class_name WonderWheelSplash`). 노드를 모두 코드로 생성합니다.
- `wonderwheel_splash.tscn`: 인스턴스용 씬.
- `ww_layout.gd`: 레이어 배치 좌표. 자동 생성 파일입니다.
- `ww_shine.gdshader`: CanvasGroup용 셰이더 (임팩트 과노출 틴트).
- `textures/`: `logo-black.png`에서 분리한 흰색 레이어(바퀴, 곤돌라, 지지대, 글자 11개). 실행 중에 색을 입힙니다.
- `sfx/`: 시안별 효과음 (`a_night_lights.wav`, `b_spin_up.wav`, `c_twilight.wav`).

로고가 바뀌면 상위 폴더의 `tools/build_layers.py`로 레이어를 다시 만드세요. 효과음은 `tools/build_sfx.py`로 다시 합성합니다.
스크립트의 타임라인 상수(`A_T_IMPACT` 등)를 바꾸면 `build_sfx.py`의 같은 값도 함께 바꿔야 소리와 화면이 맞습니다.
