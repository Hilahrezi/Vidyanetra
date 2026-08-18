"""Seed data development: guru, kelas, siswa, ujian, soal.

usage: python scripts/seed.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy.orm import Session

from app.auth import hash_password
from app.database import Base, SessionLocal, engine
from app.models import Class, Exam, Question, Student, User


def seed(db: Session) -> None:
    Base.metadata.create_all(bind=engine)

    if db.query(User).first():
        print("Database sudah terisi, lewati seed.")
        return

    teacher = User(name="Budi Guru", email="guru@sekolah.id", role="teacher", password_hash=hash_password("rahasia123"))
    db.add(teacher)
    db.flush()

    class_ = Class(teacher_id=teacher.id, name="Kelas 8A", grade_level="8")
    db.add(class_)
    db.flush()

    for i in range(1, 33):
        db.add(Student(class_id=class_.id, name=f"Siswa {i}", student_number=f"{i:02d}"))

    exam = Exam(class_id=class_.id, title="UTS Matematika Genap", total_score=100)
    db.add(exam)
    db.flush()

    exam_questions = [
        Question(exam_id=exam.id, question_number=1, type="mcq", answer_key="B", weight=2),
        Question(exam_id=exam.id, question_number=2, type="mcq", answer_key="A", weight=2),
        Question(exam_id=exam.id, question_number=3, type="mcq", answer_key="D", weight=2),
        Question(exam_id=exam.id, question_number=4, type="short", answer_key="akar kuadrat dari 16 | 4", weight=4),
        Question(exam_id=exam.id, question_number=5, type="short", answer_key="teorema Pythagoras | a^2 + b^2 = c^2 | rumus Pythagoras | a2 + b2 = c2", weight=4),
        Question(exam_id=exam.id, question_number=6, type="essay", answer_key="Jelaskan langkah menyelesaikan persamaan kuadrat dengan pemfaktoran: buat a=0, cari dua bilangan yang hasil kalinya c dan jumlahnya b, lalu tulis (x+p)(x+q)=0 sehingga x=-p atau x=-q", weight=10),
    ]
    db.add_all(exam_questions)

    db.commit()
    print("Seed selesai. Login: guru@sekolah.id / rahasia123")


if __name__ == "__main__":
    db = SessionLocal()
    try:
        seed(db)
    finally:
        db.close()
