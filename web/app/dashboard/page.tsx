'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';

import type { DashboardOverview, Exam, UserProfile } from '@/lib/types';

export default function DashboardPage() {
  const [exams, setExams] = useState<Exam[] | null>(null);
  const [overview, setOverview] = useState<DashboardOverview | null>(null);
  const [user, setUser] = useState<UserProfile | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Filters & Search
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSubject, setSelectedSubject] = useState<string>('all');
  const [selectedClass, setSelectedClass] = useState<string>('all');

  useEffect(() => {
    async function loadData() {
      setLoading(true);
      try {
        const [meRes, examsRes, overviewRes] = await Promise.all([
          fetch('/api/auth/me').then((r) => (r.ok ? r.json() : null)),
          fetch('/api/exams').then((r) => (r.ok ? r.json() : [])),
          fetch('/api/analytics/overview').then((r) => (r.ok ? r.json() : null)),
        ]);

        if (meRes) setUser(meRes);
        setExams(examsRes);
        setOverview(overviewRes);
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : 'Gagal memuat data');
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  async function logout() {
    await fetch('/api/auth/login', { method: 'DELETE' });
    window.location.href = '/login';
  }

  // Unique subjects and classes for filter dropdowns
  const availableSubjects = useMemo(() => {
    if (!exams) return [];
    const set = new Set<string>();
    exams.forEach((e) => {
      if (e.subject) set.add(e.subject);
      else if (e.class_name && e.class_name.includes(' — ')) {
        set.add(e.class_name.split(' — ')[0]);
      }
    });
    return Array.from(set);
  }, [exams]);

  const availableClasses = useMemo(() => {
    if (!exams) return [];
    const set = new Set<string>();
    exams.forEach((e) => {
      if (e.class_name) set.add(e.class_name);
    });
    return Array.from(set);
  }, [exams]);

  // Filtered exam list
  const filteredExams = useMemo(() => {
    if (!exams) return [];
    return exams.filter((exam) => {
      const matchSearch =
        searchQuery.trim() === '' ||
        exam.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (exam.class_name && exam.class_name.toLowerCase().includes(searchQuery.toLowerCase()));

      const matchSubject =
        selectedSubject === 'all' ||
        exam.subject === selectedSubject ||
        (exam.class_name && exam.class_name.startsWith(selectedSubject));

      const matchClass = selectedClass === 'all' || exam.class_name === selectedClass;

      return matchSearch && matchSubject && matchClass;
    });
  }, [exams, searchQuery, selectedSubject, selectedClass]);

  return (
    <main className="min-h-screen bg-slate-50 text-slate-800">
      {/* Top Navbar */}
      <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/90 backdrop-blur-md">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-3.5">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-indigo-600 font-bold text-white shadow-sm">
              AG
            </div>
            <div>
              <h1 className="text-lg font-bold tracking-tight text-slate-900">AutoGrading</h1>
              <p className="text-xs text-slate-500">Sistem Asesmen & Koreksi Ujian Otomatis</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <Link
              href="/dashboard/classes"
              className="inline-flex items-center gap-1.5 rounded-xl border border-sky-200 bg-sky-50 px-3 py-1.5 text-xs font-semibold text-sky-700 hover:bg-sky-100 transition shadow-sm"
            >
              <span>🏫</span>
              <span>Kelola Kelas</span>
            </Link>
            {user?.role === 'admin' && (
              <Link
                href="/dashboard/users"
                className="inline-flex items-center gap-1.5 rounded-xl border border-indigo-200 bg-indigo-50 px-3 py-1.5 text-xs font-semibold text-indigo-700 hover:bg-indigo-100 transition shadow-sm"
              >
                <span>👥</span>
                <span>Kelola Pengguna</span>
              </Link>
            )}
            {user && (
              <div className="flex items-center gap-2.5 rounded-full bg-slate-100 py-1.5 pl-3 pr-4 text-xs font-medium text-slate-700">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-indigo-100 text-[11px] font-bold text-indigo-700">
                  {user.name.charAt(0).toUpperCase()}
                </span>
                <span>{user.name}</span>
                <span className="rounded-md bg-indigo-600 px-1.5 py-0.5 text-[10px] font-semibold text-white uppercase">
                  {user.role}
                </span>
              </div>
            )}
            <button
              onClick={logout}
              className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-red-50 hover:text-red-600 transition"
            >
              Keluar
            </button>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-7xl space-y-6 px-6 py-6">
        {/* Error Alert */}
        {error && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700 flex items-center gap-2">
            <span>⚠️</span>
            <span>{error}</span>
          </div>
        )}

        {/* Global KPI Summary Row */}
        <section>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-slate-500">
              Ringkasan Asesmen Sekolah
            </h2>
            <span className="text-xs text-slate-400">Data terkini · Pembaruan real-time</span>
          </div>

          <div className="grid grid-cols-2 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {/* Card 1: Total Exams */}
            <div className="rounded-2xl border border-indigo-100 bg-gradient-to-br from-indigo-50/70 to-white p-5 shadow-sm transition hover:shadow-md">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-indigo-700 uppercase">Ujian Terjadwal</span>
                <span className="rounded-lg bg-indigo-100 p-2 text-indigo-600 text-sm">📝</span>
              </div>
              <p className="mt-3 text-3xl font-bold tracking-tight text-indigo-950">
                {overview?.total_exams ?? (loading ? '...' : 0)}
              </p>
              <p className="mt-1 text-xs text-indigo-600/80">Ujian aktif di sistem</p>
            </div>

            {/* Card 2: Total Classes */}
            <div className="rounded-2xl border border-sky-100 bg-gradient-to-br from-sky-50/70 to-white p-5 shadow-sm transition hover:shadow-md">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-sky-700 uppercase">Kelas Diampu</span>
                <span className="rounded-lg bg-sky-100 p-2 text-sky-600 text-sm">🏫</span>
              </div>
              <p className="mt-3 text-3xl font-bold tracking-tight text-sky-950">
                {overview?.total_classes ?? (loading ? '...' : 0)}
              </p>
              <p className="mt-1 text-xs text-sky-600/80">Rombongan belajar terdaftar</p>
            </div>

            {/* Card 3: Total Students */}
            <div className="rounded-2xl border border-purple-100 bg-gradient-to-br from-purple-50/70 to-white p-5 shadow-sm transition hover:shadow-md">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-purple-700 uppercase">Total Peserta</span>
                <span className="rounded-lg bg-purple-100 p-2 text-purple-600 text-sm">👥</span>
              </div>
              <p className="mt-3 text-3xl font-bold tracking-tight text-purple-950">
                {overview?.total_students ?? (loading ? '...' : 0)}
              </p>
              <p className="mt-1 text-xs text-purple-600/80">Siswa aktif di seluruh kelas</p>
            </div>

            {/* Card 4: Pass Rate */}
            <div className="rounded-2xl border border-emerald-100 bg-gradient-to-br from-emerald-50/70 to-white p-5 shadow-sm transition hover:shadow-md">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-emerald-700 uppercase">Rata-rata Ketuntasan</span>
                <span className="rounded-lg bg-emerald-100 p-2 text-emerald-600 text-sm">🎯</span>
              </div>
              <p className="mt-3 text-3xl font-bold tracking-tight text-emerald-950">
                {overview?.overall_pass_rate !== undefined ? `${overview.overall_pass_rate}%` : (loading ? '...' : '100%')}
              </p>
              <p className="mt-1 text-xs text-emerald-600/80">Siswa mencapai nilai KKM (≥70%)</p>
            </div>
          </div>
        </section>

        {/* Filter and Search Bar */}
        <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            {/* Search input */}
            <div className="relative flex-1">
              <span className="absolute inset-y-0 left-3 flex items-center text-slate-400 text-sm">
                🔍
              </span>
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Cari berdasarkan judul ujian atau kelas..."
                className="w-full rounded-xl border border-slate-200 bg-slate-50/50 py-2.5 pl-9 pr-4 text-sm placeholder:text-slate-400 focus:border-indigo-500 focus:bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500/20 transition"
              />
            </div>

            {/* Filters */}
            <div className="flex flex-wrap items-center gap-2">
              {/* Subject Filter */}
              <select
                value={selectedSubject}
                onChange={(e) => setSelectedSubject(e.target.value)}
                className="rounded-xl border border-slate-200 bg-slate-50/50 px-3 py-2.5 text-xs font-medium text-slate-700 focus:border-indigo-500 focus:bg-white focus:outline-none"
              >
                <option value="all">Semua Mata Pelajaran</option>
                {availableSubjects.map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>

              {/* Class Filter */}
              <select
                value={selectedClass}
                onChange={(e) => setSelectedClass(e.target.value)}
                className="rounded-xl border border-slate-200 bg-slate-50/50 px-3 py-2.5 text-xs font-medium text-slate-700 focus:border-indigo-500 focus:bg-white focus:outline-none"
              >
                <option value="all">Semua Kelas</option>
                {availableClasses.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>

              {(searchQuery || selectedSubject !== 'all' || selectedClass !== 'all') && (
                <button
                  onClick={() => {
                    setSearchQuery('');
                    setSelectedSubject('all');
                    setSelectedClass('all');
                  }}
                  className="rounded-xl border border-slate-200 bg-slate-100 px-3 py-2.5 text-xs font-medium text-slate-600 hover:bg-slate-200 transition"
                >
                  Reset
                </button>
              )}
            </div>
          </div>
        </section>

        {/* Assessment Feed / Exam List */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-slate-900">
              Daftar Ujian Aktif ({filteredExams.length})
            </h2>
            <span className="text-xs text-slate-500">
              Menampilkan {filteredExams.length} dari {exams?.length ?? 0} total ujian
            </span>
          </div>

          {loading && (
            <div className="rounded-2xl border border-slate-200 bg-white p-12 text-center text-slate-400">
              <div className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-indigo-600 border-t-transparent mb-2"></div>
              <p className="text-sm">Memuat daftar asesmen & analitik...</p>
            </div>
          )}

          {!loading && filteredExams.length === 0 && (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-12 text-center">
              <span className="text-3xl">📋</span>
              <h3 className="mt-2 text-sm font-semibold text-slate-800">Tidak ada ujian ditemukan</h3>
              <p className="mt-1 text-xs text-slate-500">
                {searchQuery || selectedSubject !== 'all' || selectedClass !== 'all'
                  ? 'Coba ubah kata kunci pencarian atau filter yang dipilih.'
                  : 'Belum ada ujian yang dibuat. Buat ujian baru melalui aplikasi mobile atau endpoint API.'}
              </p>
            </div>
          )}

          <div className="grid gap-4 md:grid-cols-2">
            {filteredExams.map((exam) => {
              const totalStudents = exam.total_students || 1;
              const finalized = exam.finalized_count || 0;
              const progressPct = Math.min(100, Math.round((finalized / totalStudents) * 100));

              const displaySubject =
                exam.subject ||
                (exam.class_name && exam.class_name.includes(' — ')
                  ? exam.class_name.split(' — ')[0]
                  : 'Mata Pelajaran');

              const displayClass =
                exam.class_name && exam.class_name.includes(' — ')
                  ? exam.class_name.split(' — ')[1]
                  : exam.class_name || `Kelas #${exam.class_id}`;

              return (
                <div
                  key={exam.id}
                  className="flex flex-col justify-between rounded-2xl border border-slate-200/90 bg-white p-5 shadow-sm transition hover:border-indigo-300 hover:shadow-md"
                >
                  <div>
                    {/* Badges: Subject, Class, Status */}
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="flex items-center gap-1.5">
                        <span className="rounded-lg bg-indigo-50 px-2.5 py-1 text-[11px] font-bold text-indigo-700 border border-indigo-100">
                          📚 {displaySubject}
                        </span>
                        <span className="rounded-lg bg-sky-50 px-2.5 py-1 text-[11px] font-bold text-sky-700 border border-sky-100">
                          🏫 {displayClass}
                        </span>
                      </div>
                      <span
                        className={`rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider ${
                          progressPct === 100
                            ? 'bg-emerald-100 text-emerald-700'
                            : finalized > 0
                              ? 'bg-amber-100 text-amber-800'
                              : 'bg-slate-100 text-slate-600'
                        }`}
                      >
                        {progressPct === 100 ? 'Selesai' : finalized > 0 ? 'Sedang Dinilai' : 'Baru'}
                      </span>
                    </div>

                    {/* Title */}
                    <h3 className="mt-3 text-base font-bold text-slate-900 leading-snug">
                      {exam.title}
                    </h3>

                    {/* Metadata Chips */}
                    <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-slate-500">
                      <span>🎯 Total Skor: <strong className="text-slate-700">{exam.total_score}</strong> pt</span>
                      <span>•</span>
                      <span>👥 Peserta: <strong className="text-slate-700">{exam.total_students ?? '-'}</strong> Siswa</span>
                    </div>

                    {/* Progress Bar Koreksi */}
                    <div className="mt-4 rounded-xl bg-slate-50 p-3 border border-slate-100">
                      <div className="flex items-center justify-between text-xs font-semibold">
                        <span className="text-slate-600">Progres Koreksi Lembar Jawaban</span>
                        <span className="text-indigo-600">{finalized}/{exam.total_students ?? 0} Siswa ({progressPct}%)</span>
                      </div>
                      <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-slate-200">
                        <div
                          className={`h-full transition-all duration-500 rounded-full ${
                            progressPct === 100
                              ? 'bg-emerald-500'
                              : progressPct > 50
                                ? 'bg-indigo-600'
                                : 'bg-amber-500'
                          }`}
                          style={{ width: `${progressPct}%` }}
                        />
                      </div>
                    </div>

                    {/* Average Score (if available) */}
                    {exam.average_score !== null && exam.average_score !== undefined && (
                      <div className="mt-3 flex items-center gap-2 text-xs">
                        <span className="text-slate-500">Rata-rata Nilai Terkoreksi:</span>
                        <span className="rounded-md bg-emerald-50 px-2 py-0.5 font-bold text-emerald-700 border border-emerald-200">
                          {exam.average_score} / {exam.total_score}
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Actions Bar */}
                  <div className="mt-5 flex flex-wrap items-center justify-between gap-2 border-t border-slate-100 pt-4">
                    <a
                      href={`/api/exams/${exam.id}/template.pdf`}
                      download
                      className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-50 hover:text-indigo-600 transition"
                      title="Download PDF Lembar Jawaban A4"
                    >
                      <span>📄</span>
                      <span>Download PDF</span>
                    </a>

                    <div className="flex items-center gap-2">
                      <a
                        href={`/api/exams/${exam.id}/export.csv`}
                        download
                        className="inline-flex items-center gap-1.5 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-medium text-emerald-700 hover:bg-emerald-100 transition"
                        title="Download Rekap Nilai CSV"
                      >
                        <span>📥</span>
                        <span>CSV</span>
                      </a>
                      <Link
                        href={`/dashboard/exams/${exam.id}`}
                        className="inline-flex items-center gap-1 rounded-lg bg-indigo-600 px-3.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-indigo-700 transition"
                      >
                        <span>Analitik & Hasil</span>
                        <span>›</span>
                      </Link>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      </div>
    </main>
  );
}
