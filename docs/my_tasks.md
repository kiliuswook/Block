# 내가(사용자가) 해야 할 작업

> 코드로 끝낼 수 없고 **사람이 외부 사이트에서 해야 하는 일**만 모은 목록.
> 각 항목의 자세한 절차는 링크된 체크리스트에 있다. 끝낸 항목은 `[x]`로 바꾸고,
> "📤 줄 것"에 적힌 값을 나한테 주면 내가 코드에 넣고 검증한다.
>
> 마지막 갱신: 2026-08-31

---

## 🟡 모바일 백엔드 — Supabase 세팅 · **대기 중 (사용자가 나중에 하기로)**

**왜 필요한가**: 모바일에는 스팀이 없어서 랭킹·클라우드 세이브를 대신할 곳이 필요하고,
특히 **주간 랭크 정산**은 서버가 해야 한다(클라이언트가 자기 순위를 읽고 상금을 챙기면 공짜 골드).

**코드는 끝났다** — `core/autoload/cloud.gd` + `Ranks`의 `Backend.SERVER` + 서버 스키마까지 붙어 있고,
지금은 설정이 비어 있어 **서버 기능이 꺼진 채** 예전대로(스팀=Steamworks, 그 외=jsonblob/오프라인) 돈다.
아래 4단계를 하고 값 두 개를 주면 그대로 켜진다.

- [ ] ① Supabase 프로젝트 생성 (무료, Northeast Asia/Seoul 권장)
- [ ] ② Authentication → **Anonymous sign-ins 켜기** (캡차는 켜지 말 것)
- [ ] ③ SQL Editor에 `server/supabase/schema.sql` 붙여넣고 Run
- [ ] ④ Project Settings → API 에서 **Project URL** + **anon public key** 확인

**📤 나한테 줄 것**: `Project URL`, `anon public key` 두 개
**⚠ 주지 말 것**: `service_role` 키 (RLS를 무시하는 키라 클라이언트에 들어가면 안 된다)
**⏱ 소요**: 30분쯤. 프로비저닝 2~3분 + 스키마 실행 1분

📄 상세: [`docs/cloud_setup.md`](cloud_setup.md)

> 그 뒤에 이어질 것(내가 코드를 붙일 때 알려 준다): **구글/애플 로그인** — 익명 계정은
> 앱을 지우면 사라져서 기기 이전이 안 된다. 출시 전에는 필요하다.

---

## 🟡 스팀 출시 준비 — 파트너 사이트 · **대기 중**

**코드는 끝났고 실기 검증까지 마쳤다.** 지금은 테스트 앱 id 480(Valve "Spacewar")으로 돌고 있다.

- [ ] ① 파트너 등록 — **$100 결제 + 세금/은행 서류 + 30일 대기**. ⚠ **여기가 크리티컬 패스라 제일 먼저 시작할 것**
  - **📤 줄 것**: `App ID`
- [ ] ② Auto-Cloud 경로 등록 (클라우드 세이브)
- [ ] ③ 업적 API Name 등록 — 코드 배선은 끝났고 목록의 id 그대로 등록만 하면 된다
- [ ] ④ 빌드 업로드(SteamPipe) 설정
  - **📤 줄 것**: `depot id`
- [ ] ⑤ 스토어 페이지 (코드와 무관, 별개 트랙)

📄 상세: [`docs/steam_setup.md`](steam_setup.md)

---

## 참고 — 이건 내가 한다 (사용자 작업 아님)

- 위 값들을 받아 `project.godot`(`cattris/steam/app_id`, `cattris/cloud/url`, `cattris/cloud/anon_key`)에 넣고 검증
- 구글/애플 로그인 연동, IAP 붙일 때의 서버 확장(B안 — 서버가 지갑의 주인)
- PC·모바일 두 빌드 익스포트와 배포
