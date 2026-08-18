# 🏗️ Arsitektur Sistem

Dokumen ini adalah versi implementasi dari `architecture.md` (file root) setelah konfirmasi keputusan teknis.

## 1. Arsitektur 3-Tier

```
┌─────────────────────────────────────────────────────────────────────┐
│ TIER 1 — MOBILE APP (Flutter, Android)          = Edge Scanner      │
│  • Kamera capture lembar A4                                         │
│  • Deteksi 4 fiducial marker → perspective transform (deskew)       │
│  • Grayscale + crop kotak jawaban per nomor                         │
│  • Compress JPEG (q70, ~768px) → base64                             │
│  • Review hasil AI + manual override                                 │
│  ⚠ Tanpa AI lokal, tanpa koneksi DB langsung                         │
└───────────────┬─────────────────────────────────────────────────────┘
                │ REST API (JSON, JWT)
┌───────────────▼─────────────────────────────────────────────────────┐
│ TIER 2 — BACKEND (FastAPI)                       = AI Orchestrator  │
│  • Auth & routing (JWT)                                              │
│  • Terima array crop base64 per submission                           │
│  • BatchingService: group per tipe soal → batch 4–8 crop/call        │
│  • GeminiClient: prompt engineered + response_schema JSON            │
│  • GradingService: skor berbobot + override                          │
│  • Simpan ke database (SQLite dev / PostgreSQL prod)                 │
└───────────────┬─────────────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────────────┐
│ TIER 3 — WEB DASHBOARD (Next.js)                = Analytics          │
│  • Tabel hasil ujian, detail per siswa                              │
│  • Chart: distribusi nilai, kesulitan soal                          │
│  • Export CSV/Excel                                                 │
└─────────────────────────────────────────────────────────────────────┘

External: Google Gemini API (Flash / Flash-Lite) — dipanggil hanya dari Backend
```

## 2. Alur Data Per Submission

1. Mobile kirim `POST /submissions/upload-crops` (exam_id, student identity, `crops[]`).
2. Backend simpan gambar crop ke `uploads/` + buat record `Submission` (status `pending`).
3. `BatchingService`:
   - Group questions per tipe (MCQ/isian → Flash-Lite; esai → Flash).
   - Split ke batch 4–8 crop, urut per nomor soal.
4. `GeminiClient` panggil model per batch dengan `response_mime_type=application/json` + `response_schema` (array objek).
5. Parsing hasil → tulis ke `Submission_Details` (extracted_text, similarity_score, is_correct, ai_reasoning, confidence), status per question `done`.
6. `GradingService` hitung skor akhir berbobot → update `Submissions.total_score`, status `graded`.
7. Mobile menampilkan hasil → guru override per soal bila perlu (`manual_override`, `overridden_score`) → status `finalized`.

## 3. Peran Gemini dalam Pipeline

Gemini melakukan **dua tugas dalam satu pass multimodal**:
- **Handwriting Recognition**: membaca crop gambar jawaban → `extracted_text` (bahasa Indonesia).
- **Semantic Evaluation**: membandingkan teks terhadap answer_key (LLM judgment in-context, BUKAN cosine similarity embedding) → `similarity_score` (0–100), `is_correct`, `reason`.

Ini dilakukan per-batch (beberapa gambar per request) dengan labeling nomor soal agar akurat. Detail: `05-gemini-integration.md`.

## 4. Batasan Teknis

| Aspek | Batasan |
|---|---|
| Mobile | Android API 24+, kamera autofocus, jaringan internet (hanya butuh saat scan) |
| Payload | Crop ~50–150 KB/gambar (JPEG q70, 768px) |
| API Gemini | RPM/RPD tergantung tier akun; asumsi Free = ~15 RPM/model |
| Upload file | Hanya guru, ukuran total submission < ~5 MB (30 soal × ~150 KB) |
| Override | Wajib tersedia sebelum submission di-final-kan |
