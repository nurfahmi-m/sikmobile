# sik — Sistem Informasi Kepegawaian (Mobile)

Ringkasan singkat dan panduan cepat untuk pengembang yang bekerja pada aplikasi mobile "Sistem Informasi Kepegawaian".

**Project**

- **Nama paket:** `sik` — lihat [pubspec.yaml](pubspec.yaml)
- **Judul aplikasi:** "Sistem Informasi Kepegawaian Mobile" — lihat [lib/main.dart](lib/main.dart)
- **Deskripsi singkat:** A new Flutter project (starter)
- **SDK Dart constraint:** ^3.10.1 — lihat [pubspec.yaml](pubspec.yaml)

**Quick Start**

- Jalankan aplikasi di device/emulator:

```bash
flutter run
```

- Build APK release (Android):

```bash
flutter build apk --release
```

**Dependensi utama**

- `http` — komunikasi jaringan / API
- `intl`, `flutter_localizations` — internasionalisasi
- `image_picker`, `cached_network_image` — upload/ambil gambar dan caching
- `local_auth` — fingerprint / biometrik
- `device_info_plus`, `shared_preferences` — info perangkat & penyimpanan lokal
- `google_maps_flutter`, `geolocator`, `geocoding` — peta & layanan lokasi

Selengkapnya lihat daftar di [pubspec.yaml](pubspec.yaml).

**Struktur kode penting** (folder `lib`)

- [lib/main.dart](lib/main.dart) — entry point; menginisialisasi `LoginPage` dan tema.
- [lib/login_page.dart](lib/login_page.dart) — layar login.
- [lib/registration_page.dart](lib/registration_page.dart) — layar pendaftaran.
- [lib/dashboard_page.dart](lib/dashboard_page.dart) — halaman dashboard setelah login.
- [lib/absensi_page.dart](lib/absensi_page.dart) — fitur/halaman absensi.
- [lib/services/](lib/services/) — API clients, service layer (periksa folder untuk detail).
- [lib/utils/](lib/utils/) — utilitas pembantu.

**Aset & konfigurasi native**

- Folder aset gambar: `assets/images/` sudah terdaftar di `flutter.assets` (lihat [pubspec.yaml](pubspec.yaml)).
- Untuk `google_maps_flutter`, tambahkan API key di konfigurasi native (AndroidManifest / Info.plist).
- Pastikan permission untuk `image_picker`, `local_auth`, dan `geolocation` ditambahkan pada Android/iOS native manifests.

**Rekomendasi pengembang / catatan penting**

- Periksa implementasi di `lib/services/` untuk endpoint backend dan autentikasi.
- Tambahkan dokumentasi API atau contoh environment jika proyek membutuhkan server khusus.
- Pertimbangkan menambahkan aturan analisis di `analysis_options.yaml` bila ingin konsistensi kode.

Jika mau, saya bisa:

- Menambahkan dokumen `DEVELOPING.md` dengan langkah setup lebih detail.
- Memindai `lib/services/` dan membuat ringkasan endpoint/struktur API otomatis.

---
Generated summary on project files; edit this file to add project-specific notes.
