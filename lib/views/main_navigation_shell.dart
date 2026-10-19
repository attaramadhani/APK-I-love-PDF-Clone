import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'home/home_screen.dart';
import 'recent/recent_files_screen.dart';
import 'settings/settings_screen.dart';
import 'tools/camera_scanner_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final GlobalKey<RecentFilesScreenState> _recentKey = GlobalKey<RecentFilesScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          RecentFilesScreen(
            key: _recentKey,
            onGoToTools: () => setState(() => _currentIndex = 0),
          ),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const CameraScannerScreen()),
          );
          // Bila selesai scan dan kembali, segarkan riwayat
          _recentKey.currentState?.loadFiles();
        },
        backgroundColor: AppColors.primaryBlue,
        elevation: 4,
        child: const Icon(Icons.document_scanner_rounded, size: 28, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            // Segarkan data terbaru setiap kali tab Terkini dipilih
            _recentKey.currentState?.loadFiles();
          }
        },
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: AppColors.primaryBlueLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.primaryBlue),
            label: 'Alat PDF',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded, color: AppColors.primaryBlue),
            label: 'Terkini',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primaryBlue),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
