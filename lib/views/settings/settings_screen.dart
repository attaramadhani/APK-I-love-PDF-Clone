import 'package:flutter/material.dart';
import '../../core/services/ai_intelligence_service.dart';
import '../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await AiIntelligenceService.getApiKey();
    if (key != null && key.isNotEmpty) {
      setState(() {
        _hasApiKey = true;
        _apiKeyController.text = key;
      });
    }
  }

  Future<void> _saveApiKey() async {
    await AiIntelligenceService.saveApiKey(_apiKeyController.text.trim());
    setState(() {
      _hasApiKey = _apiKeyController.text.trim().isNotEmpty;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kunci API Gemini berhasil disimpan!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pro Status Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PDF Studio Pro (Aktif)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('UNLOCKED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seluruh pemrosesan PDF berjalan 100% lokal di perangkat Anda tanpa batas ukuran file dan bebas iklan.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // AI Intelligence Section
          const Text('KECERDASAN BUATAN (AI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.intelligenceAi),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Google Gemini API Key',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (_hasApiKey)
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Digunakan untuk fitur Perangkum AI, Terjemahan PDF, dan Markdown Generator. Gratis dari Google AI Studio.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Masukkan Kunci API...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saveApiKey,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.intelligenceAi),
                      child: const Text('Simpan Kunci API'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // General Settings
          const Text('UMUM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.language_rounded, color: AppColors.primaryRed),
                  title: Text('Bahasa'),
                  trailing: Text('Bahasa Indonesia', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.security_rounded, color: AppColors.securityNavy),
                  title: Text('Privasi & Keamanan'),
                  subtitle: Text('File Anda diproses secara lokal dan tidak diunggah ke server publik.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset('assets/images/app_logo.jpg', width: 28, height: 28, fit: BoxFit.cover),
                  ),
                  title: const Text('Tentang PDF Studio Pro'),
                  subtitle: const Text('Versi 1.0.0 (Mesin PDF & AI Mandiri)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
