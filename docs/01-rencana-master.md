# 📋 Rencana Master — AutoGrading System

Dokumen ini adalah sumber kebenaran (single source of truth) untuk seluruh keputusan dan roadmap proyek.

## 1. Visi

Sistem koreksi ujian otomatis untuk institusi pendidikan: guru memindai lembar jawaban tulisan tangan (A4) via kamera Android, AI mengekstrak teks jawaban dan mengevaluasi kesamaannya secara semantik terhadap kunci jawaban, hasilnya ditinjau guru (manual override) lalu dianalisis di web dashboard.

## 2. Keputusan Kunci (dikonfirmasi pemilik proyek)

| No | Keputusan | Pilihan |
|---|---|---|
| 1 | Stack mobile + backend | **Flutter + FastAPI** |
| 2 | Format lembar jawaban | **Template custom A4** (agent mendesain, 4 fiducial marker) |
| 3 | Tipe soal MVP | **Semua: MCQ + isian singkat + esai** |
| 4 | Peran pengguna | **Guru saja** (tanpa login siswa) |
| 5 | Deployment & API | **Dev lokal (Windows)**, Gemini API key tersedia |
| 6 | Bahasa jawaban siswa | **Bahasa Indonesia** |
| 7 | Platform mobile | **Android saja** |
| 8 | Model AI | **Gemini Flash** (esai) + **Flash-Lite** (MCQ/isian) — ID model persis disesuaikan konsol pemilik |
| 9 | Database | SQLite (dev) → PostgreSQL (produksi, migrasi via SQLAlchemy) |
| 10 | Evaluasi | Batching 4–8 crop/request, JSON array strict, retry + backoff, mock mode |

## 3. Prinsip Non-Negotiable (dari architecture.md)

1. **Separation of Concerns** — REST API independen untuk mobile; frontend tidak memanggil DB.
2. **Keamanan** — Gemini API key & kredensial DB hanya di `backend/.env`; tidak pernah di mobile/web.
3. **Payload optimization** — mobile mengirim crop per kotak jawaban (JPEG q70, longest side ~768px), bukan gambar A4 penuh.
4. **JSON strict** — semua output Gemini dipaksa JSON via `response_mime_type` + `response_schema` (bukan sekadar instruksi teks).
5. **Step-by-step execution** — mengikuti fase di bawah.

## 4. Roadmap Fase

### Fase 0 — Inisialisasi (SEKARANG ✅)
- [x] Struktur repo: `backend/`, `mobile/`, `web/`, `docs/`
- [x] Seluruh dokumen perencanaan di `docs/`
- [x] Boilerplate backend (config, models, routers, services skeleton)
- [ ] Setup venv + install requirements
- [ ] Commit awal ke git

### Fase 1 — Backend API (FastAPI) ✅
- [x] Skema DB lengkap (lihat `04-database-schema.md`)
- [x] Auth JWT login guru (bcrypt, fallback mock bila API key kosong)
- [x] CRUD: classes, students, exams, questions (+ ownership check 404)
- [x] Submission flow: upload crops → evaluate (mock) → save
- [x] Manual override + finalize endpoint
- [x] Validasi upload: jumlah crop vs soal, duplikat, base64, limit 5 MB
- [x] Endpoint detail per submission (`GET /submissions/{id}/details`)
- [x] Analitik: distribution, question-difficulty, export CSV
- [x] Test suite: 23 test hijau (auth, CRUD, ownership, submission, analitik)
- [x] E2E mock: `scripts/simulate_upload.py` (upload → graded → finalize → analitik → CSV)

### Fase 2 — Integrasi Gemini (core logic) ✅ (2A + 2.6 selesai)
- [x] Benchmark 7 model (Fase 2A): `scripts/benchmark/` (prepare_dataset, run_benchmark, analyze)
- [x] Routing final: MCQ/isian → `gemini-3.5-flash-lite`; esai → `gemini-3.5-flash`; fallback otomatis → lite saat 429 (config `GEMINI_MODEL_*`)
- [x] `GeminiClient` real (SDK `google.genai`, mock fallback otomatis, retry backoff, timeout)
- [x] `BatchingService`: interleaved prompt-level batching (batch 5, maks 15) + routing per tugas
- [x] Audit model: kolom `SubmissionDetail.model_used` (mendeteksi fallback aktif)
- [x] E2E real Gemini: 8 item benchmark → graded → finalize (skor 98.5, extraction 8/8 benar)
- [x] Validasi foto tulisan tangan asli (3 foto): lite ≡ flash (f1 87.8) — keputusan esai tetap flash
- [x] Partial retry endpoint (`POST /submissions/{id}/retry-failed`) — retry hanya soal `failed`, 409 bila tak ada/kunci

### Fase 3 — Template Lembar Jawaban ✅ (+ redesain Fase 3-R)
- [x] Layout engine `app/services/template_service.py` (A4 300dpi, marker, multi-page)
- [x] Ekspor `layout.json` — kontrak koordinat px (2480×3508) untuk crop mobile
- [x] Deteksi marker `app/services/marker_detection.py`: fill-ratio filter, pusat via interseksi diagonal (projective-invariant)
- [x] CLI `scripts/generate_template.py --verify`: render → deteksi (error < 2px) → warp → crop per sel
- [x] **Redesain (3-R):** kop dummy (logo+satu sekolah), identitas ramping 9mm + TANGGAL (hanya hal.1), MCQ proper 4 kotak a/b/c/d (siswa menyilang), esai 170mm (fix terpotong tepi), footer halaman (fix menimpa marker TR), kop digeser (fix tabrak marker TL)
- [x] Validasi MCQ baru dengan Gemini real: lite 100/100/95 (5.0s) — routing tidak berubah
- [x] Test: kontrak layout, deteksi-warp, roundtrip perspektif, gagal-tanpa-marker (34 test backend + 6 test Flutter hijau)

### Fase 4 — Mobile Flutter (Android) ✅ (+ Fase 4.5 MCQ 3-tier)
- [x] `flutter create` + deps; OpenCV pipeline PURE DART (4 test, fixture render + foto miring)
- [x] UI: login → kelas → ujian → scan (multi-halaman) → review (polling + override + finalize)
- [x] Toolchain Android: JDK 21 + SDK 37 → APK debug build ✓; **E2E perangkat itel S666LN berhasil** (scan → grading → finalize via adb reverse)
- [x] **Fase 4.5:** MCQ tanpa AI — 3-tier: deteksi X di mobile (Dart, `detectMcqAnswer`) → CV backend (`mcq_vision.py`) → fallback Gemini; `model_used` = mobile-cv/cv-mcq/gemini
- [x] Prompt: rumus matematika setara nama konsep; seed kunci Pythagoras multi-varian; docs pedoman kunci guru
- [x] Kecepatan: batch 10 (dari 5), paralel antar tipe (jumlah request TIDAK bertambah), label progres per tipe
- [x] Test: 41 backend + 10 Flutter hijau (termasuk deteksi X: b/c/a benar, tanpa-X & X-ganda ambigu)
- [ ] E2E ulang dengan APK baru (menunggu HP tersambung)

### Fase 5 — Web Dashboard (Next.js) ✅
- [x] Scaffold Next.js 16 (App Router + Tailwind 4 + Turbopack); pre-install sebelum pindah koneksi lambat
- [x] Auth: login → JWT di **httpOnly cookie** (`/api/auth/login`), guard via **proxy.ts** (Next 16: middleware → proxy)
- [x] **BFF proxy generik** `app/api/[...path]/route.ts`: semua panggilan backend lewat server (token tak pernah di JS client), termasuk proxy gambar `/uploads` & export CSV
- [x] Halaman: login → dashboard (list ujian) → detail ujian (tabel submission + chart distribusi & kesulitan + export CSV) → detail siswa (crop image + override slider + finalize)
- [x] Verifikasi E2E: login → exams → submissions (finalized 89.58) → analitik → gambar → guard redirect (307)
- [x] `npm run build` sukses (semua route + Proxy terdaftar)

## 5. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Rate limit Gemini (RPM/RPD) | Batching 4–8 crop/call, routing Flash vs Flash-Lite (quota terpisah), retry backoff |
| Quota habis (RPD) | Mock mode / fallback similarity sederhana di backend |
| HWR salah baca | Flow review + manual override wajib per submission |
| Deteksi marker gagal (pencahayaan) | Panduan scan di UI, deteksi ulang, warp manual opsional |
| Biaya token | Resize crop ~768px, batch tidak menambah biaya tapi mengecilkan jumlah request |
