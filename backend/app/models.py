from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    role: Mapped[str] = mapped_column(String(20), default="teacher")
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    classes: Mapped[list["Class"]] = relationship(back_populates="teacher")


class Class(Base):
    __tablename__ = "classes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    teacher_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String(120))
    grade_level: Mapped[str] = mapped_column(String(20))
    subject: Mapped[str] = mapped_column(String(120), default="Umum")

    teacher: Mapped[User] = relationship(back_populates="classes")
    students: Mapped[list["Student"]] = relationship(back_populates="class_", cascade="all, delete-orphan")
    exams: Mapped[list["Exam"]] = relationship(back_populates="class_", cascade="all, delete-orphan")


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    name: Mapped[str] = mapped_column(String(120))
    student_number: Mapped[str] = mapped_column(String(30))

    class_: Mapped[Class] = relationship(back_populates="students")
    submissions: Mapped[list["Submission"]] = relationship(back_populates="student")


class Exam(Base):
    __tablename__ = "exams"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"))
    title: Mapped[str] = mapped_column(String(200))
    subject: Mapped[str] = mapped_column(String(120), default="Umum")
    total_score: Mapped[int] = mapped_column(Integer, default=100)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    class_: Mapped[Class] = relationship(back_populates="exams")
    questions: Mapped[list["Question"]] = relationship(back_populates="exam", cascade="all, delete-orphan")
    submissions: Mapped[list["Submission"]] = relationship(back_populates="exam", cascade="all, delete-orphan")


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    exam_id: Mapped[int] = mapped_column(ForeignKey("exams.id"))
    question_number: Mapped[int] = mapped_column(Integer)
    type: Mapped[str] = mapped_column(String(10))  # mcq | short | essay
    answer_key: Mapped[str] = mapped_column(String(1000))
    weight: Mapped[float] = mapped_column(Float, default=1.0)
    batch_group: Mapped[str | None] = mapped_column(String(10), nullable=True)  # lite | flash

    exam: Mapped[Exam] = relationship(back_populates="questions")


class Submission(Base):
    __tablename__ = "submissions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    exam_id: Mapped[int] = mapped_column(ForeignKey("exams.id"))
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id"))
    total_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")  # pending | grading | graded | finalized
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    finalized_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    exam: Mapped[Exam] = relationship(back_populates="submissions")
    student: Mapped[Student] = relationship(back_populates="submissions")
    details: Mapped[list["SubmissionDetail"]] = relationship(back_populates="submission", cascade="all, delete-orphan")


class SubmissionDetail(Base):
    __tablename__ = "submission_details"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    submission_id: Mapped[int] = mapped_column(ForeignKey("submissions.id"))
    question_id: Mapped[int] = mapped_column(ForeignKey("questions.id"))
    image_path: Mapped[str] = mapped_column(String(500))
    student_answer_text: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    similarity_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    is_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_reasoning: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")  # pending | done | failed
    model_used: Mapped[str | None] = mapped_column(String(80), nullable=True)
    mobile_answer: Mapped[str | None] = mapped_column(String(10), nullable=True)  # hasil CV mobile (MCQ)
    mobile_ambiguous: Mapped[bool] = mapped_column(Boolean, default=False)
    manual_override: Mapped[bool] = mapped_column(Boolean, default=False)
    overridden_score: Mapped[float | None] = mapped_column(Float, nullable=True)

    submission: Mapped[Submission] = relationship(back_populates="details")
    question: Mapped[Question] = relationship()
