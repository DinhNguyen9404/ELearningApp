import 'package:flutter/material.dart';
import '../../core/constants.dart';

class GameResultDialog extends StatelessWidget {
  final String title;
  final bool isSuccess;
  final int score;
  final int maxScore;
  final bool isTrial;
  final VoidCallback onQuit;
  final VoidCallback onRetry;
  const GameResultDialog({
    super.key,
    required this.title,
    required this.isSuccess,
    required this.score,
    required this.maxScore,
    this.isTrial = false,
    required this.onQuit,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGoodScore = score >= (maxScore * 0.6);

    final Color accentColor = !isSuccess
        ? AppColors.error
        : (isGoodScore ? AppColors.success : AppColors.warning);

    final IconData resultIcon = !isSuccess
        ? (title.toLowerCase().contains('giờ')
              ? Icons.timer_off_rounded
              : Icons.cancel_rounded)
        : (isGoodScore ? Icons.emoji_events_rounded : Icons.flag_rounded);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(resultIcon, size: 36, color: accentColor),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),

            if (isTrial) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  'Chế độ chơi thử: Không lưu kết quả',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            Text('Điểm số nhận được', style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSpacing.xs),

            Text(
              '$score',
              style: AppTextStyles.scoreDisplay.copyWith(color: accentColor),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (!isSuccess) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: AppButtons.outlinedButton.copyWith(
                    foregroundColor: WidgetStateProperty.all(AppColors.error),
                    side: WidgetStateProperty.all(
                      const BorderSide(color: AppColors.error, width: 2),
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text('Thử lại lần nữa'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppButtons.primaryButton,
                onPressed: onQuit,
                child: const Text('Thoát'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
