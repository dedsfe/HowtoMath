-- HowToMath — tentativas que cabem álgebra
--
-- A 0001 modelou a tentativa como aritmética: dois operandos inteiros, um
-- operador, uma resposta. Isso não escreve `2(x+5)=10`, e `(x+2)(x+5)=25` tem
-- duas raízes — não cabe num `answer` só.
--
-- Refeita agora porque a tabela só tem linha de teste. Daqui a três meses isso
-- é migração de dados; hoje é um DROP.

-- Dados de teste da 0001. As tentativas caem junto pelo cascade.
delete from public.lesson_records;

drop table if exists public.lesson_attempts;

create table public.lesson_attempts (
    id            bigint generated always as identity primary key,
    lesson_id     uuid not null references public.lesson_records (id) on delete cascade,
    user_id       uuid not null references auth.users (id) on delete cascade,
    position      integer not null check (position >= 0),

    -- ── O que foi perguntado ──────────────────────────────────

    -- O conceito, e o campo mais importante da tabela.
    --
    -- Em aritmética o que trava a pessoa é um número; em álgebra é uma *regra*
    -- — distributiva, isolar o termo, produto notável. Nenhuma análise de
    -- `numbers` chega nisso, e é exatamente isso que vira conselho ao usuário e
    -- que a curva de esquecimento precisa indexar.
    --
    -- Texto livre em vez de enum: a lista vai crescer a cada assunto novo, e uma
    -- migração de banco por tópico novo é uma migração que ninguém vai querer
    -- fazer no dia em que estiver com pressa.
    skill         text not null,

    -- Como foi apresentada: equation | story | gap | build | match.
    style         text not null,

    -- A questão como a pessoa viu, em texto: `7 + 8`, `2(x+5) = 10`.
    -- É o que permite reler um erro anos depois sem ter que reconstruir a
    -- questão a partir das peças.
    prompt        text not null,

    -- Os números que apareceram, na ordem. `{7,8}` para `7 + 8`, `{2,5,10}`
    -- para `2(x+5)=10`.
    --
    -- `numeric` e não `integer`: coeficiente fracionário chega junto com
    -- equação. Guardado apesar de estar dentro do `prompt` porque a alternativa
    -- é escrever um parser para responder "erra mais com número negativo".
    numbers       numeric[] not null default '{}',

    -- `+`, `−`, `×`. Nulo quando a questão não é uma operação só.
    operation     text,

    -- ── A resposta ────────────────────────────────────────────

    -- Lista, sempre. `{15}` para uma soma, `{1,-6}` para uma quadrática.
    -- Texto e não número porque raiz é fração, é negativo, e um dia é `x = 2/3`.
    solutions     text[] not null,
    -- O que a pessoa deu, no mesmo formato.
    chosen        text[] not null default '{}',
    correct       boolean not null,

    -- ── Como respondeu ────────────────────────────────────────

    -- Até o primeiro toque. Separa "não sabia" de "sabia e estava distraída" —
    -- sem isso `seconds` é a média de duas coisas diferentes.
    hesitation_seconds double precision check (hesitation_seconds >= 0),
    -- Até a resposta entrar.
    seconds       double precision not null check (seconds >= 0),

    -- O app foi para segundo plano no meio da questão.
    --
    -- Não gera insight nenhum: impede que os outros mintam. Sem essa flag, um
    -- celular largado sete minutos em cima da mesa envenena toda média de tempo
    -- que a gente calcular daqui pra frente.
    was_backgrounded boolean not null default false,

    -- As alternativas que estavam na tela. Sem elas `chosen` não diz se o
    -- distrator sequer existia.
    options       text[] not null default '{}',

    -- A sequência de acertos no momento da resposta: erra mais embalada?
    streak_at_answer integer not null default 0 check (streak_at_answer >= 0),

    is_retry      boolean not null default false,
    -- Pares errados antes de limpar um tabuleiro de associação.
    bad_pairs     integer not null default 0 check (bad_pairs >= 0),

    unique (lesson_id, position)
);

create index on public.lesson_attempts (lesson_id);
-- O acesso de análise é sempre "minhas tentativas, por conceito".
create index on public.lesson_attempts (user_id, skill);
-- Para a curva de esquecimento: a última vez que esta pessoa viu este assunto.
create index on public.lesson_attempts (user_id, skill, correct);

alter table public.lesson_attempts enable row level security;

create policy "own attempts readable"
    on public.lesson_attempts for select
    using (auth.uid() = user_id);

create policy "own attempts insertable"
    on public.lesson_attempts for insert
    with check (auth.uid() = user_id);

-- ── Ambiente, na lição ────────────────────────────────────────
--
-- Aqui e não na tentativa: não muda no meio de uma lição, e serve para separar
-- "o app está lento neste aparelho" de "a pessoa está pensando".

alter table public.lesson_records
    add column if not exists device_model text,
    add column if not exists os_version   text;
