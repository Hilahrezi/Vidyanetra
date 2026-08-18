import { NextRequest, NextResponse } from 'next/server';

import { TOKEN_COOKIE } from '@/lib/config';

// Next 16: middleware -> proxy.ts (lihat node_modules/next/dist/docs/).
export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const hasToken = Boolean(request.cookies.get(TOKEN_COOKIE)?.value);

  if (pathname.startsWith('/dashboard') && !hasToken) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  if (pathname === '/login' && hasToken) {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }
}

export const config = {
  matcher: ['/dashboard/:path*', '/login'],
};
