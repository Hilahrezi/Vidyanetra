# 📝 Automated Exam Grading System (Vision-NLP Hybrid)

## 1. Project Overview
This project is an automated exam correction system designed for educational institutions. It utilizes Computer Vision (Edge) and Multimodal AI (Cloud) to scan handwritten exam papers (including Arabic/Indonesian text), extract the answers, and semantically evaluate them against a teacher's answer key.

**Core Philosophy:** 
- Mobile app acts **strictly** as a pre-processing scanner and API client (Edge).
- Backend acts as the business logic controller and AI orchestrator (Cloud).
- HWR (Handwriting Recognition) and NLP (Semantic Evaluation) are delegated to the Gemini Vision API to bypass mobile hardware limitations.

---

## 2. System Architecture (3-Tier)

The system is decoupled into three main layers:

### A. Mobile Application (Client / Edge Scanner)
- **Role:** Teacher's primary tool for class management and exam scanning.
- **Key Responsibilities:**
  1. Capture exam paper via Camera.
  2. Perform **Computer Vision Pre-processing**: Detect 4 fiducial markers, apply perspective transform (deskew), convert to grayscale, and crop bounding boxes of individual answer sections.
  3. Send compressed cropped images (base64) and answer keys to the Backend via REST API.
  4. Display AI evaluation results and allow Manual Override before saving.
- **Constraint:** NO local AI modeling or direct database connection is allowed here.

### B. Backend Server (API & AI Orchestrator)
- **Role:** Secure gateway and core processor.
- **Key Responsibilities:**
  1. Handle authentication and routing.
  2. Receive base64 images from Mobile.
  3. Construct engineered prompts and call the **Gemini Multimodal API**.
  4. Parse the strict JSON response from Gemini (containing extracted text, similarity score, and evaluation reasoning).
  5. Calculate final grades and store records securely in the Database.

### C. Web Dashboard (Admin / Analytics)
- **Role:** Web-based data visualization for teachers/admins.
- **Key Responsibilities:** View aggregated exam results, analyze question difficulty, and export grade reports (CSV/Excel).

---

## 3. Tech Stack

- **Mobile App:** Flutter (or React Native) + OpenCV (`flutter_opencv` or equivalent for edge cropping).
- **Backend API:** Python (FastAPI) or Node.js (Express). *Agent to decide based on best setup for Gemini API SDK.*
- **Database:** MySQL or PostgreSQL (Relational structure for Users, Classes, Exams, Results).
- **Web Dashboard:** React.js / Next.js + Tailwind CSS + Chart.js.
- **AI Engine:** Google Gemini API (Gemini 1.5 Flash/Pro) for Multimodal Vision and Text Processing.

---

## 4. Database Schema (High-Level)

1. `Users`: id, role, name, email, password_hash
2. `Classes`: id, teacher_id, name, grade_level
3. `Students`: id, class_id, name, student_number
4. `Exams`: id, class_id, title, total_score
5. `Questions`: id, exam_id, question_number, type (MCQ/Short/Essay), answer_key, weight
6. `Submissions`: id, exam_id, student_id, total_score, created_at
7. `Submission_Details`: id, submission_id, question_id, student_answer_text, confidence_score, is_correct, ai_reasoning

---

## 5. Agent Developer Guidelines 🤖 (CRITICAL FOR AI AGENT)

If you are an AI coding assistant executing this project, adhere strictly strictly to the following rules:

1. **Separation of Concerns:** Do not mix frontend logic with backend routes. Always build independent RESTful API endpoints for the Mobile App to consume.
2. **Security:** Never expose the Gemini API Key or Database credentials in the Mobile or Web codebase. All secrets must reside in the Backend `.env` file.
3. **Payload Optimization:** When writing the Mobile scanning logic, ensure the app sends individual **cropped** answer boxes to the backend, NOT the full 5MB A4 paper image. Compress crops to reduce payload size.
4. **LLM Prompting constraint:** When configuring the Gemini API call in the Backend, you must strictly enforce JSON output via system instructions. 
   - *Expected JSON Schema from Gemini:* 
     `{ "extracted_text": "string", "similarity_score": number (0-100), "is_correct": boolean, "reason": "string" }`
5. **Step-by-Step Execution:** 
   - Phase 1: Initialize Database and construct Backend API boilerplates.
   - Phase 2: Implement Gemini API integration in Backend.
   - Phase 3: Build Mobile App UI and OpenCV cropping logic.
   - Phase 4: Build Web Dashboard tables and charts.