import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/ai_intelligence_service.dart';
import '../../core/services/pdf_engine_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_helper.dart';
import '../../widgets/processing_dialog.dart';

class AiIntelligenceScreen extends StatefulWidget {
  final String initialMode; // 'summarize', 'translate', 'markdown'

  const AiIntelligenceScreen({super.key, this.initialMode = 'summarize'});

  @override
  State<AiIntelligenceScreen> createState() => _AiIntelligenceScreenState();
}

class _AiIntelligenceScreenState extends State<AiIntelligenceScreen> {
  File? _selectedFile;
  String _extractedText = '';
  String _aiResult = '';
  late String _currentMode;
  String _targetLanguage = 'Bahasa Indonesia';

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      ProcessingDialog.show(context, title: 'Mengekstrak Teks', message: 'Membaca konten dokumen PDF...');

      try {
        final text = await PdfEngineService.extractText(file);
        if (mounted) {
          ProcessingDialog.hide(context);
          setState(() {
            _selectedFile = file;
            _extractedText = text;
            _aiResult = '';
          });
        }
      } catch (e) {
        if (mounted) {
          ProcessingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengekstrak teks: $e')),
          );
        }
      }
    }
  }

  void _runOffline() {
    String result = '';
    if (_currentMode == 'summarize') {
      result = AiIntelligenceService.summarizeTextLocally(_extractedText);
    } else if (_currentMode == 'markdown') {
      result = AiIntelligenceService.convertToMarkdownLocally(_extractedText);
    } else {
      result = 'Fitur terjemahan memerlukan koneksi internet dan Google Gemini API Key. Masukkan API Key Anda di Pengaturan untuk menerjemahkan dokumen.';
    }
    setState(() {
      _aiResult = result;
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: AppColors.intelligenceAi),
            SizedBox(width: 8),
            Text('Kunci API Gemini'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan Google Gemini API Key Anda untuk analisis AI mendalam gratis dari Google AI Studio.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runOffline();
            },
            child: const Text('Mode Offline'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await AiIntelligenceService.saveApiKey(controller.text.trim());
                if (mounted) Navigator.pop(ctx);
                _runAi();
              } else {
                Navigator.pop(ctx);
                _runOffline();
              }
            },
            child: const Text('Simpan & Jalankan'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAi() async {
    if (_extractedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teks dokumen kosong atau tidak terdeteksi')),
      );
      return;
    }

    final apiKey = await AiIntelligenceService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _showApiKeyDialog();
      return;
    }

    ProcessingDialog.show(
      context,
      title: 'Memproses dengan AI',
      message: 'Model Gemini sedang menganalisis dokumen Anda...',
    );

    try {
      String result = '';
      if (_currentMode == 'summarize') {
        result = await AiIntelligenceService.summarizeText(_extractedText);
      } else if (_currentMode == 'translate') {
        result = await AiIntelligenceService.translateText(_extractedText, _targetLanguage);
      } else {
        result = await AiIntelligenceService.convertToMarkdown(_extractedText);
      }

      if (mounted) {
        ProcessingDialog.hide(context);
        setState(() {
          _aiResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ProcessingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error AI: $e (Menampilkan hasil lokal)'),
            action: SnackBarAction(
              label: 'Mode Offline',
              onPressed: _runOffline,
            ),
          ),
        );
        _runOffline();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Intelligence (AI)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded),
            tooltip: 'Atur Kunci API AI',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: _selectedFile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.intelligenceAi.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.intelligenceAi),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pilih PDF untuk Dianalisis AI',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rangkum berkas panjang, terjemahkan bahasa, atau ekstrak teks menjadi Markdown terstruktur secara instan.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Pilih Dokumen PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.intelligenceAi),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.uri.pathSegments.last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${FileHelper.formatBytes(_selectedFile!.lengthSync())} • ${_extractedText.length} karakter teks',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(onPressed: _pickFile, child: const Text('Ganti')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      _buildModeChip('summarize', 'Perangkum AI', Icons.summarize_rounded),
                      const SizedBox(width: 8),
                      _buildModeChip('translate', 'Terjemahkan', Icons.translate_rounded),
                      const SizedBox(width: 8),
                      _buildModeChip('markdown', 'Markdown', Icons.code_rounded),
                    ],
                  ),
                ),
                if (_currentMode == 'translate')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: DropdownButtonFormField<String>(
                      value: _targetLanguage,
                      decoration: InputDecoration(
                        labelText: 'Bahasa Tujuan',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['Bahasa Indonesia', 'English', 'Español', 'Français', 'Deutsch', '日本語', 'العربية']
                          .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _targetLanguage = val);
                      },
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: _aiResult.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome_outlined, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Hasil analisis AI akan muncul di sini',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _runAi,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Mulai Proses AI'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.intelligenceAi),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Hasil Analisis AI:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.file_download_rounded, size: 20, color: AppColors.primaryBlue),
                                          tooltip: 'Simpan ke File Lokal (.txt)',
                                          onPressed: () async {
                                            final fileName = 'AI_${_currentMode}_${DateTime.now().millisecondsSinceEpoch}.txt';
                                            final bytes = utf8.encode(_aiResult);
                                            await FilePicker.saveFile(
                                              fileName: fileName,
                                              bytes: Uint8List.fromList(bytes),
                                              dialogTitle: 'Simpan Hasil AI ke File Lokal',
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Hasil AI berhasil disimpan ke penyimpanan lokal!')),
                                              );
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 20),
                                          tooltip: 'Salin Teks',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: _aiResult));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Teks berhasil disalin ke clipboard!')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                SelectableText(
                                  _aiResult,
                                  style: const TextStyle(fontSize: 14, height: 1.6),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModeChip(String mode, String label, IconData icon) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.intelligenceAi : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.intelligenceAi : AppColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
