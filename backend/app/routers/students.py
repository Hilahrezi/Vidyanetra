from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_teacher
from ..database import get_db

router = APIRouter(tags=["students"])


def _owned_student(student_id: int, user: models.User, db: Session) -> models.Student:
    student = db.get(models.Student, student_id)
    if student is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Siswa tidak ditemukan")
    class_ = db.get(models.Class, student.class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Siswa tidak ditemukan")
    if user.role != "admin" and class_.teacher_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Siswa tidak ditemukan")
    return student


@router.get("/classes/{class_id}/students", response_model=list[schemas.StudentOut])
def list_students(class_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    return db.query(models.Student).filter(models.Student.class_id == class_id).all()


@router.post("/classes/{class_id}/students", response_model=schemas.StudentOut, status_code=status.HTTP_201_CREATED)
def create_student(class_id: int, payload: schemas.StudentCreate, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    student = models.Student(class_id=class_id, **payload.model_dump())
    db.add(student)
    db.commit()
    db.refresh(student)
    return student


@router.post("/classes/{class_id}/students/bulk", response_model=list[schemas.StudentOut], status_code=status.HTTP_201_CREATED)
def bulk_create_students(class_id: int, payload: list[schemas.StudentCreate], teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    students = [models.Student(class_id=class_id, **item.model_dump()) for item in payload]
    db.add_all(students)
    db.commit()
    for s in students:
        db.refresh(s)
    return students


@router.put("/students/{student_id}", response_model=schemas.StudentOut)
def update_student(student_id: int, payload: schemas.StudentCreate, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    student = _owned_student(student_id, teacher, db)
    student.name = payload.name
    student.student_number = payload.student_number
    db.commit()
    db.refresh(student)
    return student


@router.delete("/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_student(student_id: int, teacher=Depends(require_teacher), db: Session = Depends(get_db)):
    student = _owned_student(student_id, teacher, db)
    db.delete(student)
    db.commit()

