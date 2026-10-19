import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/pdf_tools_data.dart';
import '../../models/pdf_tool_item.dart';
import '../tools/ai_intelligence_screen.dart';
import '../tools/camera_scanner_screen.dart';
import '../tools/compare_pdf_screen.dart';
import '../tools/compress_pdf_screen.dart';
import '../tools/convert_document_screen.dart';
import '../tools/crop_pdf_screen.dart';
import '../tools/esign_screen.dart';
import '../tools/image_to_pdf_screen.dart';
import '../tools/merge_pdf_screen.dart';
import '../tools/ocr_pdf_screen.dart';
import '../tools/organize_pages_screen.dart';
import '../tools/page_number_screen.dart';
import '../tools/pdf_to_image_screen.dart';
import '../tools/protect_pdf_screen.dart';
import '../tools/redact_pdf_screen.dart';
import '../tools/remove_pages_screen.dart';
import '../tools/repair_pdf_screen.dart';
import '../tools/rotate_pdf_screen.dart';
import '../tools/split_pdf_screen.dart';
import '../tools/watermark_screen.dart';
import 'widgets/category_filter_chips.dart';
import 'widgets/tool_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ToolCategory _selectedCategory = ToolCategory.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _onToolTap(PdfToolItem tool) {
    Widget targetScreen;
    switch (tool.id) {
      case 'merge':
        targetScreen = const MergePdfScreen();
        break;
      case 'split':
        targetScreen = const SplitPdfScreen();
        break;
      case 'organize_pages':
        targetScreen = const OrganizePagesScreen();
        break;
      case 'remove_pages':
        targetScreen = const RemovePagesScreen();
        break;
      case 'scan_pdf':
        targetScreen = const CameraScannerScreen();
        break;
      case 'compress':
        targetScreen = const CompressPdfScreen();
        break;
      case 'repair':
        targetScreen = const RepairPdfScreen();
        break;
      case 'ocr_pdf':
        targetScreen = const OcrPdfScreen();
        break;
      case 'jpg_to_pdf':
        targetScreen = const ImageToPdfScreen();
        break;
      case 'pdf_to_jpg':
        targetScreen = const PdfToImageScreen();
        break;
      case 'word_to_pdf':
        targetScreen = const ConvertDocumentScreen(mode: 'to_pdf', title: 'Word ke PDF');
        break;
      case 'pdf_to_word':
        targetScreen = const ConvertDocumentScreen(mode: 'to_word', title: 'PDF ke Word');
        break;
      case 'excel_to_pdf':
        targetScreen = const ConvertDocumentScreen(mode: 'to_pdf', title: 'Excel ke PDF');
        break;
      case 'pdf_to_excel':
        targetScreen = const ConvertDocumentScreen(mode: 'to_excel', title: 'PDF ke Excel');
        break;
      case 'rotate':
        targetScreen = const RotatePdfScreen();
        break;
      case 'page_numbers':
        targetScreen = const PageNumberScreen();
        break;
      case 'watermark':
        targetScreen = const WatermarkScreen();
        break;
      case 'crop':
        targetScreen = const CropPdfScreen();
        break;
      case 'sign':
        targetScreen = const EsignScreen();
        break;
      case 'protect':
        targetScreen = const ProtectPdfScreen(isUnlockMode: false);
        break;
      case 'unlock':
        targetScreen = const ProtectPdfScreen(isUnlockMode: true);
        break;
      case 'redact':
        targetScreen = const RedactPdfScreen();
        break;
      case 'compare':
        targetScreen = const ComparePdfScreen();
        break;
      case 'ai_summarize':
        targetScreen = const AiIntelligenceScreen(initialMode: 'summarize');
        break;
      case 'ai_translate':
        targetScreen = const AiIntelligenceScreen(initialMode: 'translate');
        break;
      case 'ai_markdown':
        targetScreen = const AiIntelligenceScreen(initialMode: 'markdown');
        break;
      default:
        targetScreen = const CompressPdfScreen();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTools = PdfToolsData.allTools.where((tool) {
      final matchesCategory = _selectedCategory == ToolCategory.all || tool.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          tool.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tool.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                children: [
                  TextSpan(text: 'PDF ', style: TextStyle(color: AppColors.primaryBlue)),
                  TextSpan(text: 'Studio', style: TextStyle(color: Color(0xFF0F172A))),
                  TextSpan(text: ' PRO', style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.badgeProBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.badgeProText),
                SizedBox(width: 4),
                Text(
                  'PRO AKTIF',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.badgeProText),
                ),
              ],
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search Box
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari dari 25+ alat PDF Studio...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ),
          ),

          // Category Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CategoryFilterChips(
                selectedCategory: _selectedCategory,
                onSelected: (cat) => setState(() => _selectedCategory = cat),
              ),
            ),
          ),

          // Tools Grid
          filteredTools.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Text('Tidak ada alat yang cocok dengan pencarian Anda.'),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = filteredTools[index];
                        return ToolCard(
                          tool: tool,
                          onTap: () => _onToolTap(tool),
                        );
                      },
                      childCount: filteredTools.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
