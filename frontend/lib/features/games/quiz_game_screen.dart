import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api_endpoints.dart';
import '../../core/constants.dart';
import 'game_result_dialog.dart';

class QuizGameScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final bool isTrial;
  final bool isSystemGame;

  const QuizGameScreen({
    super.key,
    required this.gameData,
    this.isTrial = false,
    this.isSystemGame = false,
  });

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late List<dynamic> _questions;
  int _currentIndex = 0;

  int _currentScore = 0;
  late int _pointPerQuestion;

  bool _isAnswered = false;
  int? _selectedIndex;

  Timer? _timer;
  bool _hasTimeLimit = false;
  int _timeLeft = 0;

  @override
  void initState() {
    super.initState();
    _questions = widget.gameData['game_data'] ?? [];

    final int baseScore = widget.gameData['base_score'] ?? 100;
    _pointPerQuestion = _questions.isNotEmpty
        ? (baseScore ~/ _questions.length)
        : 0;

    final dynamic timeLimitData = widget.gameData['time_limit'];
    if (timeLimitData != null && timeLimitData > 0) {
      _hasTimeLimit = true;
      _timeLeft = timeLimitData;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _showResultDialog(isTimeOut: true);
      }
    });
  }

  String get _formattedTime {
    int m = _timeLeft ~/ 60;
    int s = _timeLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _checkAnswer(int selectedIndex) {
    if (_isAnswered) return;

    final int correctIndex = _questions[_currentIndex]['correct_index'];

    setState(() {
      _isAnswered = true;
      _selectedIndex = selectedIndex;

      if (selectedIndex == correctIndex) {
        _currentScore += _pointPerQuestion;

        final int maxScore = widget.gameData['base_score'] ?? 100;
        if (_currentScore > maxScore) {
          _currentScore = maxScore;
        }
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      if (_timeLeft <= 0 && _hasTimeLimit) return;

      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _selectedIndex = null;
        });
      } else {
        _timer?.cancel();
        _showResultDialog(isTimeOut: false);
      }
    });
  }

  Future<void> _submitScore() async {
    if (widget.isTrial) return;
    try {
      String? token = await _storage.read(key: 'access_token');
      final int levelId = widget.gameData['id'];

      final Uri submitUri = widget.isSystemGame
          ? Uri.parse(ApiEndpoints.submitSystemGame(levelId))
          : Uri.parse(ApiEndpoints.submitCommunityGame(levelId));

      await http.post(
        submitUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{"score_earned": $_currentScore}',
      );
    } catch (e) {
      debugPrint("Lỗi lưu điểm: $e");
    }
  }

  void _showResultDialog({required bool isTimeOut}) {
    setState(() => _isAnswered = true);
    _submitScore();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return GameResultDialog(
          title: isTimeOut ? 'Hết giờ!' : 'Hoàn thành!',
          isSuccess: !isTimeOut,
          score: _currentScore,
          maxScore: widget.gameData['base_score'] ?? 100,
          isTrial: widget.isTrial,
          onQuit: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          onRetry: () {
            Navigator.of(context).pop();

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => QuizGameScreen(
                  gameData: widget.gameData,
                  isSystemGame: widget.isSystemGame,
                  isTrial: widget.isTrial,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Dữ liệu lỗi!', style: AppTextStyles.body)),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final List<dynamic> options = currentQuestion['options'];
    final int correctIndex = currentQuestion['correct_index'];
    final double progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.md),

              _buildProgressBar(progress),
              const SizedBox(height: AppSpacing.lg),

              if (_hasTimeLimit) ...[
                _buildTimerChip(),
                const SizedBox(height: AppSpacing.lg),
              ],

              Expanded(flex: 3, child: _buildQuestionCard(currentQuestion)),
              const SizedBox(height: AppSpacing.lg),

              Expanded(flex: 3, child: _buildAnswerGrid(options, correctIndex)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.full),
          onTap: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: AppShadows.soft,
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            widget.isTrial ? 'Chơi thử' : (widget.gameData['name'] ?? ''),
            style: AppTextStyles.h2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
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
              const SizedBox(width: 6),
              Text(
                'Điểm số: $_currentScore',
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${_currentIndex + 1}/${_questions.length}',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildTimerChip() {
    final bool isLow = _timeLeft <= 10;
    final Color color = isLow ? AppColors.error : AppColors.primary;

    return Center(
      child: AnimatedScale(
        scale: isLow && _timeLeft.isOdd ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: AppDecorations.statChip(color: color),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_filled_rounded, size: 20, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Thời gian còn lại: $_formattedTime',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(dynamic currentQuestion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.questionCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'CÂU HỎI ${_currentIndex + 1}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Text(currentQuestion['question'], style: AppTextStyles.h3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerGrid(List<dynamic> options, int correctIndex) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.2,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        return _buildOptionCard(index, options[index], correctIndex);
      },
    );
  }

  Widget _buildOptionCard(int index, dynamic optionText, int correctIndex) {
    final bool isCorrect = index == correctIndex;
    final bool isSelected = index == _selectedIndex;
    final bool showResultColor = _isAnswered && (isCorrect || isSelected);

    Color textColor = AppColors.textPrimary;
    Color badgeColor = AppColors.primaryLight;
    Color badgeTextColor = AppColors.primary;
    Widget? trailingIcon;

    if (showResultColor) {
      textColor = AppColors.textWhite;
      badgeColor = Colors.white.withValues(alpha: 0.25);
      badgeTextColor = AppColors.textWhite;
      if (isCorrect) {
        trailingIcon = const Icon(
          Icons.check_circle_rounded,
          color: AppColors.textWhite,
          size: 20,
        );
      } else if (isSelected) {
        trailingIcon = const Icon(
          Icons.cancel_rounded,
          color: AppColors.textWhite,
          size: 20,
        );
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _checkAnswer(index),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: AppDecorations.answerOption(
              isAnswered: _isAnswered,
              isCorrect: isCorrect,
              isSelected: isSelected,
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: badgeTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    optionText.toString(),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ?trailingIcon,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
