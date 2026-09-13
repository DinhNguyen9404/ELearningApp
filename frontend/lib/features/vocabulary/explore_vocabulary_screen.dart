import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/config.dart';
import 'study_screen.dart';

class ExploreVocabularyScreen extends StatefulWidget {
  const ExploreVocabularyScreen({super.key});

  @override
  State<ExploreVocabularyScreen> createState() =>
      _ExploreVocabularyScreenState();
}

class _ExploreVocabularyScreenState extends State<ExploreVocabularyScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Timer? _debounce;

  final List<dynamic> _decks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _errorMessage = '';

  String _selectedDifficulty = 'ALL';
  String _sortOrder = 'Giảm dần';

  @override
  void initState() {
    super.initState();
    _fetchDecks(isRefresh: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _fetchDecks(isRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConfig.searchDebounceMs),
      () {
        _fetchDecks(isRefresh: true);
      },
    );
  }

  Future<void> _fetchDecks({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _decks.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      String? token = await _storage.read(key: 'access_token');

      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'search': _searchController.text,
        'sort': _sortOrder,
      };

      if (_selectedDifficulty != 'ALL') {
        queryParams['difficulty'] = _selectedDifficulty;
      }

      final uri = Uri.parse(
        ApiEndpoints.decks(),
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = json.decode(
          utf8.decode(response.bodyBytes),
        );

        final List<dynamic> newResults = decodedData['results'] ?? [];

        setState(() {
          _decks.addAll(newResults);
          _currentPage++;
          _hasMore = decodedData['next'] != null;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Lỗi máy chủ: ${response.statusCode}';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối mạng: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _showFilterBottomSheet() {
    const difficultyOptions = {
      'ALL': 'Tất cả',
      'EASY': 'Dễ',
      'MEDIUM': 'Vừa',
      'HARD': 'Khó',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bộ lọc & Sắp xếp', style: AppTextStyles.h2),
                  const SizedBox(height: 24),
                  const Text('Mức độ khó', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: difficultyOptions.entries.map((entry) {
                      final isSelected = _selectedDifficulty == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setModalState(() => _selectedDifficulty = entry.key);
                          setState(() => _selectedDifficulty = entry.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Lượng người học', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _sortOrder,
                    onChanged: (String? value) {
                      if (value != null) {
                        setModalState(() => _sortOrder = value);
                        setState(() => _sortOrder = value);
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Tăng dần',
                              style: AppTextStyles.body,
                            ),
                            value: 'Tăng dần',
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Giảm dần',
                              style: AppTextStyles.body,
                            ),
                            value: 'Giảm dần',
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: AppButtons.primaryButton,
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchDecks(isRefresh: true);
                      },
                      child: const Text('ÁP DỤNG'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return AppColors.success;
      case 'MEDIUM':
        return AppColors.accent;
      case 'HARD':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _translateDifficulty(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return 'Dễ';
      case 'MEDIUM':
        return 'Vừa';
      case 'HARD':
        return 'Khó';
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Khám phá từ vựng',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration:
                                AppDecorations.inputDecoration(
                                  'Nhập tên bộ từ vựng...',
                                ).copyWith(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: AppButtons.outlinedButton.copyWith(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          side: WidgetStateProperty.all(
                            const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onPressed: _showFilterBottomSheet,
                        icon: const Icon(Icons.filter_alt_outlined, size: 20),
                        label: const Text('Lọc'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage,
                            style: const TextStyle(color: AppColors.error),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _fetchDecks(isRefresh: true),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    )
                  : _decks.isEmpty
                  ? const Center(
                      child: Text(
                        'Không tìm thấy kết quả nào.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: _decks.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _decks.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }

                        final deck = _decks[index];
                        final String title = deck['title'] ?? 'Chưa có tên';
                        final String difficulty =
                            deck['difficulty'] ?? 'Chưa rõ';
                        final int wordsCount = deck['words_count'] ?? 0;
                        final int learnersCount = deck['learners_count'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: AppDecorations.cardStyle,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: AppTextStyles.h3),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text(
                                            'Độ khó: ',
                                            style: AppTextStyles.bodySecondary,
                                          ),
                                          Text(
                                            _translateDifficulty(difficulty),
                                            style: TextStyle(
                                              color: _getDifficultyColor(
                                                difficulty,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Số người đã học: $learnersCount',
                                        style: AppTextStyles.bodySecondary,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Số từ vựng: $wordsCount',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: 100,
                                      height: 40,
                                      child: ElevatedButton(
                                        style: AppButtons.primaryButton
                                            .copyWith(
                                              padding: WidgetStateProperty.all(
                                                EdgeInsets.zero,
                                              ),
                                              shape: WidgetStateProperty.all(
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                        onPressed: () async {
                                          final int deckId = deck['id'];
                                          String? token = await _storage.read(
                                            key: 'access_token',
                                          );

                                          try {
                                            await http.post(
                                              Uri.parse(
                                                ApiEndpoints.enrollDeck(deckId),
                                              ),
                                              headers: {
                                                'Authorization':
                                                    'Bearer $token',
                                              },
                                            );
                                          } catch (e) {
                                            debugPrint(
                                              'Lỗi khi enroll bộ từ vựng: $e',
                                            );
                                          }

                                          if (context.mounted) {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    StudyScreen(
                                                      deckId: deckId,
                                                      deckTitle: title,
                                                    ),
                                              ),
                                            );

                                            _fetchDecks(isRefresh: true);
                                          }
                                        },
                                        child: const Text('Học'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
