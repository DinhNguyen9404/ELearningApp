import 'config.dart';

class ApiEndpoints {
  static String get _base => AppConfig.baseUrl;

  static String login() => '$_base/o/token/';
  static String register() => '$_base/api/register/';
  static String currentUser() => '$_base/api/users/me/';
  static String updateProfile() => '$_base/api/user/update/';
  static String changePassword() => '$_base/api/user/change-password/';
  static String requestPasswordReset() => '$_base/api/password-reset/';
  static String confirmPasswordReset() => '$_base/api/password-reset-confirm/';

  static String decks() => '$_base/api/decks/';
  static String savedDecks() => '$_base/api/decks/saved/';
  static String enrollDeck(int id) => '$_base/api/decks/$id/enroll/';
  static String toggleActiveDeck(int id) =>
      '$_base/api/decks/$id/toggle-active/';
  static String deckVocabularies(int id) =>
      '$_base/api/decks/$id/vocabularies/';
  static String activeTest() => '$_base/api/vocabulary/active-test/';

  static String manageDecks() => '$_base/api/manage/decks/';
  static String manageDeckDetail(int id) => '$_base/api/manage/decks/$id/';
  static String manageDeckVocabularies(int deckId) =>
      '$_base/api/manage/decks/$deckId/vocabularies/';
  static String manageVocabularyDetail(int vocabId) =>
      '$_base/api/manage/vocabularies/$vocabId/';

  static String aiChatAsk() => '$_base/api/chat/ask/';
  static String aiChatSessions() => '$_base/api/chat/sessions/';
  static String aiChatSessionDetail(int id) => '$_base/api/chat/sessions/$id/';

  static String forumPosts() => '$_base/api/forum/posts/';
  static String forumPostDetail(int id) => '$_base/api/forum/posts/$id/';
  static String toggleForumLike(int id) => '$_base/api/forum/posts/$id/like/';
  static String forumComments(int postId) =>
      '$_base/api/forum/posts/$postId/comments/';
  static String forumCommentDetail(int id) => '$_base/api/forum/comments/$id/';

  static String communityGames() => '$_base/api/games/community/';
  static String communityGameDetail(int id) =>
      '$_base/api/games/community/$id/';
  static String toggleCommunityGameLike(int id) =>
      '$_base/api/games/community/$id/like/';
  static String submitCommunityGame(int id) =>
      '$_base/api/games/community/$id/submit/';

  static String myGames() => '$_base/api/games/my-games/';
  static String pendingGames() => '$_base/api/games/pending/';
  static String reviewGame(int id) => '$_base/api/games/pending/$id/review/';

  static String systemGames(String gameType) =>
      '$_base/api/games/system/type/$gameType/';
  static String systemGameDetail(int id) => '$_base/api/games/system/$id/';
  static String submitSystemGame(int id) =>
      '$_base/api/games/system/$id/submit/';

  static String adminUsers() => '$_base/api/admin/users/';
  static String adminChangeRole(int id) => '$_base/api/admin/users/$id/role/';
  static String adminUserDetail(int id) => '$_base/api/admin/users/$id/';
  static String adminStatistics() => '$_base/api/admin/statistics/';
}
