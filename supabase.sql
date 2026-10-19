-- GDA 11.º · sincronização. Corre isto uma vez no Supabase: SQL Editor > New query > Run.
create table if not exists public.gda_sessions(
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  exercise smallint not null check (exercise between 31 and 74),
  solved_on date not null,
  started_at timestamptz not null,
  finished_at timestamptz not null,
  duration_seconds integer not null check (duration_seconds >= 0),
  time_precision text not null default 'exato' check (time_precision in ('exato','margem')),
  margin_seconds integer not null default 0 check (margin_seconds >= 0),
  manual boolean not null default false,
  xp integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists gda_sessions_user_day on public.gda_sessions(user_id, solved_on);
alter table public.gda_sessions enable row level security;
create policy "ler as minhas sessoes"       on public.gda_sessions for select to authenticated using (auth.uid() = user_id);
create policy "inserir as minhas sessoes"   on public.gda_sessions for insert to authenticated with check (auth.uid() = user_id);
create policy "atualizar as minhas sessoes" on public.gda_sessions for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "apagar as minhas sessoes"    on public.gda_sessions for delete to authenticated using (auth.uid() = user_id);

-- Resumo por dia, para a tua outra aplicação ler. security_invoker faz a vista respeitar o RLS.
create or replace view public.gda_daily with (security_invoker = true) as
select user_id, solved_on,
  count(*)::int                                   as exercises,
  array_agg(exercise order by exercise)           as exercise_list,
  sum(duration_seconds)::int                      as total_seconds,
  round(sum(duration_seconds) / 60.0)::int        as approx_minutes,
  round(sum(margin_seconds) / 60.0)::int          as margin_minutes,
  count(*) filter (where time_precision = 'exato')::int  as exact_sessions,
  count(*) filter (where time_precision = 'margem')::int as estimated_sessions,
  case when bool_and(time_precision = 'exato') then 'exato' else 'margem' end as time_precision,
  sum(xp)::int                                    as xp
from public.gda_sessions group by user_id, solved_on;
grant select on public.gda_daily to authenticated;
