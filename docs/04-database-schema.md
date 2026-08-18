# 🗄️ Database Schema

ORM: SQLAlchemy. Dev: SQLite → Produksi: PostgreSQL (perbedaan sintaks ditangani SQLAlchemy; hindari tipe SQLite-spesifik).

## Diagram Relasi (ringkas)

```
users ──1:N── classes ──1:N── students
classes ──1:N── exams ──1:N── questions
exams ──1:N── submissions ──1:N── submission_details
submissions ──N:1── students
submission_details ──N:1── questions
```

## Tabel

### `users`
| Kolom | Tipe | Ket |
|---|---|---|
| id | PK int | |
| role | str | `teacher` (default) / `admin` |
| name | str | |
| email | str unique | |
| password_hash | str | bcrypt |
| created_at | datetime | |

### `classes`
| Kolom | Tipe | Ket |
|---|---|---|
| id | PK | |
| teacher_id | FK → users.id | ownership check |
| name | str | "Kelas 8A" |
| grade_level | str | "8" |

### `students`
| Kolom | Tipe | Ket |
|---|---|---|
| id | PK | |
| class_id | FK → classes.id | |
| name | str | |
| student_number | str | nomor absen |

### `exams`
| Kolom | Tipe | Ket |
|---|---|---|
| id | PK | |
| class_id | FK → classes.id | |
| title | str | "UTS Matematika Genap" |
| total_score | int | mis. 100 |
| created_at | datetime | |

### `questions`
| Kolom | Tipe | Ket |
|---|---|---|
| id | PK | |
| exam_id | FK → exams.id | |
| question_number | int | 1..N |
| type | str enum | `mcq` / `short` / `essay` |
| answer_key | str | MCQ: "A"; isian/esai: teks, alternatif dipisah `|` |
| weight | float | bobot (mis. 5) |
| batch_group | str nullable | diisi runtime: `lite` / `flash` |

### `submissions`
| Kolom | Tipe | Ket |
|---|---|---|
| id | PK | |
| exam_id | FK | |
| student_id | FK | |
| total_score | float nullable | hasil grading |
| status | str enum | `pending` / `grading` / `graded` / `finalized` |
| created_at | datetime | |
| finalized_at | datetime nullable | |

### `submission_details`
| Kolom | Tipe | Ket |
|---|---|---|
| id | PK | |
| submission_id | FK → submissions.id | |
| question_id | FK → questions.id | |
| image_path | str | path crop tersimpan |
| student_answer_text | str nullable | hasil HWR Gemini |
| similarity_score | float nullable | 0–100 (LLM judgment) |
| is_correct | bool nullable | MCQ: benar/salah; isian/esai: threshold ≥ 70 |
| confidence | float nullable | keyakinan model |
| ai_reasoning | str nullable | penjelasan model |
| status | str enum | `pending` / `done` / `failed` |
| manual_override | bool default false | guru sudah override? |
| overridden_score | float nullable | skor pengganti dari guru |

## Penjelasan Keputusan

1. **`manual_override` + `overridden_score`** (tambahan dari architecture.md): diperlukan karena flow review/override adalah inti produk; skor final = `overridden_score` bila ada, else `similarity_score`.
2. **`status` dua level**: submission-level (keseluruhan) dan question-level (untuk partial retry bila satu batch gagal).
3. **`batch_group`** pada questions: routing Flash vs Flash-Lite dicatat agar debugging mudah, bukan logika utama.
4. **Tidak ada tabel answer key terpisah**: `answer_key` menempel pada question (satu ujian = satu kunci). Alternatif multi-kunci dipisah `|` di satu string.
5. **Siswa tidak punya login** → tidak ada tabel auth siswa; identitas via `student_number`.

## Migrasi

- Fase dev: `Base.metadata.create_all()` pada startup (auto).
- Produksi: gunakan Alembic (`alembic init`, migrations versioned) saat beralih PostgreSQL.
