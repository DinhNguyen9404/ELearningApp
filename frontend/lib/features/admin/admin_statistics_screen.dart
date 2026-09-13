import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/api_endpoints.dart';
import '../../core/constants.dart';

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _statsData;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.adminStatistics()),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _statsData = json.decode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Lỗi tải dữ liệu: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối mạng!';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Thống kê Hệ thống',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: AppColors.error),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchStatistics,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng quan', style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Người dùng',
                            value: '${_statsData!['overview']['total_users']}',
                            icon: Icons.people_alt_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Lượt chơi Game',
                            value:
                                '${_statsData!['overview']['total_game_plays']}',
                            icon: Icons.sports_esports_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    const Text('Trò chơi Minigame', style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.md),

                    _buildGameCategoryCard(
                      title: 'Trò chơi Hệ thống',
                      total: _statsData!['games']['total_system'],
                      breakdown: _statsData!['games']['system_breakdown'],
                      headerColor: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildGameCategoryCard(
                      title: 'Trò chơi Cộng đồng',
                      total: _statsData!['games']['total_community'],
                      breakdown: _statsData!['games']['community_breakdown'],
                      headerColor: AppColors.accent,
                      pendingCount: _statsData!['games']['pending_approvals'],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    const Text('Học tập & Từ vựng', style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Bộ từ vựng',
                            value:
                                '${_statsData!['vocabulary']['total_decks']}',
                            icon: Icons.style_rounded,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Tổng số từ',
                            value:
                                '${_statsData!['vocabulary']['total_words']}',
                            icon: Icons.translate_rounded,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Đang có ${_statsData!['vocabulary']['total_active_learners']} lượt người dùng đang học bộ từ vựng.',
                            style: const TextStyle(
                              color: AppColors.accentDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
        border: Border(bottom: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTextStyles.h1.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(title, style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }

  Widget _buildGameCategoryCard({
    required String title,
    required int total,
    required Map<String, dynamic> breakdown,
    required Color headerColor,
    int pendingCount = 0,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.cardStyle,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  title.contains('Hệ thống')
                      ? Icons.admin_panel_settings_rounded
                      : Icons.public_rounded,
                  color: headerColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                'Tổng: $total',
                style: TextStyle(
                  color: headerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          if (pendingCount > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'Đang có $pendingCount màn chơi chờ duyệt',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],

          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTypeIcon(
                Icons.quiz_rounded,
                'Trắc nghiệm',
                breakdown['QUIZ'] ?? 0,
                AppColors.primary,
              ),
              _buildTypeIcon(
                Icons.lightbulb_rounded,
                'Đoán từ',
                breakdown['GUESS'] ?? 0,
                AppColors.accent,
              ),
              _buildTypeIcon(
                Icons.sort_rounded,
                'Sắp xếp',
                breakdown['SORT'] ?? 0,
                AppColors.success,
              ),
              _buildTypeIcon(
                Icons.headphones_rounded,
                'Đánh vần',
                breakdown['SPELLING'] ?? 0,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
