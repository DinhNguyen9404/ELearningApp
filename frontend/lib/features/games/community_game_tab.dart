import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/features/games/play_game_button.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/config.dart';
import '../../core/api_endpoints.dart';
import '../../core/notifiers.dart';

class CommunityGamesTab extends StatefulWidget {
  const CommunityGamesTab({super.key});

  @override
  State<CommunityGamesTab> createState() => _CommunityGamesTabState();
}

class _CommunityGamesTabState extends State<CommunityGamesTab> {
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

  bool _showPlayedOnly = false;
  bool _showLikedOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchGames(isRefresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _fetchGames(isRefresh: false);
      }
    });

    AppNotifiers.gameDashboardTabNotifier.addListener(_checkTabReload);
  }

  void _checkTabReload() {
    if (AppNotifiers.gameDashboardTabNotifier.value == 1 && mounted) {
      _fetchGames(isRefresh: false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    AppNotifiers.gameDashboardTabNotifier.removeListener(_checkTabReload);
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConfig.searchDebounceMs),
      () {
        _fetchGames(isRefresh: true);
      },
    );
  }

  Future<void> _fetchGames({required bool isRefresh}) async {
    if (isRefresh) {
      AppNotifiers.isCommunityGamesLoading.value = true;
      _currentPage = 1;
      _hasMore = true;
      AppNotifiers.communityGamesNotifier.value = [];
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      String? token = await _storage.read(key: 'access_token');

      final uri = Uri.parse(ApiEndpoints.communityGames()).replace(
        queryParameters: {
          'page': _currentPage.toString(),
          'search': _searchController.text,
          'game_type': _selectedGameType,
          'difficulty': _selectedDifficulty,
          'sort_by': _sortBy,
          'sort_order': _sortOrder,

          'played_only': _showPlayedOnly.toString(),
          'liked_only': _showLikedOnly.toString(),
        },
      );

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        final List<Map<String, dynamic>> fetchedGames =
            (decodedData['results'] as List).cast<Map<String, dynamic>>();

        if (mounted) {
          final currentList = AppNotifiers.communityGamesNotifier.value;
          AppNotifiers.communityGamesNotifier.value = [
            ...currentList,
            ...fetchedGames,
          ];

          setState(() {
            _currentPage++;
            _hasMore = decodedData['next'] != null;
            _isLoadingMore = false;
          });
          AppNotifiers.isCommunityGamesLoading.value = false;
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingMore = false);
          AppNotifiers.isCommunityGamesLoading.value = false;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        AppNotifiers.isCommunityGamesLoading.value = false;
      }
    }
  }

  Future<void> _toggleLike(int index) async {
    final games = List<Map<String, dynamic>>.from(
      AppNotifiers.communityGamesNotifier.value,
    );
    bool isLiked = games[index]['is_liked'];
    final int levelId = games[index]['id'];

    games[index]['is_liked'] = !isLiked;
    games[index]['likes_count'] += isLiked ? -1 : 1;
    AppNotifiers.communityGamesNotifier.value = games;

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse(ApiEndpoints.toggleCommunityGameLike(levelId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        final rbGames = List<Map<String, dynamic>>.from(
          AppNotifiers.communityGamesNotifier.value,
        );
        rbGames[index]['is_liked'] = isLiked;
        rbGames[index]['likes_count'] += isLiked ? 1 : -1;
        AppNotifiers.communityGamesNotifier.value = rbGames;
      }
    } catch (e) {
      final rbGames = List<Map<String, dynamic>>.from(
        AppNotifiers.communityGamesNotifier.value,
      );
      rbGames[index]['is_liked'] = isLiked;
      rbGames[index]['likes_count'] += isLiked ? 1 : -1;
      AppNotifiers.communityGamesNotifier.value = rbGames;
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

  void _showFilterBottomSheet() {
    const typeOptions = {
      'ALL': 'Tất cả',
      'QUIZ': 'Trắc nghiệm',
      'GUESS': 'Đoán từ',
      'SORT': 'Sắp xếp',
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
                            activeColor:
                                AppColors.primary, // Đổi từ activeColor
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
                            activeColor:
                                AppColors.primary, // Đổi từ activeColor
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Row 2: Thứ tự sắp xếp (Giảm dần / Tăng dần)
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
                            activeColor:
                                AppColors.primary, // Đổi từ activeColor
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
                            activeColor:
                                AppColors.primary, // Đổi từ activeColor
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
                        _fetchGames(isRefresh: true);
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
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
                          'Tìm màn chơi...',
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Đã chơi'),
                selected: _showPlayedOnly,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _showPlayedOnly
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: _showPlayedOnly
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSelected: (bool value) {
                  setState(() => _showPlayedOnly = value);
                  _fetchGames(isRefresh: true);
                },
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Đã Like'),
                selected: _showLikedOnly,
                selectedColor: AppColors.error.withValues(alpha: 0.15),
                checkmarkColor: AppColors.error,
                labelStyle: TextStyle(
                  color: _showLikedOnly
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontWeight: _showLikedOnly
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSelected: (bool value) {
                  setState(() => _showLikedOnly = value);
                  _fetchGames(isRefresh: true);
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: AppNotifiers.isCommunityGamesLoading,
            builder: (context, isLoading, child) {
              if (isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: AppNotifiers.communityGamesNotifier,
                builder: (context, gamesList, child) {
                  if (gamesList.isEmpty) {
                    return const Center(
                      child: Text(
                        'Không tìm thấy màn chơi nào.',
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
                      final bool isLiked = game['is_liked'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: AppDecorations.cardStyle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                                        const SizedBox(height: 8),
                                        Text(
                                          game['name'],
                                          style: AppTextStyles.h3,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (game['is_played'])
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.success,
                                      size: 24,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline_rounded,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tạo bởi: ${game['creator_name']}',
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
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${game['play_count']} lượt chơi',
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () => _toggleLike(index),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isLiked
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: isLiked
                                                ? AppColors.error
                                                : AppColors.textSecondary,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${game['likes_count']}',
                                            style: TextStyle(
                                              color: isLiked
                                                  ? AppColors.error
                                                  : AppColors.textSecondary,
                                              fontWeight: isLiked
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  PlayGameButton(
                                    gameData: game,
                                    isLocked: false,
                                    isCompleted: game['is_played'] ?? false,
                                    isSystemGame: false,
                                    isTrial: false,
                                    onPlayFinished: () {
                                      _fetchGames(isRefresh: true);
                                    },
                                  ),
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
