import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';

class ForumPostDetailScreen extends StatefulWidget {
  final int postId;

  const ForumPostDetailScreen({super.key, required this.postId});

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _commentController = TextEditingController();

  Map<String, dynamic>? _post;
  bool _isLoading = true;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _fetchPostDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final DateTime date = DateTime.parse(isoString).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} lúc ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _fetchPostDetail() async {
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.forumPostDetail(widget.postId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _post = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi tải bài viết')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;

    setState(() {
      _post!['is_liked'] = !_post!['is_liked'];
      _post!['likes_count'] += _post!['is_liked'] ? 1 : -1;
    });

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse(ApiEndpoints.toggleForumLike(widget.postId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        setState(() {
          _post!['is_liked'] = !_post!['is_liked'];
          _post!['likes_count'] += _post!['is_liked'] ? 1 : -1;
        });
      }
    } catch (e) {
      setState(() {
        _post!['is_liked'] = !_post!['is_liked'];
        _post!['likes_count'] += _post!['is_liked'] ? 1 : -1;
      });
    }
  }

  Future<void> _submitComment() async {
    final String content = _commentController.text.trim();
    if (content.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);
    FocusScope.of(context).unfocus();

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse(ApiEndpoints.forumComments(widget.postId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 201) {
        final newComment = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _post!['comments'] = [newComment, ...?_post!['comments']];
          _post!['comments_count'] += 1;
          _commentController.clear();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lỗi gửi bình luận')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi kết nối mạng')));
      }
    } finally {
      setState(() => _isSendingComment = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        Uri.parse(ApiEndpoints.forumCommentDetail(commentId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 204) {
        setState(() {
          List<dynamic> comments = _post!['comments'];
          comments.removeWhere((c) => c['id'] == commentId);
          _post!['comments_count'] -= 1;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xóa bình luận!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xóa bình luận lúc này.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi kết nối mạng.')));
      }
    }
  }

  void _confirmDeleteComment(int commentId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text(
            'Xóa bình luận',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text('Bạn có chắc muốn xóa bình luận này không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(context);
                _deleteComment(commentId);
              },
              child: const Text(
                'Xóa',
                style: TextStyle(color: AppColors.textWhite),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_post == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Bài đăng không tồn tại',
            style: AppTextStyles.bodySecondary,
          ),
        ),
      );
    }

    final bool isLiked = _post!['is_liked'] ?? false;
    final List<dynamic> comments = _post!['comments'] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Chi tiết bài đăng',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchPostDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                            color: AppColors.background,
                          ),
                          child: ClipOval(
                            child:
                                (_post!['author_avatar'] != null &&
                                    _post!['author_avatar']
                                        .toString()
                                        .isNotEmpty)
                                ? Image.network(
                                    _post!['author_avatar'],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person_rounded,
                                              size: 30,
                                              color: AppColors.textSecondary,
                                            ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    size: 24,
                                    color: AppColors.textSecondary,
                                  ),
                          ),
                        ),

                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _post!['author_name'],
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _formatDateTime(_post!['created_at']),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(_post!['title'], style: AppTextStyles.h1),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _post!['content'] ?? '',
                      style: AppTextStyles.body.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Row(
                      children: [
                        InkWell(
                          onTap: _toggleLike,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 4.0,
                            ),
                            child: Row(
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                  child: Icon(
                                    isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    key: ValueKey(isLiked),
                                    color: isLiked
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '${_post!['likes_count']}',
                                  style: AppTextStyles.h4.copyWith(
                                    color: isLiked
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${_post!['comments_count']} bình luận',
                              style: AppTextStyles.h4,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(
                      height: 32,
                      thickness: 1,
                      color: AppColors.border,
                    ),

                    if (comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            'Chưa có bình luận nào. Hãy là người đầu tiên!',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          final bool isMyComment = c['is_my_comment'] ?? false;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                  color: AppColors.background,
                                ),
                                child: ClipOval(
                                  child:
                                      (c['author_avatar'] != null &&
                                          c['author_avatar']
                                              .toString()
                                              .isNotEmpty)
                                      ? Image.network(
                                          c['author_avatar'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.person_rounded,
                                                    size: 21,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                        )
                                      : const Icon(
                                          Icons.person_rounded,
                                          size: 21,
                                          color: AppColors.textSecondary,
                                        ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            c['author_name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),

                                          Row(
                                            children: [
                                              Text(
                                                _formatDateTime(
                                                  c['created_at'],
                                                ),
                                                style: AppTextStyles.caption
                                                    .copyWith(fontSize: 10),
                                              ),
                                              if (isMyComment)
                                                GestureDetector(
                                                  onTap: () =>
                                                      _confirmDeleteComment(
                                                        c['id'],
                                                      ),
                                                  child: const Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 8.0,
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: AppColors.error,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.xs),

                                      Text(
                                        c['content'],
                                        style: AppTextStyles.body,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                    decoration: InputDecoration(
                      hintText: 'Viết bình luận...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _isSendingComment
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: _submitComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
