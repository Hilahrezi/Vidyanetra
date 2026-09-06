from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_teacher
from ..database import get_db
from .exams import _owned_exam

router = APIRouter(tags=["questions"])


def _owned_question(question_id: int, user: models.User, db: Session) -> models.Question:
    question = db.get(models.Question, question_id)
    if question is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Soal tidak ditemukan")
    _owned_exam(question.exam_id, user, db)
    return question


def _recalculate_exam_score(exam_id: int, db: Session) -> None:
    questions = (
        db.query(models.Question)
        .filter(models.Question.exam_id == exam_id)
        .order_by(models.Question.question_number)
        .all()
    )
    if not questions:
        exam = db.get(models.Exam, exam_id)
        if exam:
            exam.total_score = 100
            db.commit()
        return

    total_weight = sum(q.weight for q in questions)
    if total_weight > 100:
        allocated = 0.0
        for i, q in enumerate(questions):
            if i == len(questions) - 1:
                q.weight = round(100.0 - allocated, 2)
            else:
                new_w = round((q.weight / total_weight) * 100.0, 2)
                q.weight = new_w
                allocated += new_w
        total_weight = 100.0

    exam = db.get(models.Exam, exam_id)
    if exam:
        exam.total_score = int(round(total_weight))
    db.commit()


@router.post("/exams/{exam_id}/questions", response_model=schemas.QuestionOut, status_code=status.HTTP_201_CREATED)
def create_question(
    exam_id: int,
    payload: schemas.QuestionCreate,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    _owned_exam(exam_id, teacher, db)
    question = models.Question(exam_id=exam_id, **payload.model_dump())
    db.add(question)
    db.commit()
    db.refresh(question)
    _recalculate_exam_score(exam_id, db)
    return question


@router.put("/questions/{question_id}", response_model=schemas.QuestionOut)
def update_question(
    question_id: int,
    payload: schemas.QuestionCreate,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    question = _owned_question(question_id, teacher, db)
    for field, value in payload.model_dump().items():
        setattr(question, field, value)
    db.commit()
    db.refresh(question)
    _recalculate_exam_score(question.exam_id, db)
    return question


@router.delete("/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_question(
    question_id: int,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    question = _owned_question(question_id, teacher, db)
    exam_id = question.exam_id
    db.delete(question)
    db.commit()
    _recalculate_exam_score(exam_id, db)
