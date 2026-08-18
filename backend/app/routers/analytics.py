from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models
from ..auth import require_teacher
from ..database import get_db
from ..services.grading import effective_score
from .exams import _owned_exam

router = APIRouter(prefix="/analytics", tags=["analytics"])

FINAL_STATUSES = ("graded", "finalized")


@router.get("/exams/{exam_id}/distribution")
def score_distribution(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    _owned_exam(exam_id, teacher.id, db)
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
def question_difficulty(exam_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    _owned_exam(exam_id, teacher.id, db)
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
