from django.db import models
from django.contrib.auth.models import AbstractUser
from django.contrib.contenttypes.models import ContentType
from django.contrib.contenttypes.fields import GenericForeignKey
from django.utils import timezone

class RoleEnum(models.TextChoices):
    USER = 'USER', 'Người dùng'
    MODERATOR = 'MODERATOR', 'Kiểm duyệt viên'
    ADMIN = 'ADMIN', 'Admin'

class DifficultyEnum(models.TextChoices):
    EASY = 'EASY', 'Dễ'
    MEDIUM = 'MEDIUM', 'Vừa'
    HARD = 'HARD', 'Khó'

class GameEnum(models.TextChoices):
    QUIZ = 'QUIZ', 'Trắc nghiệm'
    GUESS = 'GUESS', 'Đoán từ vựng'
    SORT = 'SORT', 'Sắp xếp từ'
    SPELLING = 'SPELLING', 'Đánh vần'

class StatusEnum(models.TextChoices):
    PRIVATE = 'PRIVATE', 'Riêng tư'
    PENDING = 'PENDING', 'Chờ duyệt'
    APPROVED = 'APPROVED', 'Đã duyệt'
    REJECTED = 'REJECTED', 'Từ chối'

class ChatRoleEnum(models.TextChoices):
    USER = 'USER', 'Người dùng'
    AI = 'AI', 'Trợ lý AI'


class User(AbstractUser):
    role = models.CharField(max_length=20, choices=RoleEnum.choices, default=RoleEnum.USER)
    total_score = models.IntegerField(default=0)
    avatar_url = models.URLField(max_length=500, blank=True, null=True)

    class Meta:
        db_table = 'user' 

    def __str__(self):
        return self.username


class Vocabulary(models.Model):
    word = models.CharField(max_length=100)
    meaning = models.CharField(max_length=255, default="") 
    part_of_speech = models.CharField(max_length=50, blank=True, null=True)
    pronunciation = models.CharField(max_length=100, blank=True, null=True)
    description = models.TextField(help_text="Mô tả ý nghĩa bằng tiếng Anh") 
    examples = models.JSONField(default=list, help_text="Danh sách các câu ví dụ") 
    
    audio_url = models.URLField(max_length=500, blank=True, null=True)
    image_url = models.URLField(max_length=500, blank=True, null=True)
    
    class Meta:
        db_table = 'vocabulary'

    def __str__(self):
        return f"{self.word} - {self.meaning}"


class FlashcardDeck(models.Model):
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    difficulty = models.CharField(max_length=20, choices=DifficultyEnum.choices, default=DifficultyEnum.MEDIUM)
    learner_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    
    creator = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        related_name='created_decks',
        limit_choices_to={'role': RoleEnum.MODERATOR}
    )    
    
    vocabularies = models.ManyToManyField(
        Vocabulary, 
        related_name='decks', 
        blank=True,
        db_table='flashcarddeck_vocabularies' 
    )

    class Meta:
        db_table = 'flashcarddeck'

    @property
    def vocab_count(self):
        return self.vocabularies.count()

    def __str__(self):
        return self.title


class UserActiveDeck(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='active_decks')
    deck = models.ForeignKey(FlashcardDeck, on_delete=models.CASCADE)
    
    is_active = models.BooleanField(default=False) 
    enrolled_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'useractivedeck'
        unique_together = ('user', 'deck')


class BaseGameLevel(models.Model):
    name = models.CharField(max_length=255)
    game_type = models.CharField(max_length=20, choices=GameEnum.choices)
    difficulty = models.CharField(max_length=20, choices=DifficultyEnum.choices, default=DifficultyEnum.MEDIUM)
    
    base_score = models.IntegerField(default=100)
    time_limit = models.IntegerField(null=True, blank=True, help_text="Giới hạn thời gian (giây)")
    game_data = models.JSONField() 
    created_at = models.DateTimeField(auto_now_add=True)
    play_count = models.IntegerField(default=0)
    
    creator = models.ForeignKey(User, on_delete=models.CASCADE, related_name='%(class)s_created')

    class Meta:
        abstract = True 

    def __str__(self):
        return f"[{self.get_game_type_display()}] {self.name}"


class SystemGameLevel(BaseGameLevel):
    sequence_number = models.IntegerField(default=0, help_text="Thứ tự màn chơi")

    class Meta:
        db_table = 'systemgamelevel'


class CommunityGameLevel(BaseGameLevel):
    status = models.CharField(max_length=20, choices=StatusEnum.choices, default=StatusEnum.PRIVATE)
    
    likes = models.ManyToManyField(
        User, 
        related_name='liked_community_levels', 
        blank=True,
        db_table='communitygamelevel_likes' 
    )

    class Meta:
        db_table = 'communitygamelevel'


class GameHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='game_histories')
    
    content_type = models.ForeignKey(ContentType, on_delete=models.CASCADE)
    object_id = models.PositiveIntegerField()
    level = GenericForeignKey('content_type', 'object_id')
    
    score_earned = models.IntegerField(default=0)
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'gamehistory'

    def __str__(self):
        return f"{self.user.username} - Điểm: {self.score_earned}"


class AIChatSession(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ai_sessions')
    title = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'aichatsession'

    def __str__(self):
        return self.title if self.title else f"Phiên hỏi đáp của {self.user.username}"


class AIChatMessage(models.Model):
    session = models.ForeignKey(AIChatSession, on_delete=models.CASCADE, related_name='messages')
    role = models.CharField(max_length=10, choices=ChatRoleEnum.choices)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'aichatmessage'

    def __str__(self):
        return f"[{self.get_role_display()}] {self.timestamp}"


class ForumPost(models.Model):
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='posts')
    title = models.CharField(max_length=255)
    content = models.TextField()
    
    likes = models.ManyToManyField(
        User, 
        related_name='liked_posts', 
        blank=True,
        db_table='forumpost_likes' 
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'forumpost'

    @property
    def likes_count(self):
        return self.likes.count()

    @property
    def comments_count(self):
        return self.comments.count()

    def __str__(self):
        return self.title


class ForumComment(models.Model):
    post = models.ForeignKey(ForumPost, on_delete=models.CASCADE, related_name='comments')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='forum_comments')
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'forumcomment'

    def __str__(self):
        return f"Bình luận của {self.author.username} trên '{self.post.title}'"