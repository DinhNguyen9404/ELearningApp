import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'elearningapp.settings') 
django.setup()
from django.contrib.auth.hashers import make_password
from django.contrib.contenttypes.models import ContentType
from django.core.management import call_command

from elearningapp_api.models import (
    User,
    Vocabulary,
    FlashcardDeck,
    UserActiveDeck,
    SystemGameLevel,
    CommunityGameLevel,
    GameHistory,
    AIChatSession,
    AIChatMessage,
    ForumPost,
    ForumComment,
    RoleEnum,
    DifficultyEnum,
    GameEnum,
    StatusEnum,
    ChatRoleEnum,
)


# ==========================================
# 1. NGƯỜI DÙNG & PHÂN QUYỀN
# ==========================================
def seed_users():
    print("⏳ Đang tạo tài khoản mẫu...")

    users_data = [
        {"username": "admin_user", "email": "admin@test.com", "role": RoleEnum.ADMIN, "total_score": 0},
        {"username": "mod_user", "email": "mod@test.com", "role": RoleEnum.MODERATOR, "total_score": 150},
        {"username": "mod_user2", "email": "mod2@test.com", "role": RoleEnum.MODERATOR, "total_score": 90},
        {"username": "player_1", "email": "player1@test.com", "role": RoleEnum.USER, "total_score": 320},
        {"username": "player_2", "email": "player2@test.com", "role": RoleEnum.USER, "total_score": 180},
        {"username": "player_3", "email": "player3@test.com", "role": RoleEnum.USER, "total_score": 60},
        {"username": "player_4", "email": "player4@test.com", "role": RoleEnum.USER, "total_score": 410},
    ]

    users = {}
    for data in users_data:
        user, _ = User.objects.get_or_create(
            username=data["username"],
            defaults={
                "email": data["email"],
                "password": make_password("123456"),
                "role": data["role"],
                "total_score": data["total_score"],
                "avatar_url": f"https://example.com/avatars/{data['username']}.png",
            },
        )
        users[data["username"]] = user

    return users


# ==========================================
# 2. TỪ VỰNG & FLASHCARD
# ==========================================
def seed_vocabularies():
    print("⏳ Đang tạo từ vựng...")

    # (word, meaning, part_of_speech, pronunciation, description, examples)
    vocab_data = [
        ("Hello", "Xin chào", "Interjection", "/həˈloʊ/", "A word used as a greeting", ["Hello, how are you?"]),
        ("Apple", "Quả táo", "Noun", "/ˈæpəl/", "A round fruit with red or green skin", ["I eat an apple every day."]),
        ("Banana", "Quả chuối", "Noun", "/bəˈnænə/", "A long curved fruit with a yellow skin", ["She sliced a banana into her cereal."]),
        ("Computer", "Máy tính", "Noun", "/kəmˈpjuːtər/", "An electronic device for processing data", ["He works on his computer all day."]),
        ("Beautiful", "Xinh đẹp", "Adjective", "/ˈbjuːtɪfəl/", "Pleasing to look at", ["The sunset was beautiful."]),
        ("Run", "Chạy", "Verb", "/rʌn/", "To move fast using your legs", ["She likes to run every morning."]),
        ("Happy", "Hạnh phúc", "Adjective", "/ˈhæpi/", "Feeling or showing pleasure", ["They looked happy at the party."]),
        ("Dog", "Con chó", "Noun", "/dɔːg/", "A common domesticated animal", ["My dog loves to play fetch."]),
        ("Cat", "Con mèo", "Noun", "/kæt/", "A small domesticated carnivorous mammal", ["The cat is sleeping on the sofa."]),
        ("Book", "Quyển sách", "Noun", "/bʊk/", "A written or printed work", ["I read a book before bed."]),
        ("Water", "Nước", "Noun", "/ˈwɔːtər/", "A clear liquid essential for life", ["Please drink more water."]),
        ("Friend", "Bạn bè", "Noun", "/frɛnd/", "A person you like and trust", ["He is my best friend."]),
        ("School", "Trường học", "Noun", "/skuːl/", "A place for teaching and learning", ["Children go to school every day."]),
        ("Music", "Âm nhạc", "Noun", "/ˈmjuːzɪk/", "Sounds arranged in a pleasing way", ["She enjoys listening to music."]),
        ("Travel", "Du lịch", "Verb", "/ˈtrævəl/", "To go from one place to another", ["They love to travel abroad."]),
        ("Weather", "Thời tiết", "Noun", "/ˈwɛðər/", "The state of the atmosphere at a place", ["The weather is nice today."]),
        ("Family", "Gia đình", "Noun", "/ˈfæməli/", "A group of related people", ["We had a family dinner last night."]),
        ("Work", "Công việc", "Noun", "/wɜːrk/", "Activity involving effort to achieve a result", ["He goes to work by bus."]),
        ("Study", "Học tập", "Verb", "/ˈstʌdi/", "To learn about a subject", ["I study English every evening."]),
        ("Language", "Ngôn ngữ", "Noun", "/ˈlæŋgwɪdʒ/", "A system of communication", ["English is a widely spoken language."]),
    ]

    vocabularies = {}
    for word, meaning, pos, pronunciation, description, examples in vocab_data:
        vocab, _ = Vocabulary.objects.get_or_create(
            word=word,
            defaults={
                "meaning": meaning,
                "part_of_speech": pos,
                "pronunciation": pronunciation,
                "description": description,
                "examples": examples,
                "image_url": f"https://example.com/images/{word.lower()}.png",
                "audio_url": f"https://example.com/audio/{word.lower()}.mp3",
            },
        )
        vocabularies[word] = vocab

    return vocabularies


def seed_decks(users, vocabularies):
    print("⏳ Đang tạo bộ flashcard...")

    # Theo ràng buộc của model, chỉ MODERATOR mới được tạo bộ flashcard
    deck_specs = [
        {
            "title": "Tiếng Anh Giao Tiếp Cơ Bản",
            "description": "Bộ từ vựng cho người mới bắt đầu",
            "creator": users["mod_user"],
            "difficulty": DifficultyEnum.EASY,
            "learner_count": 128,
            "words": ["Hello", "Friend", "Happy", "Family"],
        },
        {
            "title": "Từ Vựng Về Động Vật",
            "description": "Các từ vựng thông dụng về động vật nuôi",
            "creator": users["mod_user2"],
            "difficulty": DifficultyEnum.EASY,
            "learner_count": 76,
            "words": ["Dog", "Cat"],
        },
        {
            "title": "Từ Vựng Học Thuật",
            "description": "Từ vựng nâng cao dùng trong học thuật",
            "creator": users["mod_user"],
            "difficulty": DifficultyEnum.HARD,
            "learner_count": 34,
            "words": ["Language", "Study", "Book"],
        },
        {
            "title": "Từ Vựng Du Lịch",
            "description": "Từ vựng cần thiết khi đi du lịch",
            "creator": users["mod_user2"],
            "difficulty": DifficultyEnum.MEDIUM,
            "learner_count": 55,
            "words": ["Travel", "Weather", "Water"],
        },
        {
            "title": "Từ Vựng Công Nghệ",
            "description": "Bộ từ vựng về công nghệ cơ bản",
            "creator": users["mod_user"],
            "difficulty": DifficultyEnum.MEDIUM,
            "learner_count": 12,
            "words": ["Computer", "Work"],
        },
    ]

    decks = {}
    for spec in deck_specs:
        deck, _ = FlashcardDeck.objects.get_or_create(
            title=spec["title"],
            defaults={
                "description": spec["description"],
                "creator": spec["creator"],
                "difficulty": spec["difficulty"],
                "learner_count": spec["learner_count"],
            },
        )
        deck.vocabularies.add(*[vocabularies[w] for w in spec["words"]])
        decks[spec["title"]] = deck

    return decks


def seed_user_activity(users, decks):
    print("⏳ Đang tạo hoạt động học tập của người dùng...")

    active_links = [
        ("player_1", "Tiếng Anh Giao Tiếp Cơ Bản", True),
        ("player_1", "Từ Vựng Du Lịch", True),
        ("player_2", "Từ Vựng Về Động Vật", True),
        ("player_3", "Tiếng Anh Giao Tiếp Cơ Bản", True),
        ("player_4", "Từ Vựng Học Thuật", False),
        ("player_4", "Từ Vựng Công Nghệ", True),
    ]
    for username, deck_title, is_active in active_links:
        UserActiveDeck.objects.get_or_create(
            user=users[username],
            deck=decks[deck_title],
            defaults={"is_active": is_active},
        )


# ==========================================
# 3. MINIGAME (HỆ THỐNG & CỘNG ĐỒNG)
# ==========================================
def seed_system_levels(users):
    print("⏳ Đang tạo dữ liệu màn chơi hệ thống đa dạng...")

    specs = [
        {
            "name": "Tiếng Anh giao tiếp cơ bản",
            "game_type": GameEnum.QUIZ,
            "difficulty": DifficultyEnum.EASY,
            "sequence_number": 1,
            "base_score": 100,
            "time_limit": 60,
            "play_count": 245,
            "creator": "mod_user",
            "game_data": [
                {
                    "question": "How do you say 'Xin chào'?",
                    "options": ["Hello", "Goodbye", "Thanks", "Sorry"],
                    "correct_index": 0,
                },
                {
                    "question": "What is the opposite of 'Hot'?",
                    "options": ["Warm", "Cold", "Boiling", "Freezing"],
                    "correct_index": 1,
                },
            ],
        },
        {
            "name": "Thử thách Ngữ pháp: Thì hiện tại",
            "game_type": GameEnum.QUIZ,
            "difficulty": DifficultyEnum.MEDIUM,
            "sequence_number": 2,
            "base_score": 120,
            "time_limit": 90,
            "play_count": 130,
            "creator": "mod_user",
            "game_data": [
                {
                    "question": "What is the plural of 'child'?",
                    "options": ["Childs", "Children", "Childes", "Child"],
                    "correct_index": 1,
                },
                {
                    "question": "Choose the correct word: She ___ to school every day.",
                    "options": ["go", "goes", "going", "gone"],
                    "correct_index": 1,
                },
                {
                    "question": "They ___ playing football right now.",
                    "options": ["is", "am", "are", "do"],
                    "correct_index": 2,
                }
            ],
        },
        {
            "name": "Thành ngữ Tiếng Anh (Idioms)",
            "game_type": GameEnum.QUIZ,
            "difficulty": DifficultyEnum.HARD,
            "sequence_number": 3,
            "base_score": 200,
            "time_limit": 120,
            "play_count": 50,
            "creator": "mod_user2",
            "game_data": [
                {
                    "question": "What does 'Piece of cake' mean?",
                    "options": ["A delicious dessert", "Very easy", "A small part", "Very difficult"],
                    "correct_index": 1,
                },
                {
                    "question": "If it's 'raining cats and dogs', it is...",
                    "options": ["Raining heavily", "Raining lightly", "Snowing", "Sunny"],
                    "correct_index": 0,
                },
            ],
        },

        {
            "name": "Đoán từ: Động vật quen thuộc",
            "game_type": GameEnum.GUESS,
            "difficulty": DifficultyEnum.EASY,
            "sequence_number": 4,
            "base_score": 150,
            "time_limit": 45,
            "play_count": 88,
            "creator": "mod_user2",
            "game_data": {
                "target_word": "Dog",
                "hints": ["It's a pet", "It barks", "Man's best friend"],
                "deduct_per_hint": 15,
            },
        },
        {
            "name": "Đoán từ: Nghề nghiệp",
            "game_type": GameEnum.GUESS,
            "difficulty": DifficultyEnum.MEDIUM,
            "sequence_number": 5,
            "base_score": 180,
            "time_limit": 60,
            "play_count": 112,
            "creator": "mod_user",
            "game_data": {
                "target_word": "Doctor",
                "hints": ["Works in a hospital", "Wears a white coat", "Helps sick people"],
                "deduct_per_hint": 20,
            },
        },
        {
            "name": "Đoán từ: Hiện tượng thiên nhiên",
            "game_type": GameEnum.GUESS,
            "difficulty": DifficultyEnum.HARD,
            "sequence_number": 6,
            "base_score": 250,
            "time_limit": 90,
            "play_count": 24,
            "creator": "mod_user2",
            "game_data": {
                "target_word": "Earthquake",
                "hints": ["A natural disaster", "The ground shakes", "Measured on the Richter scale"],
                "deduct_per_hint": 30,
            },
        },

        {
            "name": "Sắp xếp câu: Cấu trúc cơ bản",
            "game_type": GameEnum.SORT,
            "difficulty": DifficultyEnum.EASY,
            "sequence_number": 7,
            "base_score": 100,
            "time_limit": 60,
            "play_count": 200,
            "creator": "mod_user",
            "game_data": {
                "scrambled": ["is", "beautiful", "the", "sunset"],
                "correct_order": ["the", "sunset", "is", "beautiful"],
            },
        },
        {
            "name": "Sắp xếp câu: Câu điều kiện",
            "game_type": GameEnum.SORT,
            "difficulty": DifficultyEnum.HARD,
            "sequence_number": 8,
            "base_score": 200,
            "time_limit": 90,
            "play_count": 42,
            "creator": "mod_user2",
            "game_data": {
                "scrambled": ["exam", "will", "you", "pass", "if", "hard", "the", "study", "you"],
                "correct_order": ["if", "you", "study", "hard", "you", "will", "pass", "the", "exam"],
            },
        },

        {
            "name": "Luyện Đánh vần: Màu sắc & Hình khối",
            "game_type": GameEnum.SPELLING,
            "difficulty": DifficultyEnum.EASY,
            "sequence_number": 9,
            "base_score": 120,
            "time_limit": 60,
            "play_count": 310,
            "creator": "mod_user",
            "game_data": [
                {"word": "Yellow", "meaning": "Màu vàng", "audio_url": "https://dummy-audio.com/yellow.mp3"},
                {"word": "Circle", "meaning": "Hình tròn", "audio_url": "https://dummy-audio.com/circle.mp3"},
                {"word": "Purple", "meaning": "Màu tím", "audio_url": "https://dummy-audio.com/purple.mp3"}
            ],
        },
        {
            "name": "Luyện Đánh vần: Những từ dễ sai chính tả",
            "game_type": GameEnum.SPELLING,
            "difficulty": DifficultyEnum.MEDIUM,
            "sequence_number": 10,
            "base_score": 180,
            "time_limit": 120,
            "play_count": 145,
            "creator": "mod_user2",
            "game_data": [
                {"word": "Necessary", "meaning": "Cần thiết", "audio_url": ""},
                {"word": "Receive", "meaning": "Nhận được", "audio_url": ""},
                {"word": "Recommend", "meaning": "Đề xuất, giới thiệu", "audio_url": ""}
            ],
        },
        {
            "name": "Luyện Đánh vần: Từ vựng IELTS Cao cấp",
            "game_type": GameEnum.SPELLING,
            "difficulty": DifficultyEnum.HARD,
            "sequence_number": 11,
            "base_score": 300,
            "time_limit": 150,
            "play_count": 67,
            "creator": "mod_user",
            "game_data": [
                {"word": "Entrepreneur", "meaning": "Doanh nhân", "audio_url": ""},
                {"word": "Phenomenon", "meaning": "Hiện tượng", "audio_url": ""},
                {"word": "Mischievous", "meaning": "Nghịch ngợm, láu lỉnh", "audio_url": ""}
            ],
        },
    ]

    levels = {}
    for spec in specs:
        level, _ = SystemGameLevel.objects.get_or_create(
            name=spec["name"],
            defaults={
                "creator": users[spec["creator"]],
                "game_type": spec["game_type"],
                "difficulty": spec["difficulty"],
                "sequence_number": spec["sequence_number"],
                "base_score": spec["base_score"],
                "time_limit": spec["time_limit"],
                "play_count": spec["play_count"],
                "game_data": spec["game_data"],
            },
        )
        levels[spec["name"]] = level

    return levels


def seed_community_levels(users):
    print("⏳ Đang tạo dữ liệu màn chơi cộng đồng đa dạng...")

    specs = [
        {
            "name": "Thử thách đoán từ trái cây (Đã duyệt)",
            "creator": "player_1",
            "game_type": GameEnum.GUESS,
            "difficulty": DifficultyEnum.EASY,
            "status": StatusEnum.APPROVED,
            "base_score": 200,
            "play_count": 57,
            "game_data": {
                "target_word": "Apple",
                "hints": ["It's a fruit", "It can be red or green", "Keeps the doctor away"],
                "deduct_per_hint": 10,
            },
            "liked_by": ["player_2", "player_3", "player_4"],
        },
        {
            "name": "Đoán từ vựng thời tiết (Bị từ chối)",
            "creator": "player_3",
            "game_type": GameEnum.GUESS,
            "difficulty": DifficultyEnum.HARD,
            "status": StatusEnum.REJECTED,
            "base_score": 100,
            "play_count": 1,
            "game_data": {
                "target_word": "Weather",
                "hints": ["It changes every day"],
                "deduct_per_hint": 20,
            },
            "liked_by": [],
        },

        {
            "name": "Trắc nghiệm từ vựng công nghệ (Đang chờ)",
            "creator": "player_2",
            "game_type": GameEnum.QUIZ,
            "difficulty": DifficultyEnum.MEDIUM,
            "status": StatusEnum.PENDING,
            "base_score": 100,
            "play_count": 0,
            "game_data": [
                {
                    "question": "What do you use to browse the internet?",
                    "options": ["Computer", "Banana", "Dog", "Weather"],
                    "correct_index": 0,
                },
                {
                    "question": "Which of these is an operating system?",
                    "options": ["Python", "Linux", "HTML", "C++"],
                    "correct_index": 1,
                }
            ],
            "liked_by": [],
        },
        {
            "name": "Câu đố vui bằng Tiếng Anh",
            "creator": "player_4",
            "game_type": GameEnum.QUIZ,
            "difficulty": DifficultyEnum.MEDIUM,
            "status": StatusEnum.APPROVED,
            "base_score": 150,
            "play_count": 88,
            "game_data": [
                {
                    "question": "I have keys but no doors. I have space but no room. What am I?",
                    "options": ["A map", "A keyboard", "A house", "A car"],
                    "correct_index": 1,
                },
            ],
            "liked_by": ["player_1", "player_2"],
        },

        {
            "name": "Sắp xếp từ về gia đình (Riêng tư)",
            "creator": "player_4",
            "game_type": GameEnum.SORT,
            "difficulty": DifficultyEnum.EASY,
            "status": StatusEnum.PRIVATE,
            "base_score": 90,
            "play_count": 3,
            "game_data": {
                "scrambled": ["family", "my", "loves", "me"],
                "correct_order": ["my", "family", "loves", "me"],
            },
            "liked_by": [],
        },

        {
            "name": "Thử tài đánh vần: Đồ vật trong nhà",
            "creator": "player_1",
            "game_type": GameEnum.SPELLING,
            "difficulty": DifficultyEnum.MEDIUM,
            "status": StatusEnum.APPROVED,
            "base_score": 140,
            "play_count": 120,
            "game_data": [
                {"word": "Refrigerator", "meaning": "Tủ lạnh", "audio_url": ""},
                {"word": "Microwave", "meaning": "Lò vi sóng", "audio_url": ""},
                {"word": "Television", "meaning": "Ti vi", "audio_url": ""}
            ],
            "liked_by": ["player_2", "player_3", "player_4"],
        },
        {
            "name": "Đánh vần: Các hành tinh (Chờ duyệt)",
            "creator": "player_2",
            "game_type": GameEnum.SPELLING,
            "difficulty": DifficultyEnum.HARD,
            "status": StatusEnum.PENDING,
            "base_score": 220,
            "play_count": 0,
            "game_data": [
                {"word": "Jupiter", "meaning": "Sao Mộc", "audio_url": ""},
                {"word": "Saturn", "meaning": "Sao Thổ", "audio_url": ""}
            ],
            "liked_by": [],
        }
    ]

    levels = {}
    for spec in specs:
        level, _ = CommunityGameLevel.objects.get_or_create(
            name=spec["name"],
            defaults={
                "creator": users[spec["creator"]],
                "game_type": spec["game_type"],
                "difficulty": spec["difficulty"],
                "status": spec["status"],
                "base_score": spec["base_score"],
                "play_count": spec["play_count"],
                "game_data": spec["game_data"],
            },
        )
        if spec["liked_by"]:
            level.likes.add(*[users[u] for u in spec["liked_by"]])
        levels[spec["name"]] = level

    return levels


def seed_game_history(users, system_levels, community_levels):
    print("⏳ Đang tạo lịch sử chơi game...")

    system_ct = ContentType.objects.get_for_model(SystemGameLevel)
    community_ct = ContentType.objects.get_for_model(CommunityGameLevel)

    history_specs = [
        ("player_1", system_ct, system_levels["Tiếng Anh giao tiếp cơ bản"], 100),
        ("player_1", community_ct, community_levels["Thử thách đoán từ trái cây (Đã duyệt)"], 180),
        ("player_2", system_ct, system_levels["Đoán từ: Động vật quen thuộc"], 135),
        ("player_2", system_ct, system_levels["Thử thách Ngữ pháp: Thì hiện tại"], 120),
        ("player_3", system_ct, system_levels["Tiếng Anh giao tiếp cơ bản"], 80),
        ("player_4", community_ct, community_levels["Thử thách đoán từ trái cây (Đã duyệt)"], 200),
        ("player_4", system_ct, system_levels["Sắp xếp câu: Cấu trúc cơ bản"], 130),
        ("player_1", system_ct, system_levels["Luyện Đánh vần: Màu sắc & Hình khối"], 120),
        ("player_2", community_ct, community_levels["Thử tài đánh vần: Đồ vật trong nhà"], 140),
        ("player_3", system_ct, system_levels["Luyện Đánh vần: Từ vựng IELTS Cao cấp"], 280),
    ]

    for username, content_type, level_obj, score in history_specs:
        GameHistory.objects.get_or_create(
            user=users[username],
            content_type=content_type,
            object_id=level_obj.id,
            defaults={"score_earned": score},
        )


# ==========================================
# 4. HỎI ĐÁP AI
# ==========================================
def seed_ai_chat(users):
    print("⏳ Đang tạo phiên hỏi đáp AI...")

    session1, _ = AIChatSession.objects.get_or_create(
        user=users["player_1"],
        title="Hỏi về cách phát âm",
        defaults={},
    )
    messages1 = [
        (ChatRoleEnum.USER, "Làm sao để phát âm từ 'beautiful' cho đúng?"),
        (ChatRoleEnum.AI, "Từ 'beautiful' được phát âm là /ˈbjuːtɪfəl/, trọng âm rơi vào âm tiết đầu tiên."),
        (ChatRoleEnum.USER, "Cảm ơn bạn, cho mình thêm một ví dụ được không?"),
        (ChatRoleEnum.AI, "Ví dụ: 'The garden looks beautiful in spring.'"),
    ]
    for role, content in messages1:
        AIChatMessage.objects.get_or_create(
            session=session1,
            role=role,
            content=content,
        )

    session2, _ = AIChatSession.objects.get_or_create(
        user=users["player_4"],
        title="Giải thích ngữ pháp thì hiện tại đơn",
        defaults={},
    )
    messages2 = [
        (ChatRoleEnum.USER, "Thì hiện tại đơn dùng khi nào?"),
        (ChatRoleEnum.AI, "Thì hiện tại đơn dùng để diễn tả thói quen, sự thật hiển nhiên hoặc lịch trình cố định."),
        (ChatRoleEnum.USER, "Cho mình một câu ví dụ về thói quen nhé."),
        (ChatRoleEnum.AI, "Ví dụ: 'She studies English every evening.'"),
    ]
    for role, content in messages2:
        AIChatMessage.objects.get_or_create(
            session=session2,
            role=role,
            content=content,
        )


# ==========================================
# 5. DIỄN ĐÀN
# ==========================================
def seed_forum(users):
    print("⏳ Đang tạo bài đăng diễn đàn...")

    post_specs = [
        {
            "title": "Làm sao để nhớ từ vựng lâu hơn?",
            "author": "player_1",
            "content": "Mọi người có bí quyết gì không chia sẻ cho mình với ạ!",
            "liked_by": ["player_2", "player_3"],
            "comments": [
                ("player_2", "Mình hay dùng flashcard và ôn lại mỗi ngày."),
                ("player_4", "Bạn nên kết hợp nghe và nói để nhớ lâu hơn."),
            ],
        },
        {
            "title": "Chia sẻ kinh nghiệm luyện nghe tiếng Anh",
            "author": "player_4",
            "content": "Mình đã cải thiện kỹ năng nghe nhờ nghe podcast mỗi ngày, mọi người thử xem sao.",
            "liked_by": ["player_1"],
            "comments": [
                ("player_1", "Bạn có thể gợi ý podcast nào phù hợp cho người mới không?"),
                ("player_3", "Cảm ơn bạn, mình sẽ thử áp dụng!"),
            ],
        },
        {
            "title": "Minigame đoán từ trái cây khó quá!",
            "author": "player_2",
            "content": "Ai chơi thử màn 'Thử thách đoán từ trái cây' chưa, mình bị trừ hết điểm luôn.",
            "liked_by": [],
            "comments": [
                ("player_1", "Mình cũng vậy, phải dùng hết gợi ý mới đoán ra."),
            ],
        },
    ]

    for spec in post_specs:
        post, _ = ForumPost.objects.get_or_create(
            title=spec["title"],
            defaults={
                "author": users[spec["author"]],
                "content": spec["content"],
            },
        )
        if spec["liked_by"]:
            post.likes.add(*[users[u] for u in spec["liked_by"]])
        for commenter, comment_content in spec["comments"]:
            ForumComment.objects.get_or_create(
                post=post,
                author=users[commenter],
                content=comment_content,
            )


# ==========================================
# CHẠY TOÀN BỘ SEED
# ==========================================
def run_seed():
    users = seed_users()
    vocabularies = seed_vocabularies()
    decks = seed_decks(users, vocabularies)
    seed_user_activity(users, decks)

    system_levels = seed_system_levels(users)
    community_levels = seed_community_levels(users)
    seed_game_history(users, system_levels, community_levels)

    seed_ai_chat(users)
    seed_forum(users)

    print("✅ HOÀN TẤT: Dữ liệu mẫu đầy đủ đã được nạp thành công vào Database!")


if __name__ == "__main__":
    print("Đang chạy Migrate để tạo lại các bảng (nếu chưa có)...")
    call_command('migrate', interactive=False)
    
    print("Đang làm sạch dữ liệu cũ (an toàn cho Cloud)...")
    # Lệnh flush sẽ xóa sạch dữ liệu trong các bảng mà không xóa Database
    call_command('flush', interactive=False)
    
    print("Bắt đầu nạp dữ liệu...")
    run_seed()