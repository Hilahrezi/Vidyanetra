import csv
import io
import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_teacher
from ..database import get_db
from ..services.grading import effective_score
from ..services.template_service import build_pdf

router = APIRouter(prefix="/exams", tags=["exams"])


def _owned_exam(exam_id: int, teacher_id: int, db: Session) -> models.Exam:
    exam = db.get(models.Exam, exam_id)
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ujian tidak ditemukan")
    class_ = db.get(models.Class, exam.class_id)
    if class_ is None or class_.teacher_id != teacher_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ujian tidak ditemukan")
    return exam


@router.get("", response_model=list[schemas.ExamOut])
def list_exams(class_id: int | None = None, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    query = db.query(models.Exam)
    if class_id is not None:
        query = query.filter(models.Exam.class_id == class_id)
    return query.all()


@router.post("", response_model=schemas.ExamOut, status_code=status.HTTP_201_CREATED)
def create_exam(payload: schemas.ExamCreate, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    class_ = db.get(models.Class, payload.class_id)
    if class_ is None or class_.teacher_id != teacher.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")
    exam = models.Exam(**payload.model_dump())
    db.add(exam)
    db.commit()
    db.refresh(exam)
    return exam


@router.get("/{exam_id}", response_model=schemas.ExamOut)
def get_exam(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    return _owned_exam(exam_id, teacher.id, db)


@router.get("/{exam_id}/questions", response_model=list[schemas.QuestionOut])
def list_questions(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    _owned_exam(exam_id, teacher.id, db)
    return db.query(models.Question).filter(models.Question.exam_id == exam_id).order_by(models.Question.question_number).all()


@router.get("/{exam_id}/submissions", response_model=list[schemas.ExamSubmissionOut])
def list_exam_submissions(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    _owned_exam(exam_id, teacher.id, db)
    submissions = (
        db.query(models.Submission)
        .filter(models.Submission.exam_id == exam_id)
        .order_by(models.Submission.created_at)
        .all()
    )
    return [
        schemas.ExamSubmissionOut(
            id=s.id,
            exam_id=s.exam_id,
            student_id=s.student_id,
            total_score=s.total_score,
            status=s.status,
            created_at=s.created_at,
            finalized_at=s.finalized_at,
            student_name=s.student.name,
            student_number=s.student.student_number,
        )
        for s in submissions
    ]


@router.get("/{exam_id}/export.csv")
def export_exam_csv(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    exam = _owned_exam(exam_id, teacher.id, db)
    questions = (
        db.query(models.Question)
        .filter(models.Question.exam_id == exam_id)
        .order_by(models.Question.question_number)
        .all()
    )
    submissions = (
        db.query(models.Submission)
        .filter(models.Submission.exam_id == exam_id)
        .order_by(models.Submission.created_at)
        .all()
    )

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["No Absen", "Nama", "Status"] + [f"Soal {q.question_number}" for q in questions] + ["Total"])

    for s in submissions:
        score_by_question = {}
        for d in s.details:
            score_by_question[d.question_id] = effective_score(d) if d.status == "done" or d.manual_override else ""
        row = [
            s.student.student_number,
            s.student.name,
            s.status,
        ]
        row += [score_by_question.get(q.id, "") for q in questions]
        row.append(s.total_score if s.total_score is not None else "")
        writer.writerow(row)

    csv_data = buffer.getvalue()
    return Response(
        content=csv_data,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename=export_exam_{exam_id}.csv"},
    )


@router.get("/{exam_id}/template.pdf")
def get_exam_template_pdf(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    exam = _owned_exam(exam_id, teacher.id, db)
    class_ = db.get(models.Class, exam.class_id)
    class_name = class_.name if class_ else "Kelas"

    questions = (
        db.query(models.Question)
        .filter(models.Question.exam_id == exam_id)
        .order_by(models.Question.question_number)
        .all()
    )
    if not questions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ujian belum memiliki butir soal. Tambahkan soal terlebih dahulu.",
        )

    question_types = [q.type for q in questions]

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        tmp_path = Path(tmp.name)

    try:
        build_pdf(question_types, title=exam.title, class_name=class_name, out_pdf=tmp_path)
        pdf_bytes = tmp_path.read_bytes()
    finally:
        tmp_path.unlink(missing_ok=True)

    filename = f"lembar_jawaban_exam_{exam_id}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.put("/{exam_id}", response_model=schemas.ExamOut)
def update_exam(exam_id: int, payload: schemas.ExamCreate, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    exam = _owned_exam(exam_id, teacher.id, db)
    exam.title = payload.title
    exam.total_score = payload.total_score
    db.commit()
    db.refresh(exam)
    return exam


@router.delete("/{exam_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_exam(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    exam = _owned_exam(exam_id, teacher.id, db)
    db.delete(exam)
    db.commit()

