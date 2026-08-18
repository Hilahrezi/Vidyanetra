"""Batching & routing evaluasi AI.

- Model dipilih PER TUGAS via config (GEMINI_MODEL_MCQ/_SHORT/_ESSAY).
- Prompt-Level Batching + Interleaved Prompting: 1 request = 10-15 crop.
- MCQ 3-tier (Fase 4.5): mobile CV -> backend CV -> Gemini fallback.
- Partial retry: question yang gagal ditandai failed, bisa di-retry.

CATATAN: semua evaluasi memakai `BatchItem` (objek plain) — BUKAN objek ORM —
karena batch Gemini dieksekusi paralel di thread pool dan session SQLAlchemy
tidak thread-safe (lazy-load bersamaan dengan commit merusak identity map).
"""

import logging
from dataclasses import dataclass, field
from typing import Any

from .grading import apply_gemini_results

logger = logging.getLogger(__name__)

BATCH_SIZE = 10
MAX_BATCH_SIZE = 15
CORRECT_THRESHOLD = 70  # is_correct = similarity_score >= threshold


@dataclass
class BatchItem:
    """Representasi plain satu soal untuk evaluasi (thread-safe)."""

    submission_id: int
    question_number: int
    type: str
    answer_key: str
    image_path: str
    mobile_answer: str | None = None
    mobile_ambiguous: bool = False


def to_batch_items(details: list) -> list[BatchItem]:
    """Konversi SubmissionDetail ORM -> BatchItem (muat semua data di satu thread)."""
    return [
        BatchItem(
            submission_id=d.submission_id,
            question_number=d.question.question_number,
            type=d.question.type,
            answer_key=d.question.answer_key,
            image_path=d.image_path,
            mobile_answer=d.mobile_answer,
            mobile_ambiguous=d.mobile_ambiguous,
        )
        for d in details
    ]

# --- Template prompt (Bahasa Indonesia) ---

PROMPT_MCQ = (
    "Gambar {n} berisi soal pilihan ganda dengan EMPAT kotak opsi berlabel a, b, c, d. "
    "Siswa menyilang (tanda X) SALAH SATU kotak sebagai jawabannya. "
    "Kunci jawaban: \"{key}\" (huruf a/b/c/d). "
    "Identifikasi opsi yang disilang. Bila tanda ambigu atau ada lebih dari satu, "
    "beri confidence rendah dan best guess. "
    "is_correct = true jika opsi yang disilang sama dengan kunci (tidak peduli huruf besar/kecil). "
    "Return JSON sesuai schema."
)

PROMPT_SHORT = (
    "Gambar {n} berisi jawaban isian singkat. Kunci jawaban: \"{key}\" (alternatif jawaban benar dipisah '|'). "
    "Transkripsi jawaban siswa apa adanya ke extracted_text. "
    "similarity_score (0-100): kemiripan MAKNA dengan kunci; cocok dengan salah satu "
    "alternatif dianggap benar penuh. "
    "PENTING — rumus/notasi matematika dianggap SETARA dengan nama konsepnya bila maknanya sama "
    "(mis. 'a^2 + b^2 = c^2' setara dengan 'teorema Pythagoras'; 'x = -b/2a' setara dengan 'sumbu simetri'). "
    "Ejaan yang sedikit berbeda, huruf besar/kecil, atau simbol alternatif (a² vs a^2) jangan disalahkan. "
    "is_correct = similarity_score >= 70. Return JSON sesuai schema."
)

PROMPT_ESSAY = (
    "Gambar {n} berisi jawaban esai. Kunci jawaban (gagasan utama): \"{key}\". "
    "Transkripsi jawaban siswa lengkap ke extracted_text. "
    "similarity_score (0-100): nilai SEMANTIK, bukan kesamaan kata per kata; "
    "beri skor parsial bila sebagian gagasan utama muncul atau diparafrase. "
    "reason: 1-2 kalimat penjelasan skor. is_correct = similarity_score >= 70. "
    "Return JSON sesuai schema."
)

RESPONSE_SCHEMA = {
    "type": "ARRAY",
    "items": {
        "type": "OBJECT",
        "properties": {
            "question_number": {"type": "INTEGER"},
            "extracted_text": {"type": "STRING"},
            "similarity_score": {"type": "NUMBER"},
            "is_correct": {"type": "BOOLEAN"},
            "confidence": {"type": "NUMBER"},
            "reason": {"type": "STRING"},
        },
        "required": ["question_number", "extracted_text", "similarity_score", "is_correct"],
    },
}


def model_for(question_type: str) -> str:
    """Routing per tipe soal ke model terpilih (config per tugas)."""
    from ..config import settings

    return {
        "mcq": settings.gemini_model_mcq,
        "short": settings.gemini_model_short,
        "essay": settings.gemini_model_essay,
    }[question_type]


def prompt_for(question_type: str) -> str:
    return {
        "mcq": PROMPT_MCQ,
        "short": PROMPT_SHORT,
        "essay": PROMPT_ESSAY,
    }[question_type]


def split_batches(items: list, batch_size: int = BATCH_SIZE) -> list[list]:
    """Pecah item menjadi batch kecil."""
    return [items[i : i + batch_size] for i in range(0, len(items), batch_size)]


def group_and_batch(items: list[BatchItem]) -> list[list[BatchItem]]:
    """Group per tipe soal, lalu pecah ke batch (tiap batch = SATU tipe)."""
    by_type: dict[str, list[BatchItem]] = {}
    for item in items:
        by_type.setdefault(item.type, []).append(item)
    batches: list[list[BatchItem]] = []
    for grouped in by_type.values():
        batches.extend(split_batches(grouped))
    return batches


def _mark_failed(db, items: list[BatchItem]) -> None:
    """Tandai status=failed untuk item tertentu (bulk update via query, thread-safe)."""
    from sqlalchemy import select, update

    from ..models import Question, SubmissionDetail

    qnums = [i.question_number for i in items]
    sub_ids = {i.submission_id for i in items}
    question_ids = select(Question.id).where(Question.question_number.in_(qnums))
    db.execute(
        update(SubmissionDetail)
        .where(SubmissionDetail.submission_id.in_(sub_ids), SubmissionDetail.question_id.in_(question_ids))
        .values(status="failed")
    )
    db.commit()


def evaluate_details(db, items: list[BatchItem]) -> None:
    """Jalankan evaluasi atas daftar BatchItem; batch gagal ditandai failed.

    MCQ (Fase 4.5, 3-tier):
      1. Mobile CV (mobile_answer tidak ambigu) -> langsung, model_used=mobile-cv
      2. Backend CV (mcq_vision) -> model_used=cv-mcq
      3. Ambigu -> fallback Gemini (1 request untuk semua item ambigu)
    Tipe lain -> Gemini (batch paralel antar tipe, TIDAK menambah jumlah request).
    """
    from concurrent.futures import ThreadPoolExecutor

    from .gemini_client import get_client

    client = get_client()
    batches = group_and_batch(items)
    mcq_batches = [b for b in batches if b[0].type == "mcq"]
    ai_batches = [b for b in batches if b[0].type != "mcq"]

    for batch in mcq_batches:
        try:
            _evaluate_mcq_batch(db, client, batch)
        except Exception as exc:
            logger.error("Evaluasi MCQ gagal: %s", exc)
            _mark_failed(db, batch)

    def run(batch):
        try:
            return batch, client.evaluate_batch(batch), None
        except Exception as exc:
            return batch, None, exc

    with ThreadPoolExecutor(max_workers=min(4, len(ai_batches) or 1)) as pool:
        outcomes = list(pool.map(run, ai_batches))

    for batch, results, error in outcomes:
        if error is not None:
            logger.error("Evaluasi batch gagal: %s", error)
            _mark_failed(db, batch)
            continue
        apply_gemini_results(db, results)


def _apply_mcq_result(db, item: BatchItem, *, answer: str, confidence: float, model_used: str, reason: str) -> None:
    correct = answer.strip().lower() == item.answer_key.strip().lower()
    apply_gemini_results(
        db,
        [
            {
                "submission_id": item.submission_id,
                "question_number": item.question_number,
                "extracted_text": answer,
                "similarity_score": 100.0 if correct else 0.0,
                "is_correct": correct,
                "confidence": confidence,
                "model_used": model_used,
                "reason": reason,
            }
        ],
    )


def _evaluate_mcq_batch(db, client, items: list[BatchItem]) -> None:
    """3-tier evaluasi MCQ: mobile CV -> backend CV -> Gemini fallback."""
    from . import mcq_vision

    tier1, rest = [], []
    for item in items:
        if item.mobile_answer and not item.mobile_ambiguous:
            tier1.append(item)
        else:
            rest.append(item)

    for item in tier1:
        _apply_mcq_result(
            db, item,
            answer=item.mobile_answer,
            confidence=1.0,
            model_used="mobile-cv",
            reason="Deteksi tanda X di aplikasi (tier-1 mobile, CV lokal).",
        )

    tier2, ambiguous = [], []
    for item in rest:
        try:
            res = mcq_vision.evaluate_mcq_file(item.image_path)
        except Exception as exc:
            logger.warning("MCQ vision gagal untuk %s/%s: %s", item.submission_id, item.question_number, exc)
            res = {"answer": None, "ambiguous": True, "confidence": 0.0}
        if res.get("ambiguous"):
            ambiguous.append(item)
            continue
        _apply_mcq_result(
            db, item,
            answer=res["answer"],
            confidence=res["confidence"],
            model_used="cv-mcq",
            reason="Deteksi tanda X di backend (CV, OpenCV).",
        )

    if not ambiguous:
        return

    # Tier 3: fallback Gemini untuk item yang masih ambigu (1 request)
    try:
        results = client.evaluate_batch(ambiguous)
        apply_gemini_results(db, results)
    except Exception as exc:
        logger.error("Fallback Gemini MCQ gagal: %s", exc)
        _mark_failed(db, ambiguous)


def evaluate_submission(submission_id: int) -> None:
    """Entrypoint background task: evaluasi SELURUH detail submission."""
    from ..database import SessionLocal
    from ..models import Submission, SubmissionDetail

    db = SessionLocal()
    try:
        submission = db.get(Submission, submission_id)
        if submission is None:
            return
        submission.status = "grading"
        db.commit()

        details = (
            db.query(SubmissionDetail)
            .filter(SubmissionDetail.submission_id == submission_id)
            .order_by(SubmissionDetail.question_id)
            .all()
        )
        evaluate_details(db, to_batch_items(details))

        submission.status = "graded"
        db.commit()
        logger.info("Submission %s selesai dievaluasi", submission_id)
    finally:
        db.close()


def retry_failed_submission(submission_id: int) -> None:
    """Background task: evaluasi ulang HANYA detail yang status-nya failed."""
    from ..database import SessionLocal
    from ..models import Submission, SubmissionDetail

    db = SessionLocal()
    try:
        submission = db.get(Submission, submission_id)
        if submission is None or submission.status == "finalized":
            return

        failed = (
            db.query(SubmissionDetail)
            .filter(SubmissionDetail.submission_id == submission_id, SubmissionDetail.status == "failed")
            .all()
        )
        if not failed:
            return

        submission.status = "grading"
        db.commit()
        evaluate_details(db, to_batch_items(failed))

        submission.status = "graded"
        db.commit()
        logger.info("Retry submission %s selesai (%d soal)", submission_id, len(failed))
    finally:
        db.close()
