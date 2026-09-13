import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import 'add_vocabulary_screen.dart';

class EditDeckScreen extends StatefulWidget {
  final Map<String, dynamic> deckData;

  const EditDeckScreen({super.key, required this.deckData});

  @override
  State<EditDeckScreen> createState() => _EditDeckScreenState();
}

class _EditDeckScreenState extends State<EditDeckScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedDifficulty;

  List<dynamic> _vocabularies = [];
  bool _isLoadingVocabs = true;
  bool _isSavingDeck = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.deckData['title']);
    _descController = TextEditingController(
      text: widget.deckData['description'] ?? '',
    );
    _selectedDifficulty = widget.deckData['difficulty'] ?? 'MEDIUM';

    _fetchVocabularies();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchVocabularies() async {
    setState(() => _isLoadingVocabs = true);
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.deckVocabularies(widget.deckData['id'])),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _vocabularies = json.decode(utf8.decode(response.bodyBytes));
          _isLoadingVocabs = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingVocabs = false);
    }
  }

  Future<void> _updateDeckInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSavingDeck = true);
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.patch(
        Uri.parse(ApiEndpoints.manageDeckDetail(widget.deckData['id'])),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'difficulty': _selectedDifficulty,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông tin bộ từ vựng!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      setState(() => _isSavingDeck = false);
    }
  }

  Future<void> _deleteVocabulary(int vocabId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa từ vựng'),
            content: const Text(
              'Từ vựng này sẽ bị xóa vĩnh viễn khỏi bộ. Bạn chắc chứ?',
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

    String? token = await _storage.read(key: 'access_token');
    final response = await http.delete(
      Uri.parse(ApiEndpoints.manageVocabularyDetail(vocabId)),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (!mounted) return;
    if (response.statusCode == 204) {
      _fetchVocabularies();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa từ vựng')));
    }
  }

  void _openAddOrEditVocabScreen({Map<String, dynamic>? existingVocab}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVocabularyScreen(
          deckId: widget.deckData['id'],
          deckTitle: _titleController.text,
          vocabData: existingVocab,
        ),
      ),
    );
    if (result == true) {
      _fetchVocabularies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chi tiết & Chỉnh sửa',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thông tin chung', style: AppTextStyles.h2),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Tên bộ từ vựng *',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Mô tả',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDifficulty,
                    decoration: InputDecoration(
                      labelText: 'Độ khó',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'EASY', child: Text('Dễ')),
                      DropdownMenuItem(
                        value: 'MEDIUM',
                        child: Text('Trung bình'),
                      ),
                      DropdownMenuItem(value: 'HARD', child: Text('Khó')),
                    ],
                    onChanged: (v) => setState(() => _selectedDifficulty = v!),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSavingDeck ? null : _updateDeckInfo,
                      style: AppButtons.primaryButton,
                      child: _isSavingDeck
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text('LƯU THÔNG TIN BỘ'),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(thickness: 2),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Danh sách từ vựng', style: AppTextStyles.h2),
                ElevatedButton.icon(
                  onPressed: () => _openAddOrEditVocabScreen(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm từ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _isLoadingVocabs
                ? const Center(child: CircularProgressIndicator())
                : _vocabularies.isEmpty
                ? const Center(
                    child: Text(
                      'Bộ từ vựng này chưa có từ nào.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vocabularies.length,
                    itemBuilder: (context, index) {
                      final vocab = _vocabularies[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            vocab['word'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          subtitle: Text(vocab['meaning'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppColors.accent,
                                ),
                                onPressed: () => _openAddOrEditVocabScreen(
                                  existingVocab: vocab,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _deleteVocabulary(vocab['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
