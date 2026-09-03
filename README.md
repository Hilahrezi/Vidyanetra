# 📝 AutoGrading — Automated Exam Grading System (Vision-NLP Hybrid)

Platform hybrid (**Mobile Scanner + Web Dashboard**) yang memanfaatkan teknologi **Edge Computer Vision** dan **Multimodal AI (Google Gemini)** untuk mengevaluasi lembar jawaban ujian tulisan tangan siswa terhadap kunci jawaban secara otomatis, akurat, dan hemat kuota.

---

## 🏛️ Arsitektur Global Sistem

```
[Mobile App Flutter]  ──crop base64──▶  [Backend FastAPI]  ──Gemini API──▶  [Google Gemini Flash/Lite]
     Edge Scanner                        AI Orchestrator
          │                                      │
          └────────── REST API ──────────────────┤
                                                 ▼
                                         [Database SQLite/MySQL/Postgres]
                                                 │
                                                 ▼
                                      [Web Dashboard Next.js 16]
```

* **Mobile App (Flutter Android):** *Edge pre-processing scanner* (deteksi *fiducial marker*, homografi DLT, pemotongan per kotak jawaban, dan deteksi silang X murni *Pure Dart*).
* **Backend API (FastAPI):** Logika bisnis, orkestrasi AI, *interleaved prompt batching*, penilaian berbobot otomatis, dan ReportLab PDF engine.
* **Web Dashboard (Next.js 16):** Arsitektur BFF Proxy (httpOnly Cookie), analitik asesmen modern, Manajemen Pengguna (RBAC Admin), serta Manajemen Kelas & Roster Siswa.

---

## 📚 Katalog Dokumentasi Lengkap (`/docs`)

Seluruh dokumentasi teknis dan panduan operasional tersusun rapi di folder [`docs/`](docs/README.md):

| No | Dokumen | Ringkasan Isi |
|:---:|---|---|
| **00** | [**Peta Dokumentasi (`docs/README.md`)**](docs/README.md) | Katalog induk dan navigasi cepat seluruh modul dokumentasi. |
| **01** | [**Arsitektur & Desain Sistem**](docs/01-arsitektur-dan-desain-sistem.md) | Topologi 3-Tier, prinsip arsitektur, dan perbandingan model AI. |
| **02** | [**Alur Kerja Sistem Komprehensif**](docs/02-alur-kerja-komprehensif.md) | 5 Alur operasional *end-to-end* (Pembuatan Ujian $\rightarrow$ Koreksi AI $\rightarrow$ Analitik). |
| **03** | [**Spesifikasi REST API Backend**](docs/03-spesifikasi-api-backend.md) | Kontrak endpoint FastAPI lengkap (Auth, Users, Classes, Exams, Grading, Analytics). |
| **04** | [**Skema Database & ORM**](docs/04-skema-database-dan-orm.md) | Diagram Relasi Entitas (ERD), kamus data tabel, dan SQLAlchemy 2.0 ORM. |
| **05** | [**Integrasi Gemini AI & Computer Vision**](docs/05-integrasi-ai-gemini-dan-cv.md) | Strategi hybrid 3-tier MCQ, routing model, batching, dan formula penilaian. |
| **06** | [**Desain & Geometri Lembar Jawaban**](docs/06-desain-dan-geometri-lembar-jawaban.md) | Geometri PDF A4 (300 DPI), 4 *fiducial marker*, dan kontrak koordinat `layout.json`. |
| **07** | [**Spesifikasi Aplikasi Mobile**](docs/07-spesifikasi-aplikasi-mobile.md) | Flutter Android architecture, Edge CV pipeline, exam builder, dan build APK. |
| **08** | [**Spesifikasi Web Dashboard**](docs/08-spesifikasi-web-dashboard.md) | Next.js 16 BFF proxy, analitik asesmen, RBAC Admin, dan roster siswa. |
| **09** | [**Panduan Jaringan Nirkabel Tailscale**](docs/09-panduan-jaringan-nirkabel-tailscale.md) | Prosedur koneksi nirkabel HP-ke-PC via Tailscale Mesh tanpa kabel USB. |
| **10** | [**Panduan Database MySQL & phpMyAdmin**](docs/10-panduan-database-mysql-phpmyadmin.md) | Langkah integrasi MySQL / MariaDB (XAMPP) dan pengelolaan phpMyAdmin. |
| **11** | [**Panduan Deployment Cloud Gratis**](docs/11-panduan-deployment-cloud-gratis.md) | Panduan deployment 100% free tier (Supabase + Koyeb + Vercel) dan log efisiensi. |

---

## ⚡ Quick Start Panduan Menjalankan

### 1. Menjalankan Backend FastAPI
```powershell
cd backend
.venv\Scripts\activate
pip install -r requirements.txt
python scripts\seed.py
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Menjalankan Web Dashboard (Next.js)
```powershell
cd web
npm install
npm run dev    # Buka http://localhost:3000
```

### 3. Kompilasi APK Mobile Android (Flutter)
```powershell
cd mobile
flutter build apk --debug --dart-define=API_BASE=http://100.78.211.26:8000
```

---

## 🔑 Kredensial Default Login
| Peran (Role) | Email | Password | Akses Utama |
|---|---|---|---|
| **Administrator** | `admin@sekolah.id` | `admin123` | Web Dashboard (`/dashboard/users`, `/dashboard/classes`) |
| **Guru Pengampu** | `guru@sekolah.id` | `rahasia123` | Mobile App & Web Gradebook |
