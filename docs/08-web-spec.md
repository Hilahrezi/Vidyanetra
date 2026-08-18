# 🖥️ Web Dashboard Spec — Next.js

## 1. Lingkup

Dashboard analitik untuk guru: hasil ujian, distribusi nilai, kesulitan soal, export. Baca-utama + override ringan.

## 2. Scaffold

```
web/  (create-next-app . --typescript --tailwind --app)
├── app/
│   ├── (auth)/login/page.tsx
│   ├── (dashboard)/layout.tsx        # sidebar + auth guard
│   ├── (dashboard)/page.tsx          # overview: pilih ujian
│   ├── (dashboard)/exams/[id]/page.tsx         # hasil + chart
│   ├── (dashboard)/exams/[id]/student/[sid]/page.tsx  # detail + override
│   └── (dashboard)/classes/...       # kelola kelas/siswa (opsional, bisa via mobile)
├── components/
│   ├── charts/ (chart.js wrapper: distribution, difficulty)
│   ├── tables/ (results table, editable score cell)
│   └── ui/
├── lib/
│   ├── api.ts        # fetch wrapper + JWT cookie
│   └── types.ts      # tipe respons API
└── ...
```

## 3. Pages & Fitur

### Login
- Form email/password → `POST /auth/login` → token disimpan **httpOnly cookie** (server action / middleware) — jangan di localStorage.
- Middleware Next.js guard semua route dashboard.

### Overview (home)
- List ujian milik guru (dari `/exams`), badge status (`pending/graded/finalized`), jumlah siswa terkoreksi, rata-rata nilai.
- Quick stat cards: rata-rata, tertinggi, terendah, % lulus (≥ 70).

### Detail Ujian `/exams/[id]`
- **Tabel hasil**: per siswa (no absen, nama, skor per soal dalam kolom, total, status). Sortable + filter.
- **Chart distribusi nilai** (histogram, bucket 0–100/10).
- **Chart kesulitan soal**: bar chart rata-rata skor per nomor soal (rendah = sulit).
- Tombol **Export CSV** (`/exams/{id}/export.csv`).
- Klik siswa → halaman detail.

### Detail Siswa `/exams/[id]/student/[sid]`
- Per soal: image crop (URL `/uploads/...`), `extracted_text`, skor, alasan AI, badge `override`.
- **Manual override** form (angka skor) → `PUT /submissions/{id}/review`.
- Status finalisasi + tombol finalize.

### Kelola Kelas/Siswa (opsional Fase 5)
- Form CRUD kelas & siswa — atau cukup di mobile. Keputusan: **implementasi di mobile dulu**; web menyediakan view saja pada MVP.

## 4. Teknis

- Data fetching: client-side (SWR/React Query) agar chart interaktif & refetch mudah.
- Chart.js via `react-chartjs-2`.
- Export: link langsung ke endpoint backend (header `Authorization` via cookie di `credentials`/server fetch) — simpler: tombol memanggil endpoint dengan token, blob download.
- Dark/light: Tailwind default; tema terang (kantor).
