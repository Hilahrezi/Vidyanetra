# 🖥️ 07 — Web Dashboard & Analitik Asesmen (Next.js 16)

Dokumen ini mendokumentasikan arsitektur, pola keamanan BFF (*Backend-For-Frontend*), dan modul antarmuka analitik pada aplikasi **Vidyanetra Web Dashboard** ([https://vidyanetra.vercel.app](https://vidyanetra.vercel.app)).

---

## 🏗️ 1. Arsitektur & Struktur Halaman

Web Dashboard dibangun menggunakan **Next.js 16 (App Router + Turbopack + Tailwind CSS)**:

```
web/
├── app/
│   ├── layout.tsx                     # Global Root Layout
│   ├── page.tsx                       # Root Landing / Redirect
│   ├── login/page.tsx                 # Halaman Login Guru & Admin
│   ├── api/
│   │   ├── auth/login/route.ts        # Handler Login (Set httpOnly Cookie)
│   │   └── [...path]/route.ts         # Generic BFF Proxy ke FastAPI
│   └── dashboard/
│       ├── page.tsx                   # Overview KPI Asesmen & Daftar Ujian
│       ├── exams/[id]/page.tsx        # Detail Ujian, Gradebook, & Analitik Kesulitan
│       ├── exams/[id]/students/[sid]/page.tsx # Review Detail Split-View & Override
│       ├── classes/page.tsx           # Manajemen Kelas & Rombel Kurikulum
│       ├── classes/[id]/page.tsx      # Manajemen Roster & Siswa (Bulk Add)
│       └── users/page.tsx             # Manajemen Pengguna & Hak Akses (Admin RBAC)
├── lib/
│   ├── api.ts                         # Fetch client wrapper
│   ├── config.ts                      # Konfigurasi runtime
│   └── types.ts                       # TypeScript interfaces
└── proxy.ts                           # Next.js Server Proxy Middleware Guard
```

---

## 🔒 2. Pola Keamanan BFF Proxy & Auth Guard

```mermaid
sequenceDiagram
    autonumber
    actor User as 👤 Browser Client
    participant BFF as 🛡️ Next.js BFF Proxy (/api/*)
    participant BE as ⚙️ FastAPI Backend

    User->>BFF: POST /api/auth/login (email, password)
    BFF->>BE: POST /auth/login
    BE-->>BFF: { access_token, user }
    BFF-->>User: Set-Cookie: ag_token=...; HttpOnly; SameSite=Lax; Secure
    Note over User,BFF: Token JWT terisolasi aman dari serangan XSS JavaScript
    User->>BFF: GET /api/exams (Request otomatis menyertakan Cookie)
    BFF->>BE: GET /exams (Header Authorization: Bearer <ag_token>)
    BE-->>BFF: Data JSON
    BFF-->>User: Data JSON
```

---

## 📊 3. Modul & Fitur Utama Web Dashboard

### 1. Dashboard Asesmen Global (`/dashboard`)
* **4 Kartu Metrik KPI Sekolah:** Total Ujian Aktif, Total Kelas, Total Siswa, dan Rata-rata Kelulusan Sekolah.
* **Pencarian & Filter Instan:** Filter per Mata Pelajaran, Tingkat Kelas, dan kata kunci judul.
* **Kartu Ujian Informatif:** Progress bar koreksi (`24/30 Siswa Terkoreksi`), rata-rata nilai, tombol unduh PDF LJK, dan tautan detail.

### 2. Detail Ujian & Analisis Asesmen (`/dashboard/exams/[id]`)
* **4 Kartu Ringkasan KPI Ujian:** Rata-rata Nilai, Persentase Ketuntasan (KKM $\ge 70\%$), Nilai Tertinggi, dan Nilai Terendah.
* **Pencarian & Triase Filter Status:** Filter instan berdasarkan nama/nomor absen siswa serta tombol status (`Semua`, `Final`, `Terkoreksi AI`, `Diproses`).
* **Histogram Distribusi Nilai:** Grafik sebaran perolehan nilai siswa (10 bucket interval).
* **Indikator Tingkat Kesulitan Soal (Traffic Light):**
  - 🟢 **Mudah:** Rata-rata skor butir $\ge 80\%$
  - 🟡 **Sedang:** Rata-rata skor butir $40\text{--}79\%$
  - 🔴 **Sukar / Perlu Perhatian:** Rata-rata skor butir $< 40\%$
* **Aksi Cepat:** Tombol unduh **PDF Lembar A4 (300 DPI)** dan ekspor nilai **CSV format e-Rapor**.

### 3. Review Lembar Jawaban Siswa Split-View (`/dashboard/exams/[id]/students/[sid]`)
* **Tampilan Split-View (Kiri: Scan / Kanan: Evaluasi AI):** Menampilkan potongan gambar asli tulisan tangan siswa berdampingan dengan hasil koreksi AI.
* **Informasi Diagnostik Lengkap:** Menampilkan transkripsi HWR AI, skor kemiripan semantik ($0\text{--}100$), tingkat keyakinan (*confidence*), badge model penilai (`mobile-cv`, `cv-mcq`, `gemini-3.5-flash`), dan alasan evaluasi (*AI reasoning*).
* **Intervensi Guru (Manual Override):** Slider interaktif untuk mengubah nilai per butir secara langsung tanpa re-grading AI.
* **Tombol Cerdas:** `Retry Failed` untuk mengulang butir soal yang gagal dan `Finalize` untuk mengunci skor.

### 4. Manajemen Rombel, Roster & User RBAC
* **Manajemen Kelas (`/dashboard/classes`):** Penugasan guru pengampu dan ringkasan metrik kelas.
* **Manajemen Roster Siswa (`/dashboard/classes/[id]`):** Modal Tambah Siswa Individual & **Input Cepat / Bulk Import** (bisa langsung copy-paste tabel siswa dari Microsoft Excel / Google Sheets).
* **Manajemen Pengguna (`/dashboard/users`):** Khusus Administrator untuk menambah akun dan mengelola peran pengguna.
