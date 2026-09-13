import 'package:flutter/material.dart';

class AppNotifiers {
  static final ValueNotifier<int> currentTabNotifier = ValueNotifier<int>(0);

  static final ValueNotifier<int> gameDashboardTabNotifier = ValueNotifier<int>(
    0,
  );

  static final ValueNotifier<List<Map<String, dynamic>>>
  communityGamesNotifier = ValueNotifier([]);

  static final ValueNotifier<bool> isCommunityGamesLoading =
      ValueNotifier<bool>(true);

  static final ValueNotifier<List<Map<String, dynamic>>> myGamesNotifier =
      ValueNotifier([]);

  static final ValueNotifier<bool> isMyGamesLoading = ValueNotifier<bool>(true);

  static bool hasCompletedVocabTest = false;
}
