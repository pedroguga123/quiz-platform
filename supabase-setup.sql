-- ============================================================
-- InLead — Schema completo do banco de dados
-- Execute este arquivo no Supabase SQL Editor
-- ============================================================

-- EXTENSÕES
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
-- TABELA: quizzes
-- Cada quiz pertence a um usuário autenticado
-- ============================================================
create table if not exists public.quizzes (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null,
  description text,
  slug        text not null unique,
  status      text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  settings    jsonb not null default '{
    "primaryColor": "#6366f1",
    "accentColor": "#f59e0b",
    "bgColor": "#ffffff",
    "fontFamily": "Inter",
    "logoUrl": null,
    "coverImageUrl": null,
    "redirectUrl": null,
    "collectEmail": true,
    "collectPhone": false,
    "collectName": true
  }',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ============================================================
-- TABELA: questions
-- Perguntas de um quiz, com ordem e tipo
-- ============================================================
create table if not exists public.questions (
  id           uuid primary key default uuid_generate_v4(),
  quiz_id      uuid not null references public.quizzes(id) on delete cascade,
  position     int  not null default 0,
  type         text not null check (type in (
    'multiple_choice',   -- múltipla escolha (uma resposta)
    'checkbox',          -- múltipla escolha (várias respostas)
    'text',              -- texto livre
    'email',             -- campo de email
    'phone',             -- campo de telefone
    'name',              -- campo de nome
    'rating',            -- estrelas 1-5
    'nps',               -- escala 0-10
    'statement'          -- slide sem resposta (apresentação)
  )),
  title        text not null,
  description  text,
  required     boolean not null default true,
  settings     jsonb not null default '{}',
  created_at   timestamptz not null default now()
);

-- ============================================================
-- TABELA: options
-- Opções de uma pergunta de múltipla escolha
-- ============================================================
create table if not exists public.options (
  id          uuid primary key default uuid_generate_v4(),
  question_id uuid not null references public.questions(id) on delete cascade,
  position    int  not null default 0,
  label       text not null,
  value       text not null,
  emoji       text,
  created_at  timestamptz not null default now()
);

-- ============================================================
-- TABELA: responses
-- Uma "resposta" = uma pessoa que completou o quiz
-- Captura dados de contato + metadata
-- ============================================================
create table if not exists public.responses (
  id           uuid primary key default uuid_generate_v4(),
  quiz_id      uuid not null references public.quizzes(id) on delete cascade,
  respondent   jsonb not null default '{}',
  -- { "name": "...", "email": "...", "phone": "..." }
  utm_source   text,
  utm_medium   text,
  utm_campaign text,
  utm_term     text,
  utm_content  text,
  ip_hash      text,   -- hash do IP (privacidade LGPD)
  user_agent   text,
  completed_at timestamptz,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- TABELA: answers
-- Cada resposta individual de uma pergunta
-- ============================================================
create table if not exists public.answers (
  id          uuid primary key default uuid_generate_v4(),
  response_id uuid not null references public.responses(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  value       jsonb not null,
  -- string, number, string[], etc. dependendo do tipo
  created_at  timestamptz not null default now()
);

-- ============================================================
-- ÍNDICES — performance em consultas frequentes
-- ============================================================
create index if not exists idx_quizzes_user_id    on public.quizzes(user_id);
create index if not exists idx_quizzes_slug        on public.quizzes(slug);
create index if not exists idx_quizzes_status      on public.quizzes(status);
create index if not exists idx_questions_quiz_id   on public.questions(quiz_id, position);
create index if not exists idx_options_question_id on public.options(question_id, position);
create index if not exists idx_responses_quiz_id   on public.responses(quiz_id);
create index if not exists idx_responses_created   on public.responses(created_at desc);
create index if not exists idx_answers_response_id on public.answers(response_id);
create index if not exists idx_answers_question_id on public.answers(question_id);

-- ============================================================
-- TRIGGER: atualiza updated_at automaticamente
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists quizzes_updated_at on public.quizzes;
create trigger quizzes_updated_at
  before update on public.quizzes
  for each row execute function public.set_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY — cada usuário vê só o que é seu
-- ============================================================
alter table public.quizzes   enable row level security;
alter table public.questions enable row level security;
alter table public.options   enable row level security;
alter table public.responses enable row level security;
alter table public.answers   enable row level security;

-- QUIZZES: dono vê/edita tudo; público pode ler apenas publicados
drop policy if exists "quizzes_owner"  on public.quizzes;
drop policy if exists "quizzes_public" on public.quizzes;
create policy "quizzes_owner"  on public.quizzes
  for all using (auth.uid() = user_id);
create policy "quizzes_public" on public.quizzes
  for select using (status = 'published');

-- QUESTIONS: dono gerencia; público lê de quizzes publicados
drop policy if exists "questions_owner"  on public.questions;
drop policy if exists "questions_public" on public.questions;
create policy "questions_owner"  on public.questions
  for all using (
    exists (select 1 from public.quizzes q
            where q.id = quiz_id and q.user_id = auth.uid())
  );
create policy "questions_public" on public.questions
  for select using (
    exists (select 1 from public.quizzes q
            where q.id = quiz_id and q.status = 'published')
  );

-- OPTIONS: mesma lógica das questions
drop policy if exists "options_owner"  on public.options;
drop policy if exists "options_public" on public.options;
create policy "options_owner"  on public.options
  for all using (
    exists (
      select 1 from public.questions qn
      join public.quizzes q on q.id = qn.quiz_id
      where qn.id = question_id and q.user_id = auth.uid()
    )
  );
create policy "options_public" on public.options
  for select using (
    exists (
      select 1 from public.questions qn
      join public.quizzes q on q.id = qn.quiz_id
      where qn.id = question_id and q.status = 'published'
    )
  );

-- RESPONSES: dono do quiz vê todas; qualquer um pode inserir (respondentes)
drop policy if exists "responses_owner"  on public.responses;
drop policy if exists "responses_insert" on public.responses;
create policy "responses_owner"  on public.responses
  for select using (
    exists (select 1 from public.quizzes q
            where q.id = quiz_id and q.user_id = auth.uid())
  );
create policy "responses_insert" on public.responses
  for insert with check (
    exists (select 1 from public.quizzes q
            where q.id = quiz_id and q.status = 'published')
  );

-- ANSWERS: dono do quiz vê; respondente insere
drop policy if exists "answers_owner"  on public.answers;
drop policy if exists "answers_insert" on public.answers;
create policy "answers_owner"  on public.answers
  for select using (
    exists (
      select 1 from public.responses r
      join public.quizzes q on q.id = r.quiz_id
      where r.id = response_id and q.user_id = auth.uid()
    )
  );
create policy "answers_insert" on public.answers
  for insert with check (
    exists (
      select 1 from public.responses r
      join public.quizzes q on q.id = r.quiz_id
      where r.id = response_id and q.status = 'published'
    )
  );

-- ============================================================
-- VIEW: quiz_stats — estatísticas rápidas por quiz
-- ============================================================
create or replace view public.quiz_stats as
select
  q.id,
  q.user_id,
  q.title,
  q.slug,
  q.status,
  count(distinct r.id)                                    as total_responses,
  count(distinct r.id) filter (where r.completed_at is not null) as completed_responses,
  case when count(distinct r.id) > 0
    then round(100.0 * count(distinct r.id) filter (where r.completed_at is not null)
               / count(distinct r.id), 1)
    else 0
  end as completion_rate,
  max(r.created_at) as last_response_at,
  q.created_at,
  q.updated_at
from public.quizzes q
left join public.responses r on r.quiz_id = q.id
group by q.id;

select 'Schema InLead criado com sucesso! ✅' as status;
