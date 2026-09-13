import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants.dart';
import '../../core/config.dart';

class StudyScreen extends StatefulWidget {
  final int deckId;
  final String deckTitle;

  const StudyScreen({super.key, required this.deckId, required this.deckTitle});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with TickerProviderStateMixin {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late PageController _pageController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  List<dynamic> _vocabularies = [];
  bool _isLoading = true;
  String _errorMessage = '';

  int _currentIndex = 0;

  final Map<int, bool> _isFlippedMap = {};

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 0.85);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _initTts();
    _fetchVocabularies();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flipController.dispose();

    _audioPlayer.dispose();
    _flutterTts.stop();

    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _playAudio() async {
    String audioUrl = _vocabularies[_currentIndex]['audio_url'] ?? '';
    String wordToSpeak = _vocabularies[_currentIndex]['word'] ?? '';

    if (audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể phát file âm thanh này')),
          );
        }
      }
    } else if (wordToSpeak.isNotEmpty) {
      await _flutterTts.speak(wordToSpeak);
    }
  }

  Future<void> _fetchVocabularies() async {
    try {
      String? token = await _storage.read(key: 'access_token');

      final response = await http
          .get(
            Uri.parse(ApiEndpoints.deckVocabularies(widget.deckId)),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _vocabularies = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Không thể tải danh sách từ vựng (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối mạng: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleFlip() {
    bool isFlipped = _isFlippedMap[_currentIndex] ?? false;
    if (isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlippedMap[_currentIndex] = !isFlipped;
    });
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _vocabularies.length) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.deckTitle,
          style: const TextStyle(color: AppColors.textPrimary),
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
          : _vocabularies.isEmpty
          ? const Center(
              child: Text(
                'Bộ từ vựng này chưa có từ nào.',
                style: AppTextStyles.bodySecondary,
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  Text(
                    '${_currentIndex + 1}/${_vocabularies.length}',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 220,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _currentIndex > 0
                              ? () => _goToPage(_currentIndex - 1)
                              : null,
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _vocabularies.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentIndex = index;

                                if (_isFlippedMap[index] == true) {
                                  _flipController.value = 1.0;
                                } else {
                                  _flipController.value = 0.0;
                                }
                              });

                              _audioPlayer.stop();
                              _flutterTts.stop();
                            },
                            itemBuilder: (context, index) {
                              final vocab = _vocabularies[index];
                              final bool isFlipped =
                                  _isFlippedMap[index] ?? false;

                              return AnimatedBuilder(
                                animation: _flipAnimation,
                                builder: (context, child) {
                                  double angle = index == _currentIndex
                                      ? _flipAnimation.value * 3.14159
                                      : (isFlipped ? 3.14159 : 0);
                                  bool showBack = angle >= 1.5708;

                                  return Transform(
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    alignment: Alignment.center,
                                    child: GestureDetector(
                                      onTap: _toggleFlip,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        padding: const EdgeInsets.all(24.0),
                                        decoration: AppDecorations.cardStyle
                                            .copyWith(
                                              color: Colors.white,
                                              border: Border.all(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.3),
                                                width: 2,
                                              ),
                                            ),
                                        child: Center(
                                          child: showBack
                                              ? Transform(
                                                  transform: Matrix4.identity()
                                                    ..rotateY(3.14159),
                                                  alignment: Alignment.center,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Text(
                                                        'Nghĩa / Dịch:',
                                                        style: AppTextStyles
                                                            .bodySecondary,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        vocab['meaning'] ??
                                                            'Chưa có bản dịch',
                                                        style: AppTextStyles.h1
                                                            .copyWith(
                                                              color: AppColors
                                                                  .primary,
                                                            ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      vocab['word'] ?? '',
                                                      style: AppTextStyles.h1,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      '/${vocab['pronunciation'] ?? ''}/',
                                                      style: AppTextStyles
                                                          .bodySecondary
                                                          .copyWith(
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        IconButton(
                          onPressed: _currentIndex < _vocabularies.length - 1
                              ? () => _goToPage(_currentIndex + 1)
                              : null,
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    style: AppButtons.outlinedButton,
                    onPressed: _playAudio,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Phát âm'),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 24.0),
                      padding: const EdgeInsets.all(20.0),
                      decoration: AppDecorations.cardStyle.copyWith(
                        color: Colors.white,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _vocabularies[_currentIndex]['word'] ?? '',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _vocabularies[_currentIndex]['part_of_speech'] ??
                                        'noun',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            const Text(
                              'Mô tả ý nghĩa (English):',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _vocabularies[_currentIndex]['description'] ??
                                  'Chưa có mô tả.',
                              style: AppTextStyles.body,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Ví dụ minh họa:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...((_vocabularies[_currentIndex]['examples']
                                        as List?) ??
                                    [])
                                .map(
                                  (ex) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      '• $ex',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
