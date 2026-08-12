-- HowToMath — histórico de lições
--
-- Espelha LessonRecord/AttemptRecord do app. Uma linha por lição, uma linha por
-- tentativa. A granularidade é a tentativa de propósito: dá pra colapsar
-- tentativa em questão depois, nunca o contrário.
--
-- Rodar no SQL Editor do projeto (fhqafklfkysuluiwscry).

-- ─────────────────────────────────────────────────────────────
-- Lições
-- ─────────────────────────────────────────────────────────────

create table if not exists public.lesson_records (
    id                uuid primary key,
    user_id           uuid not null references auth.users (id) on delete cascade,

    stage_id          integer not null,
    stage_title       text    not null,

    started_at        timestamptz not null,
    finished_at       timestamptz not null,

    -- Quantas questões a lição pediu, repescagem incluída.
    asked_total       integer not null check (asked_total > 0),
    -- Quantas pediria sem nenhum erro. Guardado por lição pra que mudar o
    -- tamanho da lição não reescreva a precisão do que já foi gravado.
    base_total        integer not null check (base_total > 0),
    first_try_correct integer not null check (first_try_correct >= 0),
    misses            integer not null check (misses >= 0),
    best_streak       integer not null check (best_streak >= 0),

    -- Gravado, não calculado na leitura: quando a fórmula mudar, lição antiga
    -- mantém o XP que já valeu.
    xp                integer not null check (xp >= 0),

    app_version       text not null default '?',
    created_at        timestamptz not null default now()
);

-- O acesso é sempre "minhas lições, mais recentes primeiro".
create index if not exists lesson_records_user_finished_idx
    on public.lesson_records (user_id, finished_at desc);

-- ─────────────────────────────────────────────────────────────
-- Tentativas
-- ─────────────────────────────────────────────────────────────

create table if not exists public.lesson_attempts (
    id            bigint generated always as identity primary key,
    lesson_id     uuid not null references public.lesson_records (id) on delete cascade,
    -- Repetido aqui de propósito: sem ele toda policy de RLS vira um join, e
    -- RLS que precisa de join é RLS que fica lenta e fácil de escrever errado.
    user_id       uuid not null references auth.users (id) on delete cascade,

    -- Ordem em que foi respondida dentro da lição, começando em zero.
    position      integer not null check (position >= 0),

    style         text not null,   -- equation | story | gap | build | match
    operation     text not null,   -- + | −
    left_operand  integer not null,
    right_operand integer not null,
    answer        integer not null,
    chosen        integer not null,
    correct       boolean not null,

    seconds       double precision not null check (seconds >= 0),
    is_retry      boolean not null default false,
    -- Pares errados virados antes de limpar um tabuleiro de associação.
    bad_pairs     integer not null default 0 check (bad_pairs >= 0),

    unique (lesson_id, position)
);

create index if not exists lesson_attempts_lesson_idx
    on public.lesson_attempts (lesson_id);

-- Pra perguntar depois "qual operação é mais lenta" sem varrer tudo.
create index if not exists lesson_attempts_user_style_idx
    on public.lesson_attempts (user_id, style);

-- ─────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────
--
-- Ligado antes de existir qualquer linha. A chave publishable vive dentro do
-- app e é pública por definição, então sem isso qualquer pessoa lê e escreve o
-- histórico de qualquer outra.
--
-- Sem policy de update ou delete: histórico é append-only. O app nunca corrige
-- uma lição passada, e o que ninguém precisa fazer ninguém deve poder fazer.

alter table public.lesson_records  enable row level security;
alter table public.lesson_attempts enable row level security;

drop policy if exists "own lessons readable" on public.lesson_records;
create policy "own lessons readable"
    on public.lesson_records for select
    using (auth.uid() = user_id);

drop policy if exists "own lessons insertable" on public.lesson_records;
create policy "own lessons insertable"
    on public.lesson_records for insert
    with check (auth.uid() = user_id);

drop policy if exists "own attempts readable" on public.lesson_attempts;
create policy "own attempts readable"
    on public.lesson_attempts for select
    using (auth.uid() = user_id);

drop policy if exists "own attempts insertable" on public.lesson_attempts;
create policy "own attempts insertable"
    on public.lesson_attempts for insert
    with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- Agregados
-- ─────────────────────────────────────────────────────────────
--
-- security_invoker: a view roda com as permissões de quem consulta, então a RLS
-- das tabelas continua valendo através dela. Sem isso a view seria uma porta dos
-- fundos pro histórico de todo mundo.

create or replace view public.lesson_totals
with (security_invoker = on) as
select
    user_id,
    count(*)                                   as lessons_finished,
    count(*) filter (where misses = 0)         as perfect_lessons,
    coalesce(sum(xp), 0)                       as total_xp,
    coalesce(max(best_streak), 0)              as best_streak_ever,
    coalesce(sum(first_try_correct), 0)        as first_try_correct,
    coalesce(sum(base_total), 0)               as questions_asked,
    coalesce(sum(extract(epoch from (finished_at - started_at))), 0) as total_seconds,
    max(finished_at)                           as last_finished_at
from public.lesson_records
group by user_id;
