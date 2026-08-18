# 🌐 API Specification — Backend FastAPI

Semua endpoint REST JSON. Base URL dev: `http://localhost:8000`. Docs interaktif: `/docs` (Swagger UI).

## Autentikasi

Semua endpoint (kecuali `POST /auth/login` dan `/health`) butuh header:
```
Authorization: Bearer <token>
```

### `POST /auth/login`
```json
// Request
{ "email": "guru@sekolah.id", "password": "secret" }
// Response 200
{ "access_token": "<jwt>", "token_type": "bearer", "user": { "id": 1, "name": "Budi", "email": "..." } }
```

### `GET /health` — health check (public)

## CRUD Master Data

| Method | Path | Deskripsi |
|---|---|---|
| GET | `/classes` | Daftar kelas guru |
| POST | `/classes` | Buat kelas |
| GET | `/classes/{id}` | Detail kelas + siswa |
| PUT | `/classes/{id}` | Update kelas |
| DELETE | `/classes/{id}` | Hapus kelas |
| GET | `/classes/{id}/students` | Daftar siswa kelas |
| POST | `/classes/{id}/students` | Tambah siswa (single) |
| POST | `/classes/{id}/students/bulk` | Tambah banyak siswa (array) |
| PUT | `/students/{id}` | Update siswa |
| DELETE | `/students/{id}` | Hapus siswa |
| GET | `/exams?class_id=` | Daftar ujian |
| POST | `/exams` | Buat ujian (title, class_id, total_score) |
| GET | `/exams/{id}` | Detail ujian + daftar soal |
| PUT | `/exams/{id}` | Update ujian |
| DELETE | `/exams/{id}` | Hapus ujian (+ soal & submission terkait) |
| GET | `/exams/{id}/questions` | Daftar soal ujian |
| POST | `/exams/{id}/questions` | Tambah soal |
| PUT | `/questions/{id}` | Update soal (termasuk answer_key) |
| DELETE | `/questions/{id}` | Hapus soal |

**Payload soal:**
```json
{ "question_number": 1, "type": "mcq" | "short" | "essay",
  "answer_key": "A | 42 | rumus + kata kunci (pipe = alternatif)",
  "weight": 5 }
```

## Submission & Koreksi AI

### `POST /submissions/upload-crops`
Mengirim crop jawaban + identitas siswa → trigger evaluasi AI.

```json
{
  "exam_id": 3,
  "student_id": 12,
  "crops": [
    { "question_number": 1, "image_base64": "<data>" },
    { "question_number": 2, "image_base64": "<data>" }
  ]
}
```
**Response 202 Accepted:** `{ "submission_id": 55, "status": "pending" }`
Evaluasi berjalan async (background task); client polling status.

### `GET /submissions/{id}`
Detail submission: siswa, status, per-question hasil AI (extracted_text, score, is_correct, reason, confidence) + gambar crop URL.

### `GET /exams/{id}/submissions`
Daftar submission per ujian (untuk dashboard & review mobile).

### `PUT /submissions/{id}/review`
Manual override per soal sebelum finalisasi.
```json
{ "items": [ { "question_id": 5, "overridden_score": 80 } ] }
```

### `POST /submissions/{id}/retry-failed`
Retry hanya question yang status `failed` (partial retry, hemat quota; evaluasi async).
- **202 Accepted** — evaluasi ulang dijalankan di background.
- **409** — tidak ada soal `failed`, atau submission sudah `finalized`.

### `POST /submissions/{id}/finalize`
Set status `finalized` (mengunci hasil; skor akhir dihitung ulang dari override).

### `POST /submissions/{id}/retry-failed`
Retry hanya question yang status `failed` (partial retry, hemat quota).

## Web Dashboard

| Method | Path | Deskripsi |
|---|---|---|
| GET | `/analytics/exams/{id}/distribution` | Distribusi nilai (buckets 10) |
| GET | `/analytics/exams/{id}/question-difficulty` | Rata-rata skor per soal |
| GET | `/exams/{id}/export.csv` | Export nilai CSV (per kelas, per soal, total) |

## Kode Error Standar

- `401` — token invalid/kadaluarsa
- `403` — bukan pemilik resource (checks: class_id milik guru login)
- `404` — resource tidak ditemukan
- `422` — validasi payload gagal
- `429` — kuota Gemini habis (dengan `Retry-After`)
- `5xx` — error internal / Gemini failure (retry client-side)

## Catatan Implementasi

- Semua gambar crop disimpan di `backend/uploads/`, URL disajikan via static mount `/uploads/...`.
- Evaluasi AI berjalan di `BackgroundTasks` FastAPI (tidak memblokir response).
- Status submission: `pending → grading → graded → finalized`.
- Status per question: `pending | done | failed`.
