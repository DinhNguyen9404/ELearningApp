import 'config.dart';

class ApiEndpoints {
  static String get _base => AppConfig.baseUrl;

  static String login() => '$_base/o/token/';
  static String register() => '$_base/register/';
  static String currentUser() => '$_base/users/me/';
  static String updateProfile() => '$_base/user/update/';
  static String changePassword() => '$_base/user/change-password/';
  static String requestPasswordReset() => '$_base/password-reset/';
  static String confirmPasswordReset() => '$_base/password-reset-confirm/';

  static String decks() => '$_base/decks/';
  static String savedDecks() => '$_base/decks/saved/';
  static String enrollDeck(int id) => '$_base/decks/$id/enroll/';
  static String toggleActiveDeck(int id) => '$_base/decks/$id/toggle-active/';
  static String deckVocabularies(int id) => '$_base/decks/$id/vocabularies/';
  static String activeTest() => '$_base/vocabulary/active-test/';

  static String manageDecks() => '$_base/manage/decks/';
  static String manageDeckDetail(int id) => '$_base/manage/decks/$id/';
  static String manageDeckVocabularies(int deckId) =>
      '$_base/manage/decks/$deckId/vocabularies/';
  static String manageVocabularyDetail(int vocabId) =>
      '$_base/manage/vocabularies/$vocabId/';

  static String aiChatAsk() => '$_base/chat/ask/';
  static String aiChatSessions() => '$_base/chat/sessions/';
  static String aiChatSessionDetail(int id) => '$_base/chat/sessions/$id/';

  static String forumPosts() => '$_base/forum/posts/';
  static String forumPostDetail(int id) => '$_base/forum/posts/$id/';
  static String toggleForumLike(int id) => '$_base/forum/posts/$id/like/';
  static String forumComments(int postId) =>
      '$_base/forum/posts/$postId/comments/';
  static String forumCommentDetail(int id) => '$_base/forum/comments/$id/';

  static String communityGames() => '$_base/games/community/';
  static String communityGameDetail(int id) => '$_base/games/community/$id/';
  static String toggleCommunityGameLike(int id) =>
      '$_base/games/community/$id/like/';
  static String submitCommunityGame(int id) =>
      '$_base/games/community/$id/submit/';

  static String myGames() => '$_base/games/my-games/';
  static String pendingGames() => '$_base/games/pending/';
  static String reviewGame(int id) => '$_base/games/pending/$id/review/';

  static String systemGames(String gameType) =>
      '$_base/games/system/type/$gameType/';
  static String systemGameDetail(int id) => '$_base/games/system/$id/';
  static String submitSystemGame(int id) => '$_base/games/system/$id/submit/';

  static String adminUsers() => '$_base/admin/users/';
  static String adminChangeRole(int id) => '$_base/admin/users/$id/role/';
  static String adminUserDetail(int id) => '$_base/admin/users/$id/';
  static String adminStatistics() => '$_base/admin/statistics/';
}
