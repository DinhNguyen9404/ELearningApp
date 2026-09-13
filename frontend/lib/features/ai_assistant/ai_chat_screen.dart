import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../core/config.dart';
import '../../core/api_endpoints.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _chatSessions = [];
  bool _isLoadingSessions = false;

  bool _isLoading = false;
  int? _sessionId;

  Future<String?> _getToken() => _storage.read(key: 'access_token');

  Future<void> _loadSessions() async {
    final token = await _getToken();
    if (token == null) return;

    setState(() => _isLoadingSessions = true);
    try {
      final response = await http
          .get(
            Uri.parse(ApiEndpoints.aiChatSessions()),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() => _chatSessions = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {
    } finally {
      setState(() => _isLoadingSessions = false);
    }
  }

  Future<void> _openSession(int sessionId) async {
    final token = await _getToken();
    if (token == null) return;
    if (!mounted) return;
    Navigator.of(context).pop();
    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(
            Uri.parse(ApiEndpoints.aiChatSessionDetail(sessionId)),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> msgs = data['messages'];
        setState(() {
          _sessionId = data['id'];
          _messages
            ..clear()
            ..addAll(
              msgs.map(
                (m) => {
                  'role': m['role'],
                  'content': m['content'],
                  'error': false,
                },
              ),
            );
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _isLoading = false);
        _showError('Không tải được cuộc trò chuyện này.');
      }
    } catch (_) {
      setState(() => _isLoading = false);
      _showError('Lỗi kết nối khi tải lịch sử.');
    }
  }

  void _startNewChat() {
    Navigator.of(context).pop();
    setState(() {
      _sessionId = null;
      _messages.clear();
    });
  }

  Future<void> _sendMessage() async {
    if (_isLoading) return;

    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    final String? token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      _showError('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      return;
    }

    setState(() {
      _messages.add({'role': 'USER', 'content': text, 'error': false});
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    final int messageIndex = _messages.length - 1;
    await _callChatApi(text, messageIndex, token);
  }

  Future<void> _retry(int index) async {
    if (_isLoading) return;

    final String? token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      _showError('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      return;
    }

    final String text = _messages[index]['content'] as String;
    setState(() {
      _messages[index]['error'] = false;
      _isLoading = true;
    });
    await _callChatApi(text, index, token);
  }

  Future<void> _callChatApi(String text, int messageIndex, String token) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.aiChatAsk()),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'content': text, 'session_id': _sessionId}),
          )
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds + 20));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _sessionId = data['session_id'];
          _messages.add({
            'role': 'AI',
            'content': data['ai_response'],
            'error': false,
          });
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      }

      String message;
      try {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        message =
            errorData['error'] ??
            'Lỗi không xác định từ máy chủ (${response.statusCode}).';
      } catch (_) {
        message =
            'Lỗi máy chủ: Không thể nhận phản hồi từ AI (${response.statusCode}).';
      }
      setState(() {
        _messages[messageIndex]['error'] = true;
        _isLoading = false;
      });
      _showError(message);
    } on TimeoutException {
      setState(() {
        _messages[messageIndex]['error'] = true;
        _isLoading = false;
      });
      _showError('AI phản hồi quá lâu, vui lòng thử lại.');
    } on SocketException {
      setState(() {
        _messages[messageIndex]['error'] = true;
        _isLoading = false;
      });
      _showError('Mất kết nối mạng. Kiểm tra Internet rồi thử lại.');
    } catch (e) {
      setState(() {
        _messages[messageIndex]['error'] = true;
        _isLoading = false;
      });
      _showError('Đã có lỗi xảy ra. Vui lòng thử lại.');
    }
  }

  void _showError(String errorMsg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Lịch sử trò chuyện',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    tooltip: 'Cuộc trò chuyện mới',
                    onPressed: _startNewChat,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoadingSessions
                  ? const Center(child: CircularProgressIndicator())
                  : _chatSessions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chưa có cuộc trò chuyện nào',
                          style: AppTextStyles.bodySecondary,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _chatSessions.length,
                      itemBuilder: (context, index) {
                        final s = _chatSessions[index];
                        final isCurrent = s['id'] == _sessionId;
                        return ListTile(
                          selected: isCurrent,
                          selectedTileColor: AppColors.background,
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(
                            s['title'] ?? 'Không có tiêu đề',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            s['last_message'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySecondary,
                          ),
                          onTap: () => _openSession(s['id']),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      endDrawer: _buildHistoryDrawer(),
      onDrawerChanged: null,
      onEndDrawerChanged: (isOpen) {
        if (isOpen) _loadSessions();
      },
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.success),
            SizedBox(width: 8),
            Text('Gia sư AI', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_messages.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_rounded,
                        size: 60,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Hãy hỏi tôi bất kỳ điều gì\nvề ngữ pháp hoặc từ vựng!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'USER';
                    final hasError = msg['error'] == true;

                    return Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isUser ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isUser ? 16 : 0),
                                bottomRight: Radius.circular(isUser ? 0 : 16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              msg['content'] ?? '',
                              style: TextStyle(
                                color: isUser
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),

                        if (isUser && hasError)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12,
                              right: 4,
                            ),
                            child: GestureDetector(
                              onTap: () => _retry(index),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 14,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Gửi lỗi · Thử lại',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AI đang suy nghĩ...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_isLoading) _sendMessage();
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
