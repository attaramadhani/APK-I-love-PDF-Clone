# PDF Studio Pro (iLovePDF Clone) 📑✨

Aplikasi Mobile Pengolah Dokumen PDF Komprehensif berbasis **Flutter** dengan 25+ alat manipulasi PDF canggih, pemrosesan 100% lokal di perangkat (*offline-first*), fitur OCR, e-Sign tanda tangan digital, serta integrasi kecerdasan buatan (*AI Intelligence* via Google Gemini API & mode offline).

---

## 🚀 Fitur Utama (25+ Alat PDF)

### 1. 📂 Kelola & Atur Dokumen (Organize)
- **Gabungkan PDF (`merge`)**: Menyatukan beberapa berkas dokumen PDF menjadi satu kesatuan dokumen dengan mempertahankan ukuran dan orientasi halaman asli.
- **Pisahkan PDF (`split`)**: Ekstrak setiap halaman menjadi file PDF terpisah atau pisahkan berdasarkan rentang halaman kustom (multi-file split).
- **Atur Halaman (`organize_pages`)**: Pindahkan urutan halaman, putar rotasi 90°, atau hapus halaman tertentu dengan pratinjau visual.
- **Hapus Halaman (`remove_pages`)**: Hapus nomor atau rentang halaman tertentu secara presisi.
- **Pindai ke PDF (`scan_pdf`)**: Pindai dokumen fisik melalui kamera ponsel atau impor dari galeri langsung menjadi dokumen PDF multi-halaman.

### 2. ⚡ Optimalkan Dokumen (Optimize)
- **Kompres PDF (`compress`)**: Ringan (optimasi struktur, teks tetap bisa dicari), Rekomendasi (144 DPI) & Maksimal (96 DPI) yang benar-benar mengecilkan PDF hasil scan/foto. Hasil terkecil dipilih otomatis — file tidak pernah membesar.
- **Perbaiki PDF (`repair`)**: Rekonstruksi struktur tabel xref, stream, dan font dokumen PDF yang korup/rusak.
- **OCR PDF (`ocr_pdf`)**: OCR sungguhan dengan Google ML Kit (offline) untuk PDF hasil scan — berjalan otomatis bila PDF tidak punya lapisan teks. Pencarian kata menyorot semua hasil, salin teks, dan ekspor `.txt`.

### 3. 🔄 Konversi Dokumen (Convert)
- **Gambar ke PDF (`jpg_to_pdf`)**: Konversi kumpulan foto JPG/PNG menjadi PDF dengan orientasi dan margin otomatis.
- **PDF ke Gambar (`pdf_to_jpg`)**: Render setiap halaman PDF menjadi berkas gambar PNG/JPG tajam (150 DPI) dengan latar belakang putih kertas solid murni (*anti-black background*).
- **Word ke PDF (`word_to_pdf`)**: Ubah `.docx`/`.txt` menjadi PDF (paragraf & tabel dibaca langsung dari isi DOCX).
- **PDF ke Word (`pdf_to_word`)**: Ekstrak teks dokumen PDF menjadi format Microsoft Word (`.doc`) dengan styling CSS yang rapi.
- **Excel ke PDF (`excel_to_pdf`)**: Konversi `.xlsx`/`.csv` menjadi tabel PDF yang otomatis berlanjut ke halaman berikutnya.
- **PDF ke Excel (`pdf_to_excel`)**: Ekstrak tabel dan data tabular PDF menjadi berkas spreadsheet `.csv`.

### 4. ✏️ Edit & Personalisasi (Edit)
- **Putar PDF (`rotate`)**: Putar orientasi seluruh halaman 90°, 180°, atau 270°.
- **Nomor Halaman (`page_numbers`)**: Sisipkan penomoran otomatis (`Halaman X dari Y`) pada header atau footer.
- **Tanda Air / Watermark (`watermark`)**: Beri stempel hak cipta atau teks identitas pada setiap lembar dokumen.
- **Potong PDF / Crop (`crop`)**: Potong margin berlebih, kop, atau footer dengan perhitungan batas kanvas presisi.
- **Tanda Tangani PDF (`sign`)**: Kanvas tanda tangan jari/stylus (coretan vertikal tidak lagi menggulir layar), pilih halaman (pertama/terakhir/semua) dan posisi.

### 5. 🔒 Keamanan Dokumen (Security)
- **Proteksi PDF (`protect`)**: Kunci dan enkripsi dokumen PDF dengan sandi pengguna menggunakan enkripsi AES 256-bit.
- **Buka Kunci PDF (`unlock`)**: Hapus proteksi kata sandi untuk akses bebas dokumen.
- **Samarkan PDF (`redact`)**: Sensor PERMANEN (teks di bawah kotak hitam benar-benar terhapus) pada header, footer, area tengah, atau berdasarkan kata/frasa tertentu.
- **Bandingkan PDF (`compare`)**: Perbandingan isi baris-per-baris (baris ditambah/dihapus, persentase kemiripan) dan laporan PDF berformat tabel.

### 6. 🧠 PDF Intelligence (AI)
- **Perangkum AI (`ai_summarize`)**: Ringkas artikel atau laporan tebal dalam bentuk ringkasan eksekutif dan poin kunci (didukung mode Gemini 1.5 Flash & mode offline lokal).
- **Terjemahkan PDF (`ai_translate`)**: Terjemahkan isi dokumen ke berbagai bahasa dunia.
- **PDF ke Markdown (`ai_markdown`)**: Ekstrak struktur heading, list, dan tabel menjadi format Markdown (`.md`).

---

## 🆕 Perubahan v1.1.0

- **Performa**: seluruh proses PDF berat berjalan di background isolate — UI tidak lagi macet / "Not Responding" saat memproses file besar.
- **Bug diperbaiki**: rotasi halaman hilang saat gabung/pisah/susun; rotasi kini menambah rotasi yang sudah ada; PDF terkunci/rusak kini memunculkan pesan jelas (sebelumnya diam saja); dialog loading tidak lagi bisa menutup halaman alat secara tidak sengaja; "Simpan ke File Lokal" tidak lagi membuat salinan ganda dan menghormati pembatalan.
- **Gambar ke PDF / Pindai**: foto kamera tidak lagi miring (orientasi EXIF diterapkan) dan diperkecil sehingga PDF jauh lebih ringan.
- **AI**: memakai model Gemini yang masih aktif (1.5/2.0 sudah dimatikan Google), kunci API dikirim lewat header, pesan galat jelas, teks panjang dipotong aman.
- **Rentang halaman** mendukung `7-4`, `8-` (sampai akhir), dan en-dash.
- **Rilis**: dukungan `android/key.properties` untuk tanda tangan rilis + aturan ProGuard ML Kit. Unit test baru di `test/utils_test.dart`.

### Menandatangani APK rilis (untuk Play Store)
1. Buat keystore: `keytool -genkey -v -keystore %USERPROFILE%\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Buat `android/key.properties` (jangan di-commit):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=C:\\Users\\<nama>\\upload-keystore.jks
   ```
   Tanpa berkas ini, build rilis tetap jalan dengan kunci debug (cukup untuk uji coba).

---

## 🛠️ Tech Stack & Arsitektur

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.11.5`)
- **PDF Engine**: [Syncfusion Flutter PDF](https://pub.dev/packages/syncfusion_flutter_pdf) & [pdf](https://pub.dev/packages/pdf)
- **PDF Rendering & Raster**: [printing](https://pub.dev/packages/printing) & [flutter_pdfview](https://pub.dev/packages/flutter_pdfview)
- **Kamera & Galeri**: [image_picker](https://pub.dev/packages/image_picker)
- **OCR**: [google_mlkit_text_recognition](https://pub.dev/packages/google_mlkit_text_recognition) (offline)
- **Gambar & Office**: [image](https://pub.dev/packages/image), [archive](https://pub.dev/packages/archive), [xml](https://pub.dev/packages/xml)
- **Penyimpanan & File Picker**: [file_picker](https://pub.dev/packages/file_picker), [path_provider](https://pub.dev/packages/path_provider), [shared_preferences](https://pub.dev/packages/shared_preferences)
- **AI Backend**: Google Gemini API via REST HTTP (dengan fallback cerdas offline lokal)
- **Sharing**: [share_plus](https://pub.dev/packages/share_plus)

---

## 📂 Struktur Proyek

```
lib/
├── core/
│   ├── services/       # Engine PDF, Image-to-PDF, AI Intelligence, Recent Files
│   ├── theme/          # App Colors, ThemeData, Typography
│   └── utils/          # FileHelper, SAF local saving, formatters
├── data/               # Metadata daftar alat PDF (PdfToolsData)
├── models/             # ProcessedFile, PdfToolItem, Enum Category
├── views/
│   ├── home/           # Halaman utama dengan pencarian & filter kategori
│   ├── recent/         # Riwayat file terkini, filter PDF/Gambar, menu aksi 3-titik
│   ├── settings/       # Pengaturan Pro, status lokal, Gemini API Key
│   ├── tools/          # Layar khusus setiap alat PDF (25+ screens)
│   └── viewer/         # PDF Viewer interaktif dengan fast scrubber & jump-to-page
└── widgets/            # ProcessingDialog, ToolCard, Custom Chips
```

---

## ⚙️ Cara Menjalankan Proyek

### Prasyarat
- Flutter SDK (versi 3.24+ / 3.41+)
- Android Studio / VS Code dengan Flutter & Dart plugin
- Android SDK (API level 21+)

### Langkah Instalasi
1. Clone repositori ini:
   ```bash
   git clone https://github.com/attaramadhani/APK-I-love-PDF-Clone.git
   cd APK-I-love-PDF-Clone
   ```

2. Ambil seluruh dependensi:
   ```bash
   flutter pub get
   ```

3. Jalankan pengujian unit test:
   ```bash
   flutter test
   ```

4. Jalankan aplikasi pada perangkat / emulator:
   ```bash
   flutter run
   ```

5. Buat APK rilis siap instal:
   ```bash
   flutter build apk --release
   ```
   Berkas APK hasil kompilasi akan berada di `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🔒 Privasi & Keamanan

Seluruh proses manipulasi dokumen PDF (penggabungan, pemotongan, kompresi, enkripsi, e-Sign) diproses secara **100% lokal** di memori smartphone pengguna tanpa diunggah ke cloud pihak ketiga, menjaga privasi dokumen rahasia Anda tetap aman.

---

## 📄 Lisensi

Proyek ini dikembangkan untuk tujuan edukasi dan portofolio pengembangan aplikasi mobile Flutter.
