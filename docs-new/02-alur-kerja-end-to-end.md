# 🔄 02 — Alur Kerja Sistem End-to-End

Dokumen ini memuat panduan operasional dan alur kerja komprehensif sistem **Vidyanetra** dari tahap pembuatan ujian, pencetakan lembar PDF A4, pemindaian kamera HP, penilaian hybrid AI, hingga pelaporan analitik di web dashboard.

---

## 🧭 Ringkasan 5 Tahapan Alur Kerja

```mermaid
flowchart LR
    A["1️⃣ Persiapan\n(Buat Ujian & Cetak PDF)"] --> B["2️⃣ Pelaksanaan\n(Siswa Menjawab di Lembar A4)"]
    B --> C["3️⃣ Pemindaian\n(Kamera HP + Edge CV)"]
    B --> D["4️⃣ Penilaian AI\n(Hybrid 3-Tier Grading)"]
    D --> E["5️⃣ Review & Analitik\n(Web Dashboard & CSV)"]
```

---

## 🟢 TAHAP 1: Persiapan Ujian & Template PDF A4

```mermaid
sequenceDiagram
    autonumber
    actor Admin as 👨‍💼 Administrator
    actor Guru as 👨‍🏫 Guru Pengampu
    participant Web as 🖥️ Web Dashboard
    participant Mobile as 📱 Mobile App
    participant BE as ⚙️ Backend FastAPI
    participant PDF as 📄 ReportLab Engine

    Admin->>Web: Buat Kelas & Rombel (Mapel, Tingkat, Guru Pengampu)
    Web->>BE: POST /classes (Disimpan ke DB)
    Guru->>Mobile: Pilih Kelas & Buat Ujian Baru
    Guru->>Mobile: Tambah Butir Soal & Kunci Jawaban
    Note over Mobile,BE: Total Skor dihitung otomatis dari akumulasi bobot butir soal
    Mobile->>BE: POST /exams/{id}/questions (MCQ: 5pt, Isian: 10pt, Esai: 20pt)
    BE-->>Mobile: Data Ujian & Soal Tersimpan
    Guru->>Mobile: Klik "Download PDF Lembar Jawaban (A4)"
    Mobile->>BE: GET /exams/{id}/template.pdf
    BE->>PDF: build_pdf(questions, title, class_name)
    PDF-->>BE: Stream PDF A4 (300 DPI, 4 Fiducial Marker, Grid Box)
    BE-->>Mobile: Unduh File PDF
    Guru->>Guru: Cetak PDF di Kertas A4 Standar
```

### Standar Penulisan Kunci Jawaban (`answer_key`):
* **Pilihan Ganda (MCQ):** Pilih opsi benar (`A`, `B`, `C`, atau `D`).
* **Isian Singkat:** Tuliskan kata kunci benar. Tambahkan variasi sinonim/rumus setara menggunakan pemisah pipa `|` (contoh: `fotosintesis | proses pembuatan makanan pada tumbuhan` atau `teorema Pythagoras | a^2+b^2=c^2`).
* **Esai / Uraian:** Tuliskan gagasan utama / rubrik konsep kunci yang wajib dievaluasi secara semantik.

---

## 📝 TAHAP 2: Pelaksanaan Ujian oleh Siswa

1. Siswa mengisi identitas diri (Nama, Kelas, No. Absen, Tanggal) pada bagian kop lembar jawaban A4.
2. **Aturan Pengisian Kotak:**
   * **Pilihan Ganda:** Siswa memberikan **tanda silang (X)** pada salah satu kotak opsi (`a`, `b`, `c`, atau `d`).
   * **Isian & Esai:** Siswa menuliskan teks jawaban menggunakan pulpen/pensil di dalam kotak bernomor.
3. Lembar jawaban dikumpulkan setelah ujian selesai.

---

## 📷 TAHAP 3: Pemindaian Kamera & Edge Computer Vision (Mobile)

Seluruh deteksi geometris dan pemotongan gambar dilakukan **secara lokal di HP Android (Pure Dart)** tanpa mengunggah foto utuh ke server:

```mermaid
flowchart TD
    Raw["📸 Foto Kamera HP (JPEG ~4-8 MB)"] --> Gray["1. Grayscale (0.299R + 0.587G + 0.114B)"]
    Gray --> Otsu["2. Otsu Auto-Thresholding (Biner)"]
    Otsu --> CCL["3. Connected-Component Labeling (Scanline)"]
    CCL --> Filter["4. Filter Marker (Ukuran 40-426px, Fill-Ratio ≥ 0.7)"]
    Filter --> Diag["5. Titik Pusat Marker (Interseksi Diagonal Proyektif)"]
    Diag --> DLT["6. Matriks Homografi DLT (8x8 Gauss-Jordan)"]
    Diag --> Crop["7. Bilinear Sampling Crop per Kotak Jawaban (≤768px)"]
    Crop --> Tier1["8. Deteksi Tanda Silang (X) MCQ Lokal (McqMark)"]
    Tier1 --> Compress["9. Kompres JPEG q70 (~50-100 KB/soal)"]
    Compress --> Upload["🚀 POST /submissions/upload-crops (Base64)"]
```

---

## 🧠 TAHAP 4: Penilaian Hybrid & Koreksi AI (Backend)

Backend menerima muatan crop jawaban dan mengevaluasi hasil secara paralel:

```mermaid
flowchart TD
    Recv["📥 Terima Request: crops[], exam_id, student_id"] --> Save["💾 Simpan Crop Gambar ke backend/uploads/"]
    Save --> Split{"Klasifikasi Berdasarkan Tipe Soal"}

    %% MCQ
    Split -->|MCQ| MCQ_Tier1{"Hasil Mobile CV Jelas / Tidak Ambigu?"}
    MCQ_Tier1 -->|Ya| MCQ_Done["✅ model_used: 'mobile-cv'\nSkor langsung ditentukan (0 RPD, 0s)"]
    MCQ_Tier1 -->|Ambigu| MCQ_Tier2["👁️ Jalankan Backend OpenCV (mcq_vision.py)"]
    MCQ_Tier2 --> MCQ_Tier2_Check{"Hasil Backend CV Jelas?"}
    MCQ_Tier2_Check -->|Ya| MCQ_Done2["✅ model_used: 'cv-mcq'\nSkor ditentukan (0 RPD)"]
    MCQ_Tier2_Check -->|Masih Ambigu| MCQ_Tier3["⚡ Fallback ke Gemini 3.5 Flash-Lite\n(model_used: 'gemini-3.5-flash-lite')"]

    %% Isian
    Split -->|Isian Singkat| Short_AI["⚡ Gemini 3.5 Flash-Lite\n(Batch 10, HWR + Pencocokan Sinonim)"]

    %% Esai
    Split -->|Esai| Essay_AI["🧠 Gemini 3.5 Flash\n(Batch 10, Evaluasi Semantik & Rubrik)"]

    MCQ_Done --> Agg["⚖️ Grading Engine: Akumulasi Skor Berbobot"]
    MCQ_Done2 --> Agg
    MCQ_Tier3 --> Agg
    Short_AI --> Agg
    Essay_AI --> Agg

    Agg --> DB[("💾 Simpan ke Supabase PostgreSQL (Status: graded)")]
```

---

## 📊 TAHAP 5: Review, Finalisasi & Analitik Asesmen (Web)

1. **Review & Manual Override:**
   * Guru membuka antarmuka *Split-View* di Web Dashboard (`/dashboard/exams/[id]/students/[sid]`).
   * Menampilkan gambar potongan crop tulisan siswa, transkripsi HWR AI, alasan evaluasi, dan model penilai.
   * Guru dapat mengubah nilai per butir soal (*manual override*) menggunakan slider nilai tanpa re-grading AI.
2. **Finalisasi Nilai:**
   * Guru menekan tombol **Finalize** untuk mengunci nilai siswa.
3. **Analitik Asesmen di Web Dashboard:**
   * **4 Kartu KPI:** Rata-rata kelas, tingkat ketuntasan KKM ($\ge 70\%$), nilai tertinggi, nilai terendah.
   * **Distribusi Nilai:** Histogram sebaran perolehan nilai siswa (10 bucket interval).
   * **Analisis Kesukaran Soal (Traffic Light):** 🟢 Mudah $\ge 80\%$, 🟡 Sedang $40\text{--}79\%$, 🔴 Sukar $< 40\%$.
   * **Ekspor Laporan:** Unduh rekap nilai format CSV siap pakai untuk e-Rapor sekolah.
