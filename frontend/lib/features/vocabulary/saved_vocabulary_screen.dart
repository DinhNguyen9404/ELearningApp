import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/config.dart';
import 'study_screen.dart';

class SavedVocabularyScreen extends StatefulWidget {
  const SavedVocabularyScreen({super.key});

  @override
  State<SavedVocabularyScreen> createState() => _SavedVocabularyScreenState();
}

class _SavedVocabularyScreenState extends State<SavedVocabularyScreen> {
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
    _fetchSavedDecks(isRefresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _fetchSavedDecks(isRefresh: false);
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
        _fetchSavedDecks(isRefresh: true);
      },
    );
  }

  Future<void> _fetchSavedDecks({required bool isRefresh}) async {
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
        ApiEndpoints.savedDecks(),
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _decks.addAll(decodedData['results'] ?? []);
          _currentPage++;
          _hasMore = decodedData['next'] != null;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Lỗi máy chủ';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối';
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
                        // Cập nhật cả giao diện BottomSheet và giao diện màn hình chính
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
                            // Đã xóa groupValue và onChanged ở đây
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
                            // Đã xóa groupValue và onChanged ở đây
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
                        _fetchSavedDecks(isRefresh: true);
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

  Future<void> _confirmAndRemoveDeck(
    int deckId,
    int index,
    String title,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc muốn ngừng học bộ "$title" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        String? token = await _storage.read(key: 'access_token');
        final response = await http.delete(
          Uri.parse(ApiEndpoints.enrollDeck(deckId)),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          setState(() {
            _decks.removeAt(index);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã xóa bộ từ vựng'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Lỗi: $e');
      }
    }
  }

  Future<void> _toggleActiveDeck(int deckId, int currentIndex) async {
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse(ApiEndpoints.toggleActiveDeck(deckId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data['is_active']) {
            for (var item in _decks) {
              item['is_active'] = false;
            }
            _decks[currentIndex]['is_active'] = true;
          } else {
            _decks[currentIndex]['is_active'] = false;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Từ vựng đã lưu',
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
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration:
                            AppDecorations.inputDecoration(
                              'Tìm trong danh sách...',
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
                        const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onPressed: _showFilterBottomSheet,
                    icon: const Icon(Icons.filter_alt_outlined, size: 20),
                    label: const Text('Lọc'),
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
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    )
                  : _decks.isEmpty
                  ? const Center(
                      child: Text(
                        'Bạn chưa lưu bộ từ vựng nào.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: _decks.length,
                      itemBuilder: (context, index) {
                        final item = _decks[index];
                        final deck = item['deck'];
                        final bool isActive = item['is_active'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: AppDecorations.cardStyle.copyWith(
                              border: isActive
                                  ? Border.all(
                                      color: AppColors.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        deck['title'] ?? '',
                                        style: AppTextStyles.h3,
                                      ),
                                    ),
                                    Text(
                                      'Số từ: ${deck['words_count'] ?? 0}',
                                      style: AppTextStyles.bodySecondary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Bật nhắc nhở kiểm tra',
                                      style: AppTextStyles.body,
                                    ),
                                    Switch(
                                      value: isActive,
                                      activeThumbColor: AppColors.primary,
                                      onChanged: (val) =>
                                          _toggleActiveDeck(deck['id'], index),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _confirmAndRemoveDeck(
                                          deck['id'],
                                          index,
                                          deck['title'],
                                        ),
                                        child: const Text('Xóa'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton(
                                        style: AppButtons.primaryButton
                                            .copyWith(
                                              shape: WidgetStateProperty.all(
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => StudyScreen(
                                                deckId: deck['id'],
                                                deckTitle: deck['title'],
                                              ),
                                            ),
                                          );
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
