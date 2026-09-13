import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';

class CreateForumPostScreen extends StatefulWidget {
  const CreateForumPostScreen({super.key});

  @override
  State<CreateForumPostScreen> createState() => _CreateForumPostScreenState();
}

class _CreateForumPostScreenState extends State<CreateForumPostScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse(ApiEndpoints.forumPosts()),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
        }),
      );

      if (mounted) {
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tạo bài đăng thành công!')),
          );

          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể tạo bài đăng. Vui lòng thử lại.'),
            ),
          );
          setState(() => _isSubmitting = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi kết nối mạng.')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Tạo bài đăng',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Chia sẻ câu hỏi, kiến thức hoặc thảo luận với cộng đồng học tập.',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const Text('Tiêu đề', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _titleController,
                maxLength: 255,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.h2.copyWith(fontSize: 20),
                decoration: AppDecorations.inputDecoration(
                  'Nhập tiêu đề ngắn gọn...',
                ).copyWith(filled: true, fillColor: AppColors.surface),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề bài đăng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              const Text('Nội dung', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _contentController,
                maxLines: 12,
                minLines: 8,
                textAlignVertical: TextAlignVertical.top,
                style: AppTextStyles.body,
                decoration:
                    AppDecorations.inputDecoration(
                      'Viết nội dung bài đăng của bạn ở đây...',
                    ).copyWith(
                      filled: true,
                      fillColor: AppColors.surface,
                      alignLabelWithHint: true,
                    ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập nội dung bài đăng';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: AppButtons.primaryButton,
              onPressed: _isSubmitting ? null : _submitPost,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.textWhite,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Đang đăng bài...' : 'ĐĂNG BÀI'),
            ),
          ),
        ),
      ),
    );
  }
}
