from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import ForumComment, ForumPost, SystemGameLevel, User, FlashcardDeck, Vocabulary, UserActiveDeck, AIChatMessage, AIChatSession, CommunityGameLevel
import cloudinary.uploader 

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    avatar_file = serializers.ImageField(write_only=True, required=False)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'avatar_file'] 

    def create(self, validated_data):
        avatar_file = validated_data.pop('avatar_file', None)
        uploaded_avatar_url = None
        
        if avatar_file:
            upload_result = cloudinary.uploader.upload(
                avatar_file, 
                folder="elearning_avatars/" 
            )
            uploaded_avatar_url = upload_result.get('secure_url')

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            avatar_url=uploaded_avatar_url 
        )
        return user

class FlashcardDeckSerializer(serializers.ModelSerializer):
    words_count = serializers.SerializerMethodField()
    learners_count = serializers.SerializerMethodField()

    class Meta:
        model = FlashcardDeck
        fields = ['id', 'title', 'description', 'difficulty', 'words_count', 'learners_count'] 

    def get_words_count(self, obj):
        return Vocabulary.objects.filter(decks=obj).count()

    def get_learners_count(self, obj):
        return UserActiveDeck.objects.filter(deck=obj).count()

    def validate_title(self, value):
        if not value or value.isspace():
            raise serializers.ValidationError("Tên bộ từ vựng không được để trống.")
        return value

class UserActiveDeckSerializer(serializers.ModelSerializer):
    deck = FlashcardDeckSerializer(read_only=True) 

    class Meta:
        model = UserActiveDeck
        fields = ['id', 'deck', 'is_active', 'enrolled_at']


class VocabularySerializer(serializers.ModelSerializer):
    class Meta:
        model = Vocabulary
        fields = ['id', 'word', 'meaning', 'part_of_speech', 'pronunciation', 'description', 'examples', 'audio_url', 'image_url']

class AIChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIChatMessage
        fields = ['id', 'role', 'content', 'timestamp']

class AIChatSessionSerializer(serializers.ModelSerializer):
    messages = AIChatMessageSerializer(many=True, read_only=True) 

    class Meta:
        model = AIChatSession
        fields = ['id', 'title', 'created_at', 'messages']

class AIChatSessionListSerializer(serializers.ModelSerializer):
    last_message = serializers.SerializerMethodField()

    class Meta:
        model = AIChatSession
        fields = ['id', 'title', 'created_at', 'last_message']

    def get_last_message(self, obj):
        last = obj.messages.order_by('-id').first()
        return last.content[:80] if last else None

class CommunityGameLevelSerializer(serializers.ModelSerializer):
    creator_name = serializers.CharField(source='creator.username', read_only=True)
    likes_count = serializers.IntegerField(read_only=True)
    is_liked = serializers.BooleanField(read_only=True)
    is_played = serializers.BooleanField(read_only=True)

    class Meta:
        model = CommunityGameLevel
        fields = [
            'id', 'name', 'game_type', 'difficulty', 'base_score', 
            'time_limit', 'play_count', 'likes_count', 'creator_name', 
            'is_liked', 'is_played', 'created_at', 'status', 'game_data' 
        ]

class SystemGameLevelSerializer(serializers.ModelSerializer):
    is_played = serializers.BooleanField(read_only=True, default=False)

    class Meta:
        model = SystemGameLevel
        fields = [
            'id', 'name', 'game_type', 'difficulty', 'base_score', 
            'time_limit', 'sequence_number', 'is_played', 'game_data'
        ]

class ForumPostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)
    author_avatar = serializers.URLField(source='author.avatar_url', read_only=True) 
    is_liked = serializers.SerializerMethodField()
    is_my_post = serializers.SerializerMethodField()

    class Meta:
        model = ForumPost
        fields = [
            'id', 'title', 'content', 'author_name', 'author_avatar', 
            'created_at', 'likes_count', 'comments_count', 'is_liked', 'is_my_post'
        ]

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(id=request.user.id).exists()
        return False

    def get_is_my_post(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.author.id == request.user.id
        return False

class ForumCommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)
    is_my_comment = serializers.SerializerMethodField() 

    class Meta:
        model = ForumComment
        fields = ['id', 'author_name', 'content', 'created_at', 'is_my_comment']

    def get_is_my_comment(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.author.id == request.user.id
        return False


class ForumPostDetailSerializer(ForumPostSerializer):
    comments = ForumCommentSerializer(many=True, read_only=True)

    class Meta(ForumPostSerializer.Meta):
        fields = ForumPostSerializer.Meta.fields + ['comments']


User = get_user_model()

class UserManagementSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'total_score', 'avatar_url', 'is_active']

class EditProfileSerializer(serializers.ModelSerializer):
    avatar_file = serializers.ImageField(write_only=True, required=False)

    class Meta:
        model = User
        
        fields = ['username', 'email', 'avatar_file', 'avatar_url']
        read_only_fields = ['avatar_url']

    def update(self, instance, validated_data):
        avatar_file = validated_data.pop('avatar_file', None)
        
        
        instance.username = validated_data.get('username', instance.username)
        instance.email = validated_data.get('email', instance.email) 
        
        if avatar_file:
            try:
                upload_result = cloudinary.uploader.upload(
                    avatar_file,
                    folder="elearning_avatars/" 
                )
                instance.avatar_url = upload_result.get('secure_url')
            except Exception as e:
                print(f"Lỗi upload Cloudinary khi cập nhật Profile: {e}")

        instance.save()
        return instance


        
    