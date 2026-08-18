'use client';

import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LinearScale,
  Title,
  Tooltip,
} from 'chart.js';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Bar } from 'react-chartjs-2';

import type { Difficulty, Distribution, ExamSubmission } from '@/lib/types';

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

export default function ExamDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [subs, setSubs] = useState<ExamSubmission[] | null>(null);
  const [dist, setDist] = useState<Distribution | null>(null);
  const [diff, setDiff] = useState<Difficulty | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      fetch(`/api/exams/${id}/submissions`).then((r) => r.json()),
      fetch(`/api/analytics/exams/${id}/distribution`).then((r) => r.json()),
      fetch(`/api/analytics/exams/${id}/question-difficulty`).then((r) => r.json()),
    ])
      .then(([s, d, df]) => {
        setSubs(s);
        setDist(d);
        setDiff(df);
      })
      .catch((e) => setError(String(e)));
  }, [id]);

  const distData = {
    labels: dist?.buckets.map((b) => b.range) ?? [],
    datasets: [
      {
        label: 'Jumlah siswa',
        data: dist?.buckets.map((b) => b.count) ?? [],
        backgroundColor: '#6366f1',
      },
    ],
  };

  const diffData = {
    labels: diff?.questions.map((q) => `Q${q.question_number}`) ?? [],
    datasets: [
      {
        label: 'Rata-rata skor',
        data: diff?.questions.map((q) => q.average_score ?? 0) ?? [],
        backgroundColor: '#0ea5e9',
      },
    ],
  };

  return (
    <main className="min-h-screen bg-slate-100">
      <header className="flex items-center justify-between bg-white px-6 py-4 shadow">
        <div className="flex items-center gap-3">
          <Link href="/dashboard" className="text-slate-500 hover:text-slate-700">
            ← Dashboard
          </Link>
          <h1 className="text-xl font-bold text-slate-800">Ujian #{id}</h1>
        </div>
        <a
          href={`/api/exams/${id}/export.csv`}
          className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          Export CSV
        </a>
      </header>

      <section className="mx-auto max-w-6xl space-y-6 p-6">
        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="grid gap-6 lg:grid-cols-2">
          <div className="rounded-xl bg-white p-5 shadow">
            <h2 className="mb-3 font-semibold text-slate-700">Distribusi Nilai</h2>
            {dist ? <Bar data={distData} options={{ plugins: { legend: { display: false } } }} /> : <p className="text-sm text-slate-500">Memuat...</p>}
          </div>
          <div className="rounded-xl bg-white p-5 shadow">
            <h2 className="mb-3 font-semibold text-slate-700">Kesulitan Soal (rata-rata skor)</h2>
            {diff ? <Bar data={diffData} options={{ plugins: { legend: { display: false } } }} /> : <p className="text-sm text-slate-500">Memuat...</p>}
          </div>
        </div>

        <div className="overflow-x-auto rounded-xl bg-white shadow">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-slate-500">
                <th className="px-4 py-3">No Absen</th>
                <th className="px-4 py-3">Nama</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3 text-right">Total</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {subs?.map((s) => (
                <tr key={s.id} className="border-b last:border-0 hover:bg-slate-50">
                  <td className="px-4 py-2">{s.student_number ?? '-'}</td>
                  <td className="px-4 py-2">{s.student_name ?? '-'}</td>
                  <td className="px-4 py-2">
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs ${
                        s.status === 'finalized'
                          ? 'bg-emerald-100 text-emerald-700'
                          : s.status === 'graded'
                            ? 'bg-amber-100 text-amber-700'
                            : 'bg-slate-100 text-slate-500'
                      }`}
                    >
                      {s.status}
                    </span>
                  </td>
                  <td className="px-4 py-2 text-right font-medium">{s.total_score ?? '-'}</td>
                  <td className="px-4 py-2 text-right">
                    <Link href={`/dashboard/exams/${id}/students/${s.id}`} className="text-indigo-600 hover:underline">
                      Detail
                    </Link>
                  </td>
                </tr>
              ))}
              {subs && subs.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-6 text-center text-slate-500">
                    Belum ada submission untuk ujian ini.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
