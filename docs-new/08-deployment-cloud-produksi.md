# 🚀 08 — Panduan Deployment Cloud Produksi (100% Free Tier)

Dokumen ini memuat panduan komprehensif *deployment 100% cloud-ready* tanpa biaya (Free Tier) menggunakan kombinasi **Supabase (PostgreSQL)**, **Render / Koyeb (FastAPI Docker)**, **Vercel (Next.js 16 Web Dashboard)**, dan **Flutter Mobile APK Release**.

---

## 🏛️ 1. Topologi Arsitektur Cloud

```mermaid
flowchart TD
    User["👤 Guru / Admin / Siswa"]
    
    subgraph FRONTEND ["🖥️ Frontend & Client Layer"]
        Vercel["🌐 Web Dashboard\n(Vercel: https://vidyanetra.vercel.app)"]
        Mobile["📱 Mobile App APK\n(Android Client Release)"]
    end

    subgraph BACKEND ["⚙️ Application & Compute Layer"]
        Render["🚀 FastAPI Backend Container\n(Render / Koyeb Web Service)"]
    end

    subgraph STORAGE ["🗄️ Database & AI Cloud Layer"]
        Supabase[("🐘 Supabase Managed PostgreSQL\n(Transaction Pooler :6543)")]
        Gemini["☁️ Google Gemini 3.5 API\n(Google AI Studio Free Tier)"]
    end

    User --> Vercel
    User --> Mobile
    Vercel -->|BFF API Proxy| Render
    Mobile -->|HTTPS REST API / Base64 Crop| Render
    Render <-->|SQLAlchemy 2.0 / Port 6543| Supabase
    Render <-->|Interleaved Batching| Gemini
```

---

## 🛠️ 2. Langkah Demi Langkah Deployment

### 🐘 Langkah 1: Setup Database di Supabase
1. Buat project baru di [supabase.com](https://supabase.com).
2. Salin connection string URI (**Mode Transaction Pooler / Port 6543**):
   ```
   postgresql+psycopg2://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
   ```

### 🚀 Langkah 2: Deploy Backend di Render.com / Koyeb
1. Di [render.com](https://render.com), buat **New Web Service** terhubung ke repository ini.
2. Builder: `Docker` (Otomatis mendeteksi `Dockerfile` di root).
3. Masukkan **Environment Variables**:
   | Variable | Nilai |
   |---|---|
   | `DATABASE_URL` | URI Supabase PostgreSQL dari Langkah 1 |
   | `GEMINI_API_KEY` | API Key Google AI Studio Anda |
   | `JWT_SECRET` | String acak aman $\ge 32$ karakter |
   | `CORS_ORIGINS` | `https://vidyanetra.vercel.app` |
4. Deploy! Server aktif di URL seperti `https://autograding-api.onrender.com`.

### 🌐 Langkah 3: Deploy Web Dashboard di Vercel
1. Di [vercel.com](https://vercel.com), import repository ini.
2. **Pengaturan Wajib:**
   * **Root Directory:** Pilih folder **`web`** *(Wajib agar Vercel mendeteksi Next.js)*.
3. **Environment Variables:**
   | Variable | Nilai |
   |---|---|
   | `API_BASE` | URL Backend Render Anda (misal: `https://autograding-api.onrender.com`) |
4. Deploy! Dashboard aktif di **[https://vidyanetra.vercel.app](https://vidyanetra.vercel.app)**.

### 📱 Langkah 4: Kompilasi APK Mobile Android
```powershell
cd mobile
flutter build apk --release --split-per-abi --dart-define=API_BASE=https://autograding-api.onrender.com
```
File APK siap pakai (~18 MB): `mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

---

## 🔧 3. Troubleshooting Kasus Umum

| Gejala Error | Penyebab | Solusi |
|---|---|---|
| `OperationalError: SSL connection closed` | Supabase pooler mengalami idle timeout | Fitur `pool_pre_ping=True` dan `pool_recycle=300` di `database.py` sudah aktif otomatis. |
| `Access-Control-Allow-Origin blocked` | Domain Vercel belum diizinkan | Regex CORS di `main.py` sudah mencakup `*.vercel.app` dan variabel `CORS_ORIGINS`. |
| Render Cold Start / Sleep | Free tier Render tidur setelah 15 menit idle | Pasang cron ping gratis di [cron-job.org](https://cron-job.org) ke `https://.../health` setiap 10 menit. |

---

## 🔑 4. Akun Login Default Setelah Inisialisasi Cloud
| Peran (Role) | Email | Password | Akses |
|---|---|---|---|
| **Administrator** | `admin@sekolah.id` | `admin123` | Akses penuh Web Dashboard (`/dashboard/users`, `/dashboard/classes`) |
| **Guru Pengampu** | `guru@sekolah.id` | `rahasia123` | Akses Mobile Scanner App & Web Gradebook |
