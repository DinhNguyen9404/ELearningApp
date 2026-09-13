import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api_endpoints.dart';
import '../../core/constants.dart';
import 'game_result_dialog.dart';

class WordItem {
  final int id;
  final String text;
  WordItem({required this.id, required this.text});
}

class SortGameScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final bool isTrial;
  final bool isSystemGame;

  const SortGameScreen({
    super.key,
    required this.gameData,
    this.isTrial = false,
    this.isSystemGame = false,
  });

  @override
  State<SortGameScreen> createState() => _SortGameScreenState();
}

class _SortGameScreenState extends State<SortGameScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late List<dynamic> _sentences;
  int _currentIndex = 0;

  List<WordItem> _availableWords = [];
  final List<WordItem> _selectedWords = [];

  int _accumulatedScore = 0;
  late int _scorePerSentence;
  int _wrongGuessesLeft = 5;

  Timer? _timer;
  bool _hasTimeLimit = false;
  int _timeLeft = 0;
  final int _bonusTimePerCorrect = 10;

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
      _sentences = rawData;
    } else if (rawData is Map) {
      _sentences = [rawData];
    } else {
      _sentences = [];
    }

    final int totalBaseScore = widget.gameData['base_score'] ?? 100;
    _scorePerSentence = _sentences.isNotEmpty
        ? (totalBaseScore ~/ _sentences.length)
        : 0;

    final dynamic timeLimitData = widget.gameData['time_limit'];
    if (timeLimitData != null && timeLimitData > 0) {
      _hasTimeLimit = true;
      _timeLeft = timeLimitData;
      _startTimer();
    }

    if (_sentences.isNotEmpty) {
      _loadSentence(_currentIndex);
    }
  }

  void _loadSentence(int index) {
    setState(() {
      _isChecking = false;
      _isLastGuessCorrect = null;
      _selectedWords.clear();

      final List<dynamic> scrambled = _sentences[index]['scrambled'] ?? [];
      _availableWords = List.generate(
        scrambled.length,
        (i) => WordItem(id: i, text: scrambled[i].toString()),
      );
    });
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
        _showResultDialog(reason: 'Hết giờ!');
      }
    });
  }

  String get _formattedTime {
    int m = _timeLeft ~/ 60;
    int s = _timeLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _selectWord(WordItem word) {
    if (_isChecking) return;
    setState(() {
      _availableWords.remove(word);
      _selectedWords.add(word);
    });
  }

  void _deselectWord(WordItem word) {
    if (_isChecking) return;
    setState(() {
      _selectedWords.remove(word);
      _availableWords.add(word);
    });
  }

  void _submitAnswer() {
    if (_isChecking || _availableWords.isNotEmpty) return;

    setState(() => _isChecking = true);

    final List<String> currentOrder = _selectedWords
        .map((w) => w.text)
        .toList();
    final List<dynamic> correctOrderRaw =
        _sentences[_currentIndex]['correct_order'] ?? [];
    final List<String> correctOrder = correctOrderRaw
        .map((e) => e.toString())
        .toList();

    bool isCorrect = true;
    if (currentOrder.length != correctOrder.length) {
      isCorrect = false;
    } else {
      for (int i = 0; i < currentOrder.length; i++) {
        if (currentOrder[i].toLowerCase() != correctOrder[i].toLowerCase()) {
          isCorrect = false;
          break;
        }
      }
    }

    setState(() => _isLastGuessCorrect = isCorrect);

    if (isCorrect) {
      _accumulatedScore += _scorePerSentence;
      if (_hasTimeLimit) _timeLeft += _bonusTimePerCorrect;

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        if (_currentIndex < _sentences.length - 1) {
          _currentIndex++;
          _loadSentence(_currentIndex);
        } else {
          _timer?.cancel();
          _showResultDialog(reason: 'Hoàn thành xuất sắc!');
        }
      });
    } else {
      _wrongGuessesLeft--;

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        if (_wrongGuessesLeft <= 0) {
          _timer?.cancel();
          _showResultDialog(reason: 'Hết lượt đoán sai!');
        } else {
          setState(() {
            _isChecking = false;
            _isLastGuessCorrect = null;
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
        body: '{"score_earned": $_accumulatedScore}',
      );
    } catch (e) {
      debugPrint("Lỗi lưu điểm Sort Game: $e");
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
                builder: (context) => SortGameScreen(
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

  Widget _buildWordChip(WordItem word, bool isSelected) {
    return GestureDetector(
      onTap: () => isSelected ? _deselectWord(word) : _selectWord(word),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 2,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          word.text,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sentences.isEmpty) {
      return const Scaffold(body: Center(child: Text('Dữ liệu lỗi!')));
    }

    Color answerBorderColor = AppColors.border;
    Color answerBgColor = Colors.transparent;

    if (_isChecking && _isLastGuessCorrect != null) {
      if (_isLastGuessCorrect!) {
        answerBorderColor = AppColors.success;
        answerBgColor = AppColors.successLight;
      } else {
        answerBorderColor = AppColors.error;
        answerBgColor = AppColors.errorLight;
      }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Câu ${_currentIndex + 1} / ${_sentences.length}',
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
                        children: List.generate(5, (index) {
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
                  const SizedBox(height: AppSpacing.lg),

                  LinearProgressIndicator(
                    value: (_currentIndex + 1) / _sentences.length,
                    backgroundColor: Colors.grey.shade300,
                    color: AppColors.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Sắp xếp các từ thành câu đúng:',
                  style: AppTextStyles.h3,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 220,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: answerBgColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: answerBorderColor,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: _selectedWords.isEmpty
                    ? Center(
                        child: Text(
                          'Chạm vào các từ bên dưới để ghép câu...',
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _selectedWords
                            .map((word) => _buildWordChip(word, true))
                            .toList(),
                      ),
              ),
            ),

            const Spacer(),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _availableWords
                        .map((word) => _buildWordChip(word, false))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

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
                                      ? 'Chính xác! +10s'
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
                            style: AppButtons.primaryButton.copyWith(
                              backgroundColor: WidgetStateProperty.all(
                                _availableWords.isEmpty && !_isChecking
                                    ? AppColors.primary
                                    : AppColors.disabled,
                              ),
                            ),

                            onPressed: (_availableWords.isEmpty && !_isChecking)
                                ? _submitAnswer
                                : null,
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
          ],
        ),
      ),
    );
  }
}
