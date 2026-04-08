# InLead — Guia Completo de Deploy

Siga os passos na ordem. Cada passo leva no máximo 5 minutos.

---

## O que você vai precisar

- Computador com internet
- ~30 minutos no total
- Conta gratuita no **Supabase** (banco de dados)
- Conta gratuita no **GitHub** (código)
- Conta gratuita na **Vercel** (hospedagem)

---

## PASSO 1 — Instalar Node.js (se ainda não tiver)

1. Acesse **https://nodejs.org**
2. Clique no botão verde **"LTS"**
3. Instale normalmente
4. Confirme: abra o Terminal e digite `node -v`
   - Se aparecer algo como `v20.11.0` ✅

---

## PASSO 2 — Criar o banco de dados no Supabase

1. Acesse **https://supabase.com** → **"Start your project"**
2. Crie uma conta (pode usar o Google)
3. Clique em **"New project"**
   - Nome: `inlead`
   - Região: **South America (São Paulo)**
4. Aguarde ~2 minutos
5. No menu lateral → **"SQL Editor"** → **"New query"**
6. Abra o arquivo `supabase-setup.sql` desta pasta, copie tudo e cole
7. Clique em **"Run"** → deve aparecer `Schema InLead criado com sucesso! ✅`

### Pegar as chaves do Supabase:

Menu lateral → **"Settings"** → **"API"**

Copie:
- **Project URL** → `SUPABASE_URL`
- **anon / public** (em "Project API keys") → `SUPABASE_ANON_KEY`
- **service_role** → `SUPABASE_SERVICE_ROLE_KEY`

⚠️ Nunca compartilhe a `service_role` com ninguém.

### Ativar autenticação por e-mail:

Menu lateral → **"Authentication"** → **"Providers"** → **Email** → certifique que está habilitado (padrão: sim).

Opcional — desativar confirmação de e-mail (mais fácil para testar):
Menu lateral → **"Authentication"** → **"Settings"** → desmarque **"Enable email confirmations"**

---

## PASSO 3 — Configurar o projeto localmente

No Terminal, dentro da pasta `inlead`:

```bash
cd ~/Downloads/Codigo/inlead
bash setup.sh
```

Depois abra o arquivo `.env` e preencha:

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...anon...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...service_role...
```

---

## PASSO 4 — Testar localmente

```bash
npm run dev
```

Abra **http://localhost:3000** no navegador.

Teste:
1. Criar uma conta → dashboard aparece ✅
2. Criar um novo quiz → builder abre ✅
3. Adicionar perguntas, salvar ✅
4. Publicar o quiz → copiar link ✅
5. Abrir o link → responder ✅
6. Voltar em Resultados → lead aparece ✅

---

## PASSO 5 — Publicar no GitHub e Vercel

### 5a. Criar repositório no GitHub

1. Acesse **https://github.com/new**
2. Nome: `inlead`
3. Deixe **Private**
4. Clique em **"Create repository"**

### 5b. Enviar o código

No Terminal, dentro da pasta do projeto:

```bash
git init
git add .
git commit -m "primeiro commit"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/inlead.git
git push -u origin main
```

(Substitua `SEU_USUARIO` pelo seu nome no GitHub)

### 5c. Deploy na Vercel

1. Acesse **https://vercel.com** → entre com o GitHub
2. Clique em **"Add New Project"**
3. Escolha o repositório `inlead` → **"Import"**
4. Em **"Environment Variables"**, adicione:
   - `SUPABASE_URL` = sua URL
   - `SUPABASE_ANON_KEY` = sua anon key
   - `SUPABASE_SERVICE_ROLE_KEY` = sua service_role key
5. Clique em **"Deploy"**

Pronto! Seu InLead está no ar com HTTPS. 🎉

---

## Como usar a plataforma

1. Acesse seu link da Vercel → criar conta
2. No dashboard → clique em **"Novo quiz"**
3. No builder → adicione perguntas arrastando os tipos
4. Clique em **"Publicar"** → copie o link
5. Compartilhe o link com seu público
6. Acompanhe os leads em **Resultados**

---

## Estrutura dos arquivos

```
inlead/
├── public/
│   ├── index.html      ← Landing page + login/cadastro
│   ├── dashboard.html  ← Lista de quizzes
│   ├── builder.html    ← Editor visual de quiz
│   ├── q.html          ← Quiz público (respondentes)
│   └── results.html    ← Dashboard de leads
├── api/
│   ├── env.ts          ← Injeta as chaves no frontend
│   └── health.ts       ← Health check
├── supabase-setup.sql  ← Schema do banco de dados
├── vercel.json         ← Configuração de rotas
└── package.json
```

---

## Custo total

| O que | Quanto |
|---|---|
| Vercel (hospedagem) | **Grátis** |
| Supabase (banco + auth) | **Grátis** até 50 mil usuários |
| Domínio (opcional) | ~R$40/ano |
| **Total** | **R$ 0 / mês** |

---

## Problemas comuns

**"npm: command not found"**
→ Reinstale o Node.js em nodejs.org

**Login não funciona**
→ Verifique se SUPABASE_ANON_KEY está correta na Vercel

**Quiz não abre**
→ Certifique que o quiz está **Publicado** no builder

**Leads não aparecem**
→ Verifique se o SQL foi executado com sucesso no Supabase

**Erro ao fazer login "Email not confirmed"**
→ Desative a confirmação de e-mail no Supabase → Authentication → Settings
