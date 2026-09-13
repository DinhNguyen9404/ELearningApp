import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import 'quiz_game_screen.dart';
import 'guess_game_screen.dart';
import 'sort_game_screen.dart';
import 'spelling_game_screen.dart';

class CreateGameScreen extends StatefulWidget {
  final String gameType;
  final Map<String, dynamic>? existingData;

  const CreateGameScreen({
    super.key,
    required this.gameType,
    this.existingData,
  });

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  bool _isModerator = false;

  late TextEditingController _nameController;
  late TextEditingController _baseScoreController;
  late TextEditingController _timeLimitController;
  String _difficulty = 'EASY';
  bool _isSystemGame = false;

  List<Map<String, dynamic>> _quizQuestions = [];
  List<Map<String, dynamic>> _guessWords = [];
  List<TextEditingController> _sortSentences = [];

  List<Map<String, dynamic>> _spellingWords = [];

  @override
  void initState() {
    super.initState();
    _checkModeratorRole();

    _nameController = TextEditingController(
      text: widget.existingData?['name'] ?? '',
    );
    _baseScoreController = TextEditingController(
      text: widget.existingData?['base_score']?.toString() ?? '100',
    );
    _timeLimitController = TextEditingController(
      text: widget.existingData?['time_limit']?.toString() ?? '60',
    );
    _difficulty = widget.existingData?['difficulty'] ?? 'EASY';

    final List<dynamic> oldData = widget.existingData != null
        ? (widget.existingData!['game_data'] ?? [])
        : [];

    if (widget.gameType == 'QUIZ') {
      if (oldData.isNotEmpty) {
        _quizQuestions = oldData.map((q) {
          return {
            'question': TextEditingController(text: q['question'].toString()),
            'options': (q['options'] as List)
                .map((opt) => TextEditingController(text: opt.toString()))
                .toList(),
            'correct_index': q['correct_index'],
          };
        }).toList();
      } else {
        _addQuizQuestion();
      }
    } else if (widget.gameType == 'GUESS') {
      if (oldData.isNotEmpty) {
        _guessWords = oldData.map((w) {
          return {
            'target_word': TextEditingController(
              text: w['target_word'].toString(),
            ),
            'hints': (w['hints'] as List)
                .map((h) => TextEditingController(text: h.toString()))
                .toList(),
          };
        }).toList();
      } else {
        _addGuessWord();
      }
    } else if (widget.gameType == 'SORT') {
      if (oldData.isNotEmpty) {
        _sortSentences = oldData.map((s) {
          List<dynamic> correctOrder = s['correct_order'] ?? [];
          return TextEditingController(text: correctOrder.join(' '));
        }).toList();
      } else {
        _addSortSentence();
      }
    } else if (widget.gameType == 'SPELLING') {
      if (oldData.isNotEmpty) {
        _spellingWords = oldData.map((w) {
          return {
            'word': TextEditingController(text: w['word']?.toString() ?? ''),
            'hint_text': TextEditingController(
              text: w['hint_text']?.toString() ?? '',
            ),
            'word_audio': null,
            'hint_audio': null,
            'audio_url': w['audio_url'] ?? '',
            'hint_audio_url': w['hint_audio_url'] ?? '',
          };
        }).toList();
      } else {
        _addSpellingWord();
      }
    }
  }

  Future<void> _checkModeratorRole() async {
    String? role = await _storage.read(key: 'role');
    String? isStaff = await _storage.read(key: 'is_staff');
    if (role == 'MODERATOR' || role == 'ADMIN' || isStaff == 'true') {
      setState(() => _isModerator = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseScoreController.dispose();
    _timeLimitController.dispose();
    for (var w in _spellingWords) {
      w['word'].dispose();
      w['hint_text'].dispose();
    }
    super.dispose();
  }

  void _addQuizQuestion() {
    setState(
      () => _quizQuestions.add({
        'question': TextEditingController(),
        'options': [
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        'correct_index': 0,
      }),
    );
  }

  void _addGuessWord() {
    setState(
      () => _guessWords.add({
        'target_word': TextEditingController(),
        'hints': [TextEditingController()],
      }),
    );
  }

  void _addSortSentence() {
    setState(() => _sortSentences.add(TextEditingController()));
  }

  void _addSpellingWord() {
    setState(
      () => _spellingWords.add({
        'word': TextEditingController(),
        'hint_text': TextEditingController(),
        'word_audio': null,
        'hint_audio': null,
        'audio_url': '',
        'hint_audio_url': '',
      }),
    );
  }

  Future<void> _pickAudioFile(int index, String type) async {
    PlatformFile? pickedFile = await FilePicker.pickFile(type: FileType.audio);

    if (pickedFile != null && pickedFile.path != null) {
      setState(() {
        if (type == 'WORD') {
          _spellingWords[index]['word_audio'] = File(pickedFile.path!);
        } else {
          _spellingWords[index]['hint_audio'] = File(pickedFile.path!);
        }
      });
    }
  }

  bool _validateGameData() {
    if (!_formKey.currentState!.validate()) return false;

    if (widget.gameType == 'QUIZ') {
      for (var q in _quizQuestions) {
        if (q['question'].text.trim().isEmpty) {
          return _showError('Vui lòng nhập đủ nội dung câu hỏi!');
        }
        for (var opt in q['options']) {
          if (opt.text.trim().isEmpty) {
            return _showError('Vui lòng nhập đủ 4 đáp án cho mỗi câu!');
          }
        }
      }
    } else if (widget.gameType == 'GUESS') {
      for (var w in _guessWords) {
        if (w['target_word'].text.trim().isEmpty) {
          return _showError('Vui lòng nhập đầy đủ Từ vựng!');
        }
        bool hasHint = (w['hints'] as List<TextEditingController>).any(
          (h) => h.text.trim().isNotEmpty,
        );
        if (!hasHint) return _showError('Mỗi từ vựng phải có ít nhất 1 gợi ý!');
      }
    } else if (widget.gameType == 'SORT') {
      for (var s in _sortSentences) {
        List<String> words = s.text.trim().split(RegExp(r'\s+'));
        if (words.length < 2) {
          return _showError('Mỗi câu sắp xếp phải có từ 2 chữ trở lên!');
        }
      }
    } else if (widget.gameType == 'SPELLING') {
      for (var w in _spellingWords) {
        if (w['word'].text.trim().isEmpty) {
          return _showError('Vui lòng điền đủ Từ vựng cho màn chơi Đánh vần!');
        }
      }
    }
    return true;
  }

  bool _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
    return false;
  }

  Map<String, dynamic> _buildGamePayload() {
    List<dynamic> gameDataPayload = [];

    if (widget.gameType == 'QUIZ') {
      gameDataPayload = _quizQuestions
          .map(
            (q) => {
              'question': q['question'].text.trim(),
              'options': (q['options'] as List<TextEditingController>)
                  .map((c) => c.text.trim())
                  .toList(),
              'correct_index': q['correct_index'],
            },
          )
          .toList();
    } else if (widget.gameType == 'GUESS') {
      gameDataPayload = _guessWords
          .map(
            (w) => {
              'target_word': w['target_word'].text.trim(),
              'hints': (w['hints'] as List<TextEditingController>)
                  .map((h) => h.text.trim())
                  .where((t) => t.isNotEmpty)
                  .toList(),
            },
          )
          .toList();
    } else if (widget.gameType == 'SORT') {
      gameDataPayload = _sortSentences.map((s) {
        List<String> words = s.text.trim().split(RegExp(r'\s+'));
        List<String> scrambled = List.from(words)..shuffle();
        return {'correct_order': words, 'scrambled': scrambled};
      }).toList();
    } else if (widget.gameType == 'SPELLING') {
      gameDataPayload = _spellingWords
          .map(
            (w) => {
              'word': w['word'].text.trim(),
              'hint_text': w['hint_text'].text.trim(),
              'audio_url': w['audio_url'],
              'hint_audio_url': w['hint_audio_url'],
            },
          )
          .toList();
    }

    return {
      'name': _nameController.text.trim(),
      'game_type': widget.gameType,
      'difficulty': _difficulty,
      'base_score': int.tryParse(_baseScoreController.text) ?? 100,
      'time_limit': int.tryParse(_timeLimitController.text) ?? 60,
      'is_system_game': _isSystemGame,
      'game_data': gameDataPayload,
    };
  }

  Future<void> _submitToServer(String status) async {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      String? token = await _storage.read(key: 'access_token');
      Map<String, dynamic> payload = _buildGamePayload();
      payload['status'] = status;

      bool isEditing = widget.existingData != null;
      bool isSystem = payload['is_system_game'] == true;

      Uri uri;
      if (isSystem) {
        uri = isEditing
            ? Uri.parse(
                ApiEndpoints.systemGameDetail(widget.existingData!['id']),
              )
            : Uri.parse(ApiEndpoints.systemGames(payload['game_type']));
      } else {
        uri = isEditing
            ? Uri.parse(
                ApiEndpoints.communityGameDetail(widget.existingData!['id']),
              )
            : Uri.parse(ApiEndpoints.communityGames());
      }

      http.Response response;

      if (widget.gameType == 'SPELLING') {
        var request = http.MultipartRequest(isEditing ? 'PUT' : 'POST', uri);
        request.headers['Authorization'] = 'Bearer $token';

        request.fields['payload'] = jsonEncode(payload);

        for (int i = 0; i < _spellingWords.length; i++) {
          File? wordAudio = _spellingWords[i]['word_audio'];
          File? hintAudio = _spellingWords[i]['hint_audio'];

          if (wordAudio != null) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'word_audio_$i',
                wordAudio.path,
              ),
            );
          }
          if (hintAudio != null) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'hint_audio_$i',
                hintAudio.path,
              ),
            );
          }
        }

        var streamedResponse = await request.send().timeout(
          const Duration(seconds: 45),
        );
        response = await http.Response.fromStream(streamedResponse);
      } else {
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        final body = jsonEncode(payload);

        if (isEditing) {
          response = await http
              .put(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 15));
        } else {
          response = await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 15));
        }
      }

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lưu trò chơi thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _showError(
            'Lỗi (${response.statusCode}): Không thể lưu trò chơi! ${response.body}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Lỗi kết nối mạng! Vui lòng thử lại.');
      }
    }
  }

  void _showActionOptions() {
    if (!_validateGameData()) return;
    final gamePayload = _buildGamePayload();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Dữ liệu hợp lệ. Chọn hành động tiếp theo:',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Chơi thử màn chơi'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.gameType == 'QUIZ') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizGameScreen(
                          gameData: gamePayload,
                          isTrial: true,
                        ),
                      ),
                    );
                  } else if (widget.gameType == 'GUESS') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuessGameScreen(
                          gameData: gamePayload,
                          isTrial: true,
                        ),
                      ),
                    );
                  } else if (widget.gameType == 'SORT') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SortGameScreen(
                          gameData: gamePayload,
                          isTrial: true,
                        ),
                      ),
                    );
                  } else if (widget.gameType == 'SPELLING') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SpellingGameScreen(
                          gameData: gamePayload,
                          isTrial: true,
                        ),
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.save_rounded,
                  color: AppColors.textSecondary,
                ),
                title: const Text('Lưu riêng tư (Nháp)'),
                onTap: () => _submitToServer('PRIVATE'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.send_rounded,
                  color: AppColors.success,
                ),
                title: const Text('Gửi yêu cầu duyệt'),
                subtitle: const Text(
                  'Kiểm duyệt viên sẽ đánh giá trước khi công khai',
                ),
                onTap: () => _submitToServer('PENDING'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          widget.existingData == null
              ? 'Tạo mới: ${widget.gameType}'
              : 'Chỉnh sửa: ${widget.gameType}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thông tin chung', style: AppTextStyles.h2),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: AppDecorations.inputDecoration('Tên màn chơi'),
                validator: (val) => val!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _baseScoreController,
                      keyboardType: TextInputType.number,
                      decoration: AppDecorations.inputDecoration('Điểm tối đa'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _timeLimitController,
                      keyboardType: TextInputType.number,
                      decoration: AppDecorations.inputDecoration(
                        'Thời gian (giây)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: AppDecorations.inputDecoration('Độ khó'),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Vừa')),
                  DropdownMenuItem(value: 'HARD', child: Text('Khó')),
                ],
                onChanged: (val) => setState(() => _difficulty = val!),
              ),

              if (_isModerator) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Màn chơi Hệ Thống',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    subtitle: const Text(
                      'Số thứ tự sẽ được tự động tính toán sinh ra.',
                    ),
                    activeThumbColor: AppColors.primary,
                    value: _isSystemGame,
                    onChanged: (val) => setState(() => _isSystemGame = val),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                'Dữ liệu trò chơi (${widget.gameType})',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 16),

              if (widget.gameType == 'QUIZ') ...[
                ...List.generate(_quizQuestions.length, (index) {
                  final q = _quizQuestions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecorations.cardStyle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Câu hỏi ${index + 1}',
                              style: AppTextStyles.h3,
                            ),
                            if (_quizQuestions.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.error,
                                ),
                                onPressed: () => setState(
                                  () => _quizQuestions.removeAt(index),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: q['question'],
                          decoration: AppDecorations.inputDecoration(
                            'Nội dung câu hỏi',
                          ),
                        ),

                        const SizedBox(height: 12),
                        ...List.generate(4, (optIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),

                            child: Row(
                              children: [
                                Radio<int>(
                                  value: optIndex,

                                  fillColor: WidgetStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (states.contains(WidgetState.selected)) {
                                      return AppColors.success;
                                    }
                                    return null;
                                  }),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: q['options'][optIndex],
                                    decoration: AppDecorations.inputDecoration(
                                      'Đáp án ${optIndex + 1}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),

                OutlinedButton.icon(
                  style: AppButtons.outlinedButton,
                  onPressed: _addQuizQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm câu hỏi trắc nghiệm'),
                ),
              ],

              if (widget.gameType == 'GUESS') ...[
                ...List.generate(_guessWords.length, (wordIndex) {
                  final wordData = _guessWords[wordIndex];
                  final List<TextEditingController> hints = wordData['hints'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecorations.cardStyle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Từ vựng ${wordIndex + 1}',
                              style: AppTextStyles.h3,
                            ),
                            if (_guessWords.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,

                                  color: AppColors.error,
                                ),

                                onPressed: () => setState(
                                  () => _guessWords.removeAt(wordIndex),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: wordData['target_word'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          decoration: AppDecorations.inputDecoration(
                            'Từ vựng mục tiêu (Tiếng Anh)',
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Text('Danh sách gợi ý:', style: AppTextStyles.h4),
                        const SizedBox(height: 8),
                        ...List.generate(hints.length, (hintIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: hints[hintIndex],
                                    decoration:
                                        AppDecorations.inputDecoration(
                                          'Gợi ý ${hintIndex + 1}',
                                        ).copyWith(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 16,
                                              ),
                                        ),
                                  ),
                                ),

                                if (hints.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () => setState(
                                      () => hints.removeAt(hintIndex),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),

                        TextButton.icon(
                          style: AppButtons.ghostButton,
                          onPressed: () => setState(
                            () => hints.add(TextEditingController()),
                          ),
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.primary,
                          ),
                          label: const Text(
                            'Thêm gợi ý',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                OutlinedButton.icon(
                  style: AppButtons.outlinedButton,
                  onPressed: _addGuessWord,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm từ vựng mới'),
                ),
              ],

              if (widget.gameType == 'SORT') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.accent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Chỉ cần nhập câu hoàn chỉnh. Hệ thống sẽ tự động cắt và xáo trộn các từ khi người dùng chơi.',
                          style: TextStyle(
                            color: AppColors.accentDark,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...List.generate(_sortSentences.length, (index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sortSentences[index],
                            maxLines: 2,
                            minLines: 1,
                            decoration: AppDecorations.inputDecoration(
                              'Câu hoàn chỉnh ${index + 1} (vd: The sunset is beautiful)',
                            ),
                          ),
                        ),
                        if (_sortSentences.length > 1) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.error,
                            ),
                            onPressed: () =>
                                setState(() => _sortSentences.removeAt(index)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 8),

                OutlinedButton.icon(
                  style: AppButtons.outlinedButton,

                  onPressed: _addSortSentence,

                  icon: const Icon(Icons.add),

                  label: const Text('Thêm câu sắp xếp'),
                ),
              ],

              if (widget.gameType == 'SPELLING') ...[
                ...List.generate(_spellingWords.length, (index) {
                  final wordData = _spellingWords[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecorations.cardStyle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Từ vựng ${index + 1}',
                              style: AppTextStyles.h3,
                            ),
                            if (_spellingWords.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.error,
                                ),
                                onPressed: () => setState(
                                  () => _spellingWords.removeAt(index),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: wordData['word'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          decoration: AppDecorations.inputDecoration(
                            'Từ vựng (Tiếng Anh)',
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildAudioPickerRow(index, 'WORD', 'MP3 Từ vựng'),
                        const Divider(height: 24),

                        TextFormField(
                          controller: wordData['hint_text'],
                          decoration: AppDecorations.inputDecoration(
                            'Văn bản gợi ý (Tùy chọn)',
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildAudioPickerRow(index, 'HINT', 'MP3 Gợi ý'),
                      ],
                    ),
                  );
                }),
                OutlinedButton.icon(
                  style: AppButtons.outlinedButton,
                  onPressed: _addSpellingWord,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm từ vựng Đánh vần'),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            style: AppButtons.primaryButton,
            onPressed: _showActionOptions,
            child: const Text('KHỞI TẠO & KIỂM TRA'),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPickerRow(int index, String type, String label) {
    File? file = type == 'WORD'
        ? _spellingWords[index]['word_audio']
        : _spellingWords[index]['hint_audio'];
    String url = type == 'WORD'
        ? _spellingWords[index]['audio_url']
        : _spellingWords[index]['hint_audio_url'];

    String statusText = 'Chưa có file (Dùng AI đọc chữ)';
    if (file != null) {
      statusText = 'File mới: ${file.path.split('/').last}';
    } else if (url.isNotEmpty) {
      statusText = 'Đã có file lưu trên hệ thống';
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            statusText,
            style: AppTextStyles.bodySecondary.copyWith(
              color: (file != null || url.isNotEmpty)
                  ? AppColors.success
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: () => _pickAudioFile(index, type),
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(label),
        ),
        if (file != null || url.isNotEmpty)
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 18,
            ),
            onPressed: () => setState(() {
              if (type == 'WORD') {
                _spellingWords[index]['word_audio'] = null;
                _spellingWords[index]['audio_url'] = '';
              } else {
                _spellingWords[index]['hint_audio'] = null;
                _spellingWords[index]['hint_audio_url'] = '';
              }
            }),
          ),
      ],
    );
  }
}
