import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'quiz_game_screen.dart';
import 'guess_game_screen.dart';
import 'sort_game_screen.dart';
import 'spelling_game_screen.dart';

class PlayGameButton extends StatelessWidget {
  final Map<String, dynamic> gameData;
  final bool isLocked;
  final bool isCompleted;
  final bool isSystemGame;
  final bool isTrial;
  final VoidCallback? onPlayFinished;

  const PlayGameButton({
    super.key,
    required this.gameData,
    this.isLocked = false,
    this.isCompleted = false,
    this.isSystemGame = false,
    this.isTrial = false,
    this.onPlayFinished,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: AppButtons.primaryButton.copyWith(
        backgroundColor: WidgetStateProperty.all(
          isLocked ? Colors.grey.shade400 : AppColors.primary,
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        ),
      ),
      onPressed: isLocked
          ? null
          : () async {
              final String gameType = gameData['game_type'];

              if (gameType == 'QUIZ') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizGameScreen(
                      gameData: gameData,
                      isSystemGame: isSystemGame,
                      isTrial: isTrial,
                    ),
                  ),
                );

                onPlayFinished?.call();
              } else if (gameType == 'GUESS') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GuessGameScreen(
                      gameData: gameData,
                      isSystemGame: isSystemGame,
                      isTrial: isTrial,
                    ),
                  ),
                );
                onPlayFinished?.call();
              } else if (gameType == 'SORT') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SortGameScreen(
                      gameData: gameData,
                      isSystemGame: isSystemGame,
                      isTrial: isTrial,
                    ),
                  ),
                );
                onPlayFinished?.call();
              } else if (gameType == 'SPELLING') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SpellingGameScreen(
                      gameData: gameData,
                      isSystemGame: isSystemGame,
                      isTrial: isTrial,
                    ),
                  ),
                );
                onPlayFinished?.call();
              }
            },
      child: Text(
        isCompleted ? 'Chơi lại' : (isTrial ? 'Chơi thử' : 'Chơi ngay'),
      ),
    );
  }
}
