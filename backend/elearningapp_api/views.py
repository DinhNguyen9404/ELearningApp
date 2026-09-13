import json
import time
import cloudinary
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from rest_framework.response import Response
from django.db.models import Exists, Max, OuterRef, Count
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.core.cache import cache
from django.contrib.contenttypes.models import ContentType
from .models import CommunityGameLevel, ForumComment, ForumPost, GameEnum, GameHistory, StatusEnum, SystemGameLevel, User, FlashcardDeck, Vocabulary, UserActiveDeck, AIChatSession, AIChatMessage, ChatRoleEnum
from .serializers import AIChatSessionListSerializer, AIChatSessionSerializer, CommunityGameLevelSerializer, EditProfileSerializer, ForumCommentSerializer, ForumPostDetailSerializer, ForumPostSerializer, SystemGameLevelSerializer, RegisterSerializer, FlashcardDeckSerializer, SystemGameLevelSerializer, UserManagementSerializer, VocabularySerializer, UserActiveDeckSerializer
from google import genai
from google.genai import errors
from django.conf import settings
import requests
import random
import logging

logger = logging.getLogger(__name__)
User = get_user_model()

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 10 
    page_size_query_param = 'page_size'
    max_page_size = 30


class ModeratorPermissionMixin:
    def check_moderator_permission(self, request):
        if request.user.role != 'MODERATOR':
            raise PermissionDenied("Chỉ Kiểm duyệt viên mới có quyền quản lý.")


class AdminPermissionMixin:
    def check_admin_permission(self, request):
        if request.user.role != 'ADMIN':
            raise PermissionDenied("Chỉ Quản trị viên mới có quyền thực hiện hành động này.")


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,) 
    serializer_class = RegisterSerializer


class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            'username': user.username,
            'email': user.email,
            'role': user.role,
            'total_score': user.total_score,
            'avatar_url': user.avatar_url
        })


class EditProfileView(generics.UpdateAPIView):
    serializer_class = EditProfileSerializer
    permission_classes = [IsAuthenticated] 

    def get_object(self):
        
        return self.request.user


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request):
        user = request.user
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')
        
        if not old_password or not new_password:
            return Response(
                {"error": "Vui lòng cung cấp cả mật khẩu cũ và mới."}, 
                status=status.HTTP_400_BAD_REQUEST
            )
    
        if not user.check_password(old_password):
            return Response(
                {"error": "Mật khẩu hiện tại không chính xác."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        if old_password == new_password:
            return Response(
                {"error": "Mật khẩu mới không được trùng với mật khẩu hiện tại."}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        user.set_password(new_password)
        user.save()
        return Response({"message": "Đổi mật khẩu thành công!"}, status=status.HTTP_200_OK)



class RequestPasswordResetView(APIView):
    permission_classes = [] 

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({"error": "Vui lòng cung cấp email."}, status=status.HTTP_400_BAD_REQUEST)
        
        user = User.objects.filter(email=email).first()
        if not user:
            return Response({"error": "Email không tồn tại trong hệ thống."}, status=status.HTTP_404_NOT_FOUND)
        
        otp = str(random.randint(100000, 999999))
        cache.set(f"otp_{email}", otp, timeout=300)
       
        subject = 'Mã khôi phục mật khẩu ứng dụng Elearning'
        message = f'Chào {user.username},\n\nMã xác nhận khôi phục mật khẩu của bạn là: {otp}\n\nMã này có hiệu lực trong 5 phút. Vui lòng không chia sẻ mã này cho người khác.'
        
        try:
            send_mail(subject, message, settings.EMAIL_HOST_USER, [email])
            return Response({"message": "Mã OTP đã được gửi đến email của bạn."}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": "Lỗi khi gửi email, vui lòng thử lại sau."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



class ResetPasswordConfirmView(APIView):
    permission_classes = []

    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        new_password = request.data.get('new_password')

        if not all([email, otp, new_password]):
            return Response({"error": "Vui lòng điền đầy đủ thông tin."}, status=status.HTTP_400_BAD_REQUEST)
        
        cached_otp = cache.get(f"otp_{email}")

        if not cached_otp or cached_otp != str(otp):
            return Response({"error": "Mã OTP không chính xác hoặc đã hết hạn."}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(email=email).first()
        if user:
            user.set_password(new_password)
            user.save()
            cache.delete(f"otp_{email}") 
            return Response({"message": "Đổi mật khẩu thành công!"}, status=status.HTTP_200_OK)
            
        return Response({"error": "Không tìm thấy tài khoản."}, status=status.HTTP_404_NOT_FOUND)


class UserListView(AdminPermissionMixin, generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserManagementSerializer

    def get_queryset(self):
        self.check_admin_permission(self.request)
        
        return User.objects.exclude(id=self.request.user.id).order_by('username')


class ChangeUserRoleView(AdminPermissionMixin, APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, user_id):
        self.check_admin_permission(request)
        new_role = request.data.get('role')
        
        if new_role not in ['USER', 'MODERATOR', 'ADMIN']:
            return Response({"error": "Quyền không hợp lệ"}, status=status.HTTP_400_BAD_REQUEST)

        user = get_object_or_404(User, id=user_id)
        user.role = new_role
        
        if new_role == 'ADMIN':
            user.is_staff = True
            user.is_superuser = True
        elif new_role == 'MODERATOR':
            user.is_staff = True
            user.is_superuser = False
        else:
            user.is_staff = False
            user.is_superuser = False
            
        user.save()
        return Response({"message": f"Đã cấp quyền {new_role} cho {user.username}"}, status=status.HTTP_200_OK)


class DeleteUserView(AdminPermissionMixin, generics.DestroyAPIView):
    permission_classes = [IsAuthenticated]
    queryset = User.objects.all()

    def perform_destroy(self, instance):
        self.check_admin_permission(self.request)
        instance.delete()


class AdminStatisticsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role not in ['ADMIN', 'MODERATOR']:
            raise PermissionDenied("Bạn không có quyền xem thống kê.")
        
        total_users = User.objects.count()
        total_game_plays = GameHistory.objects.count()
        total_vocabularies = Vocabulary.objects.count()
        total_decks = FlashcardDeck.objects.count()
        total_active_learners = UserActiveDeck.objects.filter(is_active=True).count()
        total_system_games = SystemGameLevel.objects.count()
        total_community_games = CommunityGameLevel.objects.count()
        pending_games = CommunityGameLevel.objects.filter(status='PENDING').count()

        system_breakdown = {}
        community_breakdown = {}
        
        for game_type in GameEnum.choices:
            type_code = game_type[0]
            system_breakdown[type_code] = SystemGameLevel.objects.filter(game_type=type_code).count()
            community_breakdown[type_code] = CommunityGameLevel.objects.filter(game_type=type_code).count()

        return Response({
            "overview": {
                "total_users": total_users,
                "total_game_plays": total_game_plays,
            },
            "vocabulary": {
                "total_decks": total_decks,
                "total_words": total_vocabularies,
                "total_active_learners": total_active_learners,
            },
            "games": {
                "total_system": total_system_games,
                "total_community": total_community_games,
                "pending_approvals": pending_games,
                "system_breakdown": system_breakdown,
                "community_breakdown": community_breakdown
            }
        })


class FlashcardDeckListView(generics.ListAPIView):
    serializer_class = FlashcardDeckSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        user = self.request.user        
        
        if user.is_authenticated:
            saved_deck_ids = UserActiveDeck.objects.filter(user=user).values_list('deck_id', flat=True)
            queryset = FlashcardDeck.objects.exclude(id__in=saved_deck_ids)
        else:
            queryset = FlashcardDeck.objects.all()
        
        search_query = self.request.query_params.get('search', None)
        difficulty = self.request.query_params.get('difficulty', None)
        sort_order = self.request.query_params.get('sort', None)

        if search_query:
            queryset = queryset.filter(title__icontains=search_query)
        
        if difficulty and difficulty != 'ALL':
            queryset = queryset.filter(difficulty=difficulty)
        
        if sort_order == 'Tăng dần':
            queryset = queryset.order_by('learner_count')
        else:
            queryset = queryset.order_by('-learner_count') 

        return queryset


class SavedDeckListView(generics.ListAPIView):
    serializer_class = UserActiveDeckSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        
        queryset = UserActiveDeck.objects.filter(user=self.request.user).order_by('-enrolled_at')
        
        search_query = self.request.query_params.get('search', None)
        difficulty = self.request.query_params.get('difficulty', None)
        sort_order = self.request.query_params.get('sort', None)

        if search_query:
            queryset = queryset.filter(deck__title__icontains=search_query)
        if difficulty and difficulty != 'ALL':
            queryset = queryset.filter(deck__difficulty=difficulty)
            
        if sort_order == 'Tăng dần':
            queryset = queryset.order_by('deck__learner_count')
        elif sort_order == 'Giảm dần':
            queryset = queryset.order_by('-deck__learner_count')

        return queryset


class ToggleActiveDeckView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, deck_id):
        user = request.user
        active_deck = get_object_or_404(UserActiveDeck, user=user, deck_id=deck_id)
        
        if active_deck.is_active:
            
            active_deck.is_active = False
            active_deck.save()
            return Response({"is_active": False, "message": "Đã tắt nhắc nhở"})
        else:
            
            UserActiveDeck.objects.filter(user=user).update(is_active=False)
            
            active_deck.is_active = True
            active_deck.save()
            return Response({"is_active": True, "message": "Đã bật nhắc nhở cho bộ này"})


class EnrollDeckView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request, deck_id):
        deck = get_object_or_404(FlashcardDeck, id=deck_id)
        UserActiveDeck.objects.get_or_create(user=request.user, deck=deck)
        return Response({"message": "Đã lưu bộ từ vựng thành công"}, status=status.HTTP_201_CREATED)

    def delete(self, request, deck_id):
        UserActiveDeck.objects.filter(user=request.user, deck_id=deck_id).delete()
        return Response({"message": "Đã xóa khỏi danh sách học"}, status=status.HTTP_200_OK)


class DeckVocabularyListView(generics.ListAPIView):
    serializer_class = VocabularySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        deck_id = self.kwargs['deck_id']
        return Vocabulary.objects.filter(decks__id=deck_id)


class ActiveTestVocabularyView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        active_deck_record = UserActiveDeck.objects.filter(user=user, is_active=True).first()
        
        if not active_deck_record:
            return Response([], status=200)

        deck = active_deck_record.deck
        vocabularies = list(deck.vocabularies.all())
        
        if not vocabularies:
            return Response([], status=200)
        
        all_meanings_pool = list(Vocabulary.objects.exclude(meaning="").values_list('meaning', flat=True))
        test_questions = []
        
        for vocab in vocabularies:           
            correct_meaning = vocab.meaning
            distractors = [v.meaning for v in vocabularies if v.id != vocab.id and v.meaning != correct_meaning]
            
            if len(distractors) < 3:
                extra_needed = 3 - len(distractors)
                system_distractors = [m for m in all_meanings_pool if m != correct_meaning and m not in distractors]              
                
                random.shuffle(system_distractors)
                distractors.extend(system_distractors[:extra_needed])
                        
            random.shuffle(distractors)
            selected_distractors = distractors[:3]                      
            options = selected_distractors + [correct_meaning]         
            random.shuffle(options)                 
            correct_index = options.index(correct_meaning)  
            question_data = {
                "word_id": vocab.id,
                "word": vocab.word,
                "correct_index": correct_index,
                "options": options
            }
            test_questions.append(question_data)
            
        random.shuffle(test_questions)
        return Response(test_questions, status=200)






class ManageDeckListCreateView(ModeratorPermissionMixin, generics.ListCreateAPIView):
    serializer_class = FlashcardDeckSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        self.check_moderator_permission(self.request)
        
        queryset = FlashcardDeck.objects.filter(creator=self.request.user)
        search_query = self.request.query_params.get('search', None)
        difficulty = self.request.query_params.get('difficulty', None)

        if search_query:
            queryset = queryset.filter(title__icontains=search_query)
        if difficulty and difficulty != 'ALL':
            queryset = queryset.filter(difficulty=difficulty)
            
        return queryset.order_by('-created_at') 

    def perform_create(self, serializer):
        self.check_moderator_permission(self.request)
        serializer.save(creator=self.request.user)



class ManageDeckDetailView(ModeratorPermissionMixin, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = FlashcardDeckSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        
        if self.request.user.role == 'ADMIN':
            return FlashcardDeck.objects.all()
        return FlashcardDeck.objects.filter(creator=self.request.user)
        
    def perform_update(self, serializer):
        self.check_moderator_permission(self.request)
        serializer.save()

    def perform_destroy(self, instance):
        self.check_moderator_permission(self.request)
        instance.delete()


class ManageDeckVocabularyView(ModeratorPermissionMixin, APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser] 

    def post(self, request, deck_id):
        self.check_moderator_permission(request)
        deck = get_object_or_404(FlashcardDeck, id=deck_id, creator=request.user)
        
        word = request.data.get('word')
        meaning = request.data.get('meaning')
        pronunciation = request.data.get('pronunciation', '')
        part_of_speech = request.data.get('part_of_speech', 'noun')
        description = request.data.get('description', '')
        examples_raw = request.data.get('examples', '[]')
        audio_file = request.FILES.get('audio_file')

        if not word or not meaning:
            return Response({"error": "Vui lòng nhập đủ từ vựng và nghĩa."}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            examples = json.loads(examples_raw)
        except json.JSONDecodeError:
            examples = []

        audio_url = ""
        if audio_file:
            try:
                upload_data = cloudinary.uploader.upload(
                    audio_file, 
                    resource_type="video", 
                    folder="elearningapp/audio/"
                )
                audio_url = upload_data.get('secure_url')
            except Exception as e:
                return Response({"error": f"Lỗi upload âm thanh: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

        vocab = Vocabulary.objects.create(
            word=word,
            meaning=meaning,
            pronunciation=pronunciation,
            part_of_speech=part_of_speech,
            description=description,
            examples=examples,
            audio_url=audio_url
        )
        vocab.decks.add(deck)
        return Response({"message": "Thêm từ vựng thành công!", "vocab_id": vocab.id}, status=status.HTTP_201_CREATED)


class ManageVocabularyDetailView(ModeratorPermissionMixin, APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def put(self, request, vocab_id):
        self.check_moderator_permission(request)
        vocab = get_object_or_404(Vocabulary, id=vocab_id)
        
        vocab.word = request.data.get('word', vocab.word)
        vocab.meaning = request.data.get('meaning', vocab.meaning)
        vocab.pronunciation = request.data.get('pronunciation', vocab.pronunciation)
        vocab.part_of_speech = request.data.get('part_of_speech', vocab.part_of_speech)
        vocab.description = request.data.get('description', vocab.description)
        
        examples_raw = request.data.get('examples')
        if examples_raw:
            try:
                vocab.examples = json.loads(examples_raw)
            except json.JSONDecodeError:
                pass
                
        audio_file = request.FILES.get('audio_file')
        if audio_file:
            try:
                upload_data = cloudinary.uploader.upload(
                    audio_file, resource_type="video", folder="elearningapp/audio/"
                )
                vocab.audio_url = upload_data.get('secure_url')
            except Exception:
                pass 

        vocab.save()
        return Response({"message": "Cập nhật thành công"}, status=status.HTTP_200_OK)

    def delete(self, request, vocab_id):
        self.check_moderator_permission(request)
        vocab = get_object_or_404(Vocabulary, id=vocab_id)
        vocab.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CreateFlashcardDeckView(ModeratorPermissionMixin, generics.CreateAPIView):
    queryset = FlashcardDeck.objects.all()
    serializer_class = FlashcardDeckSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        self.check_moderator_permission(self.request)
        serializer.save(creator=self.request.user)


class ChatWithAIView(APIView):
    permission_classes = [IsAuthenticated]

    GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
    REQUEST_TIMEOUT = 25   
    MAX_RETRIES = 1        
    RETRY_BACKOFF = 2      

    def post(self, request):
        user_message = request.data.get('content')
        session_id = request.data.get('session_id')

        if not user_message:
            return Response({"error": "Nội dung không được để trống"}, status=status.HTTP_400_BAD_REQUEST)

        session = None
        history_msgs = []
        if session_id:
            session = get_object_or_404(AIChatSession, id=session_id, user=request.user)
            history_msgs = AIChatMessage.objects.filter(session=session).order_by('id')[:10]
        
        contents_array = []
        last_role = None
        for msg in history_msgs:
            is_user = "USER" in str(msg.role).upper()
            current_role = "user" if is_user else "model"
            if current_role == last_role:
                continue
            contents_array.append({"role": current_role, "parts": [{"text": msg.content}]})
            last_role = current_role

        if contents_array and contents_array[-1]["role"] == "user":
            contents_array.pop()

        prompt_text = (
            f"Bạn là một gia sư tiếng Anh nhiệt tình. Hãy giải thích ngắn gọn, dễ hiểu.\n\n"
            f"Câu hỏi của tôi: {user_message}"
        )
        contents_array.append({"role": "user", "parts": [{"text": prompt_text}]})

        headers = {
            'Content-Type': 'application/json',
            'x-goog-api-key': settings.GEMINI_API_KEY
        }

        try:
            for attempt in range(self.MAX_RETRIES + 1):
                response = requests.post(
                    self.GEMINI_URL, headers=headers,
                    json={"contents": contents_array},
                    timeout=self.REQUEST_TIMEOUT,
                )
                if response.status_code != 503:
                    break
                if attempt < self.MAX_RETRIES:
                    time.sleep(self.RETRY_BACKOFF)

            if response.status_code == 429:
                return Response(
                    {"error": "Hệ thống AI đang bận (giới hạn 5 câu/phút). Vui lòng đợi 30 giây rồi thử lại!"},
                    status=status.HTTP_429_TOO_MANY_REQUESTS
                )

            if response.status_code == 503:
                return Response(
                    {"error": "Máy chủ Google AI đang quá tải do nhu cầu cao. Vui lòng thử lại sau vài phút!"},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE
                )

            if response.status_code != 200:
                logger.error("Google API error: %s", response.text)
                return Response(
                    {"error": "Lỗi từ máy chủ AI. Vui lòng thử lại sau."},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )

            data = response.json()
            ai_response = data['candidates'][0]['content']['parts'][0]['text']

        except requests.exceptions.Timeout:
            return Response(
                {"error": "Google AI phản hồi quá chậm. Vui lòng thử lại."},
                status=status.HTTP_504_GATEWAY_TIMEOUT
            )
        except Exception as e:
            logger.error("Server connect error: %s", str(e))
            return Response(
                {"error": "Lỗi kết nối mạng đến Google AI."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        if session is None:
            session = AIChatSession.objects.create(
                user=request.user,
                title=user_message[:50] + "..." if len(user_message) > 50 else user_message
            )

        AIChatMessage.objects.create(session=session, role=ChatRoleEnum.USER, content=user_message)
        AIChatMessage.objects.create(session=session, role=ChatRoleEnum.AI, content=ai_response)

        return Response({
            "session_id": session.id,
            "ai_response": ai_response
        }, status=status.HTTP_200_OK)


class ChatSessionListView(APIView):
    """Danh sách các phiên chat của user — dùng cho sidebar lịch sử."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        sessions = AIChatSession.objects.filter(user=request.user).order_by('-created_at')
        serializer = AIChatSessionListSerializer(sessions, many=True)
        return Response(serializer.data)


class ChatSessionDetailView(APIView):
    """Chi tiết 1 phiên chat (kèm toàn bộ tin nhắn) — để tiếp tục hội thoại. Xoá phiên."""
    permission_classes = [IsAuthenticated]

    def get(self, request, session_id):
        session = get_object_or_404(AIChatSession, id=session_id, user=request.user)
        serializer = AIChatSessionSerializer(session)
        return Response(serializer.data)

    def delete(self, request, session_id):
        session = get_object_or_404(AIChatSession, id=session_id, user=request.user)
        session.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


def handle_game_submission(request, level):
    score_earned = int(request.data.get('score_earned', 0))
    game_content_type = ContentType.objects.get_for_model(level.__class__)
    
    previous_max_score = GameHistory.objects.filter(
        user=request.user,
        content_type=game_content_type,
        object_id=level.id
    ).aggregate(max_score=Max('score_earned'))['max_score'] or 0

    if score_earned > previous_max_score:
        score_diff = score_earned - previous_max_score
        request.user.total_score += score_diff
        request.user.save()

    GameHistory.objects.create(
        user=request.user,
        content_type=game_content_type,
        object_id=level.id,
        score_earned=score_earned
    )

    level.play_count += 1
    level.save()

    return {
        "message": "Lưu kết quả thành công!",
        "score_earned": score_earned,
        "new_total_score": request.user.total_score
    }


def parse_game_request_data(request):
    if 'payload' in request.data:
        payload_dict = json.loads(request.data['payload'])
        game_data_array = payload_dict.get('game_data', [])
        
        for idx, item in enumerate(game_data_array):
            word_audio = request.FILES.get(f'word_audio_{idx}')
            if word_audio:
                res_word = cloudinary.uploader.upload(
                    word_audio, 
                    resource_type="auto", 
                    folder="elearning_audios/"
                )
                item['audio_url'] = res_word.get('secure_url')
            
            hint_audio = request.FILES.get(f'hint_audio_{idx}')
            if hint_audio:
                res_hint = cloudinary.uploader.upload(
                    hint_audio, 
                    resource_type="auto", 
                    folder="elearning_audios/"
                )
                item['hint_audio_url'] = res_hint.get('secure_url')
                
        payload_dict['game_data'] = game_data_array
        return payload_dict
    return request.data


class CommunityGameListCreateView(generics.ListCreateAPIView):
    serializer_class = CommunityGameLevelSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        user = self.request.user
        queryset = CommunityGameLevel.objects.filter(status=StatusEnum.APPROVED)

        game_content_type = ContentType.objects.get_for_model(CommunityGameLevel)
        liked_subquery = CommunityGameLevel.likes.through.objects.filter(
            communitygamelevel_id=OuterRef('pk'), user_id=user.id
        )
        played_subquery = GameHistory.objects.filter(
            content_type=game_content_type, object_id=OuterRef('pk'), user=user
        )

        queryset = queryset.annotate(
            is_liked=Exists(liked_subquery),
            is_played=Exists(played_subquery),
            likes_count=Count('likes', distinct=True)
        )

        search_query = self.request.query_params.get('search', '')
        game_type = self.request.query_params.get('game_type', 'ALL')
        difficulty = self.request.query_params.get('difficulty', 'ALL')
        played_only = self.request.query_params.get('played_only', 'false') == 'true'
        liked_only = self.request.query_params.get('liked_only', 'false') == 'true'

        if search_query: queryset = queryset.filter(name__icontains=search_query)
        if game_type != 'ALL': queryset = queryset.filter(game_type=game_type)
        if difficulty != 'ALL': queryset = queryset.filter(difficulty=difficulty)
        if played_only: queryset = queryset.filter(is_played=True)
        if liked_only: queryset = queryset.filter(is_liked=True)

        sort_by = self.request.query_params.get('sort_by', 'PLAY_COUNT')
        sort_order = self.request.query_params.get('sort_order', 'DESC')
        order_prefix = '-' if sort_order == 'DESC' else ''
        order_field = 'play_count' if sort_by == 'PLAY_COUNT' else 'likes_count'
        
        return queryset.order_by(f"{order_prefix}{order_field}", '-created_at')
    
    def create(self, request, *args, **kwargs):
        processed_data = parse_game_request_data(request)
        serializer = self.get_serializer(data=processed_data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        status_val = serializer.initial_data.get('status', 'PRIVATE')
        serializer.save(creator=self.request.user, status=status_val)


class CommunityGameDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CommunityGameLevelSerializer
    permission_classes = [IsAuthenticated]
    queryset = CommunityGameLevel.objects.all()
    
    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        processed_data = parse_game_request_data(request)
        serializer = self.get_serializer(instance, data=processed_data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        
        return Response(serializer.data)

    def perform_update(self, serializer):
        if self.get_object().creator != self.request.user:
            raise PermissionDenied("Bạn không có quyền sửa màn chơi này.")
        serializer.save()

    def perform_destroy(self, instance):
        if instance.creator != self.request.user and self.request.user.role not in ['MODERATOR', 'ADMIN']:
            raise PermissionDenied("Bạn không có quyền xóa màn chơi của người khác.")
        instance.delete()



class MyGameListView(generics.ListAPIView):
    serializer_class = CommunityGameLevelSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        user = self.request.user
        queryset = CommunityGameLevel.objects.filter(creator=user).annotate(
            likes_count=Count('likes', distinct=True)
        )

        search_query = self.request.query_params.get('search', '')
        game_type = self.request.query_params.get('game_type', 'ALL')
        difficulty = self.request.query_params.get('difficulty', 'ALL')

        if search_query: queryset = queryset.filter(name__icontains=search_query)
        if game_type != 'ALL': queryset = queryset.filter(game_type=game_type)
        if difficulty != 'ALL': queryset = queryset.filter(difficulty=difficulty)

        sort_by = self.request.query_params.get('sort_by', 'PLAY_COUNT')
        sort_order = self.request.query_params.get('sort_order', 'DESC')
        order_prefix = '-' if sort_order == 'DESC' else ''
        order_field = 'play_count' if sort_by == 'PLAY_COUNT' else 'likes_count'
        
        return queryset.order_by(f"{order_prefix}{order_field}", '-created_at')


class ToggleCommunityGameLikeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, level_id):
        level = get_object_or_404(CommunityGameLevel, id=level_id)
        if level.likes.filter(id=request.user.id).exists():
            level.likes.remove(request.user)
            is_liked = False
        else:
            level.likes.add(request.user)
            is_liked = True
        return Response({"is_liked": is_liked}, status=status.HTTP_200_OK)


class SubmitCommunityGameView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, level_id):
        level = get_object_or_404(CommunityGameLevel, id=level_id)
        result = handle_game_submission(request, level) 
        return Response(result, status=status.HTTP_200_OK)


class PendingGamesListView(ModeratorPermissionMixin, generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, *args, **kwargs):
        self.check_moderator_permission(request)
        
        pending_games = CommunityGameLevel.objects.filter(status='PENDING').order_by('-created_at')
        data = [{
            'id': game.id,
            'name': game.name,
            'game_type': game.game_type,
            'difficulty': game.difficulty,
            'creator': game.creator.username,
            'base_score': game.base_score,
            'game_data': game.game_data
        } for game in pending_games]
        return Response(data, status=status.HTTP_200_OK)


class ReviewGameActionView(ModeratorPermissionMixin, APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, game_id):
        self.check_moderator_permission(request)
        action = request.data.get('action') 
        game = get_object_or_404(CommunityGameLevel, id=game_id)
        
        if action == 'APPROVE':
            game.status = StatusEnum.APPROVED
            message = "Đã phê duyệt màn chơi."
        elif action == 'REJECT':
            game.status = StatusEnum.REJECTED 
            message = "Đã từ chối màn chơi."
        else:
            return Response({'error': 'Hành động không hợp lệ'}, status=status.HTTP_400_BAD_REQUEST)
            
        game.save()
        return Response({'message': message}, status=status.HTTP_200_OK)


class SystemGameListCreateView(generics.ListCreateAPIView):
    serializer_class = SystemGameLevelSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        game_type = self.kwargs.get('game_type')
        
        queryset = SystemGameLevel.objects.filter(game_type=game_type).order_by('sequence_number')
        
        game_content_type = ContentType.objects.get_for_model(SystemGameLevel)
        played_subquery = GameHistory.objects.filter(
            content_type=game_content_type, object_id=OuterRef('pk'), user=user
        )
        
        return queryset.annotate(is_played=Exists(played_subquery))

    
    def create(self, request, *args, **kwargs):
        processed_data = parse_game_request_data(request)
        serializer = self.get_serializer(data=processed_data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        if self.request.user.role not in ['MODERATOR', 'ADMIN']:
            raise PermissionDenied("Chỉ Kiểm duyệt viên hoặc Admin mới được tạo màn chơi hệ thống.")
        
        game_type = self.kwargs.get('game_type') or serializer.initial_data.get('game_type')
        max_seq = SystemGameLevel.objects.filter(game_type=game_type).aggregate(Max('sequence_number'))['sequence_number__max'] or 0
        
        serializer.save(creator=self.request.user, sequence_number=max_seq + 1, game_type=game_type)



class SystemGameDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SystemGameLevelSerializer
    permission_classes = [IsAuthenticated]
    queryset = SystemGameLevel.objects.all()
    
    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        
        processed_data = parse_game_request_data(request)
        
        serializer = self.get_serializer(instance, data=processed_data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        
        return Response(serializer.data)

    def perform_update(self, serializer):
        if self.request.user.role not in ['MODERATOR', 'ADMIN']:
            raise PermissionDenied("Chỉ Kiểm duyệt viên mới được sửa màn chơi hệ thống.")
        serializer.save()

    def perform_destroy(self, instance):
        if self.request.user.role not in ['MODERATOR', 'ADMIN']:
            raise PermissionDenied("Chỉ Kiểm duyệt viên mới được xóa màn chơi hệ thống.")
        instance.delete()


class SubmitSystemGameView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, level_id):
        level = get_object_or_404(SystemGameLevel, id=level_id)
        result = handle_game_submission(request, level) 
        return Response(result, status=status.HTTP_200_OK)


class ForumPostListCreateView(generics.ListCreateAPIView):
    serializer_class = ForumPostSerializer
    permission_classes = [IsAuthenticated]
    queryset = ForumPost.objects.all().order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)


class ForumPostDetailView(generics.RetrieveDestroyAPIView):
    queryset = ForumPost.objects.all()
    serializer_class = ForumPostDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'
    lookup_url_kwarg = 'post_id'

    def perform_destroy(self, instance):
        if instance.author != self.request.user and self.request.user.role not in ['MODERATOR', 'ADMIN']:
            raise PermissionDenied("Bạn không có quyền xóa bài đăng này.")
        instance.delete()


class ToggleForumPostLikeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id):
        post = get_object_or_404(ForumPost, id=post_id)
        if post.likes.filter(id=request.user.id).exists():
            post.likes.remove(request.user)
            is_liked = False
        else:
            post.likes.add(request.user)
            is_liked = True
        
        return Response({
            'is_liked': is_liked, 
            'likes_count': post.likes.count()
        }, status=status.HTTP_200_OK)


class AddForumCommentView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, post_id):
        post_obj = get_object_or_404(ForumPost, id=post_id)
        content = request.data.get('content', '').strip()
        
        if not content:
            return Response({"error": "Nội dung bình luận không được rỗng"}, status=status.HTTP_400_BAD_REQUEST)
        
        comment = ForumComment.objects.create(
            post=post_obj,
            author=request.user,
            content=content
        )
        serializer = ForumCommentSerializer(comment, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class ForumCommentDetailView(generics.DestroyAPIView):
    queryset = ForumComment.objects.all()
    permission_classes = [IsAuthenticated]

    def perform_destroy(self, instance):
        if instance.author != self.request.user and self.request.user.role not in ['MODERATOR', 'ADMIN']:
            raise PermissionDenied("Bạn không có quyền xóa bình luận này.")
        instance.delete()