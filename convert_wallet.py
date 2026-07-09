import re

filepath = r'D:\My_Projects\Faster\lib\features\provider\presentation\provider_wallet_screen.dart'

with open(filepath, 'r', encoding='utf-8-sig') as f:
    content = f.read()

# Replace imports
content = content.replace(
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/cupertino.dart';\nimport 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, TextFormField, InputDecoration, ElevatedButton, MaterialPageRoute, Theme, ThemeData;"
)

# Replace Icons with CupertinoIcons equivalents
replacements = [
    ('Icons.monetization_on_outlined', 'CupertinoIcons.money_dollar_circle'),
    ('Icons.calendar_today', 'CupertinoIcons.calendar'),
    ('Icons.date_range', 'CupertinoIcons.calendar_today'),
    ('Icons.info_outline', 'CupertinoIcons.info'),
    ('Icons.copy', 'CupertinoIcons.doc_on_clipboard_fill'),
    ('Icons.open_in_new', 'CupertinoIcons.arrow_up_right_square_fill'),
    ('Icons.lock_outline', 'CupertinoIcons.lock'),
    ('Icons.account_balance_rounded', 'CupertinoIcons.building_2_fill'),
    ('Icons.phone_android_rounded', 'CupertinoIcons.device_phone_portrait'),
    ('Icons.credit_card', 'CupertinoIcons.creditcard_fill'),
    ('Icons.check_circle_outline_rounded', 'CupertinoIcons.checkmark_circle'),
    ('Icons.cloud_upload_outlined', 'CupertinoIcons.cloud_upload'),
    ('Icons.history_rounded', 'CupertinoIcons.time'),
    ('Icons.arrow_downward_rounded', 'CupertinoIcons.arrow_down_circle_fill'),
    ('Icons.payment', 'CupertinoIcons.creditcard_fill'),
    ('Icons.receipt_long_rounded', 'CupertinoIcons.doc_text_fill'),
    ('Icons.receipt_long_outlined', 'CupertinoIcons.doc_text'), 
    ('Icons.warning_amber_rounded', 'CupertinoIcons.exclamationmark_triangle_fill'),
    ('Icons.check_circle_rounded', 'CupertinoIcons.checkmark_circle_fill'),
    ('Icons.check_circle', 'CupertinoIcons.checkmark_circle_fill'),
    ('Icons.cancel', 'CupertinoIcons.xmark_circle_fill'),
    ('Icons.hourglass_top', 'CupertinoIcons.hourglass'),
    ('Icons.arrow_upward_rounded', 'CupertinoIcons.arrow_up_circle_fill'),
    ('Icons.chevron_left', 'CupertinoIcons.chevron_back'),
    ('Icons.arrow_circle_down_rounded', 'CupertinoIcons.arrow_down_circle_fill'),
]

for old, new in replacements:
    content = content.replace(old, new)

# Replace Scaffold with CupertinoPageScaffold
content = content.replace('return Scaffold(', 'return CupertinoPageScaffold(')

# Replace Colors
content = content.replace('Colors.transparent', 'CupertinoColors.transparent')
content = content.replace('Colors.white70', 'CupertinoColors.white.withValues(alpha: 0.7)')
content = content.replace('Colors.white', 'CupertinoColors.white')
content = content.replace('Colors.grey', 'CupertinoColors.systemGrey')
content = content.replace('Colors.black', 'CupertinoColors.black')

# Replace MaterialPageRoute
content = content.replace('MaterialPageRoute(', 'CupertinoPageRoute(')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done!')
