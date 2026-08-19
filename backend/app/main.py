import logging
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import inspect, text

from . import models
from .auth import hash_password
from .config import settings
from .database import Base, SessionLocal, engine
from .routers import analytics, auth, classes, exams, questions, students, submissions, users

logging.basicConfig(level=logging.INFO)


def _auto_migrate_and_seed():
    Base.metadata.create_all(bind=engine)
    try:
        with engine.begin() as conn:
            inspector = inspect(conn)
            table_names = inspector.get_table_names()

            # 1. Check classes.subject
            if "classes" in table_names:
                columns = [c["name"] for c in inspector.get_columns("classes")]
                if "subject" not in columns:
                    logging.info("Migrasi skema: menambahkan kolom 'subject' ke tabel classes")
                    conn.execute(
                        text("ALTER TABLE classes ADD COLUMN subject VARCHAR(128) DEFAULT 'Umum'")
                    )

            # 2. Check exams.subject
            if "exams" in table_names:
                columns = [c["name"] for c in inspector.get_columns("exams")]
                if "subject" not in columns:
                    logging.info("Migrasi skema: menambahkan kolom 'subject' ke tabel exams")
                    conn.execute(
                        text("ALTER TABLE exams ADD COLUMN subject VARCHAR(128) DEFAULT 'Umum'")
                    )
    except Exception as e:
        logging.warning(f"Peringatan auto-migration SQLite: {e}")

    # 3. Ensure Default Users (Admin & Guru)
    db = SessionLocal()
    try:
        admin = db.query(models.User).filter(models.User.email == "admin@sekolah.id").first()
        if not admin:
            logging.info("Inisialisasi akun Admin: admin@sekolah.id")
            admin = models.User(
                name="Admin Sekolah",
                email="admin@sekolah.id",
                role="admin",
                password_hash=hash_password("admin123"),
            )
            db.add(admin)
            db.commit()

        teacher = db.query(models.User).filter(models.User.email == "guru@sekolah.id").first()
        if not teacher:
            logging.info("Inisialisasi akun Guru: guru@sekolah.id")
            teacher = models.User(
                name="Budi Guru",
                email="guru@sekolah.id",
                role="teacher",
                password_hash=hash_password("rahasia123"),
            )
            db.add(teacher)
            db.commit()
    except Exception as e:
        logging.warning(f"Peringatan auto-seed default user: {e}")
    finally:
        db.close()


_auto_migrate_and_seed()

app = FastAPI(title=settings.app_name, version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1|100\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(classes.router)
app.include_router(students.router)
app.include_router(exams.router)
app.include_router(questions.router)
app.include_router(submissions.router)
app.include_router(analytics.router)

settings.upload_path.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.upload_path), name="uploads")


@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}
