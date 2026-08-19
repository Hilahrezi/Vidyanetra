import base64
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_teacher
from ..config import settings
from ..database import get_db
from ..services.batching_service import evaluate_submission, retry_failed_submission
from .exams import _owned_exam

router = APIRouter(prefix="/submissions", tags=["submissions"])

MAX_PAYLOAD_BYTES = 5 * 1024 * 1024  # 5 MB total (base64)


def _owned_submission(submission_id: int, user: models.User, db: Session) -> models.Submission:
    submission = db.get(models.Submission, submission_id)
    if submission is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Submission tidak ditemukan")
    _owned_exam(submission.exam_id, user, db)
    return submission


def _save_crop(image_base64: str, submission_id: int, question_number: int) -> str:
    try:
        raw = base64.b64decode(image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="base64 tidak valid")

    if not raw:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"Crop soal {question_number} kosong")

    folder = settings.upload_path / f"sub_{submission_id}"
    folder.mkdir(parents=True, exist_ok=True)
    filename = f"q{question_number}_{uuid.uuid4().hex[:8]}.jpg"
    (folder / filename).write_bytes(raw)
    return str(folder / filename)


def _image_url(image_path: str) -> str:
    try:
        rel = Path(image_path).resolve().relative_to(settings.upload_path.resolve())
    except ValueError:
        return ""
    return "/uploads/" + rel.as_posix()


def _detail_to_schema(detail: models.SubmissionDetail) -> schemas.SubmissionDetailOut:
    return schemas.SubmissionDetailOut(
        id=detail.id,
        question_id=detail.question_id,
        question_number=detail.question.question_number if detail.question else 0,
        type=detail.question.type if detail.question else "mcq",
        image_url=_image_url(detail.image_path),
        student_answer_text=detail.student_answer_text,
        similarity_score=detail.similarity_score,
        is_correct=detail.is_correct,
        confidence=detail.confidence,
        ai_reasoning=detail.ai_reasoning,
        status=detail.status,
        model_used=detail.model_used,
        mobile_answer=detail.mobile_answer,
        manual_override=detail.manual_override,
        overridden_score=detail.overridden_score,
    )


@router.post("/upload-crops", response_model=schemas.SubmissionOut, status_code=status.HTTP_202_ACCEPTED)
def upload_crops(
    payload: schemas.UploadCropsRequest,
    background: BackgroundTasks,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    exam = _owned_exam(payload.exam_id, teacher, db)
    student = db.get(models.Student, payload.student_id)
    if student is None or student.class_id != exam.class_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Siswa tidak ditemukan")

    # ---- Validasi payload ----
    total_bytes = sum(len(crop.image_base64) for crop in payload.crops)
    if total_bytes > MAX_PAYLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Payload terlalu besar ({total_bytes // 1024} KB > {MAX_PAYLOAD_BYTES // 1024} KB)",
        )

    question_numbers = [crop.question_number for crop in payload.crops]
    if len(question_numbers) != len(set(question_numbers)):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Ada nomor soal ganda dalam crops")

    questions = (
        db.query(models.Question)
        .filter(models.Question.exam_id == exam.id)
        .order_by(models.Question.question_number)
        .all()
    )
    question_map = {q.question_number: q for q in questions}
    missing = [n for n in question_numbers if n not in question_map]
    if missing:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"Soal tidak ada di ujian: {missing}")

    missing_crops = [q.question_number for q in questions if q.question_number not in set(question_numbers)]
    if missing_crops:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Belum semua soal di-scan. Kurang nomor: {missing_crops}",
        )

    # ---- Simpan ----
    submission = models.Submission(exam_id=payload.exam_id, student_id=payload.student_id, status="pending")
    db.add(submission)
    db.commit()
    db.refresh(submission)

    for crop in payload.crops:
        image_path = _save_crop(crop.image_base64, submission.id, crop.question_number)
        db.add(
            models.SubmissionDetail(
                submission_id=submission.id,
                question_id=question_map[crop.question_number].id,
                image_path=image_path,
                mobile_answer=crop.mcq_answer,
                mobile_ambiguous=crop.mcq_ambiguous,
            )
        )
    db.commit()

    background.add_task(evaluate_submission, submission.id)
    db.refresh(submission)
    return submission


@router.get("/{submission_id}", response_model=schemas.SubmissionOut)
def get_submission(
    submission_id: int,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    return _owned_submission(submission_id, teacher, db)


@router.get("/{submission_id}/details", response_model=schemas.SubmissionWithDetailsOut)
def get_submission_details(
    submission_id: int,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    submission = _owned_submission(submission_id, teacher, db)
    details = (
        db.query(models.SubmissionDetail)
        .filter(models.SubmissionDetail.submission_id == submission_id)
        .order_by(models.SubmissionDetail.question_id)
        .all()
    )
    return schemas.SubmissionWithDetailsOut(
        id=submission.id,
        exam_id=submission.exam_id,
        student_id=submission.student_id,
        total_score=submission.total_score,
        status=submission.status,
        created_at=submission.created_at,
        finalized_at=submission.finalized_at,
        student_name=submission.student.name if submission.student else None,
        details=[_detail_to_schema(d) for d in details],
    )


@router.put("/{submission_id}/review", response_model=schemas.SubmissionOut)
def review_submission(
    submission_id: int,
    payload: schemas.ReviewRequest,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    submission = _owned_submission(submission_id, teacher, db)
    if submission.status == "finalized":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Submission sudah di-final-kan")

    for item in payload.items:
        detail = db.query(models.SubmissionDetail).filter(
            models.SubmissionDetail.submission_id == submission_id,
            models.SubmissionDetail.question_id == item.question_id,
        ).first()
        if detail is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Soal {item.question_id} tidak ada di submission")
        detail.manual_override = True
        detail.overridden_score = item.overridden_score
    db.commit()
    db.refresh(submission)
    return submission


@router.post("/{submission_id}/retry-failed", response_model=schemas.SubmissionOut, status_code=status.HTTP_202_ACCEPTED)
def retry_failed(
    submission_id: int,
    background: BackgroundTasks,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    submission = _owned_submission(submission_id, teacher, db)
    if submission.status == "finalized":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Submission sudah di-final-kan")

    failed_count = (
        db.query(models.SubmissionDetail)
        .filter(models.SubmissionDetail.submission_id == submission_id, models.SubmissionDetail.status == "failed")
        .count()
    )
    if failed_count == 0:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Tidak ada soal gagal yang bisa di-retry")

    background.add_task(retry_failed_submission, submission.id)
    db.refresh(submission)
    return submission


@router.post("/{submission_id}/finalize", response_model=schemas.SubmissionOut)
def finalize_submission(
    submission_id: int,
    teacher: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    submission = _owned_submission(submission_id, teacher, db)
    if submission.status == "finalized":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Submission sudah di-final-kan")

    from ..services.grading import compute_total_score

    submission.total_score = compute_total_score(submission.id, db)
    submission.status = "finalized"
    submission.finalized_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(submission)
    return submission
