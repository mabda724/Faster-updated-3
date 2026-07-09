import re

with open('D:\My_Projects\Faster\lib\features\provider\presentation\provider_dashboard_screen.dart', 'r', encoding='utf-8-sig') as f:
    content = f.read()

# Replace imports
content = content.replace(
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/cupertino.dart';\nimport 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, TextFormField, InputDecoration, ElevatedButton, MaterialPageRoute, Theme, ThemeData, Switch, Badge;"
)

# Replace Icons with CupertinoIcons equivalents
replacements = [
    ('Icons.notifications_active', 'CupertinoIcons.bell_fill'),
    ('Icons.warning_rounded', 'CupertinoIcons.exclamationmark_triangle_fill'),
    ('Icons.info_outline', 'CupertinoIcons.info'),
    ('Icons.inventory_2_rounded', 'CupertinoIcons.cube_box_fill'),
    ('Icons.inventory_rounded', 'CupertinoIcons.cube_box_fill'),
    ('Icons.warehouse_rounded', 'CupertinoIcons.archivebox_fill'),
    ('Icons.monetization_on_rounded', 'CupertinoIcons.money_dollar_circle_fill'),
    ('Icons.directions_car_rounded', 'CupertinoIcons.car_fill'),
    ('Icons.local_shipping_rounded', 'CupertinoIcons.cube_box_fill'),
    ('Icons.route_rounded', 'CupertinoIcons.map_fill'),
    ('Icons.build_rounded', 'CupertinoIcons.wrench_fill'),
    ('Icons.check_circle_rounded', 'CupertinoIcons.checkmark_circle_fill'),
    ('Icons.star_rounded', 'CupertinoIcons.star_fill'),
    ('Icons.camera_alt_rounded', 'CupertinoIcons.camera_fill'),
    ('Icons.account_balance_wallet_rounded', 'CupertinoIcons.creditcard_fill'),
    ('Icons.payment', 'CupertinoIcons.creditcard_fill'),
    ('Icons.receipt_long_rounded', 'CupertinoIcons.doc_text_fill'),
    ('Icons.hourglass_top_rounded', 'CupertinoIcons.hourglass'),
    ('Icons.map_rounded', 'CupertinoIcons.map_fill'),
    ('Icons.arrow_forward_ios_rounded', 'CupertinoIcons.chevron_forward'),
    ('Icons.card_giftcard', 'CupertinoIcons.gift_fill'),
    ('Icons.work_rounded', 'CupertinoIcons.briefcase_fill'),
    ('Icons.lock_outline', 'CupertinoIcons.lock'),
    ('Icons.account_balance_rounded', 'CupertinoIcons.building_2_fill'),
    ('Icons.phone_android_rounded', 'CupertinoIcons.device_phone_portrait'),
    ('Icons.check_circle_outline_rounded', 'CupertinoIcons.checkmark_circle'),
    ('Icons.cloud_upload_outlined', 'CupertinoIcons.cloud_upload'),
    ('Icons.arrow_circle_down_rounded', 'CupertinoIcons.arrow_down_circle_fill'),
]

for old, new in replacements:
    content = content.replace(old, new)

# Replace Scaffold with CupertinoPageScaffold in build() only
# We need to be careful - only replace in the main build method, not in showDialog etc.
# Actually, for this file, there are showDialog calls but they use CupertinoAlertDialog already
# Let's just replace the main Scaffold if present
content = content.replace('return Scaffold(', 'return CupertinoPageScaffold(')
content = content.replace('    Scaffold(', '    CupertinoPageScaffold(')  # indent variant

# Replace Colors.white to CupertinoColors.white
content = content.replace('Colors.white', 'CupertinoColors.white')

# Replace Colors.grey to CupertinoColors.systemGrey
content = content.replace('Colors.grey', 'CupertinoColors.systemGrey')

# Replace MaterialPageRoute to CupertinoPageRoute
content = content.replace('MaterialPageRoute(', 'CupertinoPageRoute(')

# Add correct imports if not present
if 'import \'package:flutter/cupertino.dart\';' not in content:
    content = content.replace(
        'import \'package:flutter/material.dart\';',
        "import 'package:flutter/cupertino.dart';\nimport 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, TextFormField, InputDecoration, ElevatedButton, MaterialPageRoute, Theme, ThemeData, Switch, Badge;"
    )

with open('D:\My_Projects\Faster\lib\features\provider\presentation\provider_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done!')
