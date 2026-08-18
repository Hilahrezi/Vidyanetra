"""Perhitungan skor akhir dan penulisan hasil AI ke database."""

import logging

from sqlalchemy.orm import Session

from .. import models
from ..config import settings
from ..models import Submission, SubmissionDetail

logger = logging.getLogger(__name__)


def apply_gemini_results(db: Session, results: list[dict]) -> None:
    """Tulis hasil AI (satu batch) ke SubmissionDetail; gagal -> status failed."""
    for result in results:
        submission_id = result.get("submission_id")
        question_number = result.get("question_number")
        if submission_id is None or question_number is None:
            logger.warning("Hasil AI tanpa submission_id/question_number: %s", result)
            continue
        detail = (
            db.query(SubmissionDetail)
            .join(models.Question, models.Question.id == SubmissionDetail.question_id)
            .filter(
                SubmissionDetail.submission_id == submission_id,
                models.Question.question_number == question_number,
            )
            .first()
        )
        if detail is None:
            logger.warning(
                "Detail untuk submission %s / soal %s tidak ditemukan", submission_id, question_number
            )
            continue
        detail.student_answer_text = result.get("extracted_text")
        detail.similarity_score = result.get("similarity_score")
        detail.is_correct = result.get("is_correct")
        detail.confidence = result.get("confidence")
        detail.ai_reasoning = result.get("reason")
        detail.model_used = result.get("model_used")
        detail.status = "done"
    db.commit()


def effective_score(detail: SubmissionDetail) -> float:
    """Skor final per soal: override guru menang atas skor AI."""
    if detail.manual_override and detail.overridden_score is not None:
        return detail.overridden_score
    return detail.similarity_score or 0.0


def compute_total_score(submission_id: int, db: Session) -> float:
    """Σ(score × weight) / Σ(weight) dinormalisasi ke total_score ujian."""
    submission = db.get(Submission, submission_id)
    if submission is None:
        return 0.0

    details = db.query(SubmissionDetail).filter(SubmissionDetail.submission_id == submission_id).all()
    total_weight = 0.0
    weighted_sum = 0.0
    for detail in details:
        weight = detail.question.weight
        total_weight += weight
        weighted_sum += effective_score(detail) * weight

    if total_weight == 0:
        return 0.0
    raw_percent = weighted_sum / total_weight
    return round(raw_percent / 100 * submission.exam.total_score, 2)
