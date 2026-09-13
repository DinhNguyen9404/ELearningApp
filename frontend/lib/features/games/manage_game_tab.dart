import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/config.dart';
import 'create_game_screen.dart';
import '../../core/notifiers.dart';
import 'play_game_button.dart';

class ManageGamesTab extends StatefulWidget {
  const ManageGamesTab({super.key});

  @override
  State<ManageGamesTab> createState() => _ManageGamesTabState();
}

class _ManageGamesTabState extends State<ManageGamesTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _debounce;

  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  String _selectedGameType = 'ALL';
  String _selectedDifficulty = 'ALL';
  String _sortBy = 'PLAY_COUNT';
  String _sortOrder = 'DESC';

  @override
  void initState() {
    super.initState();
    _fetchMyGames(isRefresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _fetchMyGames(isRefresh: false);
      }
    });
    AppNotifiers.gameDashboardTabNotifier.addListener(_checkTabReload);
  }

  void _checkTabReload() {
    if (AppNotifiers.gameDashboardTabNotifier.value == 2 && mounted) {
      _fetchMyGames(isRefresh: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _deleteGame(int gameId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        Uri.parse(ApiEndpoints.communityGameDetail(gameId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa màn chơi thành công.')),
          );
          _fetchMyGames(isRefresh: true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xóa màn chơi lúc này.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi kết nối. Vui lòng thử lại.')),
        );
      }
    }
  }

  void _confirmDelete(int gameId, String gameName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Xác nhận xóa',
                style: AppTextStyles.h2.copyWith(color: AppColors.error),
              ),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa màn chơi "$gameName" không? Hành động này không thể hoàn tác.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(context);
                _deleteGame(gameId);
              },
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.textWhite),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConfig.searchDebounceMs),
      () {
        _fetchMyGames(isRefresh: true);
      },
    );
  }

  Future<void> _fetchMyGames({required bool isRefresh}) async {
    if (isRefresh) {
      AppNotifiers.isMyGamesLoading.value = true;
      _currentPage = 1;
      _hasMore = true;
      AppNotifiers.myGamesNotifier.value = [];
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      String? token = await _storage.read(key: 'access_token');

      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'search': _searchController.text,
        'game_type': _selectedGameType,
        'difficulty': _selectedDifficulty,
        'sort_by': _sortBy,
        'sort_order': _sortOrder,
      };

      final uri = Uri.parse(
        ApiEndpoints.myGames(),
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        final List<Map<String, dynamic>> fetchedGames =
            (decodedData['results'] as List).cast<Map<String, dynamic>>();

        if (mounted) {
          final currentList = AppNotifiers.myGamesNotifier.value;
          AppNotifiers.myGamesNotifier.value = [
            ...currentList,
            ...fetchedGames,
          ];

          setState(() {
            _currentPage++;
            _hasMore = decodedData['next'] != null;
            _isLoadingMore = false;
          });
          AppNotifiers.isMyGamesLoading.value = false;
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingMore = false);
          AppNotifiers.isMyGamesLoading.value = false;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        AppNotifiers.isMyGamesLoading.value = false;
      }
    }
  }

  String _getGameTypeDisplayName(String type) {
    switch (type) {
      case 'QUIZ':
        return 'Trắc nghiệm';
      case 'GUESS':
        return 'Đoán từ';
      case 'SORT':
        return 'Sắp xếp';
      case 'SPELLING':
        return 'Đánh vần';
      default:
        return 'Khác';
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
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

  Widget _buildStatusBadge(String status) {
    String text;
    Color color;

    switch (status) {
      case 'PRIVATE':
        text = 'Riêng tư';
        color = AppColors.textSecondary;
        break;
      case 'PENDING':
        text = 'Chờ duyệt';
        color = AppColors.accent;
        break;
      case 'APPROVED':
        text = 'Công khai';
        color = AppColors.success;
        break;
      case 'REJECTED':
        text = 'Bị từ chối';
        color = AppColors.error;
        break;
      default:
        text = 'Không rõ';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final DateTime date = DateTime.parse(isoDate).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Không xác định';
    }
  }

  void _showFilterBottomSheet() {
    const typeOptions = {
      'ALL': 'Tất cả',
      'QUIZ': 'Trắc nghiệm',
      'GUESS': 'Đoán từ',
      'SORT': 'Sắp xếp',
      'SPELLING': 'Đánh vần',
    };
    const difficultyOptions = {
      'ALL': 'Tất cả',
      'EASY': 'Dễ',
      'MEDIUM': 'Vừa',
      'HARD': 'Khó',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

                  const Text('Thể loại', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: typeOptions.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: _selectedGameType == entry.key,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setModalState(() => _selectedGameType = entry.key);
                          setState(() => _selectedGameType = entry.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  const Text('Độ khó', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: difficultyOptions.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: _selectedDifficulty == entry.key,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setModalState(() => _selectedDifficulty = entry.key);
                          setState(() => _selectedDifficulty = entry.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  const Text('Sắp xếp theo', style: AppTextStyles.h3),
                  const SizedBox(height: 12),

                  RadioGroup<String>(
                    groupValue: _sortBy,
                    onChanged: (String? v) {
                      if (v != null) {
                        setModalState(() => _sortBy = v);
                        setState(() => _sortBy = v);
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Lượt chơi',
                              style: AppTextStyles.bodySecondary,
                            ),
                            value: 'PLAY_COUNT',
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Lượt Like',
                              style: AppTextStyles.bodySecondary,
                            ),
                            value: 'LIKE_COUNT',
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  RadioGroup<String>(
                    groupValue: _sortOrder,
                    onChanged: (String? v) {
                      if (v != null) {
                        setModalState(() => _sortOrder = v);
                        setState(() => _sortOrder = v);
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Giảm dần',
                              style: AppTextStyles.bodySecondary,
                            ),
                            value: 'DESC',
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Tăng dần',
                              style: AppTextStyles.bodySecondary,
                            ),
                            value: 'ASC',
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
                        _fetchMyGames(isRefresh: true);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                          'Tìm màn chơi của bạn...',
                        ).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: AppButtons.primaryButton.copyWith(
                backgroundColor: WidgetStateProperty.all(AppColors.primaryDark),
                elevation: WidgetStateProperty.all(0),
              ),

              onPressed: () async {
                final String? selectedGameType =
                    await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: AppColors.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Chọn thể loại trò chơi',
                              style: AppTextStyles.h2,
                            ),
                            const SizedBox(height: 24),
                            ListTile(
                              leading: const Icon(
                                Icons.quiz_rounded,
                                color: AppColors.primary,
                              ),
                              title: const Text(
                                'Trắc nghiệm',
                                style: AppTextStyles.h3,
                              ),
                              onTap: () => Navigator.pop(context, 'QUIZ'),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.lightbulb_rounded,
                                color: AppColors.accent,
                              ),
                              title: const Text(
                                'Đoán từ vựng',
                                style: AppTextStyles.h3,
                              ),
                              onTap: () => Navigator.pop(context, 'GUESS'),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.sort_rounded,
                                color: AppColors.success,
                              ),
                              title: const Text(
                                'Sắp xếp câu',
                                style: AppTextStyles.h3,
                              ),
                              onTap: () => Navigator.pop(context, 'SORT'),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.headphones,
                                color: AppColors.accent,
                              ),
                              title: const Text(
                                'Đánh vần',
                                style: AppTextStyles.h3,
                              ),
                              onTap: () => Navigator.pop(context, 'SPELLING'),
                            ),
                          ],
                        ),
                      ),
                    );

                if (!context.mounted) return;

                if (selectedGameType != null) {
                  final bool? isCreated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateGameScreen(gameType: selectedGameType),
                    ),
                  );

                  if (isCreated == true) {
                    _fetchMyGames(isRefresh: true);
                  }
                }
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Tạo màn chơi mới'),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: AppNotifiers.isMyGamesLoading,
            builder: (context, isLoading, child) {
              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: AppNotifiers.myGamesNotifier,
                builder: (context, gamesList, child) {
                  if (gamesList.isEmpty) {
                    return const Center(
                      child: Text(
                        'Bạn chưa tạo màn chơi nào.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: gamesList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == gamesList.length) {
                        return _isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                      }

                      final game = gamesList[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: AppDecorations.cardStyle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getGameTypeDisplayName(
                                        game['game_type'],
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _buildStatusBadge(
                                    game['status'] ?? 'PRIVATE',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Text(game['name'], style: AppTextStyles.h3),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tạo ngày: ${_formatDate(game['created_at'])}',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Text(
                                    'Độ khó: ${game['difficulty'] == 'EASY'
                                        ? 'Dễ'
                                        : game['difficulty'] == 'MEDIUM'
                                        ? 'Vừa'
                                        : 'Khó'}',
                                    style: TextStyle(
                                      color: _getDifficultyColor(
                                        game['difficulty'],
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${game['play_count']}',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.favorite_rounded,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${game['likes_count']}',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.border,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: () => _confirmDelete(
                                        game['id'],
                                        game['name'],
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                      ),
                                      tooltip: 'Xóa màn chơi',
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: AppButtons.outlinedButton.copyWith(
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),

                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreateGameScreen(
                                              gameType: game['game_type'],
                                              existingData: game,
                                            ),
                                          ),
                                        );

                                        _fetchMyGames(isRefresh: true);
                                      },
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Sửa'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  Expanded(
                                    child: PlayGameButton(
                                      gameData: game,
                                      isSystemGame: false,
                                      isTrial: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
