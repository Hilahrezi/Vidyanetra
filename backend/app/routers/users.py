import shutil

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import hash_password, require_admin
from ..config import settings
from ..database import get_db

router = APIRouter(prefix="/users", tags=["users"])


def _enrich_user(user: models.User, db: Session) -> schemas.UserOut:
    classes_count = (
        db.query(models.Class).filter(models.Class.teacher_id == user.id).count()
    )
    return schemas.UserOut(
        id=user.id,
        name=user.name,
        email=user.email,
        role=user.role,
        classes_count=classes_count,
    )


@router.get("", response_model=list[schemas.UserOut])
def list_users(admin: models.User = Depends(require_admin), db: Session = Depends(get_db)):
    users = db.query(models.User).order_by(models.User.id).all()
    return [_enrich_user(u, db) for u in users]


@router.post("", response_model=schemas.UserOut, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: schemas.UserCreate,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if payload.role not in ("teacher", "admin"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Role harus 'teacher' atau 'admin'",
        )

    existing = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email sudah terdaftar",
        )

    user = models.User(
        name=payload.name,
        email=payload.email,
        role=payload.role,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _enrich_user(user, db)


@router.get("/{user_id}", response_model=schemas.UserOut)
def get_user(
    user_id: int,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.get(models.User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User tidak ditemukan")
    return _enrich_user(user, db)


@router.put("/{user_id}", response_model=schemas.UserOut)
def update_user(
    user_id: int,
    payload: schemas.UserUpdate,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.get(models.User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User tidak ditemukan")

    if payload.email and payload.email != user.email:
        existing = db.query(models.User).filter(models.User.email == payload.email).first()
        if existing:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email sudah digunakan")
        user.email = payload.email

    if payload.name is not None:
        user.name = payload.name

    if payload.role is not None:
        if payload.role not in ("teacher", "admin"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Role tidak valid")
        user.role = payload.role

    if payload.password:
        user.password_hash = hash_password(payload.password)

    db.commit()
    db.refresh(user)
    return _enrich_user(user, db)


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tidak dapat menghapus akun Anda sendiri yang sedang aktif",
        )

    user = db.get(models.User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User tidak ditemukan")

    class_ids = [c.id for c in user.classes]
    if class_ids:
        exam_ids = [
            e_id for (e_id,) in db.query(models.Exam.id).filter(models.Exam.class_id.in_(class_ids)).all()
        ]
        if exam_ids:
            subs = db.query(models.Submission.id).filter(models.Submission.exam_id.in_(exam_ids)).all()
            for (sub_id,) in subs:
                folder = settings.upload_path / f"sub_{sub_id}"
                if folder.exists():
                    shutil.rmtree(folder, ignore_errors=True)

    db.delete(user)
    db.commit()
