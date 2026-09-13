import 'package:flutter/material.dart';
import 'package:frontend/features/admin/admin_user_tab.dart';
import '../features/admin/admin_statistics_screen.dart';
import '../core/constants.dart';
import '../features/forum/forum_screen.dart';
import '../core/home_button.dart';

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.xl * 2,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAdminBanner(),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VividButton(
                            icon: Icons.forum_rounded,
                            label: 'Diễn đàn cộng đồng',
                            gradient: AppGradients.primary,
                            shadowColor: AppColors.primary,
                            onTap: () => Navigator.push(
                              context,
                              createSlideRoute(const ForumScreen()),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          VividButton(
                            icon: Icons.manage_accounts_rounded,
                            label: 'Quản lý người dùng',
                            gradient: AppGradients.accent,
                            shadowColor: AppColors.accent,
                            onTap: () {
                              Navigator.push(
                                context,
                                createSlideRoute(
                                  const Scaffold(
                                    backgroundColor: AppColors.background,
                                    body: SafeArea(child: AdminUsersTab()),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          VividButton(
                            icon: Icons.analytics_rounded,
                            label: 'Thống kê',
                            gradient: AppGradients.success,
                            shadowColor: AppColors.success,
                            onTap: () {
                              Navigator.push(
                                context,
                                createSlideRoute(const AdminStatisticsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminBanner() {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.primaryLight, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'QUẢN TRỊ VIÊN',
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Chào mừng bạn quay trở lại',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
