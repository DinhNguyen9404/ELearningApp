import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../ai_assistant/ai_chat_screen.dart';
import 'explore_vocabulary_screen.dart';
import 'saved_vocabulary_screen.dart';
import 'manage_vocabulary_screen.dart';
import '../../core/constants.dart';

class VocabularySelectionScreen extends StatefulWidget {
  const VocabularySelectionScreen({super.key});

  @override
  State<VocabularySelectionScreen> createState() =>
      _VocabularySelectionScreenState();
}

class _VocabularySelectionScreenState extends State<VocabularySelectionScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isModerator = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    String? role = await _storage.read(key: 'role');
    if (role == 'MODERATOR') {
      setState(() {
        _isModerator = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Học từ vựng',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chọn chế độ học', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              const Text(
                'Bạn muốn tiếp tục ôn tập hay khám phá kiến thức mới?',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 32),

              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildSelectionCard(
                      context,
                      title: 'Từ vựng đã lưu',
                      description:
                          'Ôn tập danh sách các bộ từ vựng bạn đang theo học.',
                      icon: Icons.bookmarks_rounded,
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavedVocabularyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSelectionCard(
                      context,
                      title: 'Khám phá từ vựng',
                      description:
                          'Tìm kiếm các bộ từ vựng mới từ hệ thống và cộng đồng.',
                      icon: Icons.explore_rounded,
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ExploreVocabularyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSelectionCard(
                      context,
                      title: 'Hỏi đáp với AI',
                      description:
                          'Trợ lý ảo giải thích ngữ pháp, ngữ cảnh và cách phát âm.',
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.success,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AIChatScreen(),
                          ),
                        );
                      },
                    ),

                    if (_isModerator) ...[
                      const SizedBox(height: 16),
                      _buildSelectionCard(
                        context,
                        title: 'Quản lý bộ từ vựng',
                        description:
                            'Dành cho Kiểm duyệt viên: Tạo và quản lý Flashcard.',
                        icon: Icons.admin_panel_settings_rounded,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ManageVocabularyScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.cardStyle.copyWith(
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
