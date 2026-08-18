export interface Exam {
  id: number;
  class_id: number;
  title: string;
  total_score: number;
}

export interface ExamSubmission {
  id: number;
  exam_id: number;
  student_id: number;
  total_score: number | null;
  status: string;
  student_name: string | null;
  student_number: string | null;
}

export interface DistributionBucket {
  range: string;
  count: number;
}

export interface Distribution {
  exam_id: number;
  total: number;
  buckets: DistributionBucket[];
}

export interface QuestionDifficulty {
  question_number: number;
  type: string;
  weight: number;
  attempted: number;
  average_score: number | null;
}

export interface Difficulty {
  exam_id: number;
  questions: QuestionDifficulty[];
}

export interface SubmissionDetail {
  id: number;
  question_id: number;
  question_number: number;
  type: string;
  image_url: string;
  student_answer_text: string | null;
  similarity_score: number | null;
  is_correct: boolean | null;
  confidence: number | null;
  ai_reasoning: string | null;
  status: string;
  model_used: string | null;
  mobile_answer: string | null;
  manual_override: boolean;
  overridden_score: number | null;
}

export interface SubmissionWithDetails {
  id: number;
  exam_id: number;
  student_id: number;
  total_score: number | null;
  status: string;
  student_name: string | null;
  details: SubmissionDetail[];
}
