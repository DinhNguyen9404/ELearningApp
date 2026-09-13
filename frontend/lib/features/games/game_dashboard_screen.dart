import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/features/games/manage_game_tab.dart';
import 'approve_game_tab.dart';
import 'community_game_tab.dart';
import '../../core/constants.dart';
import '../../core/notifiers.dart';
import 'system_game_list_screen.dart';

class GameDashboardScreen extends StatefulWidget {
  const GameDashboardScreen({super.key});

  @override
  State<GameDashboardScreen> createState() => _GameDashboardScreenState();
}

class _GameDashboardScreenState extends State<GameDashboardScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isModerator = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    String? role = await _storage.read(key: 'role');
    String? isStaff = await _storage.read(key: 'is_staff');
    if (role == 'MODERATOR' || role == 'ADMIN' || isStaff == 'true') {
      setState(() => _isModerator = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Trang chủ',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: AppNotifiers.gameDashboardTabNotifier,
          builder: (context, tabIndex, child) {
            final safeIndex = tabIndex >= (_isModerator ? 4 : 3) ? 0 : tabIndex;

            return IndexedStack(
              index: safeIndex,
              children: [
                _buildSystemGamesTab(),
                const CommunityGamesTab(),
                const ManageGamesTab(),
                if (_isModerator) const ApproveGamesTab(),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: AppNotifiers.gameDashboardTabNotifier,
        builder: (context, tabIndex, child) {
          final safeIndex = tabIndex >= (_isModerator ? 4 : 3) ? 0 : tabIndex;

          return Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: (index) =>
                  AppNotifiers.gameDashboardTabNotifier.value = index,
              backgroundColor: AppColors.surface,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 11,
              ),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.videogame_asset_rounded, size: 26),
                  label: 'Hệ thống',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_rounded, size: 26),
                  label: 'Cộng đồng',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.folder_rounded, size: 26),
                  label: 'Quản lý',
                ),
                if (_isModerator)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.admin_panel_settings_rounded, size: 26),
                    label: 'Duyệt bài',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSystemGamesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Chọn thể loại', style: AppTextStyles.h1),
          const SizedBox(height: 40),

          _buildGameCategoryCard(
            title: 'Trắc nghiệm',
            icon: Icons.quiz_rounded,
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemGamesListScreen(
                    gameType: 'QUIZ',
                    title: 'Trắc nghiệm',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildGameCategoryCard(
            title: 'Đoán từ vựng',
            icon: Icons.lightbulb_outline_rounded,
            color: AppColors.accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemGamesListScreen(
                    gameType: 'GUESS',
                    title: 'Đoán từ vựng',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildGameCategoryCard(
            title: 'Sắp xếp từ',
            icon: Icons.sort_by_alpha_rounded,
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemGamesListScreen(
                    gameType: 'SORT',
                    title: 'Sắp xếp từ',
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          _buildGameCategoryCard(
            title: 'Đánh vần (Spelling Bee)',
            icon: Icons.spellcheck_rounded,
            color: const Color(0xFF9B59B6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemGamesListScreen(
                    gameType: 'SPELLING',
                    title: 'Đánh vần (Spelling Bee)',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: AppDecorations.cardStyle.copyWith(
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTextStyles.h2),
            ],
          ),
        ),
      ),
    );
  }
}
