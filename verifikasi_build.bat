@echo off
REM Skrip verifikasi PDF Studio Pro: pub get, analyze, test, build APK rilis.
REM Hasil lengkap ditulis ke verifikasi_log.txt di folder ini.
cd /d "%~dp0"
set LOG=verifikasi_log.txt
echo Memverifikasi proyek... (bisa 5-15 menit untuk build pertama)
echo ==== flutter pub get ==== > %LOG%
call flutter pub get >> %LOG% 2>&1
echo ==== flutter analyze ==== >> %LOG%
call flutter analyze --no-fatal-infos --no-fatal-warnings >> %LOG% 2>&1
echo ANALYZE_EXIT=%errorlevel% >> %LOG%
echo ==== flutter test ==== >> %LOG%
call flutter test >> %LOG% 2>&1
echo TEST_EXIT=%errorlevel% >> %LOG%
echo ==== flutter build apk --release ==== >> %LOG%
call flutter build apk --release >> %LOG% 2>&1
echo BUILD_EXIT=%errorlevel% >> %LOG%
if exist build\app\outputs\flutter-apk\app-release.apk (
  copy /y build\app\outputs\flutter-apk\app-release.apk PDF_Studio_Pro_v1.2.apk >nul
  echo APK_OK=PDF_Studio_Pro_v1.2.apk >> %LOG%
)
echo ==== SELESAI ==== >> %LOG%
echo Selesai. Lihat verifikasi_log.txt
pause
