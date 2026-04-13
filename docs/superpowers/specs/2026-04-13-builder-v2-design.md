# Builder v2 — Design Spec
**Data:** 2026-04-13  
**Projeto:** Funnly / inlead  
**Arquivo principal:** `public/builder.html`

---

## 1. Visão Geral

O builder receberá quatro melhorias principais numa única iteração:

1. **Modo Fluxo** — canvas full-width estilo n8n com nós, conexões condicionais e zoom/pan
2. **Módulo de Vídeo** — dois novos tipos de bloco: `video` (standalone) e `video_question` (vídeo + pergunta)
3. **Dark Mode** — toggle na interface do builder, preferência salva em localStorage
4. **Ícones Lucide** — substituição completa de emojis por SVG vetorial

Todas as mudanças ficam em `builder.html`. Arquivos secundários afetados: `q.html` (renderização dos novos tipos de bloco no quiz publicado).

---

## 2. Arquitetura — Dual Mode

### 2.1 Modos

O builder opera em dois modos mutuamente exclusivos, controlados pela variável `let builderMode = 'editor' | 'flow'`.

**Modo Editor** (padrão atual, refinado)
- Layout 3 colunas: `.steps-panel` (260px) + `.preview-area` (flex:1) + `.edit-panel` (300px)
- Comportamento idêntico ao atual, com adição de dark mode e ícones Lucide

**Modo Fluxo** (novo)
- `.steps-panel` e `.edit-panel` colapsam: `width → 0`, `opacity → 0`, `overflow: hidden` via transição CSS 250ms
- `.preview-area` expande para 100% com `flex: 1`
- Canvas SVG + div overlay ocupam toda a área
- Drawer flutuante (300px) abre pela direita ao clicar num nó

### 2.2 Transição entre modos

Botão na top bar: ícone Lucide `git-fork` (modo Fluxo) / `layout-template` (modo Editor).

```
toggleMode() {
  builderMode = builderMode === 'editor' ? 'flow' : 'editor'
  document.body.dataset.mode = builderMode
  // CSS handles panel collapse via data-mode selector
  if (builderMode === 'flow') initFlowCanvas()
  else destroyFlowCanvas()
}
```

CSS:
```css
body[data-mode="flow"] .steps-panel,
body[data-mode="flow"] .edit-panel {
  width: 0;
  opacity: 0;
  overflow: hidden;
  padding: 0;
}
```

---

## 3. Modo Fluxo — Canvas de Workflow

### 3.1 Estrutura HTML

```html
<div id="flow-canvas" class="flow-canvas">
  <svg id="flow-svg"><!-- conexões bezier --></svg>
  <div id="flow-nodes"><!-- nós absolutos --></div>
  <div id="flow-controls"><!-- zoom +/-/reset --></div>
</div>
<div id="flow-drawer" class="flow-drawer closed"><!-- editor do nó --></div>
```

### 3.2 Tipos de Nós

| Tipo | Ícone Lucide | Portas de saída |
|------|-------------|-----------------|
| `start` | `play` | 1 (inferior) |
| `end` | `flag` | 0 |
| `multiple_choice` | `circle-dot` | 1 por opção (lateral direita) |
| `checkbox` | `check-square` | 1 (inferior) |
| `text` / `email` / `phone` / `name` | `type` / `mail` / `smartphone` / `user` | 1 (inferior) |
| `rating` | `star` | 1 (inferior) |
| `nps` | `bar-chart-2` | 1 (inferior) |
| `statement` | `message-square` | 1 (inferior) |
| `video` | `play-circle` | 1 (inferior) |
| `video_question` | `clapperboard` | 1 por opção ou 1 (inferior) |

### 3.3 Anatomia do Nó

```
┌─────────────────────────┐
│ [ícone] Tipo            │  ← header (cor por tipo)
├─────────────────────────┤
│ Título da pergunta      │  ← truncado 2 linhas
│ (truncado)              │
└─────────────────────────┘
         ↓ porta saída
```

Dimensões: 200px × 80px (nós padrão), 200px × 120px (múltipla escolha com opções).

Estados visuais:
- Default: borda `--border`, background `--surface`
- Hover: borda `--accent`, sombra leve
- Selecionado: borda `--accent` 2px, background `--soft`
- Start/End: borda `--accent` tracejada, fundo diferenciado

### 3.4 Conexões SVG

Cada conexão é um `<path>` SVG com curva cúbica de Bezier:
```
M x1,y1 C x1,y1+80 x2,y2-80 x2,y2
```

- Conexão padrão: `stroke: var(--accent)`, `stroke-width: 2`
- Conexão condicional (de opção): `stroke: var(--cta)`, com label SVG `<text>` no meio
- Clique na conexão: seleciona (espessa para 3px) + mostra botão delete flutuante

### 3.5 Interações

**Arrastar nó:** `mousedown` no nó → `mousemove` atualiza `q._flowX`, `q._flowY` → `mouseup` salva posição + redesenha SVG.

**Criar conexão:** `mousedown` na porta de saída → linha preview segue o cursor → `mouseup` em outro nó cria conexão. Dados salvos em `q._connections: [{ fromOption: null|string, toQuestionId: string }]`.

**Zoom/Pan:**
- Scroll do mouse: `transform: scale(zoom)` no `#flow-nodes` e `#flow-svg`, range 0.3–2.0, step 0.1
- Arrastar background: `cursor: grab`, translação via `transform: translate(panX, panY)`
- Botões no canto inferior direito: `+`, `100%` (reset), `-`

**Drawer de edição:**
- Clique no nó → `#flow-drawer` recebe classe `open`, renderiza o mesmo conteúdo do painel direito atual (`renderQuestionTab(q)`)
- Botão `×` ou clique fora fecha o drawer
- Listeners idênticos ao `attachPanelListeners(q)` atual

**Menu contextual (botão direito):**
- Editar (abre drawer)
- Duplicar (cria cópia com offset +40px)
- Deletar (com confirmação)

### 3.6 Layout inicial automático

Quando `flow_positions` está vazio no quiz:
```
Start (x:80, y:200) → Q1 (x:340, y:200) → Q2 (x:600, y:200) → ... → End
```
Perguntas de múltipla escolha com ramificações: filhos distribuídos verticalmente com offset de 120px por opção.

### 3.7 Persistência

Campo `settings.flow_positions` no Supabase:
```json
{
  "flow_positions": {
    "questionId1": { "x": 340, "y": 200 },
    "questionId2": { "x": 600, "y": 320 }
  },
  "flow_connections": {
    "questionId1": [{ "fromOption": "opcao-A", "toQuestionId": "questionId3" }]
  }
}
```

Salvo junto com o `saveAll()` existente (debounceSave).

---

## 4. Módulo de Vídeo

### 4.1 Novos tipos de pergunta

**`video`** — bloco standalone
- Campos: `videoUrl` (string), `autoAdvance` (boolean), `autoAdvanceDelay` (number, segundos)
- Sem campo de título obrigatório (título opcional como legenda)
- No quiz: player 16:9 + botão "Continuar" (aparece após delay ou ao fim do vídeo)

**`video_question`** — vídeo com pergunta
- Campos: todos do `video` + todos os campos de pergunta existentes (`title`, `options`, `required`, etc.)
- No quiz: player 16:9 no topo, pergunta + opções abaixo
- Suporta todos os subtipos de resposta (múltipla escolha, texto, etc.) via campo `questionSubtype`

### 4.2 Detecção de fonte

```javascript
function parseVideoUrl(url) {
  if (url.includes('youtube.com') || url.includes('youtu.be')) {
    const id = url.match(/(?:v=|youtu\.be\/|embed\/)([A-Za-z0-9_-]{11})/)?.[1]
    return { type: 'youtube', embedUrl: `https://www.youtube.com/embed/${id}` }
  }
  if (url.includes('vimeo.com')) {
    const id = url.match(/vimeo\.com\/(\d+)/)?.[1]
    return { type: 'vimeo', embedUrl: `https://player.vimeo.com/video/${id}` }
  }
  if (url.match(/\.(mp4|webm|ogg)$/i)) {
    return { type: 'direct', embedUrl: url }
  }
  return null
}
```

### 4.3 Painel de edição (painel direito)

Para `video` e `video_question`:

1. **URL do vídeo** — input com placeholder "Cole o link do YouTube, Vimeo ou MP4"
2. **Preview inline** — iframe/video 16:9 atualiza ao sair do campo (onblur)
3. **Avançar automático** — toggle + input numérico "após X segundos" (visível só quando toggle ativo)
4. Para `video_question`: seção "Pergunta" abaixo com campos normais (título, tipo de resposta, opções). Valor padrão de `questionSubtype`: `multiple_choice`

### 4.4 Preview no builder (centro)

Renderiza iframe/video em 16:9 com overlay "Preview de vídeo" (não reproduz no builder, só mostra thumbnail via oEmbed quando disponível).

### 4.5 Renderização no quiz publicado (q.html)

Novos cases no switch de tipos em `q.html`:

```javascript
case 'video':
  // Renderiza player + botão Continuar (habilitado após delay)
case 'video_question':
  // Renderiza player + pergunta + opções abaixo
```

Player responsivo:
```html
<div class="video-wrapper">
  <iframe src="embedUrl" frameborder="0" allowfullscreen></iframe>
</div>
```
```css
.video-wrapper { position: relative; padding-bottom: 56.25%; }
.video-wrapper iframe { position: absolute; inset: 0; width: 100%; height: 100%; }
```

---

## 5. Dark Mode

### 5.1 Variáveis CSS

```css
body.dark {
  --ink:     #f0ecff;
  --paper:   #0a0a0f;
  --accent:  #a855f7;
  --glow:    #c084fc;
  --soft:    #1a1030;
  --muted:   #7c6f9a;
  --border:  #1e1a2e;
  --surface: #110d1f;
  --danger:  #f87171;
  --success: #4ade80;
}
```

### 5.2 Toggle

```javascript
function toggleTheme() {
  const isDark = document.body.classList.toggle('dark')
  localStorage.setItem('funnly-theme', isDark ? 'dark' : 'light')
  lucide.createIcons() // re-renderiza ícones com nova cor
}

// Aplicar antes do primeiro render (no <head>):
if (localStorage.getItem('funnly-theme') === 'dark') {
  document.body.classList.add('dark')
}
```

Ícone no top bar: `moon` (modo light → clique ativa dark), `sun` (modo dark → clique desativa).

### 5.3 Componentes a ajustar para dark mode

- Top bar: background `--paper`, borda inferior `--border`
- Painéis laterais: background `--paper`
- Cards de nó no flow: background `--surface`
- Inputs: background `--soft`, borda `--border`, texto `--ink`
- Modal: overlay `rgba(0,0,0,0.7)`, card `--surface`
- Drawer do flow: background `--paper`
- Scrollbars: `scrollbar-color: var(--border) transparent`

---

## 6. Ícones Lucide

### 6.1 Carregamento

```html
<script src="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"></script>
```

Após qualquer `innerHTML` que contenha ícones:
```javascript
lucide.createIcons()
```

### 6.2 Uso em HTML

```html
<i data-lucide="mail" class="icon"></i>
```

```css
.icon { width: 16px; height: 16px; stroke: currentColor; stroke-width: 1.5; }
.icon-lg { width: 20px; height: 20px; }
.icon-xl { width: 24px; height: 24px; }
```

### 6.3 Mapeamento completo

| Contexto | Ícone |
|----------|-------|
| Tipo: múltipla escolha | `circle-dot` |
| Tipo: checkbox | `check-square` |
| Tipo: texto | `type` |
| Tipo: email | `mail` |
| Tipo: telefone | `smartphone` |
| Tipo: nome | `user` |
| Tipo: rating | `star` |
| Tipo: NPS | `bar-chart-2` |
| Tipo: statement | `message-square` |
| Tipo: vídeo | `play-circle` |
| Tipo: vídeo+pergunta | `clapperboard` |
| Preview desktop | `monitor` |
| Preview mobile | `smartphone` |
| Modo fluxo | `git-fork` |
| Modo editor | `layout-template` |
| Dark mode (light) | `moon` |
| Dark mode (dark) | `sun` |
| Salvo | `check` |
| Não salvo | `dot` |
| Voltar | `chevron-left` |
| Publicar | `zap` |
| Pausar | `pause-circle` |
| Visualizar | `eye` |
| Adicionar | `plus` |
| Deletar | `trash-2` |
| Fechar | `x` |
| Duplicar | `copy` |
| Arrastar | `grip-vertical` |
| Nó start | `play` |
| Nó end | `flag` |
| Empty state | `layout-template` |
| Rating preenchida | `star` (fill) |
| Rating vazia | `star` (outline) |

---

## 7. Arquivos Afetados

| Arquivo | Mudanças |
|---------|----------|
| `public/builder.html` | Reescrita principal: dual mode, flow canvas, dark mode, Lucide, módulo vídeo |
| `public/q.html` | Novos cases para `video` e `video_question` no renderer |
| `public/dashboard.html` | Dark mode CSS vars (sidebar/nav) |
| `public/results.html` | Dark mode CSS vars (sidebar/nav) |
| `public/integrations.html` | Dark mode CSS vars |
| `public/settings.html` | Dark mode CSS vars |

Dark mode no builder é isolado — não afeta o quiz publicado (`q.html` não recebe dark mode).

---

## 8. Fora de Escopo

- Dark mode no quiz publicado (`q.html`) — usuário controla cores manualmente
- Upload direto de arquivo de vídeo — apenas URLs externas nesta versão
- Colaboração em tempo real no flow canvas
- Animações de transição entre perguntas no quiz publicado
- Exportar flow como imagem/PDF
