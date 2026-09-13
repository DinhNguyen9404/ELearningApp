import 'package:flutter/material.dart';
import 'constants.dart';

Route createSlideRoute(Widget destination) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => destination,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

class VividButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final Color shadowColor;
  final VoidCallback? onTap;
  final bool loading;

  const VividButton({
    super.key,
    required this.icon,
    required this.label,
    required this.gradient,
    required this.shadowColor,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onTap == null && !loading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.55 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 92,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.full),
            splashColor: AppColors.textWhite.withValues(alpha: 0.25),
            highlightColor: AppColors.textWhite.withValues(alpha: 0.15),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: AppShadows.colored(shadowColor),
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.textWhite,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.textWhite.withValues(
                                alpha: 0.22,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: AppColors.textWhite,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            label,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 21,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
