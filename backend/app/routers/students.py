from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_admin, require_teacher
from ..database import get_db

router = APIRouter(tags=["students"])


@router.get("/classes/{class_id}/students", response_model=list[schemas.StudentOut])
def list_students(
    class_id: int,
    user: models.User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    # Verifikasi kelas ada dan milik guru/admin
    class_ = db.get(models.Class, class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")
    if user.role != "admin" and class_.teacher_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")

    return (
        db.query(models.Student)
        .filter(models.Student.class_id == class_id)
        .order_by(models.Student.student_number)
        .all()
    )


@router.post(
    "/classes/{class_id}/students",
    response_model=schemas.StudentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_student(
    class_id: int,
    payload: schemas.StudentCreate,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    class_ = db.get(models.Class, class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")

    student = models.Student(class_id=class_id, **payload.model_dump())
    db.add(student)
    db.commit()
    db.refresh(student)
    return student


@router.post(
    "/classes/{class_id}/students/bulk",
    response_model=list[schemas.StudentOut],
    status_code=status.HTTP_201_CREATED,
)
def bulk_create_students(
    class_id: int,
    payload: list[schemas.StudentCreate],
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    class_ = db.get(models.Class, class_id)
    if class_ is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kelas tidak ditemukan")

    students = [models.Student(class_id=class_id, **item.model_dump()) for item in payload]
    db.add_all(students)
    db.commit()
    for s in students:
        db.refresh(s)
    return students


@router.put("/students/{student_id}", response_model=schemas.StudentOut)
def update_student(
    student_id: int,
    payload: schemas.StudentCreate,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    student = db.get(models.Student, student_id)
    if student is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Siswa tidak ditemukan")

    student.name = payload.name
    student.student_number = payload.student_number
    db.commit()
    db.refresh(student)
    return student


@router.delete("/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_student(
    student_id: int,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    student = db.get(models.Student, student_id)
    if student is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Siswa tidak ditemukan")

    db.delete(student)
    db.commit()
