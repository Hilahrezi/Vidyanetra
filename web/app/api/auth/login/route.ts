import { NextRequest, NextResponse } from 'next/server';

import { API_BASE, TOKEN_COOKIE } from '@/lib/config';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const resp = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      cache: 'no-store',
    });

    const data = await resp.json().catch(() => null);
    if (!resp.ok) {
      return NextResponse.json(
        { detail: data?.detail || 'Email atau password salah' },
        { status: resp.status }
      );
    }

    // Validasi peran: Web Dashboard khusus Administrator Sekolah
    if (data.user?.role !== 'admin') {
      return NextResponse.json(
        {
          detail:
            'Web Dashboard ini dikhususkan untuk Administrator Sekolah. Bapak/Ibu Guru dipersilakan menggunakan Aplikasi Mobile AutoGrading untuk mengelola ujian dan penilaian.',
        },
        { status: 403 }
      );
    }

    const out = NextResponse.json(data);
    out.cookies.set(TOKEN_COOKIE, data.access_token, {
      httpOnly: true,
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 8,
    });
    return out;
  } catch (err: unknown) {
    return NextResponse.json(
      { detail: `Tidak dapat terhubung ke Backend API (${API_BASE}). Pastikan server backend sedang berjalan.` },
      { status: 502 }
    );
  }
}

export async function DELETE() {
  const out = NextResponse.json({ ok: true });
  out.cookies.set(TOKEN_COOKIE, '', { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 0 });
  return out;
}
