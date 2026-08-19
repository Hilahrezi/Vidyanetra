# 🗄️ 10 — Panduan Database MySQL & phpMyAdmin

Sistem **AutoGrading** menggunakan arsitektur **SQLAlchemy 2.0 ORM** yang mengisolasi model data dan query dari database engine tertentu. Hal ini memungkinkan sistem berjalan secara fleksibel dan kompatibel dengan berbagai jenis database.

---

## 🎯 Pilihan Database Engine

### 1. SQLite (Default / Bawaan)
* **Karakteristik:** *Zero-configuration*, file tunggal (`backend/autograding.db`), portabel.
* **Penggunaan Terbaik:** Pengembangan lokal, pengujian otomatis (`pytest`), simulasi, dan demo lomba.
* **Konfigurasi `.env`:**
  ```env
  DATABASE_URL=sqlite:///./autograding.db
  ```

### 2. MySQL / MariaDB + phpMyAdmin (XAMPP / Laragon)
* **Karakteristik:** Database relasional standar industri dengan antarmuka web GUI **phpMyAdmin** yang ramah pengguna.
* **Penggunaan Terbaik:** Server lokal sekolah, integrasi intranet, dan pengelolaan data visual oleh teknisi IT sekolah.
* **Konfigurasi `.env`:**
  ```env
  DATABASE_URL=mysql+pymysql://root:@localhost:3306/autograding_db
  ```

### 3. PostgreSQL
* **Karakteristik:** Database kelas enterprise dengan dukungan concurrency tinggi dan integritas ACID kuat.
* **Konfigurasi `.env`:**
  ```env
  DATABASE_URL=postgresql+psycopg2://postgres:postgres@localhost:5432/autograding_db
  ```

---

## 🚀 Prosedur Menghubungkan ke MySQL & phpMyAdmin (XAMPP)

### Langkah 1: Jalankan Layanan MySQL di XAMPP
1. Buka **XAMPP Control Panel**.
2. Klik tombol **Start** pada modul **Apache** dan **MySQL**.
3. Pastikan port MySQL berjalan di `3306`.

### Langkah 2: Buat Database di phpMyAdmin
1. Buka browser dan akses: `http://localhost/phpmyadmin`
2. Klik menu **Databases** (Basis data).
3. Masukkan nama basis data: `autograding_db`.
4. Pilih Collation: `utf8mb4_unicode_ci`.
5. Klik tombol **Create** (Buat).

### Langkah 3: Sesuaikan Konfigurasi `backend/.env`
Buka file `backend/.env` dan ubah variabel `DATABASE_URL`:
```env
# Format: mysql+pymysql://[USER]:[PASSWORD]@[HOST]:[PORT]/[DATABASE_NAME]
DATABASE_URL=mysql+pymysql://root:@localhost:3306/autograding_db
```
*(Catatan: Jika MySQL Anda menggunakan password, cantumkan setelah titik dua, contoh: `root:password123@localhost:3306/autograding_db`).*

### Langkah 4: Inisialisasi Skema & Data Awal (Seed)
Jalankan script seed di terminal backend:
```powershell
cd backend
.venv\Scripts\python scripts\seed.py
```
*Hasil:* Seluruh tabel (`users`, `classes`, `students`, `exams`, `questions`, `submissions`, `submission_details`) akan dibuat secara otomatis di phpMyAdmin beserta akun Admin & Guru awal.

---

## 📊 Pengelolaan Data di phpMyAdmin
Setelah inisialisasi selesai, buka `http://localhost/phpmyadmin` $\rightarrow$ pilih database `autograding_db`:
1. Tabel **`users`**: Memuat akun Administrator (`admin@sekolah.id`) dan Guru (`guru@sekolah.id`).
2. Tabel **`classes`**: Memuat data rombel beserta kolom `subject` (Mata Pelajaran).
3. Tabel **`exams`**: Memuat daftar ujian dan total skor akumulasi.
4. Tabel **`submissions`** & **`submission_details`**: Memuat riwayat koreksi AI, confidence score, dan hasil penilaian.
