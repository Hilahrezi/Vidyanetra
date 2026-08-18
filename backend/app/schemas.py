from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---- Auth ----
class LoginRequest(BaseModel):
    email: str
    password: str


class UserOut(ORMModel):
    id: int
    role: str
    name: str
    email: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---- Classes ----
class ClassCreate(BaseModel):
    name: str
    grade_level: str


class ClassUpdate(BaseModel):
    name: str | None = None
    grade_level: str | None = None


class ClassOut(ORMModel):
    id: int
    name: str
    grade_level: str


# ---- Students ----
class StudentCreate(BaseModel):
    name: str
    student_number: str


class StudentOut(ORMModel):
    id: int
    class_id: int
    name: str
    student_number: str


# ---- Exams ----
class ExamCreate(BaseModel):
    class_id: int
    title: str
    total_score: int = 100


class ExamOut(ORMModel):
    id: int
    class_id: int
    title: str
    total_score: int


# ---- Questions ----
class QuestionCreate(BaseModel):
    question_number: int
    type: str  # mcq | short | essay
    answer_key: str
    weight: float = 1.0


class QuestionOut(ORMModel):
    id: int
    exam_id: int
    question_number: int
    type: str
    answer_key: str
    weight: float


# ---- Submissions ----
class CropItem(BaseModel):
    question_number: int
    image_base64: str
    mcq_answer: str | None = None  # hasil deteksi X dari mobile (tier 1, MCQ)
    mcq_ambiguous: bool = False


class UploadCropsRequest(BaseModel):
    exam_id: int
    student_id: int
    crops: list[CropItem]


class SubmissionOut(ORMModel):
    id: int
    exam_id: int
    student_id: int
    total_score: float | None
    status: str
    created_at: datetime
    finalized_at: datetime | None


class SubmissionDetailOut(ORMModel):
    id: int
    question_id: int
    question_number: int
    type: str
    image_url: str
    student_answer_text: str | None
    similarity_score: float | None
    is_correct: bool | None
    confidence: float | None
    ai_reasoning: str | None
    status: str
    model_used: str | None
    mobile_answer: str | None
    manual_override: bool
    overridden_score: float | None


class SubmissionWithDetailsOut(SubmissionOut):
    student_name: str | None
    details: list[SubmissionDetailOut]


class ExamSubmissionOut(SubmissionOut):
    student_name: str | None
    student_number: str | None


class ReviewItem(BaseModel):
    question_id: int
    overridden_score: float


class ReviewRequest(BaseModel):
    items: list[ReviewItem]
