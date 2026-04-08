import type { VercelRequest, VercelResponse } from '@vercel/node';

/**
 * Injeta as variáveis públicas do Supabase no frontend.
 * A ANON KEY é segura para expor — só lê dados públicos ou operações autorizadas por RLS.
 * NUNCA exponha a SERVICE_ROLE KEY aqui.
 */
export default function handler(_req: VercelRequest, res: VercelResponse) {
  res.setHeader('Content-Type', 'application/javascript');
  res.setHeader('Cache-Control', 'no-store');
  res.send(`window.__env = ${JSON.stringify({
    SUPABASE_URL:      process.env.SUPABASE_URL      || '',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || '',
  })};`);
}
