# 🔄 02 — Alur Kerja Sistem Komprehensif

Dokumen ini memuat panduan operasional dan alur kerja (*end-to-end workflow*) sistem **AutoGrading** dari tahap pembuatan soal, pencetakan lembar ujian, pemindaian kamera, penilaian AI, hingga pelaporan analitik.

---

## 🧭 Ringkasan 5 Tahapan Alur Kerja

```mermaid
flowchart LR
    A["1️⃣ Persiapan\n(Buat Ujian & Cetak PDF)"] --> B["2️⃣ Pelaksanaan\n(Siswa Menjawab di Lembar A4)"]
    B --> C["3️⃣ Pemindaian\n(Kamera HP + Edge CV)"]
    C --> D["4️⃣ Penilaian AI\n(Hybrid 3-Tier Grading)"]
    D --> E["5️⃣ Review & Analitik\n(Web Dashboard & CSV)"]
```

---

## 🟢 TAHAP 1: Persiapan Ujian, Penyusunan Soal & Template PDF

```mermaid
sequenceDiagram
    autonumber
    actor Guru as 👨‍🏫 Guru / Admin
    participant Client as 📱 Mobile / 🖥️ Web
    participant BE as ⚙️ Backend FastAPI
    participant PDF as 📄 ReportLab Engine

    Guru->>Client: Buat Kelas & Rombel (Mapel, Tingkat, Guru Pengampu)
    Guru->>Client: Buat Ujian Baru (Judul Ujian, Kelas Tujuan)
    Note over Client,BE: Total Skor dihitung otomatis dari akumulasi bobot soal
    Guru->>Client: Tambah Butir Soal & Kunci Jawaban
    Client->>BE: POST /exams/{id}/questions (MCQ: 5pt, Isian: 10pt, Esai: 20pt)
    BE-->>Client: Data Ujian & Soal Tersimpan
    Guru->>Client: Klik "Download PDF Lembar Jawaban (A4)"
    Client->>BE: GET /exams/{id}/template.pdf
    BE->>PDF: build_pdf(questions, title, class_name)
    PDF-->>BE: Stream PDF A4 (300 DPI, 4 Fiducial Marker, Grid Box)
    BE-->>Client: Unduh File PDF
    Guru->>Guru: Cetak PDF di Kertas A4 Standar
```

### Standar Penulisan Kunci Jawaban (`answer_key`):
* **Pilihan Ganda (MCQ):** Pilih opsi benar (`A`, `B`, `C`, atau `D`).
* **Isian Singkat:** Tuliskan kata kunci benar. Tambahkan variasi sinonim/rumus setara menggunakan pemisah pipa `|` (contoh: `fotosintesis | proses pembuatan makanan pada tumbuhan` atau `teorema Pythagoras | a^2+b^2=c^2`).
* **Esai / Uraian:** Tuliskan gagasan utama / rubrik konsep kunci yang wajib dinilai oleh AI semantik.

---

## 📝 TAHAP 2: Pelaksanaan & Pengisian Jawaban oleh Siswa

1. Siswa mengisi identitas diri (Nama, Kelas, No. Absen, Tanggal) pada bagian kop lembar jawaban A4.
2. **Aturan Pengisian Kotak:**
   * **Pilihan Ganda:** Siswa memberikan **tanda silang (X)** pada salah satu kotak opsi (`a`, `b`, `c`, atau `d`).
   * **Isian & Esai:** Siswa menuliskan teks jawaban menggunakan pulpen/pensil di dalam kotak bernomor.
3. Kertas lembar jawaban dikumpulkan setelah ujian selesai.

---

## 📷 TAHAP 3: Pemindaian Kamera & *Edge Computer Vision* (Mobile)

Seluruh deteksi geometris dan pemotongan gambar dilakukan **secara lokal di HP Android (Pure Dart)** tanpa mengirim foto utuh ke server:

```mermaid
flowchart TD
    Raw["📸 Foto Kamera HP (JPEG ~4-8 MB)"] --> Gray["1. Grayscale (0.299R + 0.587G + 0.114B)"]
    Gray --> Otsu["2. Otsu Auto-Thresholding (Biner)"]
    Otsu --> CCL["3. Connected-Component Labeling (Scanline)"]
    CCL --> Filter["4. Filter Marker (Ukuran 40-426px, Fill-Ratio ≥ 0.7)"]
    Filter --> Diag["5. Titik Pusat Marker (Interseksi Diagonal Proyektif)"]
    Diag --> DLT["6. Matriks Homografi DLT (8x8 Gauss-Jordan)"]
    DLT --> Crop["7. Bilinear Sampling Crop per Kotak Jawaban (≤768px)"]
    Crop --> Tier1["8. Deteksi Tanda Silang (X) MCQ Lokal"]
    Tier1 --> Compress["9. Kompres JPEG q70 (~50-100 KB/soal)"]
    Compress --> Upload["🚀 POST /submissions/upload-crops"]
```

### Keunggulan Edge CV Pure Dart:
* **Projective-Invariant Marker Detection:** Menghitung pusat marker dari titik potong diagonal kontur ekstrem, sehingga deteksi tetap presisi meskipun kertas difoto dengan kemiringan perspektif sudut tertentu.
* **Bilinear Sampling Per Sel:** Aplikasi langsung memotong kotak jawaban dari matriks transformasi tanpa perlu merender ulang halaman A4 penuh, menghemat penggunaan RAM ponsel.
* **Hemat Bandwidth:** Hanya potongan kotak jawaban yang dikirim ke server via jaringan nirkabel.

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

    Agg --> DB[("💾 Simpan ke Database (Status: graded)")]
```

---

## 📊 TAHAP 5: Review, Finalisasi & Analitik Asesmen (Web & Mobile)

1. **Review & Manual Override:**
   * Guru dapat melihat transkripsi teks hasil HWR AI, alasan penilaian (*AI reasoning*), dan tingkat keyakinan (*confidence score*).
   * Guru dapat mengubah nilai (*manual override*) menggunakan slider nilai tanpa perlu memanggil ulang AI.
2. **Finalisasi Nilai:**
   * Guru menekan tombol **Finalize** untuk mengunci nilai siswa.
3. **Analitik Asesmen di Web Dashboard:**
   * **KPI Overview:** Rata-rata kelas, tingkat kelulusan, nilai tertinggi/terendah.
   * **Distribusi Nilai:** Histogram sebaran nilai siswa (interval 10 poin).
   * **Analisis Butir Soal (Item Difficulty):** Indikator warna lampu lalu lintas (🟢 Mudah $>80\%$, 🟡 Sedang $40\text{--}80\%$, 🔴 Sulit $<40\%$).
   * **Ekspor Laporan:** Unduh rekap nilai format CSV siap pakai untuk penginputan e-Rapor sekolah.
