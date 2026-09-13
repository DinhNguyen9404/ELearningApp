import 'package:flutter/material.dart';
import 'package:frontend/core/notifiers.dart';
import '../../core/constants.dart';
import 'vocabulary_selection_screen.dart';

class VocabularyTestScreen extends StatefulWidget {
  final List<dynamic> testQuestions;
  const VocabularyTestScreen({super.key, required this.testQuestions});

  @override
  State<VocabularyTestScreen> createState() => _VocabularyTestScreenState();
}

class _VocabularyTestScreenState extends State<VocabularyTestScreen> {
  int _currentIndex = 0;
  bool _isAnswering = false;
  int? _selectedIndex;
  int _correctCount = 0;

  void _handleAnswer(int selectedOptionIndex) {
    if (_isAnswering) return;

    final question = widget.testQuestions[_currentIndex];
    final bool isCorrect = (selectedOptionIndex == question['correct_index']);

    setState(() {
      _isAnswering = true;
      _selectedIndex = selectedOptionIndex;
      if (isCorrect) _correctCount++;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentIndex < widget.testQuestions.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswering = false;
          _selectedIndex = null;
        });
      } else {
        _showCompletionDialog();
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 60,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Hoàn thành ôn tập!',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            'Bạn đã trả lời đúng $_correctCount/${widget.testQuestions.length} từ vựng.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppButtons.primaryButton,
                onPressed: () {
                  AppNotifiers.hasCompletedVocabTest = true;

                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VocabularySelectionScreen(),
                    ),
                  );
                },
                child: const Text('Vào bài học mới'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.testQuestions[_currentIndex];
    final List<dynamic> options = currentQuestion['options'];
    final int correctIndex = currentQuestion['correct_index'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ôn tập từ vựng',
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.testQuestions.length,
              backgroundColor: Colors.grey.shade300,
              color: AppColors.primary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                decoration: AppDecorations.questionCard,
                child: Center(
                  child: Text(
                    currentQuestion['word'],
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final bool isSelected = (_selectedIndex == index);
                    final bool isCorrectOption = (correctIndex == index);

                    final decoration = AppDecorations.answerOption(
                      isAnswered: _isAnswering,
                      isCorrect: isCorrectOption,
                      isSelected: isSelected,
                    );

                    Color textColor = AppColors.textPrimary;
                    if (_isAnswering) {
                      if (isCorrectOption) {
                        textColor = AppColors.textWhite;
                      } else if (isSelected && !isCorrectOption) {
                        textColor = AppColors.textWhite;
                      }
                    }

                    return GestureDetector(
                      onTap: () => _handleAnswer(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: decoration,
                        child: Text(
                          options[index],
                          style: AppTextStyles.h3.copyWith(color: textColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
