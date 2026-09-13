import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import 'play_game_button.dart';

class SystemGamesListScreen extends StatefulWidget {
  final String gameType;
  final String title;

  const SystemGamesListScreen({
    super.key,
    required this.gameType,
    required this.title,
  });

  @override
  State<SystemGamesListScreen> createState() => _SystemGamesListScreenState();
}

class _SystemGamesListScreenState extends State<SystemGamesListScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSystemGames();
  }

  Future<void> _fetchSystemGames() async {
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.systemGames(widget.gameType)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));

        List<dynamic> results = decodedData is List
            ? decodedData
            : (decodedData['results'] ?? []);

        if (mounted) {
          setState(() {
            _games = results.cast<Map<String, dynamic>>();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          widget.title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _games.isEmpty
          ? const Center(
              child: Text(
                'Chưa có màn chơi nào.',
                style: AppTextStyles.bodySecondary,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _games.length,
              itemBuilder: (context, index) {
                final game = _games[index];
                final bool isCompleted = game['is_played'] ?? false;

                final bool isLocked =
                    index > 0 && !(_games[index - 1]['is_played'] ?? false);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppDecorations.cardStyle.copyWith(
                      color: isLocked
                          ? AppColors.surface.withValues(alpha: 0.6)
                          : AppColors.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Màn ${game['sequence_number']}',
                              style: AppTextStyles.h3.copyWith(
                                color: isLocked
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isLocked
                                    ? Colors.grey.shade200
                                    : (isCompleted
                                          ? AppColors.success.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.primary.withValues(
                                              alpha: 0.1,
                                            )),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isLocked
                                        ? Icons.lock_rounded
                                        : (isCompleted
                                              ? Icons.check_circle_rounded
                                              : Icons.play_arrow_rounded),
                                    size: 14,
                                    color: isLocked
                                        ? AppColors.textSecondary
                                        : (isCompleted
                                              ? AppColors.success
                                              : AppColors.primary),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLocked
                                        ? 'Chưa mở khóa'
                                        : (isCompleted
                                              ? 'Đã hoàn thành'
                                              : 'Sẵn sàng'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isLocked
                                          ? AppColors.textSecondary
                                          : (isCompleted
                                                ? AppColors.success
                                                : AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Text(
                          game['name'],
                          style: AppTextStyles.h2.copyWith(
                            color: isLocked
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Độ khó: ${game['difficulty'] == 'EASY'
                                  ? 'Dễ'
                                  : game['difficulty'] == 'MEDIUM'
                                  ? 'Vừa'
                                  : 'Khó'}',
                              style: TextStyle(
                                color: isLocked
                                    ? AppColors.textSecondary
                                    : _getDifficultyColor(game['difficulty']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PlayGameButton(
                              gameData: game,
                              isLocked: isLocked,
                              isCompleted: isCompleted,
                              isSystemGame: true,
                              isTrial: false,
                              onPlayFinished: () {
                                _fetchSystemGames();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
