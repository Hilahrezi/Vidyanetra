# 🏛️ 01 — Arsitektur & Desain Sistem Cloud

Dokumen ini mendefinisikan prinsip desain arsitektural, topologi komputasi awan (*cloud topology*), pemisahan tanggung jawab (*separation of concerns*), dan keputusan teknis sistem **Vidyanetra**.

---

## 1. Topologi Global (Edge-to-Cloud 3-Tier)

Sistem Vidyanetra mengadopsi pola **Edge Computer Vision + Cloud Multimodal AI Orchestration**:

```mermaid
flowchart TD
    subgraph CLIENT_TIER ["📱 TIER 1: Edge Client (Flutter Android)"]
        UI_Dash["🏠 Guru Dashboard & Kelas"]
        UI_Builder["✍️ Exam & Question Builder (Auto-Weight)"]
        CV_Engine["📐 Pure Dart CV Engine\n(Otsu, CCL, Marker Diagonal, DLT Homography)"]
        Tier1_MCQ["🔘 Tier-1 MCQ Detector (Densitas X)"]
        UI_Review["📝 Review & Manual Override"]
    end

    subgraph SERVER_TIER ["⚙️ TIER 2: AI Orchestrator Backend (FastAPI Cloud Container)"]
        API_GW["🛡️ Auth JWT & RBAC Controller"]
        PDF_Gen["📄 ReportLab PDF Layout Engine (300 DPI)"]
        Tier2_MCQ["👁️ Tier-2 Backend CV (OpenCV)"]
        Batcher["📦 Batching Service (Interleaved Prompt)"]
        Grading["⚖️ Grading Engine (Weighted Calculation)"]
    end

    subgraph CLOUD_STORAGE ["🗄️ TIER 3: Cloud Database & AI Services"]
        Supabase[("🐘 Supabase Managed PostgreSQL\n(Transaction Pooler Port 6543)")]
        Lite["⚡ Google Gemini 3.5 Flash-Lite\n(MCQ Tier-3 & Isian Singkat)"]
        Flash["🧠 Google Gemini 3.5 Flash\n(Esai & Penalaran Semantik)"]
    end

    subgraph WEB_TIER ["🖥️ TIER 4: Web Dashboard (Next.js 16 Vercel)"]
        BFF["🔒 BFF Proxy (httpOnly Secure Cookie)"]
        Web_Analytics["📈 Dashboard Analitik & Gradebook"]
        Web_Users["👥 User Management (Admin RBAC)"]
        Web_Classes["🏫 Class & Student Roster Management"]
    end

    CLIENT_TIER -->|HTTPS REST API / Crop Base64| SERVER_TIER
    SERVER_TIER <-->|SQLAlchemy 2.0 Pooler| Supabase
    SERVER_TIER <-->|Interleaved Batching| Lite
    SERVER_TIER <-->|Interleaved Batching| Flash
    WEB_TIER <-->|HTTPS BFF Proxy| SERVER_TIER
```

---

## 2. Prinsip Desain Non-Negotiable

1. **Separation of Concerns & Zero Database Direct Access:**
   - Aplikasi Mobile dan Web Frontend **tidak pernah mengakses database secara langsung**. Seluruh pertukaran data melalui REST API FastAPI yang terotentikasi.
2. **Keamanan Kredensial & Zero-Leakage:**
   - Kunci API Gemini (`GEMINI_API_KEY`) dan rahasia JWT (`JWT_SECRET`) **hanya berada di environment container backend**. Tidak ada kredensial sensitif yang terpapar di APK Android atau bundle JavaScript web client.
   - Web Dashboard menggunakan pola **BFF (Backend-For-Frontend)** dengan *httpOnly Secure Cookie*, mengisolasi token dari ancaman serangan *Cross-Site Scripting (XSS)*.
3. **Optimasi Muatan (*Payload Optimization*):**
   - Perangkat mobile **tidak pernah mengunggah foto lembar A4 utuh** (4–8 MB).
   - Melalui *Edge Computer Vision*, aplikasi mobile melakukan pemotongan (*crop*) per kotak jawaban, dikompresi menjadi format JPEG q70 ($\le 768\text{ px}$, $\sim 50\text{--}100\text{ KB}$ per kotak).
4. **Strict JSON Schema Enforcement:**
   - Seluruh keluaran model AI Gemini divalidasi dan dipaksa menggunakan `response_schema` struktural bawaan SDK `google.genai`, menjamin stabilitas parsing JSON tanpa halusinasi format.
5. **Grading Hybrid & Cost-Efficiency:**
   - Soal Pilihan Ganda (MCQ) dievaluasi terlebih dahulu melalui Computer Vision lokal gratis ($0\text{ RPD}$), menghemat kuota AI hingga 90%.

---

## 3. Matriks Keputusan Stack Teknologi

| Komponen | Pilihan Teknologi | Rationale & Justifikasi |
|---|---|---|
| **Mobile Client** | **Flutter 3 (Dart)** | Performa tinggi, cross-platform Android native, kapabilitas pemrosesan citra murni *Pure Dart* tanpa dependensi C++ biner yang rentan pada toolchain modern. |
| **Backend API** | **FastAPI (Python 3.14+)** | Asynchronous I/O berkecepatan tinggi, validasi skema otomatis berbasis Pydantic v2, dokumentasi Swagger interaktif (`/docs`), dan integrasi alami SDK Google GenAI. |
| **Database Cloud** | **PostgreSQL (Supabase Managed)** | Integritas ACID kuat, skalabilitas enterprise, koneksi efisien via Transaction Pooler (`pool_pre_ping=True`, `pool_recycle=300`). |
| **Web Dashboard** | **Next.js 16 (Vercel App Router)** | SSR & Turbopack bundling cepat, keamanan BFF Proxy terintegrasi, serta visualisasi data interaktif Chart.js & Tailwind CSS. |
| **Multimodal AI** | **Google Gemini 3.5 API** | Pemahaman tulisan tangan (*Handwriting Recognition* / HWR) Bahasa Indonesia terbaik, penalaran semantik jawaban esai, dan dukungan *interleaved multimodal batching*. |

---

## 4. Analisis & Routing Model AI

```
                  ┌───────── Tipe Soal: MCQ ─────────┐
                  ▼                                  ▼
           [Jawaban Jelas]                    [Tanda Ambigu / Kotor]
                  │                                  │
         (1) Edge Dart CV                   (2) Backend OpenCV
       [model_used: mobile-cv]             [model_used: cv-mcq]
                  │                                  │
                  └─────────► [Tetap Ambigu] ────────┘
                                     │
                                     ▼
                            (3) Gemini 3.5 Flash-Lite
                            [model_used: gemini-3.5-flash-lite]

         ┌─────────────── Tipe Soal: Isian Singkat ───────────────┐
         ▼                                                        ▼
   Gemini 3.5 Flash-Lite                                   Gemini 3.5 Flash
(Batch 10, HWR + Semantic)                            (Esai Kompleks & Penalaran)
```

| Tugas / Tipe Soal | Model yang Digunakan | Karakteristik & Quota | Catatan Operasional |
|---|---|---|---|
| **MCQ (Tier 1 & 2)** | **Pure Dart / OpenCV** | $0\text{ RPD}$ (Gratis, $0\text{ ms}$) | Mendeteksi posisi tanda silang (X) pada kotak a/b/c/d. |
| **MCQ (Tier 3)** | `gemini-3.5-flash-lite` | $200\text{ RPD}$ / $30\text{ RPM}$ | Fallback otomatis jika tanda silang ambigu. |
| **Isian Singkat** | `gemini-3.5-flash-lite` | $200\text{ RPD}$ / $30\text{ RPM}$ | HWR cepat + pencocokan sinonim kata kunci. |
| **Esai / Uraian** | `gemini-3.5-flash` | $20\text{ RPD}$ / $5\text{ RPM}$ | Evaluasi pemahaman konsep mendalam & rubrik. |
| **Fallback Rate Limit** | `gemini-3.5-flash-lite` | Kuota terpisah | Otomatis aktif saat model Flash utama mencapai ambang 429. |
| **Offline Dev / Mock** | `MockGeminiClient` | $0\text{ RPD}$ (Offline murni) | Aktif jika `GEMINI_MOCK_MODE=true` atau API key kosong (skor deterministik 85/45). |
