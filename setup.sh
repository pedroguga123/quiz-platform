#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════╗"
echo "║   InLead — Setup Automático      ║"
echo "╚══════════════════════════════════╝"
echo ""

if ! command -v node &> /dev/null; then
  echo "❌ Node.js não encontrado."
  echo "   Baixe em: https://nodejs.org (clique em 'LTS')"
  exit 1
fi

echo "✅ Node.js: $(node -v)"
echo ""
echo "📦 Instalando dependências..."
npm install

if [ ! -f .env ]; then
  cp .env.example .env
  echo ""
  echo "📄 Arquivo .env criado!"
  echo "   ⚠️  Abra o .env e preencha com suas chaves do Supabase"
  echo "   (veja o LEIA-ME.md)"
else
  echo "✅ .env já existe."
fi

echo ""
echo "══════════════════════════════════"
echo "✅ Setup concluído!"
echo ""
echo "   Próximo passo:"
echo "   npm run dev"
echo ""
echo "   Depois abra: http://localhost:3000"
echo "══════════════════════════════════"
echo ""
