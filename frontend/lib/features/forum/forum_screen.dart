import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import 'forum_post_detail_screen.dart';
import 'create_forum_post_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
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

  Future<void> _fetchPosts() async {
    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse(ApiEndpoints.forumPosts()),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _posts = decodedData is List
              ? decodedData
              : (decodedData['results'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int index, int postId) async {
    setState(() {
      _posts[index]['is_liked'] = !_posts[index]['is_liked'];
      _posts[index]['likes_count'] += _posts[index]['is_liked'] ? 1 : -1;
    });

    try {
      String? token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse(ApiEndpoints.toggleForumLike(postId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        setState(() {
          _posts[index]['is_liked'] = !_posts[index]['is_liked'];
          _posts[index]['likes_count'] += _posts[index]['is_liked'] ? 1 : -1;
        });
      }
    } catch (e) {
      setState(() {
        _posts[index]['is_liked'] = !_posts[index]['is_liked'];
        _posts[index]['likes_count'] += _posts[index]['is_liked'] ? 1 : -1;
      });
    }
  }

  Future<void> _deletePost(int postId) async {
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
        Uri.parse(ApiEndpoints.forumPostDetail(postId)),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 204) {
        setState(() => _posts.removeWhere((p) => p['id'] == postId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bài đăng thành công!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi khi xóa bài đăng.')),
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

  void _confirmDelete(int postId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Xác nhận xóa',
                style: AppTextStyles.h2.copyWith(color: AppColors.error),
              ),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn xóa bài đăng này không?',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(context);
                _deletePost(postId);
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

  void _openPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumPostDetailScreen(postId: post['id']),
      ),
    ).then((_) {
      _fetchPosts();
    });
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
          'Diễn đàn',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _posts.isEmpty
          ? const Center(
              child: Text(
                'Chưa có bài đăng nào.',
                style: AppTextStyles.bodySecondary,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchPosts,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final bool isMyPost = post['is_my_post'] ?? false;
                  final bool isLiked = post['is_liked'] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: AppDecorations.cardStyle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _openPostDetail(post),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                child: Text(
                                  post['title'],
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.primaryDark,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            if (isMyPost)
                              InkWell(
                                onTap: () => _confirmDelete(post['id']),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: AppSpacing.sm),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error,
                                    size: 22,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          "Ngày ${_formatDateTime(post!['created_at'])}",
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          'Đăng bởi ${post['author_name']}',
                          style: AppTextStyles.caption,
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () => _openPostDetail(post),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '${post['comments_count']}',
                                      style: AppTextStyles.bodySecondary
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),

                            InkWell(
                              onTap: () => _toggleLike(index, post['id']),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
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
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '${post['likes_count']}',
                                      style: AppTextStyles.bodySecondary
                                          .copyWith(
                                            color: isLiked
                                                ? AppColors.error
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        elevation: 4,
        onPressed: () async {
          final bool? shouldRefresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateForumPostScreen()),
          );

          if (shouldRefresh == true) {
            _fetchPosts();
          }
        },
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text(
          'Tạo bài đăng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
