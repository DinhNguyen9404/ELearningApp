import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants.dart';
import 'game_result_dialog.dart';

class SpellingGameScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final bool isSystemGame;
  final bool isTrial;

  const SpellingGameScreen({
    super.key,
    required this.gameData,
    this.isSystemGame = false,
    this.isTrial = false,
  });

  @override
  State<SpellingGameScreen> createState() => _SpellingGameScreenState();
}

class _SpellingGameScreenState extends State<SpellingGameScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _answerController = TextEditingController();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  late List<dynamic> _words;
  late int _maxScore;
  late int _pointsPerWord;

  int _currentIndex = 0;
  int _currentScore = 0;
  late int _remainingGuesses;

  Timer? _timer;
  late int _remainingSeconds;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _words = widget.gameData['game_data'] ?? [];
    _maxScore = widget.gameData['base_score'] ?? 100;

    _remainingSeconds = widget.gameData['time_limit'] ?? 60;

    _pointsPerWord = _words.isNotEmpty ? (_maxScore ~/ _words.length) : 0;

    _remainingGuesses = _words.length * 3;

    _initTts();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  String get _formattedTime {
    int m = _remainingSeconds ~/ 60;
    int s = _remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _endGame(false, isTimeOut: true);
      }
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _playAudio(String type) async {
    final currentWord = _words[_currentIndex];

    String audioUrl = '';
    String textToSpeak = '';

    if (type == 'WORD') {
      audioUrl = currentWord['audio_url'] ?? '';
      textToSpeak = currentWord['word'] ?? '';
    } else if (type == 'HINT') {
      audioUrl = currentWord['hint_audio_url'] ?? '';
      textToSpeak = currentWord['hint_text'] ?? '';
    }

    if (audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
      } catch (e) {
        _fallbackTts(textToSpeak);
      }
    } else if (textToSpeak.isNotEmpty) {
      _fallbackTts(textToSpeak);
    }
  }

  Future<void> _fallbackTts(String text) async {
    await _flutterTts.speak(text);
  }

  void _checkAnswer() {
    if (_answerController.text.trim().isEmpty) return;

    final currentWordData = _words[_currentIndex];
    final String correctWord = (currentWordData['word'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final String userWord = _answerController.text.toLowerCase().trim();

    if (userWord == correctWord) {
      setState(() {
        _currentScore += _pointsPerWord;
        _remainingSeconds += 10;
        _answerController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chính xác! (+ điểm, +10s)'),
          backgroundColor: AppColors.success,
          duration: Duration(milliseconds: 1000),
        ),
      );

      _nextWord();
    } else {
      setState(() {
        _remainingGuesses--;
        _answerController.clear();
      });

      if (_remainingGuesses <= 0) {
        _timer?.cancel();
        _endGame(false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sai rồi! Bạn còn $_remainingGuesses lượt đoán.'),
            backgroundColor: AppColors.error,
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    }
  }

  void _nextWord() {
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
      });
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _playAudio('WORD'),
      );
    } else {
      _timer?.cancel();
      _endGame(true);
    }
  }

  Future<void> _endGame(bool isSuccess, {bool isTimeOut = false}) async {
    setState(() => _isSubmitting = true);

    _audioPlayer.stop();
    _flutterTts.stop();

    if (!widget.isTrial) {
      try {
        String? token = await _storage.read(key: 'access_token');
        final uri = widget.isSystemGame
            ? ApiEndpoints.submitSystemGame(widget.gameData['id'])
            : ApiEndpoints.submitCommunityGame(widget.gameData['id']);

        await http.post(
          Uri.parse(uri),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'score_earned': _currentScore}),
        );
      } catch (e) {
        debugPrint('Lỗi lưu điểm: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    String dialogTitle = 'Tuyệt vời! Hoàn thành xuất sắc!';
    if (!isSuccess) {
      dialogTitle = isTimeOut ? 'Hết giờ mất rồi!' : 'Hết lượt đoán mất rồi!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameResultDialog(
        title: dialogTitle,
        isSuccess: isSuccess,
        score: _currentScore,
        maxScore: _maxScore,
        isTrial: widget.isTrial,
        onQuit: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onRetry: () {
          Navigator.pop(context);
          setState(() {
            _currentIndex = 0;
            _currentScore = 0;
            _remainingGuesses = _words.length * 3;
            _remainingSeconds = widget.gameData['time_limit'] ?? 60;
            _answerController.clear();
          });
          _startTimer();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_words.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Dữ liệu lỗi!', style: AppTextStyles.body)),
      );
    }

    final double progress = (_currentIndex + 1) / _words.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isSubmitting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
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

                    _buildTimerAndGuessesRow(),
                    const SizedBox(height: AppSpacing.lg),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: AppDecorations.questionCard,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.headphones_rounded,
                                size: 48,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Text(
                                'Nhấn để nghe và đánh vần từ vựng',
                                style: AppTextStyles.bodySecondary,
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: AppButtons.primaryButton.copyWith(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(vertical: 20),
                                    ),
                                  ),
                                  onPressed: () => _playAudio('WORD'),
                                  icon: const Icon(
                                    Icons.volume_up_rounded,
                                    size: 28,
                                  ),
                                  label: const Text(
                                    'Phát âm từ vựng',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),

                              if ((_words[_currentIndex]['hint_text']
                                          ?.isNotEmpty ==
                                      true) ||
                                  (_words[_currentIndex]['hint_audio_url']
                                          ?.isNotEmpty ==
                                      true))
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: AppButtons.outlinedButton.copyWith(
                                      foregroundColor: WidgetStateProperty.all(
                                        AppColors.accent,
                                      ),
                                      side: WidgetStateProperty.all(
                                        const BorderSide(
                                          color: AppColors.accent,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    onPressed: () => _playAudio('HINT'),
                                    icon: const Icon(
                                      Icons.help_outline_rounded,
                                    ),
                                    label: const Text('Nghe gợi ý'),
                                  ),
                                ),

                              const SizedBox(height: AppSpacing.xxl),

                              TextField(
                                controller: _answerController,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h1.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Nhập đáp án...',
                                  hintStyle: AppTextStyles.h2.copyWith(
                                    color: Colors.grey.shade400,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _checkAnswer(),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: AppButtons.primaryButton,
                                  onPressed: _checkAnswer,
                                  child: const Text('KIỂM TRA'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
            _audioPlayer.stop();
            _flutterTts.stop();
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
            widget.isTrial
                ? 'Chơi thử: Đánh vần'
                : (widget.gameData['name'] ?? 'Đánh vần'),
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
                'Điểm: $_currentScore',
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
          '${_currentIndex + 1}/${_words.length}',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildTimerAndGuessesRow() {
    final bool isLowTime = _remainingSeconds <= 10;
    final Color timeColor = isLowTime ? AppColors.error : AppColors.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AnimatedScale(
          scale: isLowTime && _remainingSeconds.isOdd ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: AppDecorations.statChip(color: timeColor),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_filled_rounded,
                  size: 20,
                  color: timeColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: timeColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: AppDecorations.statChip(color: AppColors.error),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                'Lượt: $_remainingGuesses',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
