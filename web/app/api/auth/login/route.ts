import { NextRequest, NextResponse } from 'next/server';

import { API_BASE, TOKEN_COOKIE } from '@/lib/config';

export async function POST(req: NextRequest) {
  const body = await req.json();
  const resp = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
  });
  const data = await resp.json().catch(() => null);
  if (!resp.ok) {
    return NextResponse.json(data ?? { detail: 'Login gagal' }, { status: resp.status });
  }
  const out = NextResponse.json(data);
  out.cookies.set(TOKEN_COOKIE, data.access_token, {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 8,
  });
  return out;
}

export async function DELETE() {
  const out = NextResponse.json({ ok: true });
  out.cookies.set(TOKEN_COOKIE, '', { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 0 });
  return out;
}
