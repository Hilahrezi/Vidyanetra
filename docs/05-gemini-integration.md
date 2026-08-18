# 🤖 Integrasi Gemini — Extraction + Semantic Evaluation + Batching

## 1. Model & Routing (hasil Benchmark Fase 2A + Validasi Foto Asli — ✅ DIPUTUSKAN)

**Routing produksi (1 model per tugas + MCQ TANPA AI — Fase 4.5):**

| Tipe Soal | Evaluator | RPD | Catatan |
|---|---|---|---|
| MCQ (tier-1) | **CV mobile (Dart)** | 0 | deteksi X di kotak a/b/c/d, `model_used=mobile-cv`, instan |
| MCQ (tier-2) | **CV backend (OpenCV)** | 0 | saat mobile ambigu/absent, `model_used=cv-mcq` |
| MCQ (tier-3) | `gemini-3.5-flash-lite` | 200 | fallback saat masih ambigu (1 request untuk semua item ambigu) |
| Isian singkat | `gemini-3.5-flash-lite` | 200 | batch 10, paralel antar tipe |
| Esai | `gemini-3.5-flash` | 20 | fallback otomatis → lite saat 429 |

**Alur MCQ 3-tier:** mobile deteksi X (densitas tinta per kotak, fraksi posisi tetap) → kirim `mcq_answer` di payload; backend pakai hasil mobile bila tidak ambigu → bila ambigu, backend deteksi ulang (CV) → bila masih ambigu, Gemini (1 request). Ambigu = densitas kotak terpilih < 0.03 atau < 1.5× kotak kedua.

**Bukti benchmark:**
1. Test set sintetis (8 item): model flash seri (MCQ 100, isian 100, esai 95); lite tercepat (3.3s).
2. Foto tulisan tangan asli (3 foto): lite ≡ flash (f1 87.8).
3. MCQ format baru (4 kotak + X, Fase 3-R): lite 100/100/95.
4. Deteksi CV MCQ: 4 unit test + 3 integrasi (tier-1/2/3) hijau.

**Status model lain (per 18 Agu 2026):** `gemini-3.7-flash` 503 high-demand; `gemini-3.5-preview` & 2.5-family 404 di akun ini. ⚠ Verifikasi di AI Studio sebelum produksi penuh.

**Config:** `GEMINI_MODEL_MCQ`, `GEMINI_MODEL_SHORT`, `GEMINI_MODEL_ESSAY`, `GEMINI_MODEL_FALLBACK` di `.env`.
**Audit:** kolom `SubmissionDetail.model_used` menyimpan model yang benar-benar dipakai per soal (mendeteksi fallback aktif).

## 2. Prompt-Level Batching + Interleaved Prompting (produksi)

- **1 request = 5–15 crop** dari tipe soal yang sama (BATCH_SIZE=5, MAX=15).
- Setiap gambar di-interleave dengan instruksi tugasnya + kunci jawaban (parts: `[img1, teks1, img2, teks2, ..., perintah output]`).
- Output JSON array via `response_schema` (SDK `google.genai`), fallback ke `response_mime_type=application/json` bila ditolak.
- Routing per tipe soal → model config masing-masing (quota terpisah per model).
- **Token per request:** ~15 × 600 = ~9k input — aman untuk konteks flash.

## 3. Prompt Template (Bahasa Indonesia)

> **Pedoman menulis kunci jawaban untuk guru** (kunci = `answer_key` pada soal):
> - Alternatif jawaban benar dipisah `|` (mis. `teorema Pythagoras | a^2 + b^2 = c^2 | rumus pythagoras`)
> - **Rumus/notasi matematika setara dengan nama konsepnya** — prompt sudah mengajarkan ini,
>   tapi mencantumkan varian di kunci membuat hasil lebih stabil (contoh kasus E2E: siswa menulis
>   `a²+b²=c²` untuk kunci "teorema Pythagoras" — seharusnya diterima).
> - Sertakan ejaan/sinonim umum (mis. `fotosintesis | proses membuat makanan pada tumbuhan`).

### MCQ
```
Kamu adalah asisten koreksi ujian. Gambar ke-N berisi jawaban tulisan tangan
untuk soal pilihan ganda. Kunci jawaban: "A".
Tugas:
1. Baca huruf yang ditulis siswa (A/B/C/D). Bila ambigu atau tidak terbaca, isi
   extracted_text dengan best guess dan confidence rendah.
2. is_correct = true jika huruf cocok dengan kunci (case-insensitive).
Return JSON sesuai schema. Jangan menebak bila gambar kosong.
```

### Isian singkat
```
Gambar ke-N berisi jawaban isian singkat. Kunci jawaban: "Ibukota Indonesia | Jakarta".
Tugas:
1. Transkripsi jawaban siswa apa adanya (extracted_text).
2. similarity_score (0-100): seberapa mirip maknanya dengan kunci. Alternatif
   kunci dipisah oleh "|" — cocok dengan salah satunya sudah dianggap benar.
3. is_correct = similarity_score >= 70.
Return JSON sesuai schema.
```

### Esai
```
Gambar ke-N berisi jawaban esai. Kunci jawaban (gagasan utama):
"...<answer_key>...".
Tugas:
1. Transkripsi jawaban lengkap (extracted_text).
2. similarity_score (0-100): nilai SEMANTIK, bukan kemiripan kata demi kata.
   Beri skor parsial bila gagasan utama ada sebagian. Pertimbangkan keyword
   dalam kunci yang muncul/diparafrase.
3. reason: 1-2 kalimat kenapa skor ini (kelebihan/kekurangan jawaban).
4. is_correct = similarity_score >= 70.
Return JSON sesuai schema.
```

### JSON schema (response_schema, semua tipe)
```json
{
  "type": "ARRAY",
  "items": {
    "type": "OBJECT",
    "properties": {
      "question_number": {"type": "INTEGER"},
      "extracted_text": {"type": "STRING"},
      "similarity_score": {"type": "NUMBER"},
      "is_correct": {"type": "BOOLEAN"},
      "confidence": {"type": "NUMBER"},
      "reason": {"type": "STRING"}
    },
    "required": ["question_number", "extracted_text", "similarity_score", "is_correct"]
  }
}
```

## 4. Skor Akhir (GradingService)

```
score_per_question = overridden_score (jika manual_override) else similarity_score
total_score       = Σ (score_per_question × weight) / Σ (weight)  ×  (total_score ujian / 100)
```
- threshold `is_correct` = 70 (konstanta di config).
- Skor akhir dibulatkan 2 desimal.

## 5. Rate Limit & Resiliency

| Aspek | Kebijakan |
|---|---|
| 429 / quota | Exponential backoff (1s → 2s → 4s → 8s, cap 30s) + jitter |
| Batch gagal total | Tandai semua question `failed` → retry manual via endpoint |
| Partial gagal | Hanya question `failed` yang di-retry |
| RPD habis | `mock_mode=true` di `.env` → jawaban simulasi deterministik (app tetap bisa demo) |
| Timeout | Per call 60s; batch > 8 tidak dianjurkan (token terlalu besar) |
| Cache | Question dengan `manual_override` tidak pernah dipanggil ulang |

## 6. Mock Mode (untuk dev tanpa quota)

`services/gemini_client.py` memiliki `MockGeminiClient` yang mengembalikan hasil deterministik:
- `extracted_text` = "MOCK: ..."
- `similarity_score` = 85 (atau 50 untuk beberapa nomor acak seeded)
- Dipilih lewat setting `GEMINI_MOCK_MODE=true`.

## 7. Library

`google-generativeai` (Python SDK). SDK menangani encoding image & `response_schema`; pastikan versi SDK mendukung `response_schema` (≥ 0.7).
