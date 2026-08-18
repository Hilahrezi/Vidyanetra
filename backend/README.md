# Backend — FastAPI (AI Orchestrator)

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt
copy .env.example .env        # lalu isi GEMINI_API_KEY
uvicorn app.main:app --reload
```

- Swagger UI: http://localhost:8000/docs
- Health check: http://localhost:8000/health

## Struktur

```
backend/
├── app/
│   ├── main.py              # entrypoint FastAPI + CORS + router
│   ├── config.py            # settings dari .env (pydantic-settings)
│   ├── database.py          # engine, session, Base
│   ├── models.py            # ORM: User, Class, Student, Exam, Question, Submission, SubmissionDetail
│   ├── schemas.py           # Pydantic request/response
│   ├── auth.py              # bcrypt + JWT utils
│   ├── routers/             # auth, classes, students, exams, questions, submissions
│   └── services/            # gemini_client, batching_service, grading
├── scripts/
│   ├── generate_template.py # PDF lembar jawaban (Fase 3)
│   └── seed.py              # data awal untuk dev
├── tests/                   # pytest
├── uploads/                 # crop jawaban (git-ignored)
├── requirements.txt
└── .env.example
```

## Catatan fase

- Fase 1: endpoint CRUD + auth + submission skeleton (mock mode default).
- Fase 2: integrasi Gemini batching (lihat `../docs/05-gemini-integration.md`).
