import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:frontend/features/vocabulary/manage_vocabulary_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../auth/welcome_screen.dart';
import '../games/manage_game_tab.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _username = 'Đang tải...';
  String _email = 'Đang tải...';
  String _role = 'USER';
  String _totalScore = '0';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    String username = await _storage.read(key: 'username') ?? 'Người dùng';
    String email = await _storage.read(key: 'email') ?? 'Chưa cập nhật';
    String role = await _storage.read(key: 'role') ?? 'USER';
    String totalScore = await _storage.read(key: 'total_score') ?? '0';
    String avatarUrl = await _storage.read(key: 'avatar_url') ?? '';

    setState(() {
      _username = username;
      _email = email;
      _role = role;
      _totalScore = totalScore;
      _avatarUrl = avatarUrl;
    });

    _fetchLatestUserData();
  }

  Future<void> _fetchLatestUserData() async {
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.currentUser()),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        await _storage.write(
          key: 'total_score',
          value: data['total_score'].toString(),
        );
        await _storage.write(
          key: 'avatar_url',
          value: data['avatar_url'] ?? '',
        );
        await _storage.write(key: 'email', value: data['email'] ?? '');

        if (mounted) {
          setState(() {
            _totalScore = data['total_score'].toString();
            _avatarUrl = data['avatar_url'] ?? '';
            _email = data['email'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ thông tin cá nhân: $e");
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _storage.deleteAll();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  String _translateRole(String role) {
    switch (role) {
      case 'ADMIN':
        return 'Quản trị viên hệ thống';
      case 'MODERATOR':
        return 'Kiểm duyệt viên';
      default:
        return 'Người dùng cơ bản';
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'ADMIN':
        return Icons.shield_rounded;
      case 'MODERATOR':
        return Icons.verified_user_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageDecks = _role == 'MODERATOR';
    final bool canManageGames = _role == 'MODERATOR' || _role == 'USER';

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildMenuCard(canManageDecks, canManageGames),
                  const SizedBox(height: AppSpacing.xl),
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textWhite,
              boxShadow: AppShadows.card,
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: _avatarUrl.isNotEmpty
                  ? NetworkImage(_avatarUrl)
                  : null,
              child: _avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _username,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(color: AppColors.textWhite),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.textWhite.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_roleIcon(_role), size: 14, color: AppColors.textWhite),
                const SizedBox(width: 6),
                Text(
                  _translateRole(_role),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: AppShadows.colored(AppColors.accent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.textWhite,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_totalScore điểm',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: AppDecorations.cardStyle,
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 0,
          ),
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: const Text('Thông tin cá nhân', style: AppTextStyles.h3),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: AppSpacing.md, color: AppColors.border),
                  _buildDetailRow('Tên đăng nhập', _username),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow('Email', _email),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow('Vai trò', _translateRole(_role)),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow('Điểm tích lũy', _totalScore),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: AppButtons.outlinedButton.copyWith(
                            side: WidgetStateProperty.all(
                              const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                          onPressed: () async {
                            final bool? isUpdated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  currentUsername: _username,
                                  currentEmail: _email,
                                  currentAvatarUrl: _avatarUrl,
                                ),
                              ),
                            );
                            if (isUpdated == true) {
                              _loadUserProfile();
                            }
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text(
                            'Sửa thông tin',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: AppButtons.outlinedButton.copyWith(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 10),
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              AppColors.warning,
                            ),
                            side: WidgetStateProperty.all(
                              const BorderSide(
                                color: AppColors.warning,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ChangePasswordScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.lock_reset_rounded, size: 16),
                          label: const Text(
                            'Đổi mật khẩu',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: AppTextStyles.bodySecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(bool canManageDecks, bool canManageGames) {
    return Container(
      decoration: AppDecorations.cardStyle,
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            if (canManageDecks) ...[
              _buildListTile(
                'Quản lý bộ từ vựng',
                Icons.library_books_rounded,
                AppColors.primary,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageVocabularyScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppColors.border, indent: 68),
            ],
            if (canManageGames) ...[
              _buildListTile(
                'Quản lý màn chơi',
                Icons.videogame_asset_rounded,
                AppColors.accent,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: AppColors.background,
                        appBar: AppBar(
                          title: const Text(
                            'Quản lý màn chơi',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          iconTheme: const IconThemeData(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        body: const SafeArea(child: ManageGamesTab()),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    String title,
    IconData icon,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: accentColor, size: 20),
      ),
      title: Text(title, style: AppTextStyles.body),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: AppButtons.outlinedButton.copyWith(
          backgroundColor: WidgetStateProperty.all(AppColors.errorLight),
          foregroundColor: WidgetStateProperty.all(AppColors.error),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
        onPressed: () => _logout(context),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Đăng xuất'),
      ),
    );
  }
}
