'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

import type { Exam } from '@/lib/types';

export default function DashboardPage() {
  const [exams, setExams] = useState<Exam[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/exams')
      .then(async (r) => {
        if (!r.ok) throw new Error((await r.json().catch(() => null))?.detail ?? 'Gagal memuat');
        return r.json();
      })
      .then(setExams)
      .catch((e) => setError(String(e)));
  }, []);

  async function logout() {
    await fetch('/api/auth/login', { method: 'DELETE' });
    window.location.href = '/login';
  }

  return (
    <main className="min-h-screen bg-slate-100">
      <header className="flex items-center justify-between bg-white px-6 py-4 shadow">
        <h1 className="text-xl font-bold text-slate-800">AutoGrading — Dashboard</h1>
        <button onClick={logout} className="text-sm text-slate-500 hover:text-red-600">
          Keluar
        </button>
      </header>

      <section className="mx-auto max-w-5xl p-6">
        <h2 className="mb-4 text-lg font-semibold text-slate-700">Daftar Ujian</h2>
        {error && <p className="mb-4 text-sm text-red-600">{error}</p>}
        {!exams && !error && <p className="text-slate-500">Memuat...</p>}
        {exams && exams.length === 0 && (
          <p className="rounded-lg bg-white p-6 text-slate-500 shadow">
            Belum ada ujian. Buat ujian lewat aplikasi/API dulu.
          </p>
        )}
        <div className="grid gap-4 md:grid-cols-2">
          {exams?.map((exam) => (
            <Link
              key={exam.id}
              href={`/dashboard/exams/${exam.id}`}
              className="rounded-xl bg-white p-5 shadow transition hover:shadow-md"
            >
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="font-semibold text-slate-800">{exam.title}</h3>
                  <p className="mt-1 text-sm text-slate-500">
                    Total skor {exam.total_score} · Kelas #{exam.class_id}
                  </p>
                </div>
                <span className="text-slate-300">›</span>
              </div>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}
