from django.contrib import admin
from django.urls import path, include 
from elearningapp_api.views import (
    ActiveTestVocabularyView, AddForumCommentView, AdminStatisticsView, ChangePasswordView, ChangeUserRoleView, ChatSessionDetailView, 
    ChatSessionListView, CommunityGameDetailView, CommunityGameListCreateView, DeleteUserView, EditProfileView, 
    ForumCommentDetailView, ForumPostDetailView, ForumPostListCreateView, ManageDeckDetailView, 
    ManageDeckListCreateView, ManageDeckVocabularyView, ManageVocabularyDetailView, PendingGamesListView, 
    RegisterView, FlashcardDeckListView, CurrentUserView, RequestPasswordResetView, ResetPasswordConfirmView, ReviewGameActionView, SavedDeckListView, 
    EnrollDeckView, SubmitSystemGameView, SubmitCommunityGameView, SystemGameDetailView, SystemGameListCreateView, 
    ToggleActiveDeckView, DeckVocabularyListView, ChatWithAIView, ToggleCommunityGameLikeView, 
    MyGameListView, ToggleForumPostLikeView, UserListView
)

urlpatterns = [
    path('admin/', admin.site.urls),
    
    
    path('o/', include('oauth2_provider.urls', namespace='oauth2_provider')),
    path('register/', RegisterView.as_view(), name='auth_register'),
    path('users/me/', CurrentUserView.as_view(), name='current_user'),
    path('user/update/', EditProfileView.as_view(), name='update_profile'),
    path('user/change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('password-reset/', RequestPasswordResetView.as_view(), name='password_reset'),
    path('password-reset-confirm/', ResetPasswordConfirmView.as_view(), name='password_reset_confirm'),

    
    path('decks/', FlashcardDeckListView.as_view(), name='deck_list'),
    path('decks/saved/', SavedDeckListView.as_view(), name='saved_decks'),
    path('decks/<int:deck_id>/enroll/', EnrollDeckView.as_view(), name='enroll_deck'),
    path('decks/<int:deck_id>/toggle-active/', ToggleActiveDeckView.as_view(), name='toggle_active_deck'),
    path('decks/<int:deck_id>/vocabularies/', DeckVocabularyListView.as_view(), name='deck_vocabularies'),
    path('vocabulary/active-test/', ActiveTestVocabularyView.as_view(), name='active_test_vocabulary'),

    
    path('manage/decks/', ManageDeckListCreateView.as_view(), name='manage_decks_list_create'),
    path('manage/decks/<int:pk>/', ManageDeckDetailView.as_view(), name='manage_decks_detail_delete'),
    path('manage/decks/<int:deck_id>/vocabularies/', ManageDeckVocabularyView.as_view(), name='manage_add_vocab'),
    path('manage/vocabularies/<int:vocab_id>/', ManageVocabularyDetailView.as_view(), name='manage_vocab_detail'),

    
    path('chat/ask/', ChatWithAIView.as_view(), name='ai_chat_ask'),
    path('chat/sessions/', ChatSessionListView.as_view(), name='ai_chat_sessions'),
    path('chat/sessions/<int:session_id>/', ChatSessionDetailView.as_view(), name='ai_chat_session_detail'),

    
    path('forum/posts/', ForumPostListCreateView.as_view(), name='forum_post_list_create'),
    path('forum/posts/<int:post_id>/', ForumPostDetailView.as_view(), name='forum_post_detail'),
    path('forum/posts/<int:post_id>/like/', ToggleForumPostLikeView.as_view(), name='toggle_forum_like'),
    path('forum/posts/<int:post_id>/comments/', AddForumCommentView.as_view(), name='add_forum_comment'),
    path('forum/comments/<int:pk>/', ForumCommentDetailView.as_view(), name='forum_comment_detail'),

    
    path('games/community/', CommunityGameListCreateView.as_view(), name='community_games'),
    path('games/community/<int:pk>/', CommunityGameDetailView.as_view(), name='community_game_detail'),
    path('games/community/<int:level_id>/like/', ToggleCommunityGameLikeView.as_view(), name='toggle_community_game_like'),
    path('games/community/<int:level_id>/submit/', SubmitCommunityGameView.as_view(), name='submit_community_game'),
    path('games/my-games/', MyGameListView.as_view(), name='my_games'),
    path('games/pending/', PendingGamesListView.as_view(), name='pending_games_list'),
    path('games/pending/<int:game_id>/review/', ReviewGameActionView.as_view(), name='review_game_action'),

    
    path('games/system/type/<str:game_type>/', SystemGameListCreateView.as_view(), name='system_games_list_create'),
    path('games/system/<int:pk>/', SystemGameDetailView.as_view(), name='system_game_detail'),
    path('games/system/<int:level_id>/submit/', SubmitSystemGameView.as_view(), name='submit_system_game'),

    
    path('admin/users/', UserListView.as_view(), name='admin_user_list'),
    path('admin/users/<int:user_id>/role/', ChangeUserRoleView.as_view(), name='admin_change_role'),
    path('admin/users/<int:pk>/', DeleteUserView.as_view(), name='admin_user_detail_delete'),
    path('admin/statistics/', AdminStatisticsView.as_view(), name='admin_statistics'),
]