# 📚 Dokumentasi Resmi — Vidyanetra System (Modern Cloud E2E)
### *Sistem Asesmen & Koreksi Ujian Otomatis (Edge CV + Multimodal AI)*

🌐 **Live Web Dashboard:** [https://vidyanetra.vercel.app](https://vidyanetra.vercel.app)

Selamat datang di repositori dokumentasi resmi sistem **Vidyanetra**. Sistem ini menggabungkan teknologi **Edge Computer Vision (Pure Dart)** pada perangkat mobile Android, **Backend API Orchestrator (FastAPI Container)**, **Multimodal AI (Google Gemini 3.5)**, dan **Web Dashboard Analitik (Next.js 16 Vercel)** untuk menyediakan solusi koreksi lembar jawaban ujian tulisan tangan secara akurat, cepat, hemat kuota, dan 100% *cloud-ready*.

---

## 🧭 Peta & Struktur Dokumentasi (`docs-new`)

Dokumentasi ini dirancang secara ringkas, modular, bebas redundansi, dan sepenuhnya berorientasi pada arsitektur produksi modern (tanpa konfigurasi lokal/legacy):

| No | Dokumen | Fokus & Deskripsi Modul |
|:---:|---|---|
| **01** | [**Arsitektur & Desain Sistem**](01-arsitektur-dan-desain-sistem.md) | Topologi Global Cloud 3-Tier, prinsip keamanan *zero-leakage* BFF, routing cerdas AI, dan optimasi *payload*. |
| **02** | [**Alur Kerja End-to-End**](02-alur-kerja-end-to-end.md) | 5 Siklus operasional sistem dari pembuatan ujian berbobot dinamis hingga publikasi nilai dan ekspor e-Rapor. |
| **03** | [**Spesifikasi API & Database**](03-spesifikasi-api-dan-database.md) | Kontrak REST API FastAPI lengkap, diagram ERD, skema tabel SQLAlchemy 2.0, relasi *cascade*, dan RBAC. |
| **04** | [**Integrasi Gemini AI & Computer Vision**](04-integrasi-ai-gemini-dan-cv.md) | Pipeline evaluasi hybrid 3-tier MCQ ($0\text{ RPD}$), *interleaved multimodal batching*, prompt engineering, dan formula *weighted scoring*. |
| **05** | [**Geometri Lembar Jawaban (A4 PDF)**](05-geometri-lembar-jawaban-a4.md) | Spesifikasi PDF A4 300 DPI, deteksi 4 *fiducial marker* proyektif, homografi DLT, dan kontrak koordinat `layout.json`. |
| **06** | [**Aplikasi Mobile Scanner (Flutter)**](06-aplikasi-mobile-scanner.md) | Arsitektur Flutter 3 Android, pemrosesan citra *Pure Dart*, deteksi tanda silang lokal (`McqMark`), dan build APK Split-ABI (~18 MB). |
| **07** | [**Web Dashboard & Analitik (Next.js)**](07-web-dashboard-analitik.md) | Dashboard Next.js 16 Vercel, BFF proxy cookie, analitik psikometrik *traffic light*, triase status, dan review *split-view*. |
| **08** | [**Panduan Deployment Cloud Produksi**](08-deployment-cloud-produksi.md) | Panduan deployment 100% Free Tier (Supabase PostgreSQL + Render/Koyeb Container + Vercel) dan optimasi anti N+1 query. |

---

## 🏛️ Topologi Global Sistem Cloud

```mermaid
flowchart TD
    subgraph CLIENT ["📱 Mobile Client (Flutter Android)"]
        M1["📸 Kamera Scanner"] --> M2["📐 Edge CV (Pure Dart)\nMarker Diagonal & DLT Homography"]
        M2 --> M3["🔘 Tier-1 MCQ Detector (X)"]
        M3 --> M4["Crop JPEG q70 (≤768px Base64)"]
    end

    subgraph WEB ["🖥️ Web Frontend (Next.js 16 Vercel)"]
        W1["🌐 https://vidyanetra.vercel.app"] --> W2["🛡️ BFF Proxy (/api/*)\nhttpOnly Secure Cookie"]
    end

    subgraph BACKEND ["⚙️ AI Orchestrator (FastAPI Cloud Container)"]
        B1["🛡️ Auth JWT & RBAC Controller"]
        B2["📄 ReportLab PDF Generator (300 DPI)"]
        B3["👁️ Tier-2 OpenCV MCQ Evaluation"]
        B4["📦 Interleaved Prompt Batching"]
        B5["⚖️ Weighted Scoring Engine"]
    end

    subgraph CLOUD_STORAGE ["☁️ Managed Cloud Layer"]
        DB[("🐘 Supabase Managed PostgreSQL\n(Transaction Pooler :6543)")]
        AI1["⚡ Google Gemini 3.5 Flash-Lite\n(Isian Singkat & Fallback MCQ)"]
        AI2["🧠 Google Gemini 3.5 Flash\n(Esai & Penalaran Semantik)"]
    end

    M4 -->|POST /submissions/upload-crops| B1
    W2 <-->|BFF Proxy| B1
    B1 <-->|SQLAlchemy 2.0| DB
    B3 -->|Ambigu| AI1
    B4 -->|Batch Isian| AI1
    B4 -->|Batch Esai| AI2
```

---

## 🔑 Kredensial Akun Default (Inisialisasi Sistem)
| Peran (Role) | Email | Password | Akses Utama |
|---|---|---|---|
| **Administrator** | `admin@sekolah.id` | `admin123` | Manajemen Pengguna & Kelas (`/dashboard/users`, `/dashboard/classes`) |
| **Guru Pengampu** | `guru@sekolah.id` | `rahasia123` | Mobile Scanner App & Web Gradebook (`/dashboard`) |
