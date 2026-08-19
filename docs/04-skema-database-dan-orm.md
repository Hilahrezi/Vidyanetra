# 🗄️ 04 — Skema Database & SQLAlchemy ORM

Dokumen ini mendokumentasikan skema database relasional, definisi tabel, hubungan kunci asing (*foreign keys*), relasi penghapusan berkaskade (*cascade delete*), dan pemetaan ORM pada sistem **AutoGrading**.

---

## 1. Diagram Relasi Entitas (ERD)

```mermaid
erDiagram
    users ||--o{ classes : "mengampu / memiliki"
    classes ||--o{ students : "terdiri dari"
    classes ||--o{ exams : "memiliki ujian"
    exams ||--o{ questions : "memiliki butir soal"
    exams ||--o{ submissions : "memiliki lembar jawaban"
    students ||--o{ submissions : "dikerjakan oleh"
    submissions ||--o{ submission_details : "rincian per butir"
    questions ||--o{ submission_details : "dievaluasi terhadap"

    users {
        int id PK
        string role "admin / teacher"
        string name
        string email UK
        string password_hash
        datetime created_at
    }

    classes {
        int id PK
        int teacher_id FK
        string name "mis. Kelas 8A"
        string grade_level "mis. 8"
        string subject "mis. Matematika"
    }

    students {
        int id PK
        int class_id FK
        string name
        string student_number "No. Absen"
    }

    exams {
        int id PK
        int class_id FK
        string title
        string subject
        int total_score "Auto-Calculated Sum"
        datetime created_at
    }

    questions {
        int id PK
        int exam_id FK
        int question_number
        string type "mcq / short / essay"
        string answer_key
        float weight "mis. 5 / 10 / 20"
        string batch_group
    }

    submissions {
        int id PK
        int exam_id FK
        int student_id FK
        float total_score
        string status "pending / grading / graded / finalized"
        datetime created_at
        datetime finalized_at
    }

    submission_details {
        int id PK
        int submission_id FK
        int question_id FK
        string image_path
        string student_answer_text
        float similarity_score
        boolean is_correct
        float confidence
        string ai_reasoning
        string model_used "mobile-cv / cv-mcq / gemini-*"
        string status "pending / done / failed"
        boolean manual_override
        float overridden_score
    }
```

---

## 2. Rincian Kamus Data Tabel

### Tabel `users`
| Kolom | Tipe Data | Nullable | Keterangan |
|---|---|:---:|---|
| `id` | `INTEGER` (PK) | ❌ | Primary Key otomatis. |
| `role` | `VARCHAR(32)` | ❌ | Peran akun: `admin` (Administrator) atau `teacher` (Guru Pengampu). |
| `name` | `VARCHAR(128)` | ❌ | Nama lengkap pengguna beserta gelar. |
| `email` | `VARCHAR(128)` | ❌ | Email unik untuk login sistem. |
| `password_hash` | `VARCHAR(256)` | ❌ | Hash kata sandi menggunakan algoritma `bcrypt`. |
| `created_at` | `DATETIME` | ❌ | Timestamp pembuatan akun. |

### Tabel `classes`
| Kolom | Tipe Data | Nullable | Keterangan |
|---|---|:---:|---|
| `id` | `INTEGER` (PK) | ❌ | Primary Key kelas / rombongan belajar. |
| `teacher_id` | `INTEGER` (FK) | ❌ | Terikat ke `users.id` guru pengampu kelas. |
| `name` | `VARCHAR(64)` | ❌ | Nama rombel (misal: `"8A"`, `"9B"`). |
| `grade_level` | `VARCHAR(32)` | ❌ | Tingkat pendidikan (misal: `"8"`). |
| `subject` | `VARCHAR(128)` | ❌ | Mata pelajaran kurikulum (misal: `"Matematika"`, `"IPA"`). |

### Tabel `students`
| Kolom | Tipe Data | Nullable | Keterangan |
|---|---|:---:|---|
| `id` | `INTEGER` (PK) | ❌ | Primary Key siswa. |
| `class_id` | `INTEGER` (FK) | ❌ | Terikat ke `classes.id`. *Cascade Delete*. |
| `name` | `VARCHAR(128)` | ❌ | Nama lengkap siswa. |
| `student_number` | `VARCHAR(32)` | ❌ | Nomor absen siswa (dicetak pada LJK). |

### Tabel `exams`
| Kolom | Tipe Data | Nullable | Keterangan |
|---|---|:---:|---|
| `id` | `INTEGER` (PK) | ❌ | Primary Key ujian. |
| `class_id` | `INTEGER` (FK) | ❌ | Terikat ke `classes.id`. *Cascade Delete*. |
| `title` | `VARCHAR(128)` | ❌ | Judul ujian (misal: `"UTS Aljabar Genap"`). |
| `subject` | `VARCHAR(128)` | ❌ | Mata pelajaran ujian. |
| `total_score` | `INTEGER` | ❌ | Akumulasi total skor (dihitung otomatis dari $\sum \text{weight}$ butir soal). |
| `created_at` | `DATETIME` | ❌ | Waktu pembuatan ujian. |

### Tabel `questions`
| Kolom | Tipe Data | Nullable | Keterangan |
|---|---|:---:|---|
| `id` | `INTEGER` (PK) | ❌ | Primary Key butir soal. |
| `exam_id` | `INTEGER` (FK) | ❌ | Terikat ke `exams.id`. *Cascade Delete*. |
| `question_number` | `INTEGER` | ❌ | Nomor urut soal ($1, 2, 3, \dots, N$). |
| `type` | `VARCHAR(16)` | ❌ | Tipe butir soal: `mcq`, `short`, atau `essay`. |
| `answer_key` | `TEXT` | ❌ | Kunci jawaban acuan (alternatif dipisah dengan `|`). |
| `weight` | `FLOAT` | ❌ | Bobot nilai butir soal (default: MCQ=5, Short=10, Essay=20). |
| `batch_group` | `VARCHAR(16)` | ✅ | Penandaan grup eksekusi AI runtime (`lite` / `flash`). |

### Tabel `submissions`
| Kolom | Tipe Data | Nullable | Keterangan |
|---|---|:---:|---|
| `id` | `INTEGER` (PK) | ❌ | Primary Key lembar jawaban siswa. |
| `exam_id` | `INTEGER` (FK) | ❌ | Terikat ke `exams.id`. |
| `student_id` | `INTEGER` (FK) | ❌ | Terikat ke `students.id`. |
| `total_score` | `FLOAT` | ✅ | Nilai akhir ujian siswa setelah evaluasi AI & override. |
| `status` | `VARCHAR(16)` | ❌ | Status pengerjaan: `pending`, `grading`, `graded`, `finalized`. |
| `created_at` | `DATETIME` | ❌ | Waktu pemindaian lembar jawaban. |
| `finalized_at` | `DATETIME` | ✅ | Waktu penguncian nilai oleh guru. |

### Tabel `submission_details`
| Kolom | Tipe Data | Nullable | Keterangan |
|---|---|:---:|---|
| `id` | `INTEGER` (PK) | ❌ | Primary Key rincian jawaban per butir. |
| `submission_id` | `INTEGER` (FK) | ❌ | Terikat ke `submissions.id`. *Cascade Delete*. |
| `question_id` | `INTEGER` (FK) | ❌ | Terikat ke `questions.id`. |
| `image_path` | `VARCHAR(256)` | ❌ | Lokasi file gambar potongan kotak jawaban tersimpan di server. |
| `student_answer_text` | `TEXT` | ✅ | Teks transkripsi hasil pembacaan AI (*HWR*). |
| `similarity_score` | `FLOAT` | ✅ | Skor kemiripan semantik terhadap kunci ($0\text{--}100$). |
| `is_correct` | `BOOLEAN` | ✅ | `true` jika skor $\ge \text{threshold}$ ($70$), `false` jika sebaliknya. |
| `confidence` | `FLOAT` | ✅ | Tingkat keyakinan model AI ($0.0\text{--}1.0$). |
| `ai_reasoning` | `TEXT` | ✅ | Penjelasan penalaran penilaian dari model AI. |
| `model_used` | `VARCHAR(32)` | ✅ | Penanda mesin penilai: `mobile-cv`, `cv-mcq`, atau nama model Gemini. |
| `status` | `VARCHAR(16)` | ❌ | Status per butir: `pending`, `done`, atau `failed`. |
| `manual_override` | `BOOLEAN` | ❌ | Penanda apakah nilai telah diubah manual oleh guru (`false` default). |
| `overridden_score` | `FLOAT` | ✅ | Nilai pengganti hasil intervensi manual guru. |
