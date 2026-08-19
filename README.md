# 📝 AutoGrading — Automated Exam Grading System (Vision-NLP Hybrid)

Platform hybrid (Mobile Scanner + Web Dashboard) yang memanfaatkan Vision-Language AI (Google Gemini) untuk **Handwriting Recognition** dan **semantic evaluation** jawaban siswa terhadap kunci jawaban guru secara otomatis. **Status: MVP lengkap (Fase 0–6 selesai).**

## Arsitektur Singkat

```
[Mobile App Flutter]  ──crop base64──▶  [Backend FastAPI]  ──Gemini API──▶  [Google Gemini Flash/Lite]
     Edge Scanner                        AI Orchestrator
         │                                      │
         └────────── REST API ──────────────────┤
                                                ▼
                                        [Database SQLite/PostgreSQL]
                                                │
                                                ▼
                                     [Web Dashboard Next.js]
```

- **Mobile App** = pre-processing scanner (fiducial marker detection, perspective warp, crop per jawaban) + API client. Tanpa AI lokal, tanpa DB langsung.
- **Backend** = business logic + AI orchestrator (batching 10, MCQ 3-tier CV→Gemini, JSON-strict, grading berbobot).
- **Web Dashboard** = analitik hasil, distribusi nilai, kesulitan soal, export CSV.

## Struktur Repositori

```
├── architecture.md            # Dokumen arsitektur asli (English)
├── docs/                      # 12 dokumen perancangan, koneksi Tailscale & alur kerja komprehensif
│   ├── 11-koneksi-tailscale.md
│   └── 12-alur-kerja-sistem-komprehensif.md
├── backend/                   # FastAPI (Python) — 43 test hijau
├── mobile/                    # Flutter (Android) — pipeline pure Dart, 10 test
└── web/                       # Next.js 16 — dashboard + BFF proxy
```

## Tech Stack (Keputusan Final)

| Layer | Teknologi |
|---|---|
| Mobile | Flutter (Android) + pipeline OpenCV **pure Dart** (`image` package) |
| Backend | Python FastAPI + SQLAlchemy |
| Database | SQLite (dev) → PostgreSQL (produksi) |
| AI Engine | Gemini: MCQ/isian → `gemini-3.5-flash-lite`; esai → `gemini-3.5-flash`; MCQ deteksi X via CV 3-tier |
| Web | Next.js 16 + Tailwind 4 + Chart.js |
| Auth | JWT: secure storage (mobile), httpOnly cookie + proxy.ts (web) |

## Quick Start

```bash
# Backend
cd backend
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env      # isi GEMINI_API_KEY
python scripts\seed.py
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Template lembar jawaban (cetak)
python scripts\generate_template.py --questions "mcq:3 short:2 essay:1" --out lembar.pdf --verify

# Mobile (HP via USB + adb reverse)
cd ../mobile && flutter build apk --debug --dart-define=API_BASE=http://127.0.0.1:8000
adb reverse tcp:8000 tcp:8000 && adb install -r build\app\outputs\flutter-apk\app-debug.apk

# Web dashboard
cd ../web && npm run dev   # http://localhost:3000 (login: guru@sekolah.id / rahasia123)
```

Laporan lengkap: [docs/10-eksekusi.md](docs/10-eksekusi.md)
