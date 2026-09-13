import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/notifiers.dart';
import 'play_game_button.dart';

class ApproveGamesTab extends StatefulWidget {
  const ApproveGamesTab({super.key});

  @override
  State<ApproveGamesTab> createState() => _ApproveGamesTabState();
}

class _ApproveGamesTabState extends State<ApproveGamesTab> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<dynamic> _pendingGames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingGames();
    AppNotifiers.gameDashboardTabNotifier.addListener(_checkTabReload);
  }

  void _checkTabReload() {
    if (AppNotifiers.gameDashboardTabNotifier.value == 3 && mounted) {
      _fetchPendingGames();
    }
  }

  @override
  void dispose() {
    AppNotifiers.gameDashboardTabNotifier.removeListener(_checkTabReload);
    super.dispose();
  }

  Future<void> _fetchPendingGames() async {
    setState(() => _isLoading = true);
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.pendingGames()),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _pendingGames = json.decode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi kết nối khi tải danh sách chờ duyệt'),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReviewAction(int gameId, String action) async {
    Navigator.pop(context);

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
        Uri.parse(ApiEndpoints.reviewGame(gameId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': action}),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'APPROVE'
                    ? 'Đã phê duyệt màn chơi!'
                    : 'Đã từ chối màn chơi.',
              ),
            ),
          );
          _fetchPendingGames();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại.')),
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

  void _showGameDetails(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game['name'], style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Người tạo: ${game['creator']}',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailBadge(
                    Icons.category,
                    game['game_type'],
                    AppColors.primary,
                  ),
                  _buildDetailBadge(
                    Icons.speed,
                    game['difficulty'],
                    AppColors.warning,
                  ),
                  _buildDetailBadge(
                    Icons.stars,
                    '${game['base_score']} điểm',
                    AppColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: PlayGameButton(
                  gameData: game,
                  isSystemGame: false,
                  isTrial: true,
                ),
              ),
              const Divider(height: AppSpacing.xxl),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: AppButtons.outlinedButton.copyWith(
                        foregroundColor: WidgetStateProperty.all(
                          AppColors.error,
                        ),
                        side: WidgetStateProperty.all(
                          const BorderSide(color: AppColors.error, width: 2),
                        ),
                      ),
                      onPressed: () =>
                          _submitReviewAction(game['id'], 'REJECT'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('TỪ CHỐI'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: AppButtons.primaryButton.copyWith(
                        backgroundColor: WidgetStateProperty.all(
                          AppColors.success,
                        ),
                      ),
                      onPressed: () =>
                          _submitReviewAction(game['id'], 'APPROVE'),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('PHÊ DUYỆT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : _pendingGames.isEmpty
        ? const Center(
            child: Text(
              'Không có màn chơi nào đang chờ duyệt.',
              style: AppTextStyles.bodySecondary,
            ),
          )
        : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _fetchPendingGames,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _pendingGames.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final game = _pendingGames[index];
                return InkWell(
                  onTap: () => _showGameDetails(game),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: AppDecorations.cardStyle.copyWith(
                      border: Border.all(color: AppColors.warning, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(game['name'], style: AppTextStyles.h3),
                              const SizedBox(height: 4),
                              Text(
                                'Bởi: ${game['creator']} • ${game['game_type']}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
  }
}
