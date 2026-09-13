import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../core/api_endpoints.dart';

class AddVocabularyScreen extends StatefulWidget {
  final int deckId;
  final String deckTitle;
  final Map<String, dynamic>? vocabData;

  const AddVocabularyScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
    this.vocabData,
  });

  @override
  State<AddVocabularyScreen> createState() => _AddVocabularyScreenState();
}

class _AddVocabularyScreenState extends State<AddVocabularyScreen> {
  final _formKey = GlobalKey<FormState>();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final _wordController = TextEditingController();
  final _meaningController = TextEditingController();
  final _pronunciationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _exampleControllers = [];

  File? _selectedAudioFile;
  bool _isLoading = false;

  bool get _isEditing => widget.vocabData != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _wordController.text = widget.vocabData!['word'] ?? '';
      _meaningController.text = widget.vocabData!['meaning'] ?? '';
      _pronunciationController.text = widget.vocabData!['pronunciation'] ?? '';
      _descriptionController.text = widget.vocabData!['description'] ?? '';
      List<dynamic> examples = widget.vocabData!['examples'] ?? [];
      for (var ex in examples) {
        _exampleControllers.add(TextEditingController(text: ex.toString()));
      }
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _pronunciationController.dispose();
    _descriptionController.dispose();
    for (var controller in _exampleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addExampleField() {
    setState(() => _exampleControllers.add(TextEditingController()));
  }

  void _removeExampleField(int index) {
    setState(() {
      _exampleControllers[index].dispose();
      _exampleControllers.removeAt(index);
    });
  }

  Future<void> _pickAudioFile() async {
    PlatformFile? pickedFile = await FilePicker.pickFile(type: FileType.audio);
    if (pickedFile != null && pickedFile.path != null) {
      setState(() => _selectedAudioFile = File(pickedFile.path!));
    }
  }

  Future<void> _submitVocabulary({bool isFinish = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? token = await _storage.read(key: 'access_token');

      Uri uri;
      if (_isEditing) {
        uri = Uri.parse(
          ApiEndpoints.manageVocabularyDetail(widget.vocabData!['id']),
        );
      } else {
        uri = Uri.parse(ApiEndpoints.manageDeckVocabularies(widget.deckId));
      }

      var request = http.MultipartRequest(_isEditing ? 'PUT' : 'POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['word'] = _wordController.text.trim();
      request.fields['meaning'] = _meaningController.text.trim();
      request.fields['pronunciation'] = _pronunciationController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['part_of_speech'] = 'noun';

      List<String> validExamples = _exampleControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      request.fields['examples'] = jsonEncode(validExamples);

      if (_selectedAudioFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio_file',
            _selectedAudioFile!.path,
          ),
        );
      }

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 201 ||
          streamedResponse.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Cập nhật từ vựng thành công!'
                  : 'Thêm từ vựng thành công!',
            ),
          ),
        );

        if (isFinish) {
          Navigator.pop(context, true);
        } else {
          _wordController.clear();
          _meaningController.clear();
          _pronunciationController.clear();
          _descriptionController.clear();
          for (var controller in _exampleControllers) {
            controller.dispose();
          }
          setState(() {
            _exampleControllers.clear();
            _selectedAudioFile = null;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi lưu từ vựng!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi kết nối mạng, vui lòng thử lại!'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFinishButtonPressed() {
    if (_wordController.text.trim().isNotEmpty ||
        _meaningController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _selectedAudioFile != null) {
      _submitVocabulary(isFinish: true);
    } else {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Chỉnh sửa từ vựng' : 'Thêm từ: ${widget.deckTitle}',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _wordController,
                decoration: InputDecoration(
                  labelText: 'Từ vựng (English) *',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Vui lòng nhập từ' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _meaningController,
                decoration: InputDecoration(
                  labelText: 'Nghĩa tiếng Việt *',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Vui lòng nhập nghĩa' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3, // Cho phép nhập nhiều dòng
                decoration: InputDecoration(
                  labelText: 'Mô tả ý nghĩa (English)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _pronunciationController,
                decoration: InputDecoration(
                  labelText: 'Cách phát âm',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Các ví dụ minh họa', style: AppTextStyles.h3),
                  TextButton.icon(
                    onPressed: _addExampleField,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.primary,
                    ),
                    label: const Text('Thêm ví dụ'),
                  ),
                ],
              ),
              if (_exampleControllers.isEmpty)
                const Text(
                  'Chưa có ví dụ nào.',
                  style: AppTextStyles.bodySecondary,
                ),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exampleControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _exampleControllers[index],
                            decoration: InputDecoration(
                              hintText: 'Nhập ví dụ ${index + 1}...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: AppColors.error,
                          ),
                          onPressed: () => _removeExampleField(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.audio_file_rounded,
                      size: 40,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedAudioFile != null
                          ? 'File đã chọn:\n${_selectedAudioFile!.path.split('/').last}'
                          : (_isEditing &&
                                widget.vocabData!['audio_url'] != '' &&
                                widget.vocabData!['audio_url'] != null)
                          ? 'Đã có audio trên hệ thống.\n(Chọn file mới để ghi đè)'
                          : 'Chưa có file âm thanh.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Chọn file MP3'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              if (!_isEditing) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _submitVocabulary(isFinish: false),
                    style: AppButtons.primaryButton,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('LƯU TỪ VỰNG & TIẾP TỤC THÊM'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _onFinishButtonPressed,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'HOÀN TẤT (LƯU & THOÁT)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _submitVocabulary(isFinish: true),
                    style: AppButtons.primaryButton,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('LƯU THAY ĐỔI TỪ VỰNG'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
