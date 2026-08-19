# 🔄 Alur Kerja Sistem Komprehensif — AutoGrading (Vision-NLP Hybrid)

Dokumen ini adalah referensi teknis dan operasional lengkap yang mendokumentasikan **seluruh arsitektur, pipeline pemrosesan, dan alur kerja (workflow) end-to-end** sistem AutoGrading dari pembuatan soal hingga pelaporan analitik.

---

## 🏗️ 1. Arsitektur Global & Topologi Sistem

Sistem AutoGrading mengadopsi arsitektur **3-Tier Hybrid (Edge Computer Vision + Cloud Multimodal AI)** yang terhubung secara nirkabel melalui mesh network **Tailscale**:

```mermaid
flowchart TD
    subgraph TIER1 ["📱 TIER 1: Edge Scanner (Flutter Android)"]
        UI_Dash["🏠 Teacher Dashboard"]
        UI_Editor["✍️ Exam & Question Builder"]
        CV_Engine["📐 Pure Dart CV Engine\n(Otsu, CCL, Marker, DLT, Crop)"]
        Tier1_MCQ["🔘 Tier-1 MCQ Detector (Densitas X)"]
        UI_Review["📝 Review & Manual Override"]
        UI_Analytics["📊 In-App Analytics"]
    end

    subgraph NETWORK ["🌐 Jaringan Privat (Tailscale WireGuard Mesh)"]
        TS_Tunnel["P2P Encrypted Tunnel\n(100.78.211.26:8000 & :3000)"]
    end

    subgraph TIER2 ["⚙️ TIER 2: AI Orchestrator & Backend (FastAPI)"]
        API_GW["🛡️ Auth JWT & REST Controller"]
        PDF_Gen["📄 ReportLab PDF Layout Engine"]
        Tier2_MCQ["👁️ Tier-2 Backend CV (OpenCV)"]
        Batcher["📦 Batching Service (Interleaved Prompt)"]
        Grading["⚖️ Grading Engine (Weighted Score)"]
        DB[(🗄️ Database: autograding.db)]
    end

    subgraph CLOUD ["☁️ Google Gemini Multimodal API"]
        Lite["⚡ Gemini 3.5 Flash-Lite\n(MCQ Tier-3 & Isian Singkat)"]
        Flash["🧠 Gemini 3.5 Flash\n(Esai & Penalaran Semantik)"]
    end

    subgraph TIER3 ["🖥️ TIER 3: Web Dashboard (Next.js 16)"]
        BFF["🔒 BFF Proxy (httpOnly Cookie)"]
        Web_View["📈 Chart.js Analytics & Hasil Siswa"]
        Web_Export["📥 Export CSV & Download PDF"]
    end

    TIER1 <==> NETWORK <==> TIER2
    TIER2 <==> CLOUD
    TIER3 <==> TIER2
```

---

## 📋 2. Alur Kerja End-to-End

---

### 🟢 ALUR 1: Pembuatan Ujian, Soal & Download Template PDF

```mermaid
sequenceDiagram
    autonumber
    actor Guru as 👨‍🏫 Guru
    participant App as 📱 Mobile App / 🖥️ Web
    participant BE as ⚙️ Backend FastAPI
    participant PDF as 📄 Layout Engine (ReportLab)

    Guru->>App: Buka menu "Buat Ujian & Soal"
    Guru->>App: Input Judul, Pilih Kelas Tujuan, Total Bobot Nilai
    Guru->>App: Tambah Butir Soal (MCQ, Isian Singkat, Esai) + Kunci Jawaban
    App->>BE: POST /exams & POST /exams/{id}/questions
    BE-->>App: Data Ujian & Soal Tersimpan di Database
    Guru->>App: Tekan tombol "Download PDF Lembar Jawaban (A4)"
    App->>BE: GET /exams/{id}/template.pdf
    BE->>PDF: build_pdf(question_types, title, class_name)
    PDF-->>BE: Render PDF A4 (300 DPI, 4 Fiducial Marker, Kop, Grid)
    BE-->>App: Stream binary application/pdf
    App->>App: Simpan file ke folder Download / Documents
    Guru->>Guru: Cetak PDF di Kertas A4 & Bagikan ke Siswa
```

#### Spesifikasi Kunci Jawaban:
* **Pilihan Ganda (MCQ):** Guru memilih opsi kunci benar (`A`, `B`, `C`, atau `D`).
* **Isian Singkat:** Guru memasukkan jawaban benar dan dapat menambahkan alternatif sinonim/variasi format rumus menggunakan tanda `|` (misal: `fotosintesis | proses pembuatan makanan pada tumbuhan` atau `teorema Pythagoras | a^2+b^2=c^2`).
* **Esai:** Guru memasukkan gagasan pokok/rubrik konsep utama yang wajib dinilai oleh AI semantik.

#### Spesifikasi Geometri PDF Lembar Jawaban (`template_service.py`):
* **Ukuran:** A4 Portrait ($210 \times 297\text{ mm}$, render 300 DPI = $2480 \times 3508\text{ px}$).
* **4 Fiducial Marker:** Kotak hitam pekat $12 \times 12\text{ mm}$ dicetak di 4 sudut halaman (pusat koordinat $(18, 18)\text{ mm}$).
* **Grid Jawaban:**
  * **MCQ:** Baris 4 kotak opsi a/b/c/d ($14 \times 16\text{ mm}$, gap $6\text{ mm}$, total lebar $76\text{ mm}$).
  * **Isian:** Kotak $100 \times 18\text{ mm}$.
  * **Esai:** Kotak $170 \times 50\text{ mm}$ (margin aman dari tepi cetak).

---

### 📝 ALUR 2: Pelaksanaan & Pengisian Jawaban oleh Siswa

1. Siswa menuliskan identitas (Nama, Kelas, No. Absen, Tanggal) di kolom identitas bagian atas lembar A4.
2. **Aturan Pengisian Jawaban:**
   * **MCQ:** Siswa memberikan **tanda silang (X)** pada salah satu kotak opsi (a/b/c/d).
   * **Isian & Esai:** Siswa menuliskan jawaban tulisan tangan biasa di dalam kotak bernomor.

---

### 📷 ALUR 3: Pemindaian Kamera & *Edge CV Pipeline* (Mobile)

Seluruh pemrosesan gambar awal dilakukan **100% lokal di HP Android (Pure Dart CV)** tanpa mengirim foto utuh ke server:

```mermaid
flowchart TD
    RawPhoto["📸 Foto Kamera Mentah (JPEG ~4-8 MB)"] --> Gray["1. Grayscale (0.299R + 0.587G + 0.114B)"]
    Gray --> Otsu["2. Otsu Auto-Thresholding (Biner Hitam-Putih)"]
    Otsu --> CCL["3. Connected-Component Labeling (Scanline Flood)"]
    CCL --> Filter["4. Filter Marker (Ukuran 40-426px, Aspect ≤ 1.3, Fill-Ratio ≥ 0.7)"]
    Filter --> Diag["5. Hitung Pusat Marker via Interseksi Diagonal (Projective-Invariant)"]
    Diag --> DLT["6. Matriks Homografi DLT (8x8 Gauss-Jordan)"]
    DLT --> Crop["7. Bilinear Sampling Crop per Kotak Jawaban (~768px)"]
    Crop --> Tier1["8. Deteksi Tanda Silang (X) MCQ Lokal (Densitas Piksel Tinta)"]
    Tier1 --> Compress["9. Kompres JPEG q70 + Base64 (Hanya ~50-100 KB per Soal)"]
    Compress --> Upload["🚀 POST /submissions/upload-crops"]
```

#### Keunggulan Algoritma Edge CV:
1. **Projective-Invariant Marker Detection:** Menghitung pusat marker dari titik perpotongan diagonal kontur ekstrem (bukan centroid momen standar), sehingga deteksi tetap presisi meskipun kertas difoto miring.
2. **Bilinear Sampling Per Sel:** Aplikasi tidak membebani RAM dengan men-transform seluruh halaman A4, melainkan langsung memotong kotak jawaban dari matriks homografi.
3. **Payload Ringan:** HP hanya mengirim potongan jawaban (~50–100 KB), menghemat bandwidth internet dan kuota data.

---

### 🧠 ALUR 4: AI Orchestration & Penilaian Hybrid (Backend)

Backend menerima request crop jawaban, menyimpannya di folder `backend/uploads/`, dan menjalankan evaluasi otomatis:

```mermaid
flowchart TD
    Recv["📥 Terima Request: crops[], exam_id, student_id"] --> Save["💾 Simpan Crop Gambar ke backend/uploads/"]
    Save --> Split{"Pisahkan Berdasarkan Tipe Soal"}

    %% MCQ Branch
    Split -->|MCQ| MCQ_Tier1{"Apakah Hasil Mobile CV Jelas / Tidak Ambigu?"}
    MCQ_Tier1 -->|Ya| MCQ_Done["✅ model_used: 'mobile-cv'\nSkor langsung ditentukan (0 RPD, 0s)"]
    MCQ_Tier1 -->|Ambigu / Kosong| MCQ_Tier2["👁️ Jalankan Backend OpenCV (mcq_vision.py)"]
    MCQ_Tier2 --> MCQ_Tier2_Check{"Apakah Backend CV Jelas?"}
    MCQ_Tier2_Check -->|Ya| MCQ_Done2["✅ model_used: 'cv-mcq'\nSkor ditentukan CV backend (0 RPD)"]
    MCQ_Tier2_Check -->|Masih Ambigu| MCQ_Tier3["⚡ Fallback ke Gemini 3.5 Flash-Lite\n(model_used: 'gemini-3.5-flash-lite')"]

    %% Isian Branch
    Split -->|Isian Singkat| Short_AI["⚡ Gemini 3.5 Flash-Lite\n(Batch 10, HWR + Semantic Match)"]

    %% Essay Branch
    Split -->|Esai| Essay_AI["🧠 Gemini 3.5 Flash\n(Penalaran Semantik Mendalam)"]

    MCQ_Done --> Calc["⚖️ Grading Engine: Hitung Nilai Akhir Berbobot"]
    MCQ_Done2 --> Calc
    MCQ_Tier3 --> Calc
    Short_AI --> Calc
    Essay_AI --> Calc

    Calc --> DB_Save["💾 Tulis ke submission_details & submissions\nStatus: 'graded'"]
```

#### 1. Mekanisme 3-Tier Soal Pilihan Ganda (MCQ):
* **Tier-1 (Mobile CV):** Menghitung densitas tinta pada 4 kotak opsi (a/b/c/d). Jika kotak tergelap memiliki densitas $\ge 0.03$ dan $\ge 1.5\times$ kotak kedua $\rightarrow$ Opsi langsung diputuskan di HP (**0 detik, 0 kuota AI**).
* **Tier-2 (Backend CV):** Jika data mobile ambigu $\rightarrow$ Backend menjalankan analisis kontur OpenCV.
* **Tier-3 (Gemini AI Fallback):** Jika siswa mencoret-coret lembar atau gambar kotor $\rightarrow$ Dikirim ke Gemini Flash-Lite.

#### 2. Single-Pass Multimodal (HWR + Semantic Evaluation):
Gemini melakukan **dua tugas sekaligus dalam satu kali panggilan**:
* **Transkripsi Tulisan Tangan:** Membaca tulisan tangan siswa bahasa Indonesia $\rightarrow$ `extracted_text`.
* **Evaluasi Semantik:** Menilai kesesuaian makna terhadap kunci jawaban guru $\rightarrow$ `similarity_score` ($0 - 100$), `is_correct` ($\ge 70$), dan `reason` (alasan penilaian).
* **Ekuivalensi Rumus Matematika:** Prompt AI telah diinstruksikan bahwa rumus/notasi matematika bernilai setara dengan nama konsepnya (misal: jawaban $a^2+b^2=c^2$ otomatis dinilai 100/benar untuk kunci "Teorema Pythagoras").

---

### ✍️ ALUR 5: Review Guru & Manual Override

```mermaid
sequenceDiagram
    actor Guru as 👨‍🏫 Guru
    participant App as 📱 Mobile / 🖥️ Web
    participant BE as ⚙️ Backend FastAPI

    App->>BE: Polling GET /submissions/{id}/details
    BE-->>App: extracted_text, similarity_score, ai_reasoning, model_used
    App->>Guru: Tampilkan gambar crop asli vs transkripsi & skor AI
    alt Guru Setuju dengan Nilai AI
        Guru->>App: Tekan tombol "Finalize"
    else Guru Ingin Mengubah Nilai
        Guru->>App: Geser Slider / Ubah Angka Skor (Manual Override)
        App->>BE: PUT /submissions/{id}/review (items: [{question_id, overridden_score}])
        BE-->>App: Override tersimpan (AI tidak dipanggil ulang)
        Guru->>App: Tekan tombol "Finalize"
    end
    App->>BE: POST /submissions/{id}/finalize
    BE-->>App: Status 'finalized' (Skor Terkunci)
```

---

### 📊 ALUR 6: Dashboard Analitik & Ekspor Laporan

Setelah seluruh lembar jawaban ujian terkoreksi, data disajikan dalam berbagai bentuk visual:

```mermaid
graph LR
    subgraph Data ["Data Terkumpul"]
        Submissions["Daftar Nilai Siswa\n(Status Finalized)"]
    end

    subgraph MobileView ["📱 Mobile Analytics"]
        M_Stats["Card: Rata-rata, Tertinggi, Terendah, % Tuntas"]
        M_Diff["Progress Bar Kesulitan Per Soal (Mudah/Sedang/Sulit)"]
        M_Hist["Histogram Distribusi Nilai"]
        M_List["Daftar Nilai Seluruh Siswa"]
    end

    subgraph WebView ["🖥️ Web Dashboard Next.js"]
        W_Charts["Chart.js: Grafik Distribusi & Kesulitan"]
        W_Table["Tabel Skor Siswa Per Nomor Soal"]
        W_CSV["📥 Export Nilai ke CSV (Excel-ready)"]
        W_PDF["📄 Download Ulang Lembar Jawaban PDF"]
    end

    Data --> MobileView
    Data --> WebView
```

---

## 🛡️ 3. Keamanan & Infrastruktur Jaringan

| Aspek | Implementasi Teknis | Keuntungan |
|---|---|---|
| **Koneksi Nirkabel** | **Tailscale WireGuard Mesh** (`100.78.211.26`) | HP dan PC terhubung nirkabel melintasi router/WiFi/4G apa pun dengan enkripsi P2P layer-3 tanpa perlu port forwarding publik. |
| **Proteksi AI Secrets** | Gemini API Key hanya berada di `backend/.env` | File APK dan frontend Web bersih dari kredensial cloud (**0% risiko kebocoran key**). |
| **Otentikasi Web** | **BFF Proxy + httpOnly Cookie** (`ag_token`) | Token JWT tidak pernah dapat diakses oleh skrip JavaScript di browser (kebal serangan XSS). |
| **Penyimpanan Mobile** | `FlutterSecureStorage` (Android Keystore AES-GCM) | Token login di HP terlindungi di level hardware keystore OS. |

---

## 📁 4. Pemetaan File & Komponen Terkait

* **Mobile App:**
  * Beranda Guru: [`mobile/lib/features/dashboard/teacher_dashboard_page.dart`](file:///C:/coding/geprekkumlot_hologyUB2026/mobile/lib/features/dashboard/teacher_dashboard_page.dart)
  * Pembuat Soal & Kunci: [`mobile/lib/features/exams/exam_editor_page.dart`](file:///C:/coding/geprekkumlot_hologyUB2026/mobile/lib/features/exams/exam_editor_page.dart)
  * Pipeline Scanner (CV): [`mobile/lib/core/opencv_pipeline.dart`](file:///C:/coding/geprekkumlot_hologyUB2026/mobile/lib/core/opencv_pipeline.dart)
  * Analitik Mobile: [`mobile/lib/features/analytics/exam_analytics_page.dart`](file:///C:/coding/geprekkumlot_hologyUB2026/mobile/lib/features/analytics/exam_analytics_page.dart)
* **Backend:**
  * Template Layout Generator: [`backend/app/services/template_service.py`](file:///C:/coding/geprekkumlot_hologyUB2026/backend/app/services/template_service.py)
  * Integrasi Gemini & Batching: [`backend/app/services/gemini_client.py`](file:///C:/coding/geprekkumlot_hologyUB2026/backend/app/services/gemini_client.py) & [`batching_service.py`](file:///C:/coding/geprekkumlot_hologyUB2026/backend/app/services/batching_service.py)
  * Evaluasi CV Backend MCQ: [`backend/app/services/mcq_vision.py`](file:///C:/coding/geprekkumlot_hologyUB2026/backend/app/services/mcq_vision.py)
* **Web Dashboard:**
  * Halaman Detail Ujian & Analitik: [`web/app/dashboard/exams/[id]/page.tsx`](file:///C:/coding/geprekkumlot_hologyUB2026/web/app/dashboard/exams/[id]/page.tsx)
  * Login & BFF Proxy: [`web/app/login/page.tsx`](file:///C:/coding/geprekkumlot_hologyUB2026/web/app/login/page.tsx) & [`web/app/api/auth/login/route.ts`](file:///C:/coding/geprekkumlot_hologyUB2026/web/app/api/auth/login/route.ts)
