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

  static void show(BuildContext context, {required String title, String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProcessingDialog(
        title: title,
        message: message ?? 'Mohon tunggu sebentar...',
      ),
    );
  }

  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
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
          ],
        ),
      ),
    );
  }
}
