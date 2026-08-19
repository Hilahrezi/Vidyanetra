# 🌐 03 — Spesifikasi REST API Backend

Dokumen ini memuat kontrak endpoint REST API lengkap dari **FastAPI Backend**.
* **Base URL Lokal:** `http://localhost:8000`
* **Dokumentasi Interaktif (Swagger UI):** `http://localhost:8000/docs`
* **Dokumentasi ReDoc:** `http://localhost:8000/redoc`

---

## 🔐 1. Autentikasi & Health Check

Kecuali endpoint publik, seluruh request wajib menyertakan header:
`Authorization: Bearer <access_token>`

### `GET /health` (Publik)
* **Deskripsi:** Pengecekan kesiapan server backend.
* **Response `200 OK`:** `{"status": "ok", "time": "2026-08-19T10:00:00Z"}`

### `POST /auth/login` (Publik)
* **Deskripsi:** Login akun Guru atau Administrator.
* **Request:** `{"email": "guru@sekolah.id", "password": "rahasia123"}`
* **Response `200 OK`:**
  ```json
  {
    "access_token": "eyJhbGciOi...",
    "token_type": "bearer",
    "user": {
      "id": 1,
      "role": "teacher",
      "name": "Budi Raharjo",
      "email": "guru@sekolah.id"
    }
  }
  ```

### `GET /auth/me`
* **Deskripsi:** Mengambil profil pengguna yang sedang login.

---

## 👥 2. Manajemen Pengguna (Role-Based Access Control / RBAC)
> [!IMPORTANT]
> Seluruh endpoint di bawah ini diproteksi oleh dependency `require_admin`. Guru yang mengakses akan menerima status `403 Forbidden`.

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/users` | Mengambil daftar seluruh pengguna + jumlah kelas yang diampu (`classes_count`). |
| `POST` | `/users` | Membuat akun Admin / Guru baru (hashing bcrypt otomatis). |
| `GET` | `/users/{id}` | Mengambil detail pengguna berdasarkan ID. |
| `PUT` | `/users/{id}` | Memperbarui nama, email, password, atau role pengguna. |
| `DELETE` | `/users/{id}` | Menghapus akun pengguna (dilindungi proteksi *self-delete prevention*). |

---

## 🏫 3. Manajemen Kelas (Rombel) & Roster Siswa

### Kelas / Rombongan Belajar (`/classes`)
* `GET /classes`: Mengambil daftar kelas. Admin menerima seluruh kelas sekolah; Guru menerima kelas yang diampunya. Setiap item diperkaya dengan `teacher_name`, `students_count`, dan `exams_count`.
* `POST /classes`: Membuat kelas baru (`name`, `grade_level`, `subject`, `teacher_id` [opsional untuk admin]).
* `GET /classes/{id}`: Mengambil informasi detail satu kelas.
* `PUT /classes/{id}`: Mengubah informasi kelas atau penugasan guru.
* `DELETE /classes/{id}`: Menghapus kelas beserta seluruh data siswa dan ujian di dalamnya.

### Siswa (`/students`)
* `GET /classes/{class_id}/students`: Mengambil daftar siswa dalam kelas tersebut (diurutkan nomor absen).
* `POST /classes/{class_id}/students`: Menambahkan 1 siswa (`name`, `student_number`).
* `POST /classes/{class_id}/students/bulk`: Menambahkan daftar siswa sekaligus (*bulk import*) via array JSON:
  ```json
  [
    {"student_number": "01", "name": "Aditya Pratama"},
    {"student_number": "02", "name": "Budi Santoso"}
  ]
  ```
* `PUT /students/{id}`: Mengubah nama atau nomor absen siswa.
* `DELETE /students/{id}`: Menghapus data siswa dari kelas.

---

## 📝 4. Manajemen Ujian & Butir Soal

### Ujian (`/exams`)
* `GET /exams`: Mengambil daftar ujian (filter opsional `?class_id=X`). Diperkaya dengan `class_name`, `subject`, `submissions_count`, `finalized_count`, `total_students`, dan `average_score`.
* `POST /exams`: Membuat ujian baru (`class_id`, `title`, `subject`, `total_score` [default: 0]).
* `GET /exams/{id}`: Mengambil detail ujian beserta daftar butir soalnya.
* `PUT /exams/{id}`: Mengubah judul ujian atau mata pelajaran.
* `DELETE /exams/{id}`: Menghapus ujian beserta butir soal dan riwayat hasil koreksi.
* `GET /exams/{id}/template.pdf`: Meng-generate dan men-stream file **PDF Lembar Jawaban A4 (300 DPI)** yang siap dicetak.
* `GET /exams/{id}/export.csv`: Mengunduh rekapitulasi nilai seluruh siswa format CSV.

### Butir Soal (`/questions`)
* `POST /exams/{id}/questions`: Menambahkan butir soal baru:
  ```json
  {
    "question_number": 1,
    "type": "mcq", // "mcq" (default weight 5) | "short" (10) | "essay" (20)
    "answer_key": "A",
    "weight": 5.0
  }
  ```
  *(Catatan: Backend secara otomatis mengkalkulasi ulang `exam.total_score = sum(weight)`).*
* `PUT /questions/{id}`: Memperbarui tipe soal, kunci jawaban, atau bobot nilai soal.
* `DELETE /questions/{id}`: Menghapus butir soal (otomatis memperbarui total skor ujian).

---

## 📥 5. Pengunggahan Crop Jawaban & Penilaian AI

### `POST /submissions/upload-crops`
* **Deskripsi:** Menerima kiriman potongan gambar jawaban dari aplikasi mobile dan memicu evaluasi grading di background.
* **Payload:**
  ```json
  {
    "exam_id": 1,
    "student_id": 5,
    "crops": [
      {
        "question_number": 1,
        "image_base64": "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDA...",
        "mcq_answer": "B" // Opsional jika terdeteksi oleh Mobile Edge CV
      }
    ]
  }
  ```
* **Response `202 Accepted`:** `{"submission_id": 12, "status": "pending"}`

### `GET /submissions/{id}`
* **Deskripsi:** Mengambil status penilaian terkini dan detail evaluasi per butir soal:
  ```json
  {
    "id": 12,
    "status": "graded",
    "total_score": 85.0,
    "details": [
      {
        "question_number": 1,
        "extracted_text": "B",
        "similarity_score": 100.0,
        "is_correct": true,
        "confidence": 0.98,
        "ai_reasoning": "Jawaban siswa cocok dengan kunci.",
        "model_used": "mobile-cv",
        "image_path": "/uploads/crop_12_q1.jpg",
        "manual_override": false,
        "overridden_score": null
      }
    ]
  }
  ```

### `PUT /submissions/{id}/review`
* **Deskripsi:** Melakukan intervensi guru / pengubahan nilai manual (*manual override*):
  ```json
  {
    "items": [
      { "question_id": 1, "overridden_score": 90.0 }
    ]
  }
  ```

### `POST /submissions/{id}/retry-failed`
* **Deskripsi:** Mengulang evaluasi AI hanya untuk butir soal yang berstatus `failed` (hemat kuota).

### `POST /submissions/{id}/finalize`
* **Deskripsi:** Mengunci hasil penilaian siswa menjadi status `finalized`.

---

## 📊 6. Endpoint Analitik Asesmen

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/analytics/overview` | Ringkasan metrik global dashboard: `total_exams`, `total_classes`, `total_students`, `overall_pass_rate`, `pending_submissions_count`. |
| `GET` | `/analytics/exams/{id}/distribution` | Histogram distribusi perolehan nilai siswa (interval 10 poin). |
| `GET` | `/analytics/exams/{id}/question-difficulty` | Analisis tingkat kesulitan butir soal (rata-rata skor per nomor soal). |
