import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:frontend/features/games/game_dashboard_screen.dart';
import '../core/constants.dart';
import '../features/forum/forum_screen.dart';
import '../core/notifiers.dart';
import '../features/vocabulary/vocabulary_selection_screen.dart';
import '../features/vocabulary/vocabulary_test_screen.dart';
import '../core/home_button.dart';

class UserHomeTab extends StatefulWidget {
  const UserHomeTab({super.key});

  @override
  State<UserHomeTab> createState() => _UserHomeTabState();
}

class _UserHomeTabState extends State<UserHomeTab> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isCheckingVocab = false;

  Future<void> _handleVocabularyNavigation() async {
    if (_isCheckingVocab) return;

    if (AppNotifiers.hasCompletedVocabTest) {
      Navigator.push(
        context,
        createSlideRoute(const VocabularySelectionScreen()),
      );
      return;
    }

    setState(() => _isCheckingVocab = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.activeTest()),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await Future.delayed(const Duration(milliseconds: 150));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        if (data.isNotEmpty && mounted) {
          Navigator.push(
            context,
            createSlideRoute(VocabularyTestScreen(testQuestions: data)),
          );
        } else {
          AppNotifiers.hasCompletedVocabTest = true;
          if (mounted) {
            Navigator.push(
              context,
              createSlideRoute(const VocabularySelectionScreen()),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            createSlideRoute(const VocabularySelectionScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        Navigator.push(
          context,
          createSlideRoute(const VocabularySelectionScreen()),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingVocab = false);
    }
  }

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
                  _buildWelcomeBanner(),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VividButton(
                            icon: Icons.videogame_asset_rounded,
                            label: 'Trò chơi',
                            gradient: AppGradients.primary,
                            shadowColor: AppColors.primary,
                            onTap: () => Navigator.push(
                              context,
                              createSlideRoute(const GameDashboardScreen()),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          VividButton(
                            icon: Icons.auto_stories_rounded,
                            label: 'Học từ vựng',
                            gradient: AppGradients.accent,
                            shadowColor: AppColors.accent,
                            onTap: _isCheckingVocab
                                ? null
                                : _handleVocabularyNavigation,
                            loading: _isCheckingVocab,
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          VividButton(
                            icon: Icons.forum_rounded,
                            label: 'Diễn đàn',
                            gradient: AppGradients.success,
                            shadowColor: AppColors.success,
                            onTap: () => Navigator.push(
                              context,
                              createSlideRoute(const ForumScreen()),
                            ),
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

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.colored(AppColors.primary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.textWhite.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 40,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'WELCOME',
                  style: AppTextStyles.h1.copyWith(color: AppColors.textWhite),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hãy chọn phương pháp học tập của bạn',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textWhite.withValues(alpha: 0.85),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
