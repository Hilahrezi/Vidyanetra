'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';

import type { Class, Student } from '@/lib/types';

export default function ClassDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [classInfo, setClassInfo] = useState<Class | null>(null);
  const [students, setStudents] = useState<Student[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search
  const [searchQuery, setSearchQuery] = useState('');

  // Single Student Modal
  const [isSingleModalOpen, setIsSingleModalOpen] = useState(false);
  const [editingStudent, setEditingStudent] = useState<Student | null>(null);
  const [formNumber, setFormNumber] = useState('');
  const [formName, setFormName] = useState('');
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Bulk Modal
  const [isBulkModalOpen, setIsBulkModalOpen] = useState(false);
  const [bulkText, setBulkText] = useState('');
  const [bulkSubmitting, setBulkSubmitting] = useState(false);
  const [bulkError, setBulkError] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, [id]);

  async function loadData() {
    setLoading(true);
    setError(null);
    try {
      const [classRes, studentsRes] = await Promise.all([
        fetch(`/api/classes/${id}`).then(async (r) => {
          if (!r.ok) throw new Error('Gagal memuat info kelas');
          return r.json();
        }),
        fetch(`/api/classes/${id}/students`).then(async (r) => {
          if (!r.ok) throw new Error('Gagal memuat daftar siswa');
          return r.json();
        }),
      ]);

      setClassInfo(classRes);
      setStudents(studentsRes);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Terjadi kesalahan');
    } finally {
      setLoading(false);
    }
  }

  function openCreateStudentModal() {
    setEditingStudent(null);
    // Auto-predict next student number
    const nextNum = students ? (students.length + 1).toString().padStart(2, '0') : '01';
    setFormNumber(nextNum);
    setFormName('');
    setFormError(null);
    setIsSingleModalOpen(true);
  }

  function openEditStudentModal(s: Student) {
    setEditingStudent(s);
    setFormNumber(s.student_number);
    setFormName(s.name);
    setFormError(null);
    setIsSingleModalOpen(true);
  }

  async function handleSaveStudent(e: React.FormEvent) {
    e.preventDefault();
    setFormSubmitting(true);
    setFormError(null);

    const payload = {
      name: formName.trim(),
      student_number: formNumber.trim(),
    };

    try {
      const url = editingStudent
        ? `/api/students/${editingStudent.id}`
        : `/api/classes/${id}/students`;
      const method = editingStudent ? 'PUT' : 'POST';

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => null);
        throw new Error(err?.detail ?? 'Gagal menyimpan siswa');
      }

      setIsSingleModalOpen(false);
      await loadData();
    } catch (err: unknown) {
      setFormError(err instanceof Error ? err.message : 'Gagal menyimpan siswa');
    } finally {
      setFormSubmitting(false);
    }
  }

  async function handleBulkAddStudents(e: React.FormEvent) {
    e.preventDefault();
    setBulkSubmitting(true);
    setBulkError(null);

    const lines = bulkText.trim().split('\n');
    const payload: { student_number: string; name: string }[] = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;

      let num = '';
      let name = '';

      if (line.includes(',')) {
        const parts = line.split(',');
        num = parts[0].trim();
        name = parts.slice(1).join(',').trim();
      } else if (line.includes('\t')) {
        const parts = line.split('\t');
        num = parts[0].trim();
        name = parts.slice(1).join('\t').trim();
      } else {
        num = (payload.length + 1).toString().padStart(2, '0');
        name = line;
      }

      if (name) {
        payload.push({ student_number: num, name });
      }
    }

    if (payload.length === 0) {
      setBulkError('Tidak ada data siswa valid yang ditemukan.');
      setBulkSubmitting(false);
      return;
    }

    try {
      const res = await fetch(`/api/classes/${id}/students/bulk`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => null);
        throw new Error(err?.detail ?? 'Gagal mengimpor daftar siswa');
      }

      setIsBulkModalOpen(false);
      setBulkText('');
      await loadData();
    } catch (err: unknown) {
      setBulkError(err instanceof Error ? err.message : 'Gagal mengimpor siswa');
    } finally {
      setBulkSubmitting(false);
    }
  }

  async function handleDeleteStudent(studentId: number, studentName: string) {
    if (!confirm(`Hapus siswa "${studentName}" dari rombel ini?`)) {
      return;
    }

    try {
      const res = await fetch(`/api/students/${studentId}`, { method: 'DELETE' });
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        throw new Error(err?.detail ?? 'Gagal menghapus siswa');
      }
      await loadData();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Gagal menghapus siswa');
    }
  }

  // Filtered students
  const filteredStudents = useMemo(() => {
    if (!students) return [];
    return students.filter((s) => {
      return (
        searchQuery.trim() === '' ||
        s.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        s.student_number.includes(searchQuery)
      );
    });
  }, [students, searchQuery]);

  const displayTitle = classInfo
    ? classInfo.name.startsWith(classInfo.subject)
      ? classInfo.name
      : `${classInfo.subject} — ${classInfo.name}`
    : `Kelas #${id}`;

  return (
    <main className="min-h-screen bg-slate-50 text-slate-800 pb-12">
      {/* Top Navbar */}
      <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/90 backdrop-blur-md">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-3.5">
          <div className="flex items-center gap-3">
            <Link
              href="/dashboard/classes"
              className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-100 transition"
            >
              <span>←</span>
              <span>Daftar Rombel</span>
            </Link>
            <div>
              <div className="flex items-center gap-2">
                <span className="rounded-md bg-indigo-50 px-2 py-0.5 text-[11px] font-bold text-indigo-700 border border-indigo-100">
                  📚 {classInfo?.subject ?? 'Mapel'}
                </span>
                <span className="rounded-md bg-sky-50 px-2 py-0.5 text-[11px] font-bold text-sky-700 border border-sky-100">
                  Tingkat {classInfo?.grade_level ?? '-'}
                </span>
              </div>
              <h1 className="text-base font-bold tracking-tight text-slate-900 mt-0.5">
                {displayTitle}
              </h1>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setIsBulkModalOpen(true)}
              className="inline-flex items-center gap-1.5 rounded-xl border border-indigo-200 bg-indigo-50 px-3.5 py-2 text-xs font-semibold text-indigo-700 hover:bg-indigo-100 transition shadow-sm"
            >
              <span>⚡</span>
              <span>Input Cepat / Bulk</span>
            </button>
            <button
              onClick={openCreateStudentModal}
              className="inline-flex items-center gap-1.5 rounded-xl bg-indigo-600 px-3.5 py-2 text-xs font-bold text-white hover:bg-indigo-700 transition shadow-sm"
            >
              <span>+</span>
              <span>Tambah Siswa</span>
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

        {/* 3 Summary Stat Cards */}
        <section className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <span className="text-xs font-semibold text-slate-500 uppercase">Total Siswa Terdaftar</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-slate-900">
              {students?.length ?? 0} <span className="text-sm font-normal text-slate-400">Siswa</span>
            </p>
            <p className="mt-1 text-xs text-slate-400">Dalam rombel {classInfo?.name}</p>
          </div>

          <div className="rounded-2xl border border-sky-100 bg-sky-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-sky-700 uppercase">Guru Pengampu</span>
            <p className="mt-2 text-2xl font-bold tracking-tight text-sky-950 truncate">
              {classInfo?.teacher_name ?? `Guru #${classInfo?.teacher_id}`}
            </p>
            <p className="mt-1 text-xs text-sky-700/80">Penanggung jawab kelas</p>
          </div>

          <div className="rounded-2xl border border-indigo-100 bg-indigo-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-indigo-700 uppercase">Total Ujian Terjadwal</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-indigo-950">
              {classInfo?.exams_count ?? 0} <span className="text-sm font-normal text-indigo-600">Ujian</span>
            </p>
            <p className="mt-1 text-xs text-indigo-700/80">Asesmen aktif</p>
          </div>
        </section>

        {/* Student Roster Table */}
        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-sm font-bold text-slate-900">
                Daftar Hadir & Roster Siswa ({filteredStudents.length})
              </h2>
              <p className="text-xs text-slate-400">
                Nomor absen dan identitas siswa yang tercetak pada Lembar Jawaban Komputer (LJK)
              </p>
            </div>

            <div className="relative w-full max-w-xs">
              <span className="absolute inset-y-0 left-3 flex items-center text-slate-400 text-xs">
                🔍
              </span>
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Cari no. absen atau nama siswa..."
                className="w-full rounded-xl border border-slate-200 bg-slate-50 py-1.5 pl-8 pr-3 text-xs placeholder:text-slate-400 focus:bg-white focus:outline-none"
              />
            </div>
          </div>

          <div className="overflow-x-auto rounded-xl border border-slate-100">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-slate-100 bg-slate-50 text-xs font-semibold text-slate-500">
                <tr>
                  <th className="px-4 py-3 w-28">No. Absen</th>
                  <th className="px-4 py-3">Nama Lengkap Siswa</th>
                  <th className="px-4 py-3 w-32 text-center">ID Sistem</th>
                  <th className="px-4 py-3 text-right w-36">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredStudents.map((s) => (
                  <tr key={s.id} className="hover:bg-slate-50/80 transition">
                    <td className="px-4 py-3 font-mono font-bold text-xs text-indigo-700">
                      <span className="rounded-md bg-indigo-50 px-2 py-1 border border-indigo-100">
                        {s.student_number}
                      </span>
                    </td>
                    <td className="px-4 py-3 font-medium text-slate-900">
                      {s.name}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-400 font-mono text-center">
                      #{s.id}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => openEditStudentModal(s)}
                          className="rounded-lg border border-slate-200 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 hover:bg-slate-50 transition"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => handleDeleteStudent(s.id, s.name)}
                          className="rounded-lg border border-red-200 bg-red-50 px-2.5 py-1 text-xs font-medium text-red-600 hover:bg-red-100 transition"
                        >
                          Hapus
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {filteredStudents.length === 0 && !loading && (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-xs text-slate-400">
                      Tidak ada data siswa yang cocok dengan kriteria.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </div>

      {/* Modal Tambah / Edit Siswa Individual */}
      {isSingleModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-bold text-slate-900">
                {editingStudent ? 'Edit Data Siswa' : 'Tambah Siswa Baru'}
              </h3>
              <button
                onClick={() => setIsSingleModalOpen(false)}
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

            <form onSubmit={handleSaveStudent} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Nomor Absen
                </label>
                <input
                  type="text"
                  required
                  value={formNumber}
                  onChange={(e) => setFormNumber(e.target.value)}
                  placeholder="mis. 01, 02, 15"
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm font-mono focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Nama Lengkap Siswa
                </label>
                <input
                  type="text"
                  required
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="mis. Muhammad Rayhan"
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsSingleModalOpen(false)}
                  className="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50 transition"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={formSubmitting}
                  className="rounded-xl bg-indigo-600 px-4 py-2 text-xs font-bold text-white shadow-sm hover:bg-indigo-700 transition disabled:opacity-50"
                >
                  {formSubmitting ? 'Menyimpan...' : 'Simpan Siswa'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Input Cepat / Bulk Add Siswa */}
      {isBulkModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm p-4">
          <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-base font-bold text-slate-900">Input Cepat / Bulk Import Siswa</h3>
                <p className="text-xs text-slate-500">Paste daftar siswa langsung dari Excel / Word</p>
              </div>
              <button
                onClick={() => setIsBulkModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 text-lg leading-none"
              >
                ✕
              </button>
            </div>

            {bulkError && (
              <div className="mb-4 rounded-xl border border-red-200 bg-red-50 p-3 text-xs text-red-700">
                {bulkError}
              </div>
            )}

            <form onSubmit={handleBulkAddStudents} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Format: Nomor Absen, Nama Siswa (1 siswa per baris)
                </label>
                <textarea
                  required
                  rows={8}
                  value={bulkText}
                  onChange={(e) => setBulkText(e.target.value)}
                  placeholder="01, Andi Pratama&#10;02, Budi Santoso&#10;03, Citra Lestari"
                  className="w-full font-mono rounded-xl border border-slate-200 p-3 text-xs leading-relaxed focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div className="rounded-xl bg-slate-50 p-3 text-[11px] text-slate-500 border border-slate-100">
                💡 <strong>Tips:</strong> Anda dapat meng-copy 2 kolom (No. Absen & Nama) langsung dari Microsoft Excel atau Google Sheets lalu paste di kotak di atas.
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsBulkModalOpen(false)}
                  className="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50 transition"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={bulkSubmitting}
                  className="rounded-xl bg-indigo-600 px-4 py-2 text-xs font-bold text-white shadow-sm hover:bg-indigo-700 transition disabled:opacity-50"
                >
                  {bulkSubmitting ? 'Mengimpor...' : 'Impor Daftar Siswa'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </main>
  );
}
