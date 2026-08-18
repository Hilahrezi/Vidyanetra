from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_teacher
from ..database import get_db

router = APIRouter(prefix="/classes", tags=["classes"])


def _owned_class(class_id: int, teacher_id: int, db: Session) -> models.Class:
    class_ = db.get(models.Class, class_id)
    if class_ is None or class_.teacher_id != teacher_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")
    return class_


@router.get("", response_model=list[schemas.ClassOut])
def list_classes(teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    return db.query(models.Class).filter(models.Class.teacher_id == teacher.id).all()


@router.post("", response_model=schemas.ClassOut, status_code=status.HTTP_201_CREATED)
def create_class(payload: schemas.ClassCreate, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    class_ = models.Class(teacher_id=teacher.id, **payload.model_dump())
    db.add(class_)
    db.commit()
    db.refresh(class_)
    return class_


@router.get("/{class_id}", response_model=schemas.ClassOut)
def get_class(class_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    return _owned_class(class_id, teacher.id, db)


@router.put("/{class_id}", response_model=schemas.ClassOut)
def update_class(class_id: int, payload: schemas.ClassUpdate, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    class_ = _owned_class(class_id, teacher.id, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(class_, field, value)
    db.commit()
    db.refresh(class_)
    return class_


@router.delete("/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_class(class_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    class_ = _owned_class(class_id, teacher.id, db)
    db.delete(class_)
    db.commit()
