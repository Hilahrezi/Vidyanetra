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
    total = (
        db.query(func.sum(models.Question.weight))
        .filter(models.Question.exam_id == exam_id)
        .scalar()
        or 0
    )
    exam = db.get(models.Exam, exam_id)
    if exam:
        exam.total_score = int(round(total))
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
