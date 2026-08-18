import { cookies } from 'next/headers';
import { NextRequest } from 'next/server';

import { API_BASE, TOKEN_COOKIE } from '@/lib/config';

type RouteContext = { params: Promise<{ path: string[] }> };

const METHODS = ['GET', 'POST', 'PUT', 'DELETE'] as const;

async function proxy(req: NextRequest, ctx: RouteContext, method: (typeof METHODS)[number]) {
  const { path } = await ctx.params;
  const token = (await cookies()).get(TOKEN_COOKIE)?.value;
  const url = `${API_BASE}/${path.join('/')}${req.nextUrl.search}`;

  const headers: Record<string, string> = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (method !== 'GET' && method !== 'DELETE') headers['Content-Type'] = 'application/json';

  const body = method === 'GET' || method === 'DELETE' ? undefined : await req.text();
  const resp = await fetch(url, { method, headers, body, cache: 'no-store' });

  const contentType = resp.headers.get('content-type') ?? 'application/json';
  const headersOut: Record<string, string> = { 'Content-Type': contentType };
  const disposition = resp.headers.get('content-disposition');
  if (disposition) headersOut['Content-Disposition'] = disposition;

  return new Response(await resp.arrayBuffer(), { status: resp.status, headers: headersOut });
}

export const GET = (req: NextRequest, ctx: RouteContext) => proxy(req, ctx, 'GET');
export const POST = (req: NextRequest, ctx: RouteContext) => proxy(req, ctx, 'POST');
export const PUT = (req: NextRequest, ctx: RouteContext) => proxy(req, ctx, 'PUT');
export const DELETE = (req: NextRequest, ctx: RouteContext) => proxy(req, ctx, 'DELETE');
