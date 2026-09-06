'use client';

import { useState } from 'react';

export default function LoginPage() {
  const [email, setEmail] = useState('admin@sekolah.id');
  const [password, setPassword] = useState('admin123');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const resp = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email.trim(), password }),
      });
      const data = await resp.json().catch(() => null);
      if (!resp.ok) {
        setError(data?.detail ?? 'Login gagal. Periksa email & password.');
        return;
      }
      window.location.href = '/dashboard';
    } catch (err: unknown) {
      setError('Tidak dapat terhubung ke server backend. Pastikan server sedang berjalan.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#F8FAFC] p-4 text-[#0F172A]">
      <div className="w-full max-w-sm space-y-4">
        <form
          onSubmit={submit}
          className="rounded-3xl bg-white p-8 shadow-xl shadow-slate-200/50 border border-slate-200/80"
        >
          {/* Vidyanetra Brand Icon */}
          <div className="flex justify-center mb-3">
            <div className="relative flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-tr from-[#0F766E] to-[#14B8A6] text-white shadow-lg shadow-teal-900/20">
              <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                />
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                />
              </svg>
              <div className="absolute -top-1 -right-1 h-3.5 w-3.5 rounded-full bg-[#10B981] border-2 border-white animate-pulse" />
            </div>
          </div>

          <h1 className="text-center text-xl font-bold tracking-tight text-[#0F172A]">
            Vidyanetra <span className="text-[#0F766E]">Admin</span>
          </h1>
          <p className="mb-6 text-center text-xs text-slate-500 font-medium">
            Intelligent Academic Vision & Assessment Portal
          </p>

          {error && (
            <div className="mb-4 rounded-xl bg-rose-50 p-3.5 border border-rose-200 text-xs text-rose-700 leading-relaxed flex items-start gap-2.5">
              <span className="text-sm leading-none mt-0.5">⚠️</span>
              <span>{error}</span>
            </div>
          )}

          <div className="space-y-3.5">
            <div>
              <label className="mb-1 block text-xs font-bold text-slate-700">Email Administrator</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@sekolah.id"
                className="w-full rounded-xl border border-slate-200 bg-slate-50/50 px-3.5 py-2.5 text-sm focus:border-[#0F766E] focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#0F766E]/20 transition"
                required
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-bold text-slate-700">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full rounded-xl border border-slate-200 bg-slate-50/50 px-3.5 py-2.5 text-sm focus:border-[#0F766E] focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#0F766E]/20 transition"
                required
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="mt-6 w-full rounded-xl bg-[#0F766E] hover:bg-[#115E59] py-2.5 text-sm font-bold text-white shadow-md shadow-teal-900/20 active:scale-[0.99] disabled:opacity-50 transition"
          >
            {loading ? 'Memproses Autentikasi...' : 'Masuk ke Portal'}
          </button>
        </form>
      </div>
    </main>
  );
}
