'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';

import type { UserProfile } from '@/lib/types';

export default function UsersPage() {
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);
  const [users, setUsers] = useState<UserProfile[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRole, setSelectedRole] = useState<'all' | 'admin' | 'teacher'>('all');

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [formName, setFormName] = useState('');
  const [formEmail, setFormEmail] = useState('');
  const [formPassword, setFormPassword] = useState('');
  const [formRole, setFormRole] = useState<'teacher' | 'admin'>('teacher');
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    setLoading(true);
    setError(null);
    try {
      const [meRes, usersRes] = await Promise.all([
        fetch('/api/auth/me').then((r) => (r.ok ? r.json() : null)),
        fetch('/api/users').then(async (r) => {
          if (!r.ok) {
            const err = await r.json().catch(() => null);
            throw new Error(err?.detail ?? 'Gagal memuat daftar pengguna');
          }
          return r.json();
        }),
      ]);

      if (meRes) setCurrentUser(meRes);
      setUsers(usersRes);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Terjadi kesalahan');
    } finally {
      setLoading(false);
    }
  }

  async function handleCreateUser(e: React.FormEvent) {
    e.preventDefault();
    setFormSubmitting(true);
    setFormError(null);

    try {
      const res = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: formName.trim(),
          email: formEmail.trim(),
          password: formPassword,
          role: formRole,
        }),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => null);
        throw new Error(err?.detail ?? 'Gagal menambahkan pengguna');
      }

      setIsModalOpen(false);
      setFormName('');
      setFormEmail('');
      setFormPassword('');
      setFormRole('teacher');
      await loadData();
    } catch (err: unknown) {
      setFormError(err instanceof Error ? err.message : 'Gagal menambahkan pengguna');
    } finally {
      setFormSubmitting(false);
    }
  }

  async function handleDeleteUser(userId: number, userName: string) {
    if (!confirm(`Apakah Anda yakin ingin menghapus pengguna "${userName}"?`)) {
      return;
    }

    try {
      const res = await fetch(`/api/users/${userId}`, { method: 'DELETE' });
      if (!res.ok) {
        const err = await res.json().catch(() => null);
        throw new Error(err?.detail ?? 'Gagal menghapus pengguna');
      }
      await loadData();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Gagal menghapus pengguna');
    }
  }

  // Filtered users
  const filteredUsers = useMemo(() => {
    if (!users) return [];
    return users.filter((u) => {
      const matchSearch =
        searchQuery.trim() === '' ||
        u.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        u.email.toLowerCase().includes(searchQuery.toLowerCase());
      const matchRole = selectedRole === 'all' || u.role === selectedRole;
      return matchSearch && matchRole;
    });
  }, [users, searchQuery, selectedRole]);

  // Summary Metrics
  const metrics = useMemo(() => {
    if (!users) return { total: 0, admins: 0, teachers: 0, totalClasses: 0 };
    const total = users.length;
    const admins = users.filter((u) => u.role === 'admin').length;
    const teachers = users.filter((u) => u.role === 'teacher').length;
    const totalClasses = users.reduce((acc, u) => acc + (u.classes_count ?? 0), 0);
    return { total, admins, teachers, totalClasses };
  }, [users]);

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
                Manajemen Pengguna & Hak Akses
              </h1>
              <p className="text-xs text-slate-500">Kelola akun Administrator dan Guru pengampu</p>
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
          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <span className="text-xs font-semibold text-slate-500 uppercase">Total Pengguna</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-slate-900">
              {metrics.total} <span className="text-sm font-normal text-slate-400">Akun</span>
            </p>
            <p className="mt-1 text-xs text-slate-400">Terdaftar di sistem sekolah</p>
          </div>

          <div className="rounded-2xl border border-purple-100 bg-purple-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-purple-700 uppercase">Administrator</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-purple-950">
              {metrics.admins} <span className="text-sm font-normal text-purple-600">Admin</span>
            </p>
            <p className="mt-1 text-xs text-purple-700/80">Hak akses konfigurasi penuh</p>
          </div>

          <div className="rounded-2xl border border-sky-100 bg-sky-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-sky-700 uppercase">Guru Pengampu</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-sky-950">
              {metrics.teachers} <span className="text-sm font-normal text-sky-600">Guru</span>
            </p>
            <p className="mt-1 text-xs text-sky-700/80">Akses koreksi & manajemen soal</p>
          </div>

          <div className="rounded-2xl border border-emerald-100 bg-emerald-50/50 p-5 shadow-sm">
            <span className="text-xs font-semibold text-emerald-700 uppercase">Kelas Terdistribusi</span>
            <p className="mt-2 text-3xl font-bold tracking-tight text-emerald-950">
              {metrics.totalClasses} <span className="text-sm font-normal text-emerald-600">Kelas</span>
            </p>
            <p className="mt-1 text-xs text-emerald-700/80">Total rombel yang diampu</p>
          </div>
        </section>

        {/* Action Bar & Search */}
        <section className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm">
          <div className="flex flex-1 items-center gap-2">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Cari berdasarkan nama atau email pengguna..."
              className="w-full max-w-md rounded-xl border border-slate-200 bg-slate-50/60 px-3.5 py-2 text-sm placeholder:text-slate-400 focus:border-[#0F766E] focus:bg-white focus:outline-none"
            />
            <select
              value={selectedRole}
              onChange={(e) => setSelectedRole(e.target.value as 'all' | 'admin' | 'teacher')}
              className="rounded-xl border border-slate-200 bg-slate-50/60 px-3 py-2 text-xs font-semibold text-slate-700 focus:border-[#0F766E] focus:bg-white focus:outline-none"
            >
              <option value="all">Semua Role</option>
              <option value="admin">Administrator</option>
              <option value="teacher">Guru</option>
            </select>
          </div>

          <button
            onClick={() => setIsModalOpen(true)}
            className="inline-flex items-center justify-center gap-1.5 rounded-xl bg-[#0F766E] hover:bg-[#115E59] px-4 py-2.5 text-xs font-bold text-white shadow-md shadow-teal-900/10 active:scale-[0.99] transition"
          >
            <span>+</span>
            <span>Tambah Pengguna Baru</span>
          </button>
        </section>

        {/* Users Table */}
        <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-sm font-bold text-slate-900">
              Daftar Pengguna ({filteredUsers.length})
            </h2>
            <span className="text-xs text-slate-400">
              Menampilkan {filteredUsers.length} akun terdaftar
            </span>
          </div>

          <div className="overflow-x-auto rounded-xl border border-slate-100">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-slate-100 bg-slate-50 text-xs font-semibold text-slate-500">
                <tr>
                  <th className="px-4 py-3">Pengguna</th>
                  <th className="px-4 py-3">Email Akun</th>
                  <th className="px-4 py-3">Role Hak Akses</th>
                  <th className="px-4 py-3 text-center">Kelas Diampu</th>
                  <th className="px-4 py-3 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredUsers.map((u) => {
                  const isSelf = currentUser?.id === u.id;
                  const isAdmin = u.role === 'admin';

                  return (
                    <tr key={u.id} className="hover:bg-slate-50/80 transition">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div
                            className={`flex h-9 w-9 items-center justify-center rounded-xl text-xs font-bold ${
                              isAdmin
                                ? 'bg-purple-100 text-purple-700'
                                : 'bg-sky-100 text-sky-700'
                            }`}
                          >
                            {u.name.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <p className="font-bold text-slate-900 flex items-center gap-1.5">
                              <span>{u.name}</span>
                              {isSelf && (
                                <span className="rounded bg-slate-200 px-1.5 py-0.2 text-[10px] font-semibold text-slate-600">
                                  Anda
                                </span>
                              )}
                            </p>
                            <p className="text-xs text-slate-400">ID #{u.id}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-xs font-mono text-slate-600">{u.email}</td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-bold ${
                            isAdmin
                              ? 'bg-purple-100 text-purple-800'
                              : 'bg-sky-100 text-sky-800'
                          }`}
                        >
                          {isAdmin ? '🛡️ Administrator' : '🎓 Guru Pengampu'}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-center">
                        <span className="rounded-lg bg-slate-100 px-2.5 py-1 text-xs font-bold text-slate-700">
                          {u.classes_count ?? 0} Kelas
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right">
                        {!isSelf && (
                          <button
                            onClick={() => handleDeleteUser(u.id, u.name)}
                            className="rounded-lg border border-red-200 bg-red-50 px-2.5 py-1 text-xs font-medium text-red-600 hover:bg-red-100 transition"
                          >
                            Hapus
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
                {filteredUsers.length === 0 && !loading && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-xs text-slate-400">
                      Tidak ada pengguna yang cocok dengan filter pencarian.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </div>

      {/* Modal Tambah Pengguna Baru */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-bold text-slate-900">Tambah Pengguna Baru</h3>
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

            <form onSubmit={handleCreateUser} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Nama Lengkap
                </label>
                <input
                  type="text"
                  required
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="mis. Budi Raharjo, S.Pd."
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Email Akun
                </label>
                <input
                  type="email"
                  required
                  value={formEmail}
                  onChange={(e) => setFormEmail(e.target.value)}
                  placeholder="mis. budi@sekolah.id"
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Password
                </label>
                <input
                  type="password"
                  required
                  value={formPassword}
                  onChange={(e) => setFormPassword(e.target.value)}
                  placeholder="Minimal 6 karakter"
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Role / Hak Akses
                </label>
                <select
                  value={formRole}
                  onChange={(e) => setFormRole(e.target.value as 'teacher' | 'admin')}
                  className="w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm focus:border-indigo-500 focus:outline-none"
                >
                  <option value="teacher">🎓 Guru Pengampu (Teacher)</option>
                  <option value="admin">🛡️ Administrator (Admin)</option>
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
                  {formSubmitting ? 'Menyimpan...' : 'Simpan Pengguna'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </main>
  );
}
