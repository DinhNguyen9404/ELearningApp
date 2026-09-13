import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api_endpoints.dart';
import '../../core/constants.dart';
import 'game_result_dialog.dart';

class GuessGameScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final bool isTrial;
  final bool isSystemGame;

  const GuessGameScreen({
    super.key,
    required this.gameData,
    this.isTrial = false,
    this.isSystemGame = false,
  });

  @override
  State<GuessGameScreen> createState() => _GuessGameScreenState();
}

class _GuessGameScreenState extends State<GuessGameScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late List<dynamic> _words;
  int _currentIndex = 0;

  late int _wrongGuessesLeft;
  final int _maxWrongGuesses = 5;

  int _accumulatedScore = 0;
  late int _maxScorePerWord;
  late int _currentWordPotentialScore;
  late int _pointDeductPerHint;

  List<bool> _openedHints = [];
  List<String> _currentHints = [];

  Timer? _timer;
  bool _hasTimeLimit = false;
  int _timeLeft = 0;

  bool _isChecking = false;
  bool? _isLastGuessCorrect;

  @override
  void initState() {
    super.initState();
    _initGameData();
  }

  void _initGameData() {
    final rawData = widget.gameData['game_data'];
    if (rawData is List) {
      _words = rawData;
    } else if (rawData is Map) {
      _words = [rawData];
    } else {
      _words = [];
    }

    _wrongGuessesLeft = _maxWrongGuesses;

    final int totalBaseScore = widget.gameData['base_score'] ?? 100;
    _maxScorePerWord = _words.isNotEmpty
        ? (totalBaseScore ~/ _words.length)
        : 0;

    final dynamic timeLimitData = widget.gameData['time_limit'];
    if (timeLimitData != null && timeLimitData > 0) {
      _hasTimeLimit = true;
      _timeLeft = timeLimitData;
      _startTimer();
    }

    if (_words.isNotEmpty) {
      _loadWord(_currentIndex);
    }
  }

  void _loadWord(int index) {
    _answerController.clear();
    _isLastGuessCorrect = null;

    _currentHints = List<String>.from(_words[index]['hints'] ?? []);

    _openedHints = List<bool>.filled(_currentHints.length, false);
    if (_currentHints.isNotEmpty) {
      _openedHints[0] = true;
    }

    _currentWordPotentialScore = _maxScorePerWord;

    int deductAmount = _words[index]['deduct_per_hint'] ?? 0;
    if (deductAmount <= 0 && _currentHints.length > 1) {
      int maxPenalty = (_maxScorePerWord * 0.8).toInt();
      deductAmount = maxPenalty ~/ (_currentHints.length - 1);
    }
    _pointDeductPerHint = deductAmount;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _showResultDialog(reason: 'Hết giờ!');
      }
    });
  }

  String get _formattedTime {
    int m = _timeLeft ~/ 60;
    int s = _timeLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _openHint(int index) {
    if (_openedHints[index] || _isChecking) return;

    setState(() {
      _openedHints[index] = true;

      _currentWordPotentialScore -= _pointDeductPerHint;
      if (_currentWordPotentialScore < 0) _currentWordPotentialScore = 0;
    });
  }

  void _submitGuess() {
    final String guess = _answerController.text.trim();
    if (guess.isEmpty || _isChecking) return;

    setState(() => _isChecking = true);
    _focusNode.unfocus();

    final String targetWord = _words[_currentIndex]['target_word']
        .toString()
        .toLowerCase();
    final bool isCorrect = guess.toLowerCase() == targetWord;

    setState(() {
      _isLastGuessCorrect = isCorrect;
    });

    if (isCorrect) {
      _accumulatedScore += _currentWordPotentialScore;

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        if (_currentIndex < _words.length - 1) {
          setState(() {
            _currentIndex++;
            _isChecking = false;
            _loadWord(_currentIndex);
          });
        } else {
          _timer?.cancel();
          _showResultDialog(reason: 'Hoàn thành xuất sắc!');
        }
      });
    } else {
      _wrongGuessesLeft--;

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        if (_wrongGuessesLeft <= 0) {
          _timer?.cancel();
          _showResultDialog(reason: 'Hết lượt đoán sai!');
        } else {
          setState(() {
            _isChecking = false;
            _isLastGuessCorrect = null;
            _answerController.clear();
            _focusNode.requestFocus();
          });
        }
      });
    }
  }

  Future<void> _submitScoreToAPI() async {
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

        body: jsonEncode({'score_earned': _accumulatedScore}),
      );
    } catch (e) {
      debugPrint("Lỗi lưu điểm Game: $e");
    }
  }

  void _showResultDialog({required String reason}) {
    _submitScoreToAPI();

    final bool isSuccess = reason.contains('Hoàn thành');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return GameResultDialog(
          title: reason,
          isSuccess: isSuccess,
          score: _accumulatedScore,
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
                builder: (context) => GuessGameScreen(
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
    if (_words.isEmpty) {
      return const Scaffold(body: Center(child: Text('Dữ liệu lỗi!')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Thoát',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: AppShadows.soft,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Từ ${_currentIndex + 1} / ${_words.length}',
                        style: AppTextStyles.h3,
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: AppDecorations.statChip(
                          color: AppColors.accent,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Điểm: $_accumulatedScore',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(_maxWrongGuesses, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Icon(
                              index < _wrongGuessesLeft
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                          );
                        }),
                      ),

                      if (_hasTimeLimit)
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 20,
                              color: _timeLeft <= 10
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _formattedTime,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _timeLeft <= 10
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Đoán đúng nhận: +$_currentWordPotentialScore điểm',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  TextField(
                    controller: _answerController,
                    focusNode: _focusNode,
                    enabled: !_isChecking,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitGuess(),
                    decoration: InputDecoration(
                      hintText: 'Nhập từ tiếng Anh...',
                      hintStyle: AppTextStyles.h3.copyWith(
                        color: AppColors.disabled,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _isLastGuessCorrect != null
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: _isLastGuessCorrect!
                                  ? AppGradients.success
                                  : AppGradients.error,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.colored(
                                _isLastGuessCorrect!
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isLastGuessCorrect!
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: AppColors.textWhite,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  _isLastGuessCorrect!
                                      ? 'Chính xác!'
                                      : 'Sai rồi! Mất 1 mạng.',
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            style: AppButtons.primaryButton,
                            onPressed: _isChecking ? null : _submitGuess,
                            child: _isChecking
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: AppColors.textWhite,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text('KIỂM TRA'),
                          ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Column(
                  children: [
                    const Text('Các gợi ý', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Mở thêm gợi ý sẽ bị trừ $_pointDeductPerHint điểm tiềm năng',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: _currentHints.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final bool isOpen = _openedHints[index];

                          return GestureDetector(
                            onTap: () => _openHint(index),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    final rotateAnim = Tween(
                                      begin: 3.14,
                                      end: 0.0,
                                    ).animate(animation);
                                    return AnimatedBuilder(
                                      animation: rotateAnim,
                                      child: child,
                                      builder: (context, widget) {
                                        final isUnder =
                                            (ValueKey(isOpen) != widget?.key);
                                        var tilt =
                                            ((animation.value - 0.5).abs() -
                                                0.5) *
                                            0.003;
                                        tilt *= isUnder ? -1.0 : 1.0;
                                        return Transform(
                                          transform: Matrix4.rotationX(
                                            rotateAnim.value,
                                          )..setEntry(3, 1, tilt),
                                          alignment: Alignment.center,
                                          child: widget,
                                        );
                                      },
                                    );
                                  },
                              child: isOpen
                                  ? Container(
                                      key: const ValueKey(true),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.lg,
                                      ),
                                      decoration: AppDecorations.cardStyle
                                          .copyWith(
                                            color: AppColors.primaryLight,
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                      child: Text(
                                        _currentHints[index],
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.primaryDark,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : Container(
                                      key: const ValueKey(false),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.lg,
                                      ),
                                      decoration: AppDecorations.cardStyle
                                          .copyWith(
                                            color: AppColors.surface,
                                            border: Border.all(
                                              color: AppColors.border,
                                              width: 2,
                                            ),
                                          ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.lock_rounded,
                                            color: AppColors.disabled,
                                            size: 20,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            'Gợi ý ${index + 1}',
                                            style: AppTextStyles.h4.copyWith(
                                              color: AppColors.disabled,
                                            ),
                                          ),
                                        ],
                                      ),
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
          ],
        ),
      ),
    );
  }
}
