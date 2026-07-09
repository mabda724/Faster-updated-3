import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/in_app_notifier.dart';
import '../../../core/widgets/app_report_bottom_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String partnerName;
  final String partnerId;
  final String? bookingId; // Optional booking ID for better notification context

  const ChatScreen({super.key, required this.partnerName, required this.partnerId, this.bookingId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _canChat = false;
  String? _denialReason;
  bool _isTyping = false;
  Timer? _typingTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkBookingPermission();
    _listenToMessages();
  }

  StreamSubscription? _messagesSub;

  void _listenToMessages() {
    _messagesSub = SupabaseService.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        final currentUserId = SupabaseService.currentUserId;
        final relevantMessages = <Map<String, dynamic>>[];
        
        for (var m in data) {
          // Check if this message belongs to this conversation
          bool isMe = m['sender_id'] == currentUserId;
          bool isRelevant = (m['sender_id'] == currentUserId && m['receiver_id'] == widget.partnerId) ||
                            (m['sender_id'] == widget.partnerId && m['receiver_id'] == currentUserId);

          if (isRelevant) {
            relevantMessages.add({
              'text': m['content'] ?? m['text'] ?? '',
              'isMe': isMe,
              'time': _formatTime(m['created_at']),
              'image_url': m['image_url'],
            });
          }
        }

        setState(() {
          _messages.clear();
          _messages.addAll(relevantMessages);
        });

        // Auto-scroll to bottom when new message arrives
        if (relevantMessages.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'الآن';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'الآن';
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _typingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkBookingPermission() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) {
      setState(() {
        _canChat = false;
        _denialReason = 'يجب تسجيل الدخول أولاً';
        _isLoading = false;
      });
      return;
    }

    try {
      final profile = await SupabaseService.db
          .from('profiles')
          .select('role')
          .eq('id', currentUserId)
          .maybeSingle();
      
      if (profile == null || profile['role'] == null) {
        setState(() {
          _canChat = false;
          _denialReason = 'بيانات الحساب غير مكتملة';
          _isLoading = false;
        });
        return;
      }
      final userRole = profile['role'].toString();

      bool hasBooking = false;
      bool chatVisible = true;

      if (userRole == 'client') {
        // Client can chat if they have an active booking with this partner
        // Chat is hidden after service completion (chat_visible = false)
        final res = await SupabaseService.db
            .from('bookings')
            .select('id, status, chat_visible')
            .eq('client_id', currentUserId)
            .eq('provider_id', widget.partnerId)
            .inFilter('status', ['pending', 'accepted', 'on_the_way', 'arrived', 'in_progress', 'completed'])
            .limit(1);
        hasBooking = (res as List).isNotEmpty;
        // Check if chat is still visible (not hidden after completion)
        if (hasBooking) {
          chatVisible = res.first['chat_visible'] != false;
        }
      } else if (userRole == 'provider') {
        // Provider can chat if they have a booking from this client
        final res = await SupabaseService.db
            .from('bookings')
            .select('id, status, chat_visible')
            .eq('provider_id', currentUserId)
            .eq('client_id', widget.partnerId)
            .inFilter('status', ['pending', 'accepted', 'on_the_way', 'arrived', 'in_progress', 'completed'])
            .limit(1);
        hasBooking = (res as List).isNotEmpty;
        if (hasBooking) {
          chatVisible = res.first['chat_visible'] != false;
        }
      } else {
        // Admin can chat for support
        hasBooking = true;
      }

      setState(() {
        _canChat = hasBooking && chatVisible;
        _denialReason = !hasBooking
            ? 'يجب إنشاء طلب (حجز) مع الطرف الآخر أولاً للتواصل'
            : !chatVisible
                ? 'المحادثة غير متاحة بعد إتمام الخدمة. تواصل مع خدمة العملاء للرجوع لنفس الطرف.'
                : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _canChat = false;
        _denialReason = 'حدث خطأ في التحقق من الحجز';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    if (_isLoading) return;

    if (!_canChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إنشاء حجز مع الطرف الآخر أولاً للتواصل'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final text = _msgController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    // Off-platform transaction prevention filter (only for text messages)
    if (imageUrl == null) {
      final sensitivePatterns = [
        r'(\d{11})', // Egyptian phone numbers
        r'(رقمي|كلمني|واتساب|واتس|تلفون|موبايل|فون)',
        r'(خارج|بعيد|تطبيق|ابليكيشن|عمولة)',
      ];

      bool isSuspicious = false;
      String? matchedPattern;
      for (var pattern in sensitivePatterns) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(text)) {
          isSuspicious = true;
          matchedPattern = pattern;
          break;
        }
      }

      if (isSuspicious) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إتمام الحجز عبر التطبيق لضمان حقوقك وتجنب حظر الحساب'),
            backgroundColor: AppTheme.warningColor,
            duration: Duration(seconds: 4),
          ),
        );
        // Log suspicious attempt to database
        _logSuspiciousMessage(text, matchedPattern ?? '');
        return;
      }
    }

    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': 'الآن',
        'image_url': imageUrl,
      });
      if (imageUrl == null) _msgController.clear();
    });

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      await SupabaseService.db.from('chat_messages').insert({
        'sender_id': currentUserId,
        'receiver_id': widget.partnerId,
        'content': text.isNotEmpty ? text : null,
        'image_url': imageUrl,
        'booking_id': widget.bookingId, // Link to booking if available
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Get sender name for notification
      final profile = await SupabaseService.db
          .from('profiles')
          .select('full_name')
          .eq('id', currentUserId)
          .maybeSingle();

      final senderName = profile?['full_name'] ?? 'مستخدم';

      // Send in-app notification
      await InAppNotifier.newMessage(
        recipientId: widget.partnerId,
        senderName: senderName,
        bookingId: widget.bookingId ?? 'chat',
        messagePreview: imageUrl != null ? 'صورة' : text,
      );

      // Send FCM notification to receiver
      try {
        await NotificationService.sendPushNotification(
          userId: widget.partnerId,
          title: 'رسالة جديدة من $senderName',
          body: imageUrl != null ? 'صورة' : text,
          type: 'chat_message',
          data: {
            'booking_id': widget.bookingId ?? 'chat',
            'sender_name': senderName,
            'sender_id': currentUserId,
          },
        );
      } catch (e) {
        debugPrint('FCM chat notification error: $e');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إرسال الرسالة، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _logSuspiciousMessage(String message, String pattern) async {
    try {
      final currentUserId = SupabaseService.currentUserId;
      if (currentUserId == null) return;
      await SupabaseService.db.from('suspicious_messages').insert({
        'sender_id': currentUserId,
        'receiver_id': widget.partnerId,
        'message_text': message,
        'flagged_pattern': pattern,
      });
    } catch (e) {
      debugPrint('Error logging suspicious message: $e');
    }
  }

  Future<void> _sendPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final name = 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = SupabaseService.storage.from('chat-photos');
      
      await bucket.uploadBinary(name, bytes);
      final imageUrl = bucket.getPublicUrl(name);

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      debugPrint('Error sending photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إرسال الصورة، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusXl)),
      ),
      builder: (_) => AppReportBottomSheet(
        providerId: widget.partnerId,
        reportedById: SupabaseService.currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: DesignTokens.elevation0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          tooltip: 'العودة',
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: DesignTokens.space40,
              height: DesignTokens.space40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
              ),
              child: Center(
                child: Text(
                  widget.partnerName.isNotEmpty ? widget.partnerName.substring(0, 1) : '?',
                  style: const TextStyle(color: AppTheme.surfaceColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
              const SizedBox(width: DesignTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerName,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: DesignTokens.textBodyLarge, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isLoading)
                      const Text('جاري التحقق...', style: TextStyle(color: AppTheme.textSecondary, fontSize: DesignTokens.textBodySmall))
                  else if (!_canChat)
                      Text(_denialReason ?? 'غير مصرح', style: const TextStyle(color: AppTheme.errorColor, fontSize: DesignTokens.textBodySmall))
                  else
                    const Text('متصل الآن', style: TextStyle(color: AppTheme.successColor, fontSize: DesignTokens.textBodySmall)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Report button
          IconButton(
            icon: const Icon(Icons.flag_rounded, color: AppTheme.errorColor, size: DesignTokens.iconMd),
            tooltip: 'الإبلاغ',
            onPressed: () => _showReportDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 64,
                                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                              ),
                              SizedBox(height: DesignTokens.space16),
                              Text(
                                _canChat ? 'ابدأ المحادثة الآن' : 'غير مسموح بالتواصل',
                                style: TextStyle(
                                  color: _canChat ? AppTheme.textSecondary : AppTheme.errorColor,
                                  fontSize: DesignTokens.textBodyLarge,
                                ),
                              ),
                              if (!_canChat) ...[
                                SizedBox(height: DesignTokens.space8),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: DesignTokens.space32),
                                  child: Text(
                                    _denialReason ?? 'يجب إنشاء حجز مع مقدم الخدمة أولاً',
                                    style: TextStyle(
                                      color: AppTheme.errorColor.withValues(alpha: 0.7),
                                      fontSize: DesignTokens.textBodySmall,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(DesignTokens.space16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['isMe'] as bool;
                            final hasImage = msg['image_url'] != null;
                            
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.only(
                                  bottom: DesignTokens.space12,
                                  left: isMe ? DesignTokens.space48 : 0,
                                  right: isMe ? 0 : DesignTokens.space48,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space16,
                                  vertical: hasImage ? DesignTokens.space8 : DesignTokens.space12,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? AppTheme.primaryColor : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(DesignTokens.radiusLg),
                                    topRight: const Radius.circular(DesignTokens.radiusLg),
                                    bottomLeft: Radius.circular(isMe ? DesignTokens.radiusLg : DesignTokens.radiusMd),
                                    bottomRight: Radius.circular(isMe ? DesignTokens.radiusMd : DesignTokens.radiusLg),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: isMe
                                      ? null
                                      : Border.all(
                                          color: AppTheme.textPrimary.withValues(alpha: 0.1),
                                          width: 1,
                                        ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasImage)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                                        child: Image.network(
                                          msg['image_url'],
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          semanticLabel: 'صورة مرفقة',
                                        ),
                                      ),
                                    if (hasImage && (msg['text'] ?? '').toString().isNotEmpty)
                                      SizedBox(height: DesignTokens.space8),
                                    if ((msg['text'] ?? '').toString().isNotEmpty)
                                      Text(
                                        (msg['text'] ?? '').toString(),
                                        style: TextStyle(
                                          color: isMe ? Colors.white : AppTheme.textPrimary,
                                          fontSize: DesignTokens.textBodyMedium,
                                          height: 1.4,
                                        ),
                                      ),
                                    SizedBox(height: DesignTokens.space4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        (msg['time'] ?? 'الآن').toString(),
                                        style: TextStyle(
                                          color: isMe ? AppTheme.surfaceColor.withValues(alpha: 0.8) : AppTheme.textSecondary,
                                          fontSize: DesignTokens.textLabelSmall,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Input Field
                Container(
                  padding: EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space12, DesignTokens.space16, DesignTokens.space24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        // Image picker button
                        if (_canChat)
                          Semantics(label: 'إرسال صورة',
                            child: GestureDetector(
                            onTap: _sendPhoto,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.image_rounded,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        if (_canChat) SizedBox(width: DesignTokens.space8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                            ),
                            child: TextField(
                              controller: _msgController,
                              enabled: _canChat,
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _canChat ? _sendMessage() : null,
                              decoration: InputDecoration(
                                hintText: _canChat ? 'اكتب رسالتك هنا...' : 'أكمل الحجز للتواصل',
                                hintStyle: TextStyle(
                                  color: _canChat ? AppTheme.textSecondary : AppTheme.textTertiary,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: DesignTokens.space20,
                                  vertical: DesignTokens.space12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: DesignTokens.space12),
                        Semantics(label: 'إرسال',
                          child: GestureDetector(
                          onTap: _canChat ? _sendMessage : null,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _canChat ? AppTheme.primaryColor : AppTheme.textSecondary,
                              shape: BoxShape.circle,
                              boxShadow: _canChat
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.send_rounded,
                              color: AppTheme.surfaceColor,
                              size: 20,
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
