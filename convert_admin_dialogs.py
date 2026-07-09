import re
import os

def convert_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if already converted
    if 'CupertinoAlertDialog' in content and 'AlertDialog' not in content:
        return False, "Already converted"
    
    # Add cupertino import if not present
    if 'package:flutter/cupertino.dart' not in content:
        content = content.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/cupertino.dart';\nimport 'package:flutter/material.dart';"
        )
    
    original = content
    
    # Simple confirmation dialogs: AlertDialog with only title/content/actions (no TextField)
    # Pattern 1: Simple confirmation dialog
    content = re.sub(
        r'AlertDialog\(\s*shape:[^,)]+,\s*title: const Text\(([^)]+),[^)]*\),\s*content: const Text\(([^)]+),[^)]*\),\s*actions:',
        r'CupertinoAlertDialog(\n        title: const Text(\1),\n        content: const Text(\2),\n        actions:',
        content
    )
    
    # Pattern 2: Remove shape and styling from AlertDialog, keep title/content
    content = re.sub(
        r'AlertDialog\(\s*shape:[^)]+\),?\s*',
        r'CupertinoAlertDialog(\n        ',
        content
    )
    
    # Convert TextButton in dialog actions to CupertinoDialogAction
    content = re.sub(
        r'TextButton\(\s*onPressed: \(\) => Navigator\.pop\(([^)]+)\),\s*child: const Text\(([^)]+)\)',
        r'CupertinoDialogAction(\n              onPressed: () => Navigator.pop(\1),\n              child: const Text(\2)',
        content
    )
    
    content = re.sub(
        r'TextButton\(\s*onPressed: \(\) => Navigator\.pop\(([^)]+)\),\s*child: Text\(([^)]+)\)',
        r'CupertinoDialogAction(\n              onPressed: () => Navigator.pop(\1),\n              child: Text(\2)',
        content
    )
    
    # Convert ElevatedButton in dialog actions to CupertinoDialogAction with isDestructiveAction
    content = re.sub(
        r'ElevatedButton\(\s*onPressed: \(\) => Navigator\.pop\(([^)]+)\),\s*style: [^,]+,\s*child: (?:const )?Text\(([^)]+)\)',
        r'CupertinoDialogAction(\n              isDestructiveAction: true,\n              onPressed: () => Navigator.pop(\1),\n              child: Text(\2)',
        content
    )
    
    # Remove ElevatedButton.styleFrom lines that are no longer needed
    content = re.sub(
        r'style: ElevatedButton\.styleFrom\(\s*backgroundColor: [^)]+\),\s*',
        '',
        content
    )
    
    # Remove trailing ElevatedButton.styleFrom with shape that spans multiple lines
    content = re.sub(
        r'style: ElevatedButton\.styleFrom\([^)]+\),\s*',
        '',
        content
    )
    
    if content == original:
        return False, "No changes made"
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return True, "Converted"

# Run on admin files
admin_files = [
    'lib/features/admin/presentation/admin_offers_screen.dart',
    'lib/features/admin/presentation/admin_settlements_screen.dart',
    'lib/features/admin/presentation/admin_verification_screen.dart',
    'lib/features/admin/presentation/admin_carousel_screen.dart',
    'lib/features/admin/presentation/admin_cash_remittance_screen.dart',
]

base_dir = r'D:\My_Projects\Faster'

for file_rel in admin_files:
    filepath = os.path.join(base_dir, file_rel)
    if os.path.exists(filepath):
        success, msg = convert_file(filepath)
        print(f"{'✅' if success else '⏭'} {file_rel}: {msg}")
    else:
        print(f"❌ {file_rel}: File not found")
