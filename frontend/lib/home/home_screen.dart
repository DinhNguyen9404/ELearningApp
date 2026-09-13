import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../core/notifiers.dart';
import '../features/profile/profile_tab.dart';
import 'admin_home_tab.dart';
import 'user_home_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    String? role = await _storage.read(key: 'role');
    setState(() {
      _isAdmin = (role == 'ADMIN');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final List<Widget> pages = [
      _isAdmin ? const AdminHomeTab() : const UserHomeTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<int>(
        valueListenable: AppNotifiers.currentTabNotifier,
        builder: (context, index, child) {
          final safeIndex = index >= pages.length ? 0 : index;
          return SafeArea(child: pages[safeIndex]);
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: AppNotifiers.currentTabNotifier,
        builder: (context, index, child) {
          final safeIndex = index >= pages.length ? 0 : index;
          return ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: BottomNavigationBar(
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  items: <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(
                        _isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.home_rounded,
                      ),
                      label: _isAdmin ? 'Bảng điều khiển' : 'Trang chủ',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person_rounded),
                      label: 'Trang cá nhân',
                    ),
                  ],
                  currentIndex: safeIndex,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textSecondary,
                  onTap: (newIndex) {
                    AppNotifiers.currentTabNotifier.value = newIndex;
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
