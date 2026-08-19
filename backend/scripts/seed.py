"""Seed data development: admin, guru, kelas, siswa, ujian, soal.

usage:
    python scripts/seed.py          # Idempotent seed (tambah yang belum ada)
    python scripts/seed.py --reset  # Drop & recreate database bersih
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from app.auth import hash_password
from app.database import Base, SessionLocal, engine
from app.models import Class, Exam, Question, Student, User


def seed(db: Session, reset: bool = False) -> None:
    if reset:
        print("Mereset database (drop_all)...")
        Base.metadata.drop_all(bind=engine)

    Base.metadata.create_all(bind=engine)

    # Migrasi kolom subject jika tabel lama ada
    with engine.begin() as conn:
        inspector = inspect(conn)
        tables = inspector.get_table_names()
        if "classes" in tables:
            cols = [c["name"] for c in inspector.get_columns("classes")]
            if "subject" not in cols:
                conn.execute(text("ALTER TABLE classes ADD COLUMN subject VARCHAR(128) DEFAULT 'Umum'"))
        if "exams" in tables:
            cols = [c["name"] for c in inspector.get_columns("exams")]
            if "subject" not in cols:
                conn.execute(text("ALTER TABLE exams ADD COLUMN subject VARCHAR(128) DEFAULT 'Umum'"))

    # 1. Admin User
    admin = db.query(User).filter(User.email == "admin@sekolah.id").first()
    if not admin:
        admin = User(
            name="Admin Sekolah",
            email="admin@sekolah.id",
            role="admin",
            password_hash=hash_password("admin123"),
        )
        db.add(admin)
        db.flush()
        print("Akun Admin dibuat: admin@sekolah.id / admin123")
    else:
        admin.role = "admin"
        admin.password_hash = hash_password("admin123")
        db.flush()

    # 2. Teacher User
    teacher = db.query(User).filter(User.email == "guru@sekolah.id").first()
    if not teacher:
        teacher = User(
            name="Budi Guru",
            email="guru@sekolah.id",
            role="teacher",
            password_hash=hash_password("rahasia123"),
        )
        db.add(teacher)
        db.flush()
        print("Akun Guru dibuat: guru@sekolah.id / rahasia123")
    else:
        teacher.password_hash = hash_password("rahasia123")
        db.flush()

    # 3. Kelas / Rombel
    class_1 = db.query(Class).filter(Class.name == "Kelas 8A", Class.teacher_id == teacher.id).first()
    if not class_1:
        class_1 = Class(teacher_id=teacher.id, name="Kelas 8A", grade_level="8", subject="Matematika")
        db.add(class_1)
        db.flush()

    class_2 = db.query(Class).filter(Class.name == "Kelas 8B", Class.teacher_id == teacher.id).first()
    if not class_2:
        class_2 = Class(teacher_id=teacher.id, name="Kelas 8B", grade_level="8", subject="IPA")
        db.add(class_2)
        db.flush()

    class_3 = db.query(Class).filter(Class.name == "Kelas 9A", Class.teacher_id == teacher.id).first()
    if not class_3:
        class_3 = Class(teacher_id=teacher.id, name="Kelas 9A", grade_level="9", subject="Bahasa Indonesia")
        db.add(class_3)
        db.flush()

    # 4. Siswa
    for c in [class_1, class_2, class_3]:
        count = db.query(Student).filter(Student.class_id == c.id).count()
        if count == 0:
            for i in range(1, 31):
                db.add(Student(class_id=c.id, name=f"Siswa {i}", student_number=f"{i:02d}"))
            db.flush()

    # 5. Ujian & Soal
    exam_1 = db.query(Exam).filter(Exam.class_id == class_1.id, Exam.title == "UTS Matematika Genap").first()
    if not exam_1:
        exam_1 = Exam(class_id=class_1.id, title="UTS Matematika Genap", subject="Matematika", total_score=100)
        db.add(exam_1)
        db.flush()
        db.add_all([
            Question(exam_id=exam_1.id, question_number=1, type="mcq", answer_key="B", weight=5),
            Question(exam_id=exam_1.id, question_number=2, type="mcq", answer_key="A", weight=5),
            Question(exam_id=exam_1.id, question_number=3, type="mcq", answer_key="D", weight=5),
            Question(exam_id=exam_1.id, question_number=4, type="short", answer_key="akar kuadrat dari 16 | 4", weight=10),
            Question(exam_id=exam_1.id, question_number=5, type="short", answer_key="teorema Pythagoras | a^2 + b^2 = c^2 | rumus Pythagoras | a2 + b2 = c2", weight=10),
            Question(exam_id=exam_1.id, question_number=6, type="essay", answer_key="Jelaskan langkah menyelesaikan persamaan kuadrat dengan pemfaktoran: buat a=0, cari dua bilangan yang hasil kalinya c dan jumlahnya b, lalu tulis (x+p)(x+q)=0 sehingga x=-p atau x=-q", weight=20),
        ])

    exam_2 = db.query(Exam).filter(Exam.class_id == class_2.id, Exam.title == "Ulangan Harian Ekosistem").first()
    if not exam_2:
        exam_2 = Exam(class_id=class_2.id, title="Ulangan Harian Ekosistem", subject="IPA", total_score=60)
        db.add(exam_2)
        db.flush()
        db.add_all([
            Question(exam_id=exam_2.id, question_number=1, type="mcq", answer_key="C", weight=5),
            Question(exam_id=exam_2.id, question_number=2, type="short", answer_key="fotosintesis | reaksi fotosintesis", weight=10),
        ])

    db.commit()
    print("Seed selesai dengan sukses!")
    print("  -> Admin: admin@sekolah.id / admin123")
    print("  -> Guru:  guru@sekolah.id / rahasia123")


if __name__ == "__main__":
    reset_flag = "--reset" in sys.argv
    db = SessionLocal()
    try:
        seed(db, reset=reset_flag)
    finally:
        db.close()
