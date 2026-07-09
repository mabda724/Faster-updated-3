import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';

/// Chat overlay used within the tracking screen.
class TrackingChatOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final ScrollController scrollController;
  final TextEditingController textController;
  final String partnerName;
  final VoidCallback onClose;
  final VoidCallback onSend;
  final VoidCallback onSendPhoto;

  const TrackingChatOverlay({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.textController,
    required this.partnerName,
    required this.onClose,
    required this.onSend,
    required this.onSendPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radius2xl),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space20,
                DesignTokens.space12,
                DesignTokens.space12,
                DesignTokens.space8,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(DesignTokens.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(width: DesignTokens.space12),
                  ClipRRect(
                    borderRadius: DesignTokens.brLg,
                    child: Container(
                      width: DesignTokens.space40,
                      height: DesignTokens.space40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          partnerName.isNotEmpty
                              ? partnerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodyLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partnerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: DesignTokens.textBodyLarge,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'متصل الآن',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: DesignTokens.textLabelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: DesignTokens.space8),
                ],
              ),
            ),
            Divider(
              color: AppTheme.textPrimary.withValues(alpha: 0.08),
              height: 1,
            ),
            // Messages
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_rounded,
                            size: 64,
                            color: AppTheme.textSecondary.withValues(alpha: 0.3),
                          ),
                          SizedBox(height: DesignTokens.space16),
                          const Text(
                            'ابدأ المحادثة الآن',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: DesignTokens.textBodyLarge,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space16,
                        vertical: DesignTokens.space8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        return _ChatBubble(
                          message: messages[i],
                          partnerName: partnerName,
                        );
                      },
                    ),
            ),
            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space16,
                DesignTokens.space12,
                DesignTokens.space16,
                DesignTokens.space24,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Semantics(
                      label: 'إرسال صورة',
                      child: GestureDetector(
                        onTap: onSendPhoto,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.photo_rounded,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: DesignTokens.space8),
                    Expanded(
                      child: TextField(
                        controller: textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك هنا...',
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radius2xl),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space20,
                            vertical: DesignTokens.space12,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: DesignTokens.space12),
                    Semantics(
                      label: 'إرسال',
                      child: GestureDetector(
                        onTap: onSend,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
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
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String partnerName;

  const _ChatBubble({
    required this.message,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    final me = message['isMe'] as bool;
    final hasImage = message['image_url'] != null;
    final text = message['text'] as String? ?? '';
    final time = message['time'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
      child: Row(
        mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!me)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: DesignTokens.space8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: DesignTokens.space16,
                vertical: hasImage ? DesignTokens.space8 : DesignTokens.space12,
              ),
              decoration: BoxDecoration(
                color: me ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(DesignTokens.radiusLg),
                  topRight: const Radius.circular(DesignTokens.radiusLg),
                  bottomLeft: Radius.circular(
                    me ? DesignTokens.radiusLg : DesignTokens.radiusMd,
                  ),
                  bottomRight: Radius.circular(
                    me ? DesignTokens.radiusMd : DesignTokens.radiusLg,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: me
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
                        message['image_url'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel: 'صورة مرفقة',
                      ),
                    ),
                  if (hasImage && text.isNotEmpty)
                    SizedBox(height: DesignTokens.space8),
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(
                        color: me ? Colors.white : AppTheme.textPrimary,
                        fontSize: DesignTokens.textBodyMedium,
                        height: 1.4,
                      ),
                    ),
                  SizedBox(height: DesignTokens.space4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      time,
                      style: TextStyle(
                        color: me
                            ? AppTheme.surfaceColor.withValues(alpha: 0.8)
                            : AppTheme.textSecondary,
                        fontSize: DesignTokens.textLabelSmall,
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
