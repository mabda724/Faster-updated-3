import re

filepath = r'D:\My_Projects\Faster\lib\features\provider\presentation\provider_order_detail_screen.dart'

with open(filepath, 'r', encoding='utf-8-sig') as f:
    content = f.read()

# Replace imports
content = content.replace(
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/cupertino.dart';\nimport 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, TextFormField, InputDecoration, ElevatedButton, MaterialPageRoute, AlertDialog, Image, ClipRRect, BorderRadius, RoundedRectangleBorder;"
)

# Replace Icons with CupertinoIcons equivalents
replacements = [
    ('Icons.warning_amber_rounded', 'CupertinoIcons.exclamationmark_triangle_fill'),
    ('Icons.check_circle', 'CupertinoIcons.checkmark_circle_fill'),
    ('Icons.info', 'CupertinoIcons.info'),
    ('Icons.block', 'CupertinoIcons.nosign'),
    ('Icons.local_offer_rounded', 'CupertinoIcons.tag_fill'),
    ('Icons.card_giftcard_rounded', 'CupertinoIcons.gift_fill'),
    ('Icons.arrow_back_ios_new_rounded', 'CupertinoIcons.back'),
    ('Icons.cancel_outlined', 'CupertinoIcons.xmark_circle'),
    ('Icons.qr_code_rounded', 'CupertinoIcons.qrcode'),
    ('Icons.person_outline', 'CupertinoIcons.person'),
    ('Icons.phone_outlined', 'CupertinoIcons.phone'),
    ('Icons.location_on_outlined', 'CupertinoIcons.location'),
    ('Icons.local_offer', 'CupertinoIcons.tag'),
    ('Icons.payment', 'CupertinoIcons.creditcard_fill'),
    ('Icons.camera_alt', 'CupertinoIcons.camera_fill'),
    ('Icons.broken_image', 'CupertinoIcons.photo'),
    ('Icons.chat_bubble_outline', 'CupertinoIcons.chat_bubble'),
    ('Icons.location_on_rounded', 'CupertinoIcons.location_solid'),
    ('Icons.local_offer_outlined', 'CupertinoIcons.tag'),
    ('Icons.card_giftcard_outlined', 'CupertinoIcons.gift'),
    ('Icons.check_rounded', 'CupertinoIcons.checkmark_alt'),
    ('Icons.close_rounded', 'CupertinoIcons.xmark'),
    ('Icons.directions_car_rounded', 'CupertinoIcons.car_fill'),
    ('Icons.info_outline', 'CupertinoIcons.info'),
]

for old, new in replacements:
    content = content.replace(old, new)

# Replace Scaffold with CupertinoPageScaffold
content = content.replace('return Scaffold(', 'return CupertinoPageScaffold(')
content = content.replace('      appBar: AppBar(', '      navigationBar: CupertinoNavigationBar(')

# Replace Colors
content = content.replace('Colors.blue', 'CupertinoColors.systemBlue')
content = content.replace('Colors.white', 'CupertinoColors.white')
content = content.replace('Colors.grey', 'CupertinoColors.systemGrey')
content = content.replace('Colors.black', 'CupertinoColors.black')

# Replace MaterialPageRoute
content = content.replace('MaterialPageRoute(', 'CupertinoPageRoute(')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done!')
