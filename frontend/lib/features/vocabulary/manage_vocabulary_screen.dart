import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api_endpoints.dart';
import '../../core/constants.dart';
import '../../core/config.dart';
import 'create_deck_screen.dart';
import 'edit_deck_screen.dart';

class ManageVocabularyScreen extends StatefulWidget {
  const ManageVocabularyScreen({super.key});

  @override
  State<ManageVocabularyScreen> createState() => _ManageVocabularyScreenState();
}

class _ManageVocabularyScreenState extends State<ManageVocabularyScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();

  String _selectedDifficulty = 'ALL';
  List<dynamic> _decks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchManagedDecks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchManagedDecks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? token = await _storage.read(key: 'access_token');

      final Map<String, String> queryParams = {
        'search': _searchController.text,
      };

      if (_selectedDifficulty != 'ALL') {
        queryParams['difficulty'] = _selectedDifficulty;
      }

      final uri = Uri.parse(
        ApiEndpoints.manageDecks(),
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _decks = data['results'] ?? data;
          _isLoading = false;
        });
      } else {
        _showErrorSnackBar(
          'Lỗi (${response.statusCode}): Không thể tải danh sách',
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi kết nối mạng: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDeck(int deckId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text(
              'Bạn có chắc muốn xóa bộ từ vựng này không? Mọi dữ liệu học của người dùng sẽ bị ảnh hưởng và không thể khôi phục.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Xóa',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http
          .delete(
            Uri.parse(ApiEndpoints.manageDeckDetail(deckId)),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
      if (!mounted) return;
      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bộ từ vựng thành công!')),
        );
        _fetchManagedDecks();
      } else {
        _showErrorSnackBar('Lỗi khi xóa bộ từ vựng (${response.statusCode})');
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi kết nối mạng khi xóa: $e');
    }
  }

  void _createNewDeck() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateDeckScreen()),
    );

    if (result == true) {
      _fetchManagedDecks();
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Quản lý từ vựng',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewDeck,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tạo bộ mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _fetchManagedDecks(),
                    decoration: InputDecoration(
                      hintText: 'Tìm bộ từ vựng...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDifficulty,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.filter_list_rounded,
                          color: AppColors.primary,
                        ),
                        style: AppTextStyles.body,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Tất cả')),
                          DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Vừa')),
                          DropdownMenuItem(value: 'HARD', child: Text('Khó')),
                        ],
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedDifficulty = newValue;
                            });
                            _fetchManagedDecks();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _decks.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có bộ từ vựng nào.\nHãy thử đổi bộ lọc hoặc tạo mới.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _decks.length,
                    itemBuilder: (context, index) {
                      final deck = _decks[index];
                      return _buildDeckManagementCard(deck);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckManagementCard(Map<String, dynamic> deck) {
    Color difficultyColor = AppColors.primary;
    if (deck['difficulty'] == 'HARD') difficultyColor = AppColors.error;
    if (deck['difficulty'] == 'EASY') difficultyColor = AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.cardStyle.copyWith(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  deck['title'] ?? 'Chưa có tên',
                  style: AppTextStyles.h3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: difficultyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deck['difficulty'] ?? 'N/A',
                  style: TextStyle(
                    color: difficultyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                Icons.library_books_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Số lượng: ${deck['words_count'] ?? 0} từ',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.people_alt_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Người học: ${deck['learners_count'] ?? 0}',
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _deleteDeck(deck['id']),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                label: const Text(
                  'Xóa',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(width: 8),

              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditDeckScreen(deckData: deck),
                    ),
                  );

                  if (result == true) {
                    _fetchManagedDecks();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                label: const Text(
                  'Chi tiết',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
