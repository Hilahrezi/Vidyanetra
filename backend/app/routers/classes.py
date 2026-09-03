import re

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_admin, require_teacher
from ..database import get_db

router = APIRouter(prefix="/classes", tags=["classes"])


def _derive_grade(name: str, grade_level: str | None) -> str:
    if grade_level and grade_level.strip():
        return grade_level.strip()
    match = re.search(r"\d+", name)
    return match.group(0) if match else name


def _enrich_class(class_: models.Class, db: Session) -> schemas.ClassOut:
    teacher = db.get(models.User, class_.teacher_id)
    students_count = (
        db.query(models.Student).filter(models.Student.class_id == class_.id).count()
    )
    exams_count = (
        db.query(models.Exam).filter(models.Exam.class_id == class_.id).count()
    )

    return schemas.ClassOut(
        id=class_.id,
        teacher_id=class_.teacher_id,
        teacher_name=teacher.name if teacher else None,
        name=class_.name,
        grade_level=class_.grade_level,
        subject=class_.subject,
        students_count=students_count,
        exams_count=exams_count,
    )


def _owned_class(class_id: int, user: models.User, db: Session) -> models.Class:
    class_ = db.get(models.Class, class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")
    if user.role != "admin" and class_.teacher_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")
    return class_


@router.get("", response_model=list[schemas.ClassOut])
def list_classes(user: models.User = Depends(require_teacher), db: Session = Depends(get_db)):
    if user.role == "admin":
        classes = db.query(models.Class).order_by(models.Class.id).all()
    else:
        classes = (
            db.query(models.Class)
            .filter(models.Class.teacher_id == user.id)
            .order_by(models.Class.id)
            .all()
        )
    return [_enrich_class(c, db) for c in classes]


@router.post("", response_model=schemas.ClassOut, status_code=status.HTTP_201_CREATED)
def create_class(
    payload: schemas.ClassCreate,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    target_teacher_id = payload.teacher_id or admin.id
    teacher = db.get(models.User, target_teacher_id)
    if not teacher:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Guru pengampu tidak ditemukan")

    data = payload.model_dump(exclude={"teacher_id", "grade_level"})
    grade_level = _derive_grade(payload.name, payload.grade_level)
    class_ = models.Class(
        teacher_id=target_teacher_id,
        grade_level=grade_level,
        **data,
    )
    db.add(class_)
    db.commit()
    db.refresh(class_)
    return _enrich_class(class_, db)


@router.get("/{class_id}", response_model=schemas.ClassOut)
def get_class(
    class_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    class_ = _owned_class(class_id, user, db)
    return _enrich_class(class_, db)


@router.put("/{class_id}", response_model=schemas.ClassOut)
def update_class(
    class_id: int,
    payload: schemas.ClassUpdate,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    class_ = db.get(models.Class, class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")

    data = payload.model_dump(exclude_unset=True)
    if "teacher_id" in data and data["teacher_id"]:
        teacher = db.get(models.User, data["teacher_id"])
        if not teacher:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Guru pengampu tidak ditemukan")
        class_.teacher_id = data["teacher_id"]
        del data["teacher_id"]

    if "name" in data and "grade_level" not in data:
        class_.grade_level = _derive_grade(data["name"], getattr(class_, "grade_level", None))

    for field, value in data.items():
        setattr(class_, field, value)
    db.commit()
    db.refresh(class_)
    return _enrich_class(class_, db)


@router.delete("/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_class(
    class_id: int,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    class_ = db.get(models.Class, class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")
    db.delete(class_)
    db.commit()
