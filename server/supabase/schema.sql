-- Cat-Tris 모바일 백엔드 스키마 (Supabase / Postgres)
-- 클라이언트는 core/autoload/cloud.gd (autoload `Cloud`), 대시보드 절차는
-- docs/cloud_setup.md. Supabase SQL Editor 에 이 파일을 통째로 붙여 실행한다
-- (여러 번 실행해도 안전하게 짰다).
--
-- 신뢰 모델 = A안: 지갑(골드·키캡·레벨)은 클라이언트가 주인이고, 서버는
--   ① 랭킹 보드 ② 주간 정산 ③ 세이브 백업만 맡는다. 그래서 여기서 서버가
--   실제로 강제하는 것은 "내 행만 쓸 수 있다" + "주간 상금은 서버가 계산한
--   것만 받을 수 있다" 둘뿐이다. 결제를 붙여 B안(서버가 지갑의 주인)으로
--   올릴 때 늘어날 자리도 여기다.

create extension if not exists pg_cron;

-- ---------------------------------------------------------------------------
-- 주차 계산 — 클라이언트(core/autoload/ranks.gd)의 WEEK_ANCHOR/WEEK_LEN 과
-- 반드시 같은 값이어야 한다. 313200 = 월요일 1970-01-05 00:00 KST.
-- 주차는 **서버 시계**로 정해진다 (기기 시간을 돌려 주차를 넘길 수 없다).
-- ---------------------------------------------------------------------------
create or replace function public.week_id(ts timestamptz default now())
returns int language sql stable as $$
  select ((extract(epoch from ts)::bigint - 313200) / 604800)::int;
$$;


-- ---------------------------------------------------------------------------
-- 리더보드 — 보드 하나 = (mode, week_id) 한 쌍. week_id = -1 이 누적 보드고
-- 주간 보드는 그 주차 번호를 쓴다. 지난 주 보드는 밀어 옮기지 않고 그대로
-- 남으므로 롤오버 코드가 아예 없다.
-- ---------------------------------------------------------------------------
create table if not exists public.scores (
	user_id    uuid not null references auth.users(id) on delete cascade,
	mode       text not null check (mode in ('endless', 'classic')),
	week_id    int  not null,
	value      int  not null check (value >= 0),
	name       text not null default '',
	cat        text not null default '',
	replay     text,
	updated_at timestamptz not null default now(),
	primary key (user_id, mode, week_id)
);

create index if not exists scores_board_idx
	on public.scores (mode, week_id, value desc, updated_at);

-- 제출 검증. A안이라 정밀한 치팅 판정은 하지 않고, 남의 행으로 위장하는 것과
-- 눈에 띄게 말이 안 되는 값·오래된 주차만 막는다. keep-best 도 여기서 지킨다.
create or replace function public.scores_guard() returns trigger
language plpgsql as $$
declare cur int := public.week_id();
begin
	new.user_id := auth.uid();
	new.updated_at := now();
	new.name := left(coalesce(new.name, ''), 24);
	new.cat := left(coalesce(new.cat, ''), 32);

	-- 누적(-1) 이거나 지금 주차만 받는다 (시계 오차 여유로 직전 주까지 허용).
	if new.week_id <> -1 and new.week_id not between cur - 1 and cur then
		raise exception 'bad week_id %', new.week_id;
	end if;

	if new.mode = 'endless' and new.value > 5000 then
		raise exception 'value out of range';
	elsif new.mode = 'classic' and new.value > 100000000 then
		raise exception 'value out of range';
	end if;

	-- 리플레이는 누적 보드 행에만, 그것도 작을 때만 붙인다.
	if new.replay is not null and (new.week_id <> -1 or length(new.replay) > 90000) then
		new.replay := null;
	end if;

	-- 이전 기록보다 낮은 제출은 조용히 무시한다 (스팀 리더보드의 keep_best 와 같다).
	if tg_op = 'UPDATE' and new.value <= old.value then
		return old;
	end if;
	return new;
end $$;

drop trigger if exists scores_guard on public.scores;
create trigger scores_guard before insert or update on public.scores
	for each row execute function public.scores_guard();

alter table public.scores enable row level security;

drop policy if exists scores_read on public.scores;
create policy scores_read on public.scores
	for select to authenticated using (true);

drop policy if exists scores_insert on public.scores;
create policy scores_insert on public.scores
	for insert to authenticated with check (user_id = auth.uid());

drop policy if exists scores_update on public.scores;
create policy scores_update on public.scores
	for update to authenticated
	using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists scores_delete on public.scores;
create policy scores_delete on public.scores
	for delete to authenticated using (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 클라우드 세이브 — save.json 통째로 한 행. 충돌은 rev(단조 증가) 하나로
-- 정리한다. 값 검증은 하지 않는다(A안: 지갑의 주인은 클라이언트).
-- ---------------------------------------------------------------------------
create table if not exists public.saves (
	user_id    uuid primary key references auth.users(id) on delete cascade,
	data       jsonb not null,
	rev        int not null default 0,
	updated_at timestamptz not null default now()
);

create or replace function public.saves_guard() returns trigger
language plpgsql as $$
begin
	new.user_id := auth.uid();
	new.updated_at := now();
	if pg_column_size(new.data) > 262144 then
		raise exception 'save too large';
	end if;
	-- 오래된 판이 최신본을 덮어쓰지 못하게 (기기 두 대를 오갈 때).
	if tg_op = 'UPDATE' and new.rev <= old.rev then
		return old;
	end if;
	return new;
end $$;

drop trigger if exists saves_guard on public.saves;
create trigger saves_guard before insert or update on public.saves
	for each row execute function public.saves_guard();

alter table public.saves enable row level security;

drop policy if exists saves_own on public.saves;
create policy saves_own on public.saves
	for all to authenticated
	using (user_id = auth.uid()) with check (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 주간 시상 — 정산은 아래 cron 이 하고, 클라이언트는 claim_rewards() 로 받기만
-- 한다. rewards 에 쓰기 정책이 없으므로 상금 행은 정산 함수만 만들 수 있다.
-- 금액은 클라이언트의 Ranks.WEEKLY_REWARDS = [500, 300, 200] 과 같아야 하고,
-- 통조림 캔은 Ranks.WEEKLY_CANS (1위 10캔 ~ 100위 1캔) 과 같아야 한다.
-- ---------------------------------------------------------------------------
create table if not exists public.rewards (
	user_id    uuid not null references auth.users(id) on delete cascade,
	week_id    int not null,
	mode       text not null,
	rank       int not null,
	gold       int not null,
	cans       int not null default 0,
	claimed_at timestamptz,
	primary key (user_id, week_id, mode)
);

-- 캔 이전에 만들어 둔 테이블에도 열을 붙인다 (이미 있으면 무시).
alter table public.rewards add column if not exists cans int not null default 0;

alter table public.rewards enable row level security;

drop policy if exists rewards_read on public.rewards;
create policy rewards_read on public.rewards
	for select to authenticated using (user_id = auth.uid());

-- 이 순위의 주간 캔 보상 (1위 10캔 ~ 100위 1캔, 그 밖은 0).
-- 클라이언트의 Ranks.WEEKLY_CANS 와 같은 값이어야 한다.
create or replace function public.week_cans(rnk int)
returns int language sql immutable as $$
	select case
		when rnk <= 1 then 10 when rnk <= 3 then 8 when rnk <= 5 then 7
		when rnk <= 10 then 6 when rnk <= 20 then 5 when rnk <= 30 then 4
		when rnk <= 50 then 3 when rnk <= 75 then 2 when rnk <= 100 then 1
		else 0 end;
$$;

-- 끝난 주의 보드에서 모드별 상위 100을 뽑아 상금 행을 만든다 (골드는 3위까지,
-- 캔은 100위까지). 같은 주를 두 번 정산해도 on conflict 로 한 번만 들어간다.
create or replace function public.settle_week(w int)
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
	insert into public.rewards (user_id, week_id, mode, rank, gold, cans)
	select user_id, w, mode, rnk,
		coalesce((array[500, 300, 200])[rnk], 0), public.week_cans(rnk::int)
	from (
		select user_id, mode,
			row_number() over (
				partition by mode order by value desc, updated_at asc) as rnk
		from public.scores where week_id = w
	) t
	where rnk <= 100
	on conflict (user_id, week_id, mode) do nothing;
	get diagnostics n = row_count;
	return n;
end $$;

-- 미청구 상금을 모두 받아 합계를 돌려준다. 순위 판정은 이미 끝나 있으므로
-- 클라이언트가 할 수 있는 일은 "받기"뿐이다.
create or replace function public.claim_rewards()
returns json language plpgsql security definer set search_path = public as $$
declare out json;
begin
	with c as (
		update public.rewards set claimed_at = now()
		where user_id = auth.uid() and claimed_at is null
		returning gold, cans
	)
	select json_build_object(
			'gold', coalesce(sum(gold), 0), 'cans', coalesce(sum(cans), 0))
		into out from c;
	return out;
end $$;

revoke execute on function public.settle_week(int) from public, anon, authenticated;
revoke execute on function public.week_cans(int) from public, anon;
grant execute on function public.claim_rewards() to authenticated;


-- ---------------------------------------------------------------------------
-- 주간 cron — 주 flip 은 월요일 00:00 KST = 일요일 15:00 UTC.
-- 정산은 그 직후(15:05 UTC)에 돌아 방금 끝난 주를 집계한다.
-- ---------------------------------------------------------------------------
select cron.unschedule('cattris-weekly-settle')
	where exists (select 1 from cron.job where jobname = 'cattris-weekly-settle');
select cron.schedule('cattris-weekly-settle', '5 15 * * 0',
	$$ select public.settle_week(public.week_id() - 1) $$);

-- 오래된 주간 행은 치운다 (누적 보드 week_id = -1 은 건드리지 않는다).
select cron.unschedule('cattris-weekly-prune')
	where exists (select 1 from cron.job where jobname = 'cattris-weekly-prune');
select cron.schedule('cattris-weekly-prune', '20 15 * * 0',
	$$ delete from public.scores
	   where week_id >= 0 and week_id < public.week_id() - 8 $$);
