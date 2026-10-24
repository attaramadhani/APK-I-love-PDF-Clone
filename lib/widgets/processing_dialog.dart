import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ProcessingDialog extends StatelessWidget {
  final String title;
  final String message;

  const ProcessingDialog({
    super.key,
    required this.title,
    this.message = 'Mohon tunggu sebentar...',
  });

  /// Teks progres opsional (mis. "Halaman 3 dari 10") yang bisa diperbarui
  /// selama proses berjalan lewat [updateProgress].
  static final ValueNotifier<String> _progress = ValueNotifier<String>('');

  /// Memperbarui teks progres pada dialog yang sedang tampil.
  static void updateProgress(String text) => _progress.value = text;

  static bool _isShowing = false;
  static int _token = 0;

  /// Menampilkan dialog loading. Aman dipanggil berulang (tidak menumpuk).
  static void show(BuildContext context, {required String title, String? message}) {
    if (_isShowing) return;
    _isShowing = true;
    _progress.value = '';
    final myToken = ++_token;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: ProcessingDialog(
          title: title,
          message: message ?? 'Mohon tunggu sebentar...',
        ),
      ),
    ).whenComplete(() {
      if (myToken == _token) _isShowing = false;
    });
  }

  /// Menutup dialog loading HANYA bila sedang tampil, sehingga tidak pernah
  /// menutup halaman alat secara tidak sengaja.
  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            ValueListenableBuilder<String>(
              valueListenable: _progress,
              builder: (context, value, _) => value.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
