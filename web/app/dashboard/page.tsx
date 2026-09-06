'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';

import type { DashboardOverview, Exam, UserProfile } from '@/lib/types';

export default function DashboardPage() {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [overview, setOverview] = useState<DashboardOverview | null>(null);
  const [exams, setExams] = useState<Exam[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search and Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSubject, setSelectedSubject] = useState<string>('all');
  const [selectedClass, setSelectedClass] = useState<string>('all');

  async function logout() {
    try {
      await fetch('/api/auth/login', { method: 'DELETE' });
    } finally {
      window.location.href = '/login';
    }
  }

  useEffect(() => {
    async function loadData() {
      setLoading(true);
      setError(null);
      try {
        const [meRes, overviewRes, examsRes] = await Promise.all([
          fetch('/api/auth/me').then((r) => (r.ok ? r.json() : null)),
          fetch('/api/analytics/overview'),
          fetch('/api/exams'),
        ]);

        if (meRes) setUser(meRes);

        if (!overviewRes.ok) {
          throw new Error('Gagal memuat ringkasan analitik sekolah');
        }
        if (!examsRes.ok) {
          throw new Error('Gagal memuat daftar ujian');
        }

        const [overviewData, examsData] = await Promise.all([
          overviewRes.json(),
          examsRes.json(),
        ]);

        setOverview(overviewData);
        setExams(examsData);
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : 'Terjadi kesalahan');
      } finally {
        setLoading(false);
      }
    }

    loadData();
  }, []);

  // Unique subjects for filter
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

  // Unique classes for filter
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
    <main className="min-h-screen bg-[#F8FAFC] text-[#0F172A]">
      {/* Top Navbar */}
      <header className="sticky top-0 z-30 border-b border-slate-200/80 bg-white/95 backdrop-blur-md">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-3.5">
          <div className="flex items-center gap-3">
            <div className="relative flex h-10 w-auto items-center justify-center">
              <Image
                src="/vidyanetra_logo.png"
                alt="Vidyanetra Logo"
                width={48}
                height={38}
                className="h-10 w-auto object-contain drop-shadow-sm"
                priority
              />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-lg font-extrabold tracking-tight text-[#0F172A]">
                  Vidyanetra
                </h1>
                <span className="rounded-full bg-[#E6F4F1] border border-[#CCFBF1] px-2 py-0.5 text-[10px] font-bold text-[#0F766E] uppercase tracking-wider">
                  Academic Vision
                </span>
              </div>
              <p className="text-[11px] text-slate-500 font-medium">
                Portal Manajemen Asesmen & Evaluasi Semantik AI
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <Link
              href="/dashboard/classes"
              className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3.5 py-1.5 text-xs font-bold text-slate-700 hover:border-[#0F766E] hover:text-[#0F766E] hover:bg-[#E6F4F1]/40 transition shadow-sm"
            >
              <span>🏫</span>
              <span>Kelola Kelas</span>
            </Link>
            {user?.role === 'admin' && (
              <Link
                href="/dashboard/users"
                className="inline-flex items-center gap-1.5 rounded-xl border border-[#CCFBF1] bg-[#E6F4F1] px-3.5 py-1.5 text-xs font-bold text-[#0F766E] hover:bg-[#CCFBF1] transition shadow-sm"
              >
                <span>👥</span>
                <span>Kelola Pengguna</span>
              </Link>
            )}
            {user && (
              <div className="flex items-center gap-2 rounded-full bg-slate-100 py-1 pl-2.5 pr-3 text-xs font-semibold text-slate-700">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-[#0F766E] text-[11px] font-bold text-white">
                  {user.name.charAt(0).toUpperCase()}
                </span>
                <span className="hidden sm:inline">{user.name}</span>
                <span className="rounded-md bg-[#0F766E] px-1.5 py-0.2 text-[9px] font-bold text-white uppercase">
                  {user.role}
                </span>
              </div>
            )}
            <button
              onClick={logout}
              className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-rose-50 hover:text-rose-600 hover:border-rose-200 transition"
            >
              Keluar
            </button>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-7xl space-y-6 px-6 py-6">
        {/* Error Alert */}
        {error && (
          <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-xs font-medium text-rose-700 flex items-center gap-2">
            <span>⚠️</span>
            <span>{error}</span>
          </div>
        )}

        {/* Global KPI Summary Row */}
        <section>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Ringkasan Asesmen Sekolah
            </h2>
            <span className="flex items-center gap-1.5 text-[11px] text-slate-400 font-medium">
              <span className="h-2 w-2 rounded-full bg-[#10B981] animate-pulse"></span>
              Pembaruan Real-Time
            </span>
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            {/* Card 1: Total Exams */}
            <div className="rounded-2xl border border-[#CCFBF1] bg-gradient-to-br from-[#E6F4F1]/80 to-white p-5 shadow-sm transition hover:shadow-md">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-[#0F766E] uppercase">Ujian Terjadwal</span>
                <span className="rounded-xl bg-white p-2 text-[#0F766E] shadow-sm text-sm">📝</span>
              </div>
              <p className="mt-3 text-3xl font-extrabold tracking-tight text-[#0F172A]">
                {overview?.total_exams ?? (loading ? '...' : 0)}
              </p>
              <p className="mt-1 text-xs text-[#0F766E]/80 font-medium">Ujian aktif terdaftar di sistem</p>
            </div>

            {/* Card 2: Total Classes */}
            <div className="rounded-2xl border border-teal-100 bg-gradient-to-br from-teal-50/50 to-white p-5 shadow-sm transition hover:shadow-md">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-teal-800 uppercase">Total Rombel</span>
                <span className="rounded-xl bg-white p-2 text-teal-700 shadow-sm text-sm">🏫</span>
              </div>
              <p className="mt-3 text-3xl font-extrabold tracking-tight text-[#0F172A]">
                {overview?.total_classes ?? (loading ? '...' : 0)}
              </p>
              <p className="mt-1 text-xs text-teal-700/80 font-medium">Rombongan belajar terdaftar</p>
            </div>

            {/* Card 3: Pass Rate */}
            <div className="rounded-2xl border border-emerald-100 bg-gradient-to-br from-emerald-50/60 to-white p-5 shadow-sm transition hover:shadow-md">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-emerald-800 uppercase">Rata-rata Ketuntasan</span>
                <span className="rounded-xl bg-white p-2 text-emerald-700 shadow-sm text-sm">🎯</span>
              </div>
              <p className="mt-3 text-3xl font-extrabold tracking-tight text-emerald-950">
                {overview?.overall_pass_rate !== undefined ? `${overview.overall_pass_rate}%` : (loading ? '...' : '100%')}
              </p>
              <p className="mt-1 text-xs text-emerald-700/80 font-medium">Siswa mencapai KKM (≥70%)</p>
            </div>
          </div>
        </section>

        {/* Filter and Search Bar */}
        <section className="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            {/* Search input */}
            <div className="relative flex-1">
              <span className="absolute inset-y-0 left-3.5 flex items-center text-slate-400 text-sm">
                🔍
              </span>
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Cari berdasarkan judul ujian atau rombel..."
                className="w-full rounded-xl border border-slate-200 bg-slate-50/60 py-2.5 pl-10 pr-4 text-sm placeholder:text-slate-400 focus:border-[#0F766E] focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#0F766E]/15 transition"
              />
            </div>

            {/* Filters */}
            <div className="flex flex-wrap items-center gap-2">
              {/* Subject Filter */}
              <select
                value={selectedSubject}
                onChange={(e) => setSelectedSubject(e.target.value)}
                className="rounded-xl border border-slate-200 bg-slate-50/60 px-3 py-2.5 text-xs font-semibold text-slate-700 focus:border-[#0F766E] focus:bg-white focus:outline-none"
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
                className="rounded-xl border border-slate-200 bg-slate-50/60 px-3 py-2.5 text-xs font-semibold text-slate-700 focus:border-[#0F766E] focus:bg-white focus:outline-none"
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
                  className="rounded-xl border border-slate-200 bg-slate-100 px-3 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-200 transition"
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
            <h2 className="text-base font-extrabold text-[#0F172A]">
              Daftar Ujian Aktif ({filteredExams.length})
            </h2>
            <span className="text-xs text-slate-500 font-medium">
              Menampilkan {filteredExams.length} dari {exams?.length ?? 0} total ujian
            </span>
          </div>

          {loading && (
            <div className="rounded-2xl border border-slate-200 bg-white p-12 text-center text-slate-400">
              <div className="inline-block h-7 w-7 animate-spin rounded-full border-2 border-[#0F766E] border-t-transparent mb-2"></div>
              <p className="text-xs font-medium">Memuat data analitik & asesmen Vidyanetra...</p>
            </div>
          )}

          {!loading && filteredExams.length === 0 && (
            <div className="rounded-3xl border border-dashed border-slate-300 bg-white p-12 text-center">
              <span className="text-3xl">📋</span>
              <h3 className="mt-2 text-sm font-bold text-slate-800">Tidak ada ujian ditemukan</h3>
              <p className="mt-1 text-xs text-slate-500">
                {searchQuery || selectedSubject !== 'all' || selectedClass !== 'all'
                  ? 'Coba ubah kata kunci pencarian atau filter yang dipilih.'
                  : 'Belum ada ujian yang dibuat oleh Guru pengampu di aplikasi mobile.'}
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
                  className="flex flex-col justify-between rounded-3xl border border-slate-200/90 bg-white p-6 shadow-sm transition hover:border-[#0F766E]/40 hover:shadow-md"
                >
                  <div>
                    {/* Badges: Subject, Class, Status */}
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="flex items-center gap-1.5">
                        <span className="rounded-lg bg-[#E6F4F1] px-2.5 py-1 text-[11px] font-bold text-[#0F766E] border border-[#CCFBF1]">
                          📚 {displaySubject}
                        </span>
                        <span className="rounded-lg bg-teal-50 px-2.5 py-1 text-[11px] font-bold text-teal-800 border border-teal-100">
                          🏫 {displayClass}
                        </span>
                      </div>
                      <span
                        className={`rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-wider ${
                          progressPct === 100
                            ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                            : finalized > 0
                              ? 'bg-amber-100 text-amber-800 border border-amber-200'
                              : 'bg-slate-100 text-slate-600 border border-slate-200'
                        }`}
                      >
                        {progressPct === 100 ? '✓ Selesai' : finalized > 0 ? '⏳ Sedang Dinilai' : 'Baru'}
                      </span>
                    </div>

                    {/* Title */}
                    <h3 className="mt-3 text-base font-extrabold text-[#0F172A] leading-snug">
                      {exam.title}
                    </h3>

                    {/* Metadata Chips */}
                    <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-slate-500 font-medium">
                      <span>🎯 Total Skor: <strong className="text-slate-800">{exam.total_score}</strong> pt</span>
                      <span>•</span>
                      <span>👥 Roster: <strong className="text-slate-800">{exam.total_students ?? '-'}</strong> Siswa</span>
                    </div>

                    {/* Progress Bar Koreksi */}
                    <div className="mt-4 rounded-2xl bg-[#F8FAFC] p-3.5 border border-slate-100">
                      <div className="flex items-center justify-between text-xs font-bold">
                        <span className="text-slate-600">Progres Evaluasi Lembar Jawaban</span>
                        <span className="text-[#0F766E]">{finalized}/{exam.total_students ?? 0} Siswa ({progressPct}%)</span>
                      </div>
                      <div className="mt-2 h-2.5 w-full overflow-hidden rounded-full bg-slate-200">
                        <div
                          className={`h-full transition-all duration-500 rounded-full ${
                            progressPct === 100
                              ? 'bg-[#10B981]'
                              : progressPct > 50
                                ? 'bg-[#0F766E]'
                                : 'bg-amber-500'
                          }`}
                          style={{ width: `${progressPct}%` }}
                        />
                      </div>
                    </div>

                    {/* Average Score (if available) */}
                    {exam.average_score !== null && exam.average_score !== undefined && (
                      <div className="mt-3 flex items-center gap-2 text-xs">
                        <span className="text-slate-500 font-medium">Rata-rata Skor Terkoreksi:</span>
                        <span className="rounded-lg bg-emerald-50 px-2.5 py-0.5 font-bold text-emerald-800 border border-emerald-200">
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
                      className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 hover:border-[#0F766E] hover:text-[#0F766E] transition shadow-sm"
                      title="Download PDF Lembar Jawaban A4"
                    >
                      <span>📄</span>
                      <span>PDF LJK A4</span>
                    </a>

                    <div className="flex items-center gap-2">
                      <a
                        href={`/api/exams/${exam.id}/export.csv`}
                        download
                        className="inline-flex items-center gap-1.5 rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-bold text-emerald-800 hover:bg-emerald-100 transition shadow-sm"
                        title="Download Rekap Nilai CSV"
                      >
                        <span>📥</span>
                        <span>CSV</span>
                      </a>
                      <Link
                        href={`/dashboard/exams/${exam.id}`}
                        className="inline-flex items-center gap-1 rounded-xl bg-[#0F766E] hover:bg-[#115E59] px-3.5 py-1.5 text-xs font-bold text-white shadow-sm transition"
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
