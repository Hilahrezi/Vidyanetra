from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_teacher
from ..database import get_db
from ..services.grading import effective_score
from .exams import _owned_exam

router = APIRouter(prefix="/analytics", tags=["analytics"])

FINAL_STATUSES = ("graded", "finalized")


@router.get("/overview", response_model=schemas.DashboardOverview)
def dashboard_overview(
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    if teacher.role == "admin":
        classes = db.query(models.Class).all()
    else:
        classes = db.query(models.Class).filter(models.Class.teacher_id == teacher.id).all()

    class_ids = [c.id for c in classes]

    total_classes = len(classes)
    total_students = (
        db.query(models.Student).filter(models.Student.class_id.in_(class_ids)).count()
        if class_ids
        else 0
    )

    if teacher.role == "admin":
        exams = db.query(models.Exam).all()
    else:
        exams = (
            db.query(models.Exam).filter(models.Exam.class_id.in_(class_ids)).all()
            if class_ids
            else []
        )

    exam_ids = [e.id for e in exams]
    total_exams = len(exams)

    all_subs = (
        db.query(models.Submission).filter(models.Submission.exam_id.in_(exam_ids)).all()
        if exam_ids
        else []
    )

    pending_count = sum(1 for s in all_subs if s.status == "pending")
    graded_subs = [s for s in all_subs if s.status in FINAL_STATUSES and s.total_score is not None]

    # Calculate overall pass rate (score >= 70% of exam total)
    exam_map = {e.id: e.total_score for e in exams}
    passed_count = sum(
        1 for s in graded_subs if s.total_score >= (exam_map.get(s.exam_id, 100) * 0.7)
    )
    overall_pass_rate = (
        round((passed_count / len(graded_subs)) * 100, 1) if graded_subs else 100.0
    )

    return schemas.DashboardOverview(
        total_exams=total_exams,
        total_classes=total_classes,
        total_students=total_students,
        overall_pass_rate=overall_pass_rate,
        pending_submissions_count=pending_count,
        recent_submissions_count=len(all_subs),
    )


@router.get("/exams/{exam_id}/distribution")
def score_distribution(
    exam_id: int,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    _owned_exam(exam_id, teacher, db)
    submissions = (
        db.query(models.Submission)
        .filter(models.Submission.exam_id == exam_id, models.Submission.status.in_(FINAL_STATUSES))
        .all()
    )
    buckets = [{"range": f"{i * 10}-{i * 10 + 9}" if i < 9 else "90-100", "count": 0} for i in range(10)]
    for s in submissions:
        score = s.total_score or 0.0
        index = min(9, int(score // 10))
        buckets[index]["count"] += 1
    return {"exam_id": exam_id, "total": len(submissions), "buckets": buckets}


@router.get("/exams/{exam_id}/question-difficulty")
def question_difficulty(
    exam_id: int,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    _owned_exam(exam_id, teacher, db)
    questions = (
        db.query(models.Question)
        .filter(models.Question.exam_id == exam_id)
        .order_by(models.Question.question_number)
        .all()
    )

    result = []
    for q in questions:
        details = (
            db.query(models.SubmissionDetail)
            .join(models.Submission, models.Submission.id == models.SubmissionDetail.submission_id)
            .filter(
                models.SubmissionDetail.question_id == q.id,
                models.Submission.status.in_(FINAL_STATUSES),
            )
            .all()
        )
        scores = [effective_score(d) for d in details if effective_score(d) is not None]
        result.append(
            {
                "question_number": q.question_number,
                "type": q.type,
                "weight": q.weight,
                "attempted": len(scores),
                "average_score": round(sum(scores) / len(scores), 2) if scores else None,
            }
        )
    return {"exam_id": exam_id, "questions": result}
