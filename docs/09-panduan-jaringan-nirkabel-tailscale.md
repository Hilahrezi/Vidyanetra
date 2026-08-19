# 🌐 09 — Panduan Jaringan Nirkabel & Simulasi (Tailscale Mesh)

Dokumen ini memuat panduan operasional untuk menghubungkan aplikasi HP Android fisik (**AutoGrading Scanner**) ke server lokal di PC secara nirkabel melalui jaringan mesh **Tailscale** tanpa memerlukan kabel USB / `adb reverse`.

---

## 1. Topologi Jaringan Nirkabel

```
[HP Android Fisik] ──(WireGuard Tunnel 100.x.y.z)──▶ [PC Windows Host :8000] ──▶ [Gemini AI]
```

* **IP Tailscale PC Host:** `100.78.211.26`
* **Port Backend FastAPI:** `8000`
* **Port Web Dashboard Next.js:** `3000`
* **Base URL API Mobile:** `http://100.78.211.26:8000`

---

## 2. Konfigurasi di PC Windows

### A. Izin Firewall Windows
Jalankan PowerShell sebagai Administrator (hanya perlu sekali):
```powershell
New-NetFirewallRule -DisplayName "AutoGrading FastAPI (8000)" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```

### B. Menjalankan Backend Server
Jalankan server backend agar mendengarkan seluruh interface jaringan (`0.0.0.0`):
```powershell
cd backend
.venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 3. Konfigurasi di HP Android

1. Buka aplikasi **Tailscale** di ponsel dan pastikan status terhubung (**Connected** / warna hijau) menggunakan akun yang sama dengan PC.
2. **Uji Koneksi Awal via Browser Ponsel:**
   - Buka Google Chrome di ponsel.
   - Akses alamat: `http://100.78.211.26:8000/health`
   - Pastikan muncul respons JSON: `{"status":"ok", "time":"..."}`.

---

## 4. Pemasangan Aplikasi & Pemindaian

1. File APK debug siap pakai berada di:
   `mobile/build/app/outputs/flutter-apk/app-debug.apk`
2. Kirimkan file `.apk` tersebut ke ponsel Anda dan pasang (*Install*).
3. Buka aplikasi **AutoGrading**, pastikan URL server mengarah ke `http://100.78.211.26:8000`.
4. Masuk dengan akun guru:
   - **Email:** `guru@sekolah.id`
   - **Password:** `rahasia123`
5. Lakukan pemindaian (*scanning*) lembar ujian secara nirkabel dan pantau hasilnya langsung di Web Dashboard!

---

## 🛠️ 5. Troubleshooting Koneksi

| Gejala | Penyebab | Langkah Solusi |
|---|---|---|
| "Tidak dapat terhubung ke server" | Status Tailscale mati atau IP berbeda | Buka Tailscale di HP dan PC, pastikan IP Tailscale PC adalah `100.78.211.26`. |
| Browser HP *Connection Timed Out* | Windows Firewall memblokir port 8000 | Jalankan perintah `New-NetFirewallRule` di atas atau izinkan aplikasi Python di Windows Defender. |
| Status 429 pada saat koreksi | Kuota AI Gemini habis | Sistem otomatis beralih ke `gemini-3.5-flash-lite` atau aktifkan `GEMINI_MOCK_MODE=true` di `backend/.env`. |
