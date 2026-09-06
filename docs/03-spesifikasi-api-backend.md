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
* `GET /exams/{id}/submissions`: Mengambil seluruh lembar jawaban siswa pada ujian terkait (termasuk nomor absen, nama siswa, status pengerjaan, dan total skor).

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
* **Deskripsi:** Menerima kiriman potongan gambar jawaban dari aplikasi mobile dan memicu evaluasi grading di background (`BackgroundTasks`).
* **Batasan Ukuran (Payload Limit):** Maksimal **5 MB** total per request (`MAX_PAYLOAD_BYTES`).
* **Validasi Soal:** Seluruh butir soal ujian wajib ada dalam payload (`missing_crops` memicu HTTP `422`).
* **Payload:**
  ```json
  {
    "exam_id": 1,
    "student_id": 5,
    "crops": [
      {
        "question_number": 1,
        "image_base64": "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDA...",
        "mcq_answer": "b",       // Opsional jika terdeteksi oleh Mobile Edge CV
        "mcq_ambiguous": false   // true jika deteksi mobile ragu (memicu tier-2/3)
      }
    ]
  }
  ```
* **Response `202 Accepted`:** `{"id": 12, "exam_id": 1, "student_id": 5, "status": "pending", ...}`

### `GET /submissions/{id}`
* **Deskripsi:** Mengambil status penilaian dasar dan total skor lembar jawaban.

### `GET /submissions/{id}/details`
* **Deskripsi:** Mengambil status penilaian lengkap beserta detail evaluasi per butir soal:
  ```json
  {
    "id": 12,
    "exam_id": 1,
    "student_id": 5,
    "student_name": "Aditya Pratama",
    "status": "graded",
    "total_score": 85.0,
    "created_at": "2026-08-19T10:00:00Z",
    "finalized_at": null,
    "details": [
      {
        "id": 101,
        "question_id": 1,
        "question_number": 1,
        "type": "mcq",
        "image_url": "/uploads/sub_12/q1_a1b2c3d4.jpg",
        "student_answer_text": "b",
        "similarity_score": 100.0,
        "is_correct": true,
        "confidence": 0.98,
        "ai_reasoning": "Deteksi tanda X di aplikasi (tier-1 mobile, CV lokal).",
        "status": "done",
        "model_used": "mobile-cv",
        "mobile_answer": "b",
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
* **Deskripsi:** Mengunci hasil penilaian siswa menjadi status `finalized` dan menghitung skor akhir terbobot (`compute_total_score`).

---

## 📊 6. Endpoint Analitik Asesmen

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/analytics/overview` | Ringkasan metrik global dashboard: `total_exams`, `total_classes`, `total_students`, `overall_pass_rate`, `pending_submissions_count`, `recent_submissions_count`. |
| `GET` | `/analytics/exams/{id}/distribution` | Histogram distribusi perolehan nilai siswa (10 bucket: `0-9`, `10-19`, $\dots$, `90-100`). |
| `GET` | `/analytics/exams/{id}/question-difficulty` | Analisis tingkat kesulitan butir soal (bobot, jumlah siswa mencoba, dan rata-rata skor per nomor). |

---

## 🛡️ 7. Konfigurasi Jaringan & Middleware Startup

### Kebijakan CORS Dinamis
Backend FastAPI secara default mengizinkan origin:
- `http://localhost:3000` & `http://127.0.0.1:3000`
- Regex Origin: `https?://(localhost|127\.0\.0\.1|.*\.vercel\.app|100\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+)?`
- Nilai kustom tambahan melalui environment variable `CORS_ORIGINS`.

### Lifecycle Auto-Migration (`_auto_migrate_and_seed`)
Saat server FastAPI dimulai (*cold start*), sistem secara otomatis:
1. Menjalankan `Base.metadata.create_all()` untuk membuat tabel jika belum ada.
2. Memeriksa keberadaan kolom `subject` pada tabel `classes` dan `exams`, serta menjalankan dynamic `ALTER TABLE` jika kolom belum tersedia.
3. Melakukan seeding default akun Admin (`admin@sekolah.id` / `admin123`) dan Guru (`guru@sekolah.id` / `rahasia123`) jika database masih kosong.
