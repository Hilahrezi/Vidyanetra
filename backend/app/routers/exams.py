import csv
import io
import shutil
import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_teacher
from ..config import settings
from ..database import get_db
from ..services.grading import effective_score
from ..services.template_service import build_pdf

router = APIRouter(prefix="/exams", tags=["exams"])


def _owned_exam(exam_id: int, user: models.User, db: Session) -> models.Exam:
    exam = db.get(models.Exam, exam_id)
    if exam is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ujian tidak ditemukan")
    if user.role != "admin":
        class_ = db.get(models.Class, exam.class_id)
        if class_ is None or class_.teacher_id != user.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ujian tidak ditemukan")
    return exam


def _enrich_exam(exam: models.Exam, db: Session) -> schemas.ExamOut:
    class_ = db.get(models.Class, exam.class_id)
    subject = exam.subject or (class_.subject if class_ else "Umum")
    class_name = class_.name if class_ else None
    formatted_class_name = (
        f"{subject} — {class_name}"
        if class_name and not class_name.startswith(f"{subject} — ")
        else (class_name or "Kelas")
    )
    total_students = db.query(models.Student).filter(models.Student.class_id == exam.class_id).count()

    subs = db.query(models.Submission).filter(models.Submission.exam_id == exam.id).all()
    submissions_count = len(subs)
    finalized_count = sum(1 for s in subs if s.status == "finalized")
    scores = [s.total_score for s in subs if s.total_score is not None]
    avg_score = round(sum(scores) / len(scores), 1) if scores else None

    return schemas.ExamOut(
        id=exam.id,
        class_id=exam.class_id,
        title=exam.title,
        total_score=exam.total_score,
        class_name=formatted_class_name,
        subject=subject,
        submissions_count=submissions_count,
        finalized_count=finalized_count,
        total_students=total_students,
        average_score=avg_score,
    )


@router.get("", response_model=list[schemas.ExamOut])
def list_exams(
    class_id: int | None = None,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    if user.role == "admin":
        query = db.query(models.Exam)
    else:
        query = db.query(models.Exam).join(models.Class).filter(models.Class.teacher_id == user.id)

    if class_id is not None:
        query = query.filter(models.Exam.class_id == class_id)
    exams = query.all()
    if not exams:
        return []

    exam_ids = [e.id for e in exams]
    class_ids = list({e.class_id for e in exams})

    # 1 Query untuk ambil semua kelas terkait
    classes = {c.id: c for c in db.query(models.Class).filter(models.Class.id.in_(class_ids)).all()}

    # 1 Query agregasi hitung total siswa per kelas
    student_counts_raw = (
        db.query(models.Student.class_id, func.count(models.Student.id))
        .filter(models.Student.class_id.in_(class_ids))
        .group_by(models.Student.class_id)
        .all()
    )
    student_counts = dict(student_counts_raw)

    # 1 Query untuk ambil semua submissions terkait
    subs_by_exam: dict[int, list[models.Submission]] = {eid: [] for eid in exam_ids}
    all_subs = db.query(models.Submission).filter(models.Submission.exam_id.in_(exam_ids)).all()
    for s in all_subs:
        subs_by_exam[s.exam_id].append(s)

    result: list[schemas.ExamOut] = []
    for exam in exams:
        class_ = classes.get(exam.class_id)
        subject = exam.subject or (class_.subject if class_ else "Umum")
        class_name = class_.name if class_ else None
        formatted_class_name = (
            f"{subject} — {class_name}"
            if class_name and not class_name.startswith(f"{subject} — ")
            else (class_name or "Kelas")
        )
        total_students = student_counts.get(exam.class_id, 0)
        subs = subs_by_exam.get(exam.id, [])
        submissions_count = len(subs)
        finalized_count = sum(1 for s in subs if s.status == "finalized")
        scores = [s.total_score for s in subs if s.total_score is not None]
        avg_score = round(sum(scores) / len(scores), 1) if scores else None

        result.append(
            schemas.ExamOut(
                id=exam.id,
                class_id=exam.class_id,
                title=exam.title,
                total_score=exam.total_score,
                class_name=formatted_class_name,
                subject=subject,
                submissions_count=submissions_count,
                finalized_count=finalized_count,
                total_students=total_students,
                average_score=avg_score,
            )
        )
    return result


@router.post("", response_model=schemas.ExamOut, status_code=status.HTTP_201_CREATED)
def create_exam(
    payload: schemas.ExamCreate,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    class_ = db.get(models.Class, payload.class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")
    if user.role != "admin" and class_.teacher_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")

    data = payload.model_dump()
    if not data.get("subject") or data.get("subject") == "Umum":
        data["subject"] = class_.subject or "Umum"
    exam = models.Exam(**data)
    db.add(exam)
    db.commit()
    db.refresh(exam)
    return _enrich_exam(exam, db)


@router.get("/{exam_id}", response_model=schemas.ExamOut)
def get_exam(
    exam_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    exam = _owned_exam(exam_id, user, db)
    return _enrich_exam(exam, db)


@router.get("/{exam_id}/questions", response_model=list[schemas.QuestionOut])
def list_questions(
    exam_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    _owned_exam(exam_id, user, db)
    return (
        db.query(models.Question)
        .filter(models.Question.exam_id == exam_id)
        .order_by(models.Question.question_number)
        .all()
    )


@router.get("/{exam_id}/submissions", response_model=list[schemas.ExamSubmissionOut])
def list_exam_submissions(
    exam_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    _owned_exam(exam_id, user, db)
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
            student_name=s.student.name if s.student else None,
            student_number=s.student.student_number if s.student else None,
        )
        for s in submissions
    ]


@router.get("/{exam_id}/export.csv")
def export_exam_csv(
    exam_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    exam = _owned_exam(exam_id, user, db)
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
    writer.writerow(
        ["No Absen", "Nama", "Status"]
        + [f"Soal {q.question_number}" for q in questions]
        + ["Total"]
    )

    for s in submissions:
        score_by_question = {}
        for d in s.details:
            score_by_question[d.question_id] = (
                effective_score(d) if d.status == "done" or d.manual_override else ""
            )
        row = [
            s.student.student_number if s.student else "",
            s.student.name if s.student else "",
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
def get_exam_template_pdf(
    exam_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    exam = _owned_exam(exam_id, user, db)
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
def update_exam(
    exam_id: int,
    payload: schemas.ExamCreate,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    exam = _owned_exam(exam_id, user, db)
    exam.title = payload.title
    exam.total_score = payload.total_score
    if payload.subject:
        exam.subject = payload.subject
    db.commit()
    db.refresh(exam)
    return _enrich_exam(exam, db)


@router.delete("/{exam_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_exam(
    exam_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    exam = _owned_exam(exam_id, user, db)

    subs = db.query(models.Submission.id).filter(models.Submission.exam_id == exam_id).all()
    for (sub_id,) in subs:
        folder = settings.upload_path / f"sub_{sub_id}"
        if folder.exists():
            shutil.rmtree(folder, ignore_errors=True)

    db.delete(exam)
    db.commit()
