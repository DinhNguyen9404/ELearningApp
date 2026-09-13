from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import (
    User, Vocabulary, FlashcardDeck, UserActiveDeck, 
    SystemGameLevel, CommunityGameLevel, GameHistory, 
    AIChatSession, AIChatMessage, ForumPost, ForumComment
)


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('username', 'email', 'role', 'total_score')
    fieldsets = UserAdmin.fieldsets + (
        ('Thông tin Ứng dụng', {'fields': ('role', 'total_score', 'avatar_url')}),
    )


@admin.register(Vocabulary)
class VocabularyAdmin(admin.ModelAdmin):
    list_display = ('word', 'meaning', 'part_of_speech')
    search_fields = ('word', 'meaning')


@admin.register(FlashcardDeck)
class FlashcardDeckAdmin(admin.ModelAdmin):
    list_display = ('title', 'difficulty', 'creator', 'learner_count', 'created_at')
    list_filter = ('difficulty',)


admin.site.register(UserActiveDeck)
admin.site.register(SystemGameLevel)
admin.site.register(CommunityGameLevel)
admin.site.register(GameHistory)
admin.site.register(AIChatSession)
admin.site.register(AIChatMessage)
admin.site.register(ForumPost)
admin.site.register(ForumComment)