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
import { useEffect, useMemo, useState } from 'react';
import { Bar } from 'react-chartjs-2';

import type { Difficulty, Distribution, Exam, ExamSubmission } from '@/lib/types';

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

export default function ExamDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [exam, setExam] = useState<Exam | null>(null);
  const [subs, setSubs] = useState<ExamSubmission[] | null>(null);
  const [dist, setDist] = useState<Distribution | null>(null);
  const [diff, setDiff] = useState<Difficulty | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Student search & status filter
  const [studentSearch, setStudentSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'finalized' | 'graded' | 'pending'>('all');

  useEffect(() => {
    setLoading(true);
    Promise.all([
      fetch(`/api/exams/${id}`).then((r) => (r.ok ? r.json() : null)),
      fetch(`/api/exams/${id}/submissions`).then((r) => (r.ok ? r.json() : [])),
      fetch(`/api/analytics/exams/${id}/distribution`).then((r) => (r.ok ? r.json() : null)),
      fetch(`/api/analytics/exams/${id}/question-difficulty`).then((r) => (r.ok ? r.json() : null)),
    ])
      .then(([ex, s, d, df]) => {
        setExam(ex);
        setSubs(s);
        setDist(d);
        setDiff(df);
      })
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, [id]);

  // Exam stats calculations
  const stats = useMemo(() => {
    if (!subs || subs.length === 0) {
      return { avg: 0, passRate: 0, max: 0, min: 0, total: 0, completed: 0 };
    }
    const scores = subs.map((s) => s.total_score).filter((s): s is number => s !== null);
    if (scores.length === 0) {
      return { avg: 0, passRate: 0, max: 0, min: 0, total: subs.length, completed: 0 };
    }
    const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
    const max = Math.max(...scores);
    const min = Math.min(...scores);
    const passThreshold = (exam?.total_score ?? 100) * 0.7;
    const passed = scores.filter((s) => s >= passThreshold).length;
    const passRate = (passed / scores.length) * 100;
    const completed = subs.filter((s) => s.status === 'finalized').length;

    return {
      avg: Math.round(avg * 10) / 10,
      passRate: Math.round(passRate),
      max: Math.round(max * 10) / 10,
      min: Math.round(min * 10) / 10,
      total: subs.length,
      completed,
    };
  }, [subs, exam]);

  // Filtered submissions
  const filteredSubs = useMemo(() => {
    if (!subs) return [];
    return subs.filter((s) => {
      const matchSearch =
        studentSearch.trim() === '' ||
        (s.student_name && s.student_name.toLowerCase().includes(studentSearch.toLowerCase())) ||
        (s.student_number && s.student_number.includes(studentSearch));
      const matchStatus = statusFilter === 'all' || s.status === statusFilter;
      return matchSearch && matchStatus;
    });
  }, [subs, studentSearch, statusFilter]);

  const distData = {
    labels: dist?.buckets.map((b) => b.range) ?? [],
    datasets: [
      {
        label: 'Jumlah Siswa',
        data: dist?.buckets.map((b) => b.count) ?? [],
        backgroundColor: '#6366f1',
        borderRadius: 6,
      },
    ],
  };

  const displaySubject =
    exam?.subject ||
    (exam?.class_name && exam?.class_name.includes(' — ')
      ? exam.class_name.split(' — ')[0]
      : 'Mata Pelajaran');

  const displayClass =
    exam?.class_name && exam?.class_name.includes(' — ')
      ? exam.class_name.split(' — ')[1]
      : exam?.class_name || `Kelas #${exam?.class_id}`;

  return (
    <main className="min-h-screen bg-slate-50 text-slate-800 pb-12">
      {/* Top Header */}
      <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/90 backdrop-blur-md">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-3">
            <Link
              href="/dashboard"
              className="inline-flex items-center gap-1 rounded-lg border border-slate-200 bg-slate-50 px-2.5 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100 hover:text-slate-900 transition"
            >
              <span>←</span>
              <span>Dashboard</span>
            </Link>
            <div>
              <div className="flex items-center gap-2">
                <span className="rounded-md bg-indigo-50 px-2 py-0.5 text-[11px] font-bold text-indigo-700 border border-indigo-100">
                  {displaySubject}
                </span>
                <span className="rounded-md bg-sky-50 px-2 py-0.5 text-[11px] font-bold text-sky-700 border border-sky-100">
                  {displayClass}
                </span>
              </div>
              <h1 className="text-lg font-bold text-slate-900 mt-0.5">
                {exam?.title ?? `Ujian #${id}`}
              </h1>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <a
              href={`/api/exams/${id}/template.pdf`}
              download
              className="inline-flex items-center gap-1.5 rounded-xl border border-indigo-200 bg-indigo-50 px-3.5 py-2 text-xs font-semibold text-indigo-700 hover:bg-indigo-100 shadow-sm transition"
            >
              <span>📄</span>
              <span>Download PDF Lembar</span>
            </a>
            <a
              href={`/api/exams/${id}/export.csv`}
              download
              className="inline-flex items-center gap-1.5 rounded-xl border border-emerald-200 bg-emerald-50 px-3.5 py-2 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 shadow-sm transition"
            >
              <span>📥</span>
              <span>Export CSV</span>
            </a>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-7xl space-y-6 px-6 py-6">
        {error && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 flex items-center gap-2">
            <span>⚠️</span>
            <span>{error}</span>
          </div>
        )}

        {/* 4 KPI Summary Cards for this Exam */}
        <section className="grid grid-cols-2 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <span className="text-xs font-semibold text-slate-500 uppercase">Rata-rata Nilai</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-slate-900">
              {stats.avg} <span className="text-sm font-normal text-slate-400">/ {exam?.total_score ?? 100}</span>
            </p>
            <p className="mt-1 text-xs text-slate-400">Rata-rata dari lembar tergradasi</p>
          </div>

          <div className="rounded-2xl border border-emerald-100 bg-emerald-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-emerald-700 uppercase">Ketuntasan (≥70%)</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-emerald-950">
              {stats.passRate}%
            </p>
            <p className="mt-1 text-xs text-emerald-700/80">Memenuhi standar KKM</p>
          </div>

          <div className="rounded-2xl border border-sky-100 bg-sky-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-sky-700 uppercase">Nilai Tertinggi</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-sky-950">
              {stats.max} <span className="text-sm font-normal text-sky-600">pt</span>
            </p>
            <p className="mt-1 text-xs text-sky-700/80">Skor maksimum siswa</p>
          </div>

          <div className="rounded-2xl border border-amber-100 bg-amber-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-amber-700 uppercase">Nilai Terendah</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-amber-950">
              {stats.min} <span className="text-sm font-normal text-amber-600">pt</span>
            </p>
            <p className="mt-1 text-xs text-amber-700/80">Perlu perhatian / remedial</p>
          </div>
        </section>

        {/* Charts: Distribution & Psychometric Item Difficulty */}
        <section className="grid gap-6 lg:grid-cols-2">
          {/* Histogram Distribusi Nilai */}
          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <div className="mb-4 flex items-center justify-between">
              <div>
                <h2 className="text-sm font-bold text-slate-800">Distribusi Frekuensi Nilai</h2>
                <p className="text-xs text-slate-400">Rentang nilai total seluruh peserta ujian</p>
              </div>
              <span className="rounded-lg bg-indigo-50 px-2.5 py-1 text-xs font-bold text-indigo-700">
                📊 Histogram
              </span>
            </div>
            {dist ? (
              <div className="h-64">
                <Bar
                  data={distData}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: {
                      y: {
                        beginAtZero: true,
                        ticks: { stepSize: 1 },
                      },
                    },
                  }}
                />
              </div>
            ) : (
              <p className="py-12 text-center text-sm text-slate-400">Memuat distribusi nilai...</p>
            )}
          </div>

          {/* Analisis Tingkat Kesulitan Butir Soal (Traffic-Light) */}
          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <div className="mb-4 flex items-center justify-between">
              <div>
                <h2 className="text-sm font-bold text-slate-800">Analisis Butir Soal (Item Difficulty)</h2>
                <p className="text-xs text-slate-400">Tingkat penguasaan konsep per nomor soal</p>
              </div>
              <div className="flex items-center gap-1.5 text-[10px]">
                <span className="flex items-center gap-1 text-emerald-700">🟢 &gt;80%</span>
                <span className="flex items-center gap-1 text-amber-700">🟡 40-80%</span>
                <span className="flex items-center gap-1 text-red-700">🔴 &lt;40%</span>
              </div>
            </div>

            {diff ? (
              <div className="space-y-3 max-h-64 overflow-y-auto pr-1">
                {diff.questions.map((q) => {
                  const avg = q.average_score ?? 0;
                  const maxWeight = q.weight || 10;
                  const ratio = Math.min(100, Math.round((avg / maxWeight) * 100));

                  const isEasy = ratio >= 80;
                  const isMedium = ratio >= 40 && ratio < 80;
                  const isHard = ratio < 40;

                  return (
                    <div
                      key={q.question_number}
                      className="rounded-xl border border-slate-100 bg-slate-50/70 p-3"
                    >
                      <div className="flex items-center justify-between text-xs">
                        <div className="flex items-center gap-2">
                          <span className="font-bold text-slate-800">No. {q.question_number}</span>
                          <span className="rounded bg-slate-200 px-1.5 py-0.5 text-[10px] font-semibold text-slate-600 uppercase">
                            {q.type}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span
                            className={`rounded-full px-2 py-0.5 text-[10px] font-bold ${
                              isEasy
                                ? 'bg-emerald-100 text-emerald-700'
                                : isMedium
                                  ? 'bg-amber-100 text-amber-700'
                                  : 'bg-red-100 text-red-700'
                            }`}
                          >
                            {isEasy ? 'Mudah' : isMedium ? 'Sedang' : 'Perlu Perhatian'}
                          </span>
                          <span className="font-bold text-slate-700">
                            {avg} / {maxWeight} pt ({ratio}%)
                          </span>
                        </div>
                      </div>

                      <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-200">
                        <div
                          className={`h-full rounded-full transition-all ${
                            isEasy
                              ? 'bg-emerald-500'
                              : isMedium
                                ? 'bg-amber-500'
                                : 'bg-red-500'
                          }`}
                          style={{ width: `${ratio}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="py-12 text-center text-sm text-slate-400">Memuat analisis butir soal...</p>
            )}
          </div>
        </section>

        {/* Interactive Gradebook Table */}
        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-base font-bold text-slate-900">
                Buku Nilai & Hasil Siswa ({filteredSubs.length})
              </h2>
              <p className="text-xs text-slate-400">
                Daftar nilai individu beserta akses lembar jawaban scan AI
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <input
                type="text"
                value={studentSearch}
                onChange={(e) => setStudentSearch(e.target.value)}
                placeholder="Cari nama atau no absen..."
                className="rounded-xl border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs placeholder:text-slate-400 focus:bg-white focus:outline-none"
              />

              <div className="flex rounded-xl border border-slate-200 bg-slate-50 p-0.5 text-xs">
                {(['all', 'finalized', 'graded', 'pending'] as const).map((st) => (
                  <button
                    key={st}
                    onClick={() => setStatusFilter(st)}
                    className={`rounded-lg px-2.5 py-1 font-medium capitalize transition ${
                      statusFilter === st
                        ? 'bg-white text-indigo-700 shadow-sm'
                        : 'text-slate-500 hover:text-slate-800'
                    }`}
                  >
                    {st === 'all' ? 'Semua' : st}
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="overflow-x-auto rounded-xl border border-slate-100">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-slate-100 bg-slate-50 text-xs font-semibold text-slate-500">
                <tr>
                  <th className="px-4 py-3">No. Absen</th>
                  <th className="px-4 py-3">Nama Siswa</th>
                  <th className="px-4 py-3">Status Koreksi</th>
                  <th className="px-4 py-3 text-right">Nilai Total</th>
                  <th className="px-4 py-3 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredSubs.map((s) => {
                  const pass = (s.total_score ?? 0) >= (exam?.total_score ?? 100) * 0.7;
                  return (
                    <tr key={s.id} className="hover:bg-slate-50/80 transition">
                      <td className="px-4 py-3 font-mono text-xs font-semibold text-slate-600">
                        {s.student_number ?? '-'}
                      </td>
                      <td className="px-4 py-3 font-medium text-slate-900">
                        {s.student_name ?? `Siswa #${s.student_id}`}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-bold ${
                            s.status === 'finalized'
                              ? 'bg-emerald-100 text-emerald-800'
                              : s.status === 'graded'
                                ? 'bg-amber-100 text-amber-800'
                                : 'bg-slate-100 text-slate-600'
                          }`}
                        >
                          {s.status === 'finalized' ? '✓ Final' : s.status === 'graded' ? '⚡ Terkoreksi' : '⏳ Diproses'}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right">
                        {s.total_score !== null ? (
                          <span
                            className={`font-bold ${
                              pass ? 'text-emerald-700' : 'text-amber-700'
                            }`}
                          >
                            {s.total_score}
                          </span>
                        ) : (
                          <span className="text-slate-400">-</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <Link
                          href={`/dashboard/exams/${id}/students/${s.id}`}
                          className="inline-flex items-center gap-1 rounded-lg border border-indigo-200 bg-indigo-50 px-2.5 py-1 text-xs font-semibold text-indigo-700 hover:bg-indigo-100 transition"
                        >
                          <span>Review Scan AI</span>
                          <span>›</span>
                        </Link>
                      </td>
                    </tr>
                  );
                })}
                {filteredSubs.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-xs text-slate-400">
                      Tidak ada submission siswa yang sesuai kriteria.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
  );
}
