'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';

import type { Class, UserProfile } from '@/lib/types';

export default function ClassesPage() {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);
  const [classes, setClasses] = useState<Class[] | null>(null);
  const [teachers, setTeachers] = useState<UserProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filters & Search
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedSubject, setSelectedSubject] = useState<string>('all');
  const [selectedGrade, setSelectedGrade] = useState<string>('all');

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingClass, setEditingClass] = useState<Class | null>(null);

  // Form State
  const [formName, setFormName] = useState('');
  const [formGrade, setFormGrade] = useState('8');
  const [formSubject, setFormSubject] = useState('Matematika');
  const [formTeacherId, setFormTeacherId] = useState<number | undefined>();
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    setLoading(true);
    setError(null);
    try {
      const [meRes, classesRes, usersRes] = await Promise.all([
        fetch('/api/auth/me').then((r) => (r.ok ? r.json() : null)),
        fetch('/api/classes').then(async (r) => {
          if (!r.ok) {
            const err = await r.json().catch(() => null);
            throw new Error(err?.detail ?? 'Gagal memuat daftar kelas');
          }
          return r.json();
        }),
        fetch('/api/users').then((r) => (r.ok ? r.json() : [])),
      ]);

      if (meRes) {
        setCurrentUser(meRes);
        setFormTeacherId(meRes.id);
      }
      setClasses(classesRes);
      setTeachers(usersRes.filter((u: UserProfile) => u.role === 'teacher' || u.role === 'admin'));
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Terjadi kesalahan');
    } finally {
      setLoading(false);
    }
  }

  function openCreateModal() {
    setEditingClass(null);
    setFormName('');
    setFormSubject('Matematika');
    setFormTeacherId(teachers[0]?.id ?? currentUser?.id);
    setFormError(null);
    setIsModalOpen(true);
  }

  function openEditModal(c: Class) {
    setEditingClass(c);
    setFormName(c.name);
    setFormSubject(c.subject);
    setFormTeacherId(c.teacher_id);
    setFormError(null);
    setIsModalOpen(true);
  }

  async function handleSaveClass(e: React.FormEvent) {
    e.preventDefault();
    setFormSubmitting(true);
    setFormError(null);

    const payload: {
      name: string;
      subject: string;
      teacher_id?: number;
    } = {
      name: formName.trim(),
      subject: formSubject.trim(),
      teacher_id: formTeacherId,
    };

    try {
      const url = editingClass ? `/api/classes/${editingClass.id}` : '/api/classes';
      const method = editingClass ? 'PUT' : 'POST';

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => null);
        throw new Error(err?.detail ?? 'Gagal menyimpan kelas');
      }

      setIsModalOpen(false);
      await loadData();
    } catch (err: unknown) {
      setFormError(err instanceof Error ? err.message : 'Gagal menyimpan kelas');
    } finally {
      setFormSubmitting(false);
    }
  }

  async function handleDeleteClass(classId: number, className: string) {
    if (!confirm(`Apakah Anda yakin ingin menghapus kelas "${className}"? Seluruh data siswa dan ujian di kelas ini akan dihapus.`)) {
      return;
    }

    try {
      const res = await fetch(`/api/classes/${classId}`, { method: 'DELETE' });
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        throw new Error(err?.detail ?? 'Gagal menghapus kelas');
      }
      await loadData();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Gagal menghapus kelas');
    }
  }

  // Filter options
  const availableSubjects = useMemo(() => {
    if (!classes) return [];
    const set = new Set<string>();
    classes.forEach((c) => {
      if (c.subject) set.add(c.subject);
    });
    return Array.from(set);
  }, [classes]);

  const availableGrades = useMemo(() => {
    if (!classes) return [];
    const set = new Set<string>();
    classes.forEach((c) => {
      if (c.grade_level) set.add(c.grade_level);
    });
    return Array.from(set);
  }, [classes]);

  // Filtered classes
  const filteredClasses = useMemo(() => {
    if (!classes) return [];
    return classes.filter((c) => {
      const matchSearch =
        searchQuery.trim() === '' ||
        c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.subject.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (c.teacher_name && c.teacher_name.toLowerCase().includes(searchQuery.toLowerCase()));

      const matchSubject = selectedSubject === 'all' || c.subject === selectedSubject;
      const matchGrade = selectedGrade === 'all' || c.grade_level === selectedGrade;

      return matchSearch && matchSubject && matchGrade;
    });
  }, [classes, searchQuery, selectedSubject, selectedGrade]);

  // Summary Metrics
  const metrics = useMemo(() => {
    if (!classes) return { totalClasses: 0, totalStudents: 0, totalTeachers: 0, totalSubjects: 0 };
    const totalClasses = classes.length;
    const totalStudents = classes.reduce((acc, c) => acc + (c.students_count ?? 0), 0);
    const teacherSet = new Set(classes.map((c) => c.teacher_id));
    const subjectSet = new Set(classes.map((c) => c.subject));
    return {
      totalClasses,
      totalStudents,
      totalTeachers: teacherSet.size,
      totalSubjects: subjectSet.size,
    };
  }, [classes]);

  return (
    <main className="min-h-screen bg-slate-50 text-slate-800 pb-12">
      {/* Top Navbar */}
      <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/90 backdrop-blur-md">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-3.5">
          <div className="flex items-center gap-3">
            <Link
              href="/dashboard"
              className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-100 transition"
            >
              <span>←</span>
              <span>Kembali ke Dashboard</span>
            </Link>
            <div>
              <h1 className="text-base font-bold tracking-tight text-slate-900">
                Manajemen Rombel & Kelas
              </h1>
              <p className="text-xs text-slate-500">Kelola rombongan belajar, kurikulum, dan penugasan guru</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {currentUser && (
              <div className="flex items-center gap-2 rounded-full bg-slate-100 py-1 pl-3 pr-3.5 text-xs font-medium text-slate-700">
                <span className="flex h-5 w-5 items-center justify-center rounded-full bg-indigo-100 text-[10px] font-bold text-indigo-700">
                  {currentUser.name.charAt(0).toUpperCase()}
                </span>
                <span>{currentUser.name}</span>
                <span className="rounded-md bg-indigo-600 px-1.5 py-0.5 text-[10px] font-semibold text-white uppercase">
                  {currentUser.role}
                </span>
              </div>
            )}
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

        {/* 4 KPI Summary Cards */}
        <section className="grid grid-cols-2 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl border border-[#CCFBF1] bg-gradient-to-br from-[#E6F4F1]/80 to-white p-5 shadow-sm">
            <span className="text-xs font-bold text-[#0F766E] uppercase">Total Rombel / Kelas</span>
            <p className="mt-2 text-3xl font-extrabold tracking-tight text-[#0F172A]">
              {metrics.totalClasses} <span className="text-sm font-normal text-slate-400">Kelas</span>
            </p>
            <p className="mt-1 text-xs text-[#0F766E]/80 font-medium">Terdaftar di sistem</p>
          </div>

          <div className="rounded-2xl border border-teal-100 bg-gradient-to-br from-teal-50/50 to-white p-5 shadow-sm">
            <span className="text-xs font-bold text-teal-800 uppercase">Total Siswa Terdata</span>
            <p className="mt-2 text-3xl font-extrabold tracking-tight text-[#0F172A]">
              {metrics.totalStudents} <span className="text-sm font-normal text-slate-400">Siswa</span>
            </p>
            <p className="mt-1 text-xs text-teal-700/80 font-medium">Tersebar di seluruh rombel</p>
          </div>

          <div className="rounded-2xl border border-emerald-100 bg-gradient-to-br from-emerald-50/60 to-white p-5 shadow-sm">
            <span className="text-xs font-bold text-emerald-800 uppercase">Guru Pengampu</span>
            <p className="mt-2 text-3xl font-extrabold tracking-tight text-[#0F172A]">
              {metrics.totalTeachers} <span className="text-sm font-normal text-slate-400">Guru</span>
            </p>
            <p className="mt-1 text-xs text-emerald-700/80 font-medium">Memiliki penugasan aktif</p>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <span className="text-xs font-bold text-slate-500 uppercase">Mata Pelajaran</span>
            <p className="mt-2 text-3xl font-extrabold tracking-tight text-[#0F172A]">
              {metrics.totalSubjects} <span className="text-sm font-normal text-slate-400">Mapel</span>
            </p>
            <p className="mt-1 text-xs text-slate-400 font-medium">Kurikulum terdaftar</p>
          </div>
        </section>

        {/* Action Bar & Search */}
        <section className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm">
          <div className="flex flex-1 flex-wrap items-center gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Cari nama kelas, mapel, atau guru..."
              className="w-full max-w-sm rounded-xl border border-slate-200 bg-slate-50/60 px-3.5 py-2 text-sm placeholder:text-slate-400 focus:border-[#0F766E] focus:bg-white focus:outline-none"
            />
            <select
              value={selectedSubject}
              onChange={(e) => setSelectedSubject(e.target.value)}
              className="rounded-xl border border-slate-200 bg-slate-50/60 px-3 py-2 text-xs font-semibold text-slate-700 focus:border-[#0F766E] focus:bg-white focus:outline-none"
            >
              <option value="all">Semua Mata Pelajaran</option>
              {availableSubjects.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>

            <select
              value={selectedGrade}
              onChange={(e) => setSelectedGrade(e.target.value)}
              className="rounded-xl border border-slate-200 bg-slate-50/60 px-3 py-2 text-xs font-semibold text-slate-700 focus:border-[#0F766E] focus:bg-white focus:outline-none"
            >
              <option value="all">Semua Tingkat</option>
              {availableGrades.map((g) => (
                <option key={g} value={g}>
                  Tingkat {g}
                </option>
              ))}
            </select>
          </div>

          <button
            onClick={openCreateModal}
            className="inline-flex items-center justify-center gap-1.5 rounded-xl bg-[#0F766E] hover:bg-[#115E59] px-4 py-2.5 text-xs font-bold text-white shadow-md shadow-teal-900/10 active:scale-[0.99] transition"
          >
            <span>+</span>
            <span>Tambah Kelas Baru</span>
          </button>
        </section>

        {/* Classes Grid */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-extrabold text-[#0F172A]">
              Daftar Rombongan Belajar ({filteredClasses.length})
            </h2>
            <span className="text-xs text-slate-500 font-medium">
              Menampilkan {filteredClasses.length} dari {classes?.length ?? 0} kelas
            </span>
          </div>

          {loading && (
            <div className="rounded-2xl border border-slate-200 bg-white p-12 text-center text-slate-400">
              <div className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-indigo-600 border-t-transparent mb-2"></div>
              <p className="text-sm">Memuat data kelas & rombel...</p>
            </div>
          )}

          {!loading && filteredClasses.length === 0 && (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-12 text-center">
              <span className="text-3xl">🏫</span>
              <h3 className="mt-2 text-sm font-semibold text-slate-800">Tidak ada kelas ditemukan</h3>
              <p className="mt-1 text-xs text-slate-500">
                {searchQuery || selectedSubject !== 'all' || selectedGrade !== 'all'
                  ? 'Coba ubah kata kunci pencarian atau filter yang dipilih.'
                  : 'Belum ada kelas terdaftar. Klik "+ Tambah Kelas Baru" untuk memulai.'}
              </p>
            </div>
          )}

          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {filteredClasses.map((c) => {
              const displayTitle = c.name.startsWith(c.subject) ? c.name : `${c.subject} — ${c.name}`;

              return (
                <div
                  key={c.id}
                  className="flex flex-col justify-between rounded-2xl border border-slate-200/90 bg-white p-5 shadow-sm transition hover:border-indigo-300 hover:shadow-md"
                >
                  <div>
                    {/* Header Badges */}
                    <div className="flex flex-wrap items-center justify-between gap-1.5">
                      <div className="flex items-center gap-1.5">
                        <span className="rounded-lg bg-indigo-50 px-2.5 py-1 text-[11px] font-bold text-indigo-700 border border-indigo-100">
                          📚 {c.subject}
                        </span>
                        <span className="rounded-lg bg-sky-50 px-2.5 py-1 text-[11px] font-bold text-sky-700 border border-sky-100">
                          Tingkat {c.grade_level}
                        </span>
                      </div>
                      <span className="text-xs text-slate-400 font-mono">ID #{c.id}</span>
                    </div>

                    {/* Class Name */}
                    <h3 className="mt-3 text-base font-bold text-slate-900 leading-snug">
                      {displayTitle}
                    </h3>

                    {/* Teacher info */}
                    <div className="mt-2 flex items-center gap-2 text-xs text-slate-500">
                      <span>👨‍🏫 Pengampu:</span>
                      <strong className="text-slate-800">{c.teacher_name ?? `Guru #${c.teacher_id}`}</strong>
                    </div>

                    {/* Meta stats chips */}
                    <div className="mt-4 flex items-center gap-2">
                      <div className="flex-1 rounded-xl bg-slate-50 p-2.5 text-center border border-slate-100">
                        <span className="block text-xs text-slate-400">Total Siswa</span>
                        <strong className="text-sm font-bold text-slate-800">{c.students_count ?? 0} Siswa</strong>
                      </div>
                      <div className="flex-1 rounded-xl bg-slate-50 p-2.5 text-center border border-slate-100">
                        <span className="block text-xs text-slate-400">Total Ujian</span>
                        <strong className="text-sm font-bold text-slate-800">{c.exams_count ?? 0} Ujian</strong>
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="mt-5 flex items-center justify-between border-t border-slate-100 pt-4 gap-2">
                    <Link
                      href={`/dashboard/classes/${c.id}`}
                      className="inline-flex items-center gap-1 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-indigo-700 transition"
                    >
                      <span>👥 Roster Siswa</span>
                      <span>›</span>
                    </Link>

                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() => openEditModal(c)}
                        className="rounded-lg border border-slate-200 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 hover:bg-slate-50 transition"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDeleteClass(c.id, displayTitle)}
                        className="rounded-lg border border-red-200 bg-red-50 px-2.5 py-1 text-xs font-medium text-red-600 hover:bg-red-100 transition"
                      >
                        Hapus
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      </div>

      {/* Modal Tambah / Edit Kelas */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-bold text-slate-900">
                {editingClass ? 'Edit Rombel & Kelas' : 'Tambah Rombel Kelas Baru'}
              </h3>
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 text-lg leading-none"
              >
                ✕
              </button>
            </div>

            {formError && (
              <div className="mb-4 rounded-xl border border-red-200 bg-red-50 p-3 text-xs text-red-700">
                {formError}
              </div>
            )}

            <form onSubmit={handleSaveClass} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Nama Rombel / Kelas
                </label>
                <input
                  type="text"
                  required
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="mis. 8A, 8B, 10C, 12B"
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Mata Pelajaran
                </label>
                <input
                  type="text"
                  required
                  value={formSubject}
                  onChange={(e) => setFormSubject(e.target.value)}
                  placeholder="mis. Fisika, Matematika, Bahasa Indonesia"
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Guru Pengampu (Penugasan)
                </label>
                <select
                  value={formTeacherId}
                  onChange={(e) => setFormTeacherId(Number(e.target.value))}
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                >
                  {teachers.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.name} ({t.email})
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50 transition"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={formSubmitting}
                  className="rounded-xl bg-indigo-600 px-4 py-2 text-xs font-bold text-white shadow-sm hover:bg-indigo-700 transition disabled:opacity-50"
                >
                  {formSubmitting ? 'Menyimpan...' : 'Simpan Kelas'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </main>
  );
}
