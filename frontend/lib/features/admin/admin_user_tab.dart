import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/api_endpoints.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.adminUsers()),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _users = json.decode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi kết nối khi tải danh sách người dùng'),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole(int userId, String currentRole) async {
    final String? newRole = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Cấp quyền người dùng', style: AppTextStyles.h3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          children: <Widget>[
            _buildRoleOption(context, 'USER', 'Người dùng', currentRole),
            _buildRoleOption(
              context,
              'MODERATOR',
              'Kiểm duyệt viên',
              currentRole,
            ),
            _buildRoleOption(context, 'ADMIN', 'Quản trị viên', currentRole),
          ],
        );
      },
    );

    if (newRole == null || newRole == currentRole) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse(ApiEndpoints.adminChangeRole(userId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'role': newRole}),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật quyền thành công!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi khi cập nhật quyền.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi kết nối mạng.')));
      }
    }
  }

  SimpleDialogOption _buildRoleOption(
    BuildContext context,
    String roleValue,
    String roleName,
    String currentRole,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, roleValue),
      child: Row(
        children: [
          Icon(
            currentRole == roleValue
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: currentRole == roleValue
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Text(roleName, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Future<void> _deleteUser(int userId, String username) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Xác nhận xóa',
                style: AppTextStyles.h2.copyWith(color: AppColors.error),
              ),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa người dùng "$username" không? Hành động này không thể hoàn tác.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.textWhite),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        Uri.parse(ApiEndpoints.adminUserDetail(userId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 204) {
        setState(() => _users.removeWhere((u) => u['id'] == userId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa người dùng thành công.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi khi xóa người dùng.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi kết nối mạng.')));
      }
    }
  }

  Widget _buildAvatar(String? avatarUrl, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.5),
        color: AppColors.background,
      ),
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.person_rounded,
                  size: size * 0.6,
                  color: AppColors.textSecondary,
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: size * 0.6,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'ADMIN':
        return AppColors.error;
      case 'MODERATOR':
        return AppColors.accent;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Quản lý người dùng', style: AppTextStyles.h2),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _users.isEmpty
          ? const Center(
              child: Text(
                'Không có người dùng nào.',
                style: AppTextStyles.bodySecondary,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchUsers,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _users.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final role = user['role'] ?? 'USER';

                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: AppDecorations.cardStyle,
                    child: Row(
                      children: [
                        _buildAvatar(user['avatar_url']),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['username'], style: AppTextStyles.h3),
                              const SizedBox(height: 4),
                              Text(
                                user['email'] ?? 'Không có email',
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(
                                    role,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    color: _getRoleColor(role),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppColors.textSecondary,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _changeRole(user['id'], role);
                            } else if (value == 'delete') {
                              _deleteUser(user['id'], user['username']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Cấp quyền'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Xóa tài khoản',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
