import 'package:flutter/material.dart';

enum ToolCategory {
  all('Semua', Icons.grid_view_rounded),
  organize('Atur PDF', Icons.layers_outlined),
  optimize('Optimalkan', Icons.speed_rounded),
  convert('Konversi', Icons.transform_rounded),
  edit('Edit PDF', Icons.edit_document),
  security('Keamanan', Icons.lock_outline_rounded),
  intelligence('PDF AI', Icons.auto_awesome_rounded);

  final String label;
  final IconData icon;
  const ToolCategory(this.label, this.icon);
}

class PdfToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconBgColor;
  final ToolCategory category;
  final String? badge;
  final Color? badgeColor;
  final bool isPro;

  const PdfToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBgColor,
    required this.category,
    this.badge,
    this.badgeColor,
    this.isPro = false,
  });
}
