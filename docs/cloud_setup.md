# 모바일 백엔드(Supabase) 세팅 — 사용자 작업 체크리스트

> 작성일: 2026-08-31. **코드 쪽은 끝났다** — `Cloud` autoload(익명 로그인 · 클라우드 세이브 ·
> 리더보드 · 주간 시상 청구)와 `Ranks`의 `Backend.SERVER` 경로가 붙어 있고, 서버 스키마는
> `server/supabase/schema.sql`에 그대로 있다.
> 남은 건 **Supabase 대시보드에서 사람이 해야 하는 일**과, 그 결과로 나오는 값 두 개를 나한테 주는 것뿐이다.
>
> 지금은 `project.godot`의 `cattris/cloud/url`·`cattris/cloud/anon_key`가 **비어 있어서 서버 기능이 통째로 꺼져 있다** —
> 게임은 예전대로(스팀 빌드는 Steamworks, 그 외는 jsonblob/오프라인) 돈다. 값을 채우는 순간 서버 백엔드로 갈아탄다.

## 무엇을 서버에 맡기는가 (A안)

**지갑의 주인은 계속 클라이언트다.** 골드·키캡·계정 레벨은 로컬 `save.json`이 진짜고, 서버는 셋만 맡는다:

| 서버가 맡는 것 | 왜 |
| --- | --- |
| 랭킹 보드 | 내 행만 쓸 수 있게 막아야 순위표가 의미가 있다 |
| **주간 정산** | 클라이언트가 자기 순위를 읽고 상금을 챙기면 공짜 골드다. 서버 cron이 정산하고 클라는 받기만 한다 |
| 세이브 백업 | 기기 이전·재설치 복구 |

골드 IAP를 붙이게 되면 그때 B안(서버가 지갑의 주인)으로 올린다 — 그건 이 문서가 아니라 서버 함수를 늘리는 작업이다.

---

## 진행 순서 한눈에

```
① Supabase 프로젝트 생성 (무료)
② Anonymous sign-in 켜기
③ schema.sql 실행 (테이블 · RLS · 정산 함수 · cron)
④ URL + anon key 확인  ────▶ [나한테 두 값 전달]  ──▶ 내가 project.godot 에 넣고 검증
⑤ (나중) 구글/애플 로그인 — 기기 이전용
```

---

## ① 프로젝트 생성

1. https://supabase.com 가입 → **New project**
2. Region은 **Northeast Asia (Seoul)** 권장 (한국 유저 기준 지연이 제일 낮다)
3. Database password는 아무거나 — 게임 클라이언트는 쓰지 않는다. 잃어버리지만 말 것
4. 무료 티어로 충분하다 (500MB DB / 월 5만 MAU). 프로젝트가 **7일간 요청이 없으면 일시정지**되니, 테스트를 쉬다 돌아왔을 때 대시보드에서 Resume가 필요할 수 있다

**⏱ 소요**: 프로비저닝 2~3분.

## ② 익명 로그인 켜기

**Authentication → Sign In / Providers → Anonymous sign-ins → Enable.**

계정 만들기·로그인 화면 없이 첫 실행에서 바로 계정이 생긴다(토큰은 기기의 `user://cloud.json`에 남는다).
**앱을 지우면 그 계정도 사라진다** — 그래서 ⑤(구글/애플 로그인)가 나중에 필요하다.

같은 화면에서 **Enable Captcha protection은 켜지 말 것** — 게임 클라이언트가 캡차를 띄울 수 없다.

## ③ 스키마 실행

**SQL Editor → New query** 에 `server/supabase/schema.sql` 내용을 통째로 붙여 넣고 **Run**.

여러 번 실행해도 안전하게 짜 뒀다(전부 `if not exists` / `or replace`). 이게 만드는 것:

- `scores` — 보드. 행 하나 = (나, 모드, 주차). **주차 `-1`이 누적 보드**고 주간은 그 주차 번호다. 지난 주 보드는 밀어 옮기지 않고 그대로 남는다
- `saves` — 세이브 백업 한 행 (`rev`가 큰 쪽이 최신)
- `rewards` — 주간 상금. **쓰기 정책이 없어서 정산 함수만 행을 만들 수 있다**
- `settle_week(w)` / `claim_rewards()` — 정산 · 청구
- cron 두 개 — 일요일 15:05 UTC(= 월요일 00:05 KST) 정산, 15:20 UTC 오래된 주간 행 정리

> `create extension pg_cron`에서 권한 오류가 나면 **Database → Extensions**에서 `pg_cron`을 먼저 켜고 다시 실행한다.

**확인**: Run 뒤 **Database → Cron Jobs**(또는 `select * from cron.job;`)에 `cattris-weekly-settle`이 보이면 된다.

## ④ 나한테 줄 값 두 개

**Project Settings → API**에서:

| 값 | 예 | 어디에 들어가나 |
| --- | --- | --- |
| **Project URL** | `https://abcdefgh.supabase.co` | `cattris/cloud/url` |
| **anon public key** | `eyJhbGciOi...` (긴 JWT) | `cattris/cloud/anon_key` |

> ⚠ **`service_role` 키는 절대 주지 말 것.** 그건 RLS를 통째로 무시하는 키라 클라이언트에 들어가면 안 된다.
> anon key는 공개돼도 되는 키다(빌드에 박혀 나간다) — 실제 방어는 RLS가 한다.

**📤 나한테 줄 것**: 위 두 값. 받으면 내가 `project.godot`에 넣고, 타이틀 → DEV 패널 → 리더보드 탭에서 백엔드가 `SERVER (Supabase)`로 뜨는지, 제출·조회·주간 정산이 도는지 확인한다.

## ⑤ (나중) 구글/애플 로그인 — 기기 이전

익명 계정은 앱을 지우면 끝이라, 폰을 바꾸면 기록이 못 따라간다. 출시 전에는 붙여야 한다.

- Android: Google Sign-In → Supabase **Authentication → Providers → Google**
- iOS: Apple Sign-In → 같은 화면의 **Apple** (App Store 심사 요건이기도 하다)

코드 쪽은 익명 계정을 그대로 **승격**(link identity)하는 방식이라 `uid`가 유지되고 보드·세이브가 그대로 따라온다. 붙일 때 알려 주면 된다.

---

## 확인·운영 메모

- **주차 기준은 서버 시계다.** `week_id()` SQL 함수의 `313200`(월요일 1970-01-05 00:00 KST)과 `604800`은 클라이언트 `core/autoload/ranks.gd`의 `WEEK_ANCHOR`/`WEEK_LEN`과 **같은 값이어야 한다** — 한쪽만 바꾸면 주간 보드가 어긋난다
- **상금 금액**은 `settle_week()`의 `array[500, 300, 200]`과 클라이언트 `Ranks.WEEKLY_REWARDS`가 같아야 한다
- 정산을 손으로 돌려 보려면 SQL Editor에서 `select public.settle_week(public.week_id() - 1);` (같은 주를 두 번 돌려도 상금은 한 번만 들어간다)
- 모드를 추가하면 `scores.mode`의 `check` 제약과 `Ranks.MODES`를 같이 늘린다
