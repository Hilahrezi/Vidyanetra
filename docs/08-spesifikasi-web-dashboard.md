# 🖥️ 08 — Spesifikasi Web Dashboard (Next.js 16)

Dokumen ini mendokumentasikan arsitektur, pola autentikasi BFF (*Backend-For-Frontend*), dan modul antarmuka web pada aplikasi **AutoGrading Web Dashboard**.

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
│   │   └── [...path]/route.ts         # Generic BFF Proxy ke Backend FastAPI
│   └── dashboard/
│       ├── page.tsx                   # Overview Dashboard Asesmen & Daftar Ujian
│       ├── exams/[id]/page.tsx        # Detail Ujian, Gradebook, & Analitik Kesulitan
│       ├── exams/[id]/students/[sid]/page.tsx # Review Detail Siswa & Override
│       ├── classes/page.tsx           # Manajemen Kelas & Rombel Kurikulum
│       ├── classes/[id]/page.tsx      # Manajemen Roster & Siswa (Bulk Add)
│       └── users/page.tsx             # Manajemen Pengguna & Hak Akses (Admin RBAC)
├── components/                        # UI Components & Modal Dialogs
├── lib/
│   ├── api.ts                         # Fetch client wrapper
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
    participant BE as ⚙️ FastAPI Backend (:8000)

    User->>BFF: POST /api/auth/login (email, password)
    BFF->>BE: POST /auth/login
    BE-->>BFF: { access_token, user }
    BFF-->>User: Set-Cookie: token=...; HttpOnly; SameSite=Lax
    Note over User,BFF: Token JWT terisolasi aman dari serangan XSS JavaScript
    User->>BFF: GET /api/exams (Request otomatis menyertakan Cookie)
    BFF->>BE: GET /exams (Header Authorization: Bearer <cookie_token>)
    BE-->>BFF: Data JSON
    BFF-->>User: Data JSON
```

* **Keuntungan:** Browser klien tidak pernah menyimpan JWT di `localStorage` atau variabel JavaScript global.
* **Server-Side Guard:** File `proxy.ts` secara otomatis mengarahkan pengguna tanpa cookie login ke `/login` (*Status 307 Redirect*).

---

## 📊 3. Modul & Fitur Utama Web Dashboard

### 1. Dashboard Asesmen Global (`/dashboard`)
* **4 Kartu Metrik KPI:** Total Ujian Aktif, Total Kelas, Total Siswa, dan Rata-rata Kelulusan Sekolah.
* **Pencarian & Filter Instan:** Filter per Mata Pelajaran, Tingkat Kelas, dan kata kunci judul.
* **Kartu Ujian Informatif:** Progress bar koreksi (`24/30 Siswa Terkoreksi`), rata-rata nilai, tombol unduh PDF lembar jawaban, dan tautan detail.

### 2. Detail Ujian & Analisis Asesmen (`/dashboard/exams/[id]`)
* **Tabel Gradebook Interaktif:** Menampilkan status pengerjaan siswa, skor per butir soal, dan nilai akhir.
* **Histogram Distribusi Nilai:** Grafik sebaran perolehan nilai siswa (interval 10 poin).
* **Indikator Tingkat Kesulitan Soal (Traffic Light):**
  - 🟢 **Mudah:** Rata-rata skor butir $> 80\%$
  - 🟡 **Sedang:** Rata-rata skor butir $40\text{--}80\%$
  - 🔴 **Perlu Perhatian:** Rata-rata skor butir $< 40\%$
* **Export CSV:** Unduh laporan rekap nilai lengkap satu kelas.

### 3. Review Lembar Jawaban Siswa (`/dashboard/exams/[id]/students/[sid]`)
* Menampilkan foto asli potongan kotak tulisan tangan siswa.
* Hasil transkripsi HWR AI, alasan evaluasi, dan keyakinan AI.
* Form penyesuaian nilai (*manual override*) dan tombol finalisasi.

### 4. Manajemen Rombel & Kelas (`/dashboard/classes`)
* Melihat daftar seluruh kelas, mata pelajaran, tingkat, dan guru pengampu.
* Modal tambah dan edit kelas (dengan penugasan guru pengampu oleh Admin).
* Kartu kelas dengan metrik jumlah siswa & ujian aktif.

### 5. Manajemen Roster Siswa (`/dashboard/classes/[id]`)
* Tabel daftar hadir siswa terformat (Nomor Absen & Nama Lengkap).
* Modal **Tambah Siswa Individual** (Nomor absen terprediksi otomatis).
* Modal **Input Cepat / Bulk Import**: Guru dapat langsung meng-copy tabel siswa dari Microsoft Excel / Google Sheets dan menempelkannya di sistem untuk impor instan multi-baris (`01, Budi Santoso\n02, Citra Lestari`).

### 6. Manajemen Pengguna & RBAC (`/dashboard/users`)
* Khusus Administrator: Menampilkan metrik total pengguna, jumlah admin, dan jumlah guru.
* Form pop-up penambahan akun baru (Nama, Email, Password, Role).
* Proteksi akun dan penghapusan akun guru/admin.
