import re
import os

def convert_material_to_cupertino(file_path):
    """Convert common Material widgets to Cupertino in a file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if file has material imports
    if 'package:flutter/material.dart' not in content:
        return False, "No material import"
    
    # Track if we made changes
    original = content
    
    # 1. Add cupertino import if not present
    if 'package:flutter/cupertino.dart' not in content:
        content = content.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/cupertino.dart';\nimport 'package:flutter/material.dart';"
        )
    
    # 2. Convert Scaffold to CupertinoPageScaffold (careful - only where it makes sense)
    # We don't auto-convert Scaffold as it requires structural changes
    
    # 3. Convert AlertDialog to CupertinoAlertDialog (in showDialog calls)
    # This is handled per-file as the structure varies
    
    # 4. Convert ElevatedButton to CupertinoButton
    # This is complex - skip for now
    
    if content != original:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True, "Converted"
    
    return False, "No changes needed"

def find_dialogs_in_file(file_path):
    """Find all dialog-related patterns in a file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    results = []
    
    # Find showDialog occurrences
    for match in re.finditer(r'showDialog', content):
        line_num = content[:match.start()].count('\n') + 1
        results.append((line_num, 'showDialog'))
    
    # Find AlertDialog occurrences
    for match in re.finditer(r'AlertDialog', content):
        line_num = content[:match.start()].count('\n') + 1
        results.append((line_num, 'AlertDialog'))
    
    # Find showModalBottomSheet
    for match in re.finditer(r'showModalBottomSheet', content):
        line_num = content[:match.start()].count('\n') + 1
        results.append((line_num, 'showModalBottomSheet'))
    
    return results

# Target files from the original request
target_files = [
    'lib/features/booking/presentation/booking_screen.dart',
    'lib/features/home/presentation/home_screen.dart',
]

# Admin screens (18 total)
admin_files = [
    'lib/features/admin/presentation/admin_dashboard_screen.dart',
    'lib/features/admin/presentation/admin_orders_screen.dart',
    'lib/features/admin/presentation/admin_providers_screen.dart',
    'lib/features/admin/presentation/admin_services_screen.dart',
    'lib/features/admin/presentation/admin_categories_screen.dart',
    'lib/features/admin/presentation/admin_offers_screen.dart',
    'lib/features/admin/presentation/admin_notifications_screen.dart',
    'lib/features/admin/presentation/admin_withdrawals_screen.dart',
    'lib/features/admin/presentation/admin_settlements_screen.dart',
    'lib/features/admin/presentation/admin_verification_screen.dart',
    'lib/features/admin/presentation/admin_reports_screen.dart',
    'lib/features/admin/presentation/admin_settings_screen.dart',
    'lib/features/admin/presentation/admin_pricing_screen.dart',
    'lib/features/admin/presentation/admin_maintenance_screen.dart',
    'lib/features/admin/presentation/admin_carousel_screen.dart',
    'lib/features/admin/presentation/admin_cash_remittance_screen.dart',
    'lib/features/admin/presentation/admin_quality_dashboard_screen.dart',
    'lib/features/admin/presentation/admin_nav_screen.dart',
]

# Seller, driver, delivery screens (16 total)
role_files = [
    'lib/features/seller/presentation/seller_nav_screen.dart',
    'lib/features/seller/presentation/seller_dashboard_screen.dart',
    'lib/features/seller/presentation/seller_products_screen.dart',
    'lib/features/seller/presentation/seller_orders_screen.dart',
    'lib/features/seller/presentation/seller_store_profile_screen.dart',
    'lib/features/driver/presentation/driver_nav_screen.dart',
    'lib/features/driver/presentation/driver_dashboard_screen.dart',
    'lib/features_DRIVER/presentation/driver_active_ride_screen.dart',
    'lib/features/driver/presentation/driver_ride_active_screen.dart',
    'lib/features/driver/presentation/driver_ride_requests_screen.dart',
    'lib/features/driver/presentation/driver_history_screen.dart',
    'lib/features/driver/presentation/driver_arrival_qr_scan_screen.dart',
    'lib/features/delivery/presentation/delivery_nav_screen.dart',
    'lib/features/delivery/presentation/delivery_dashboard_screen.dart',
    'lib/features/delivery/presentation/delivery_active_screen.dart',
    'lib/features/delivery/presentation/delivery_orders_screen.dart',
    'lib/features/delivery/presentation/delivery_history_screen.dart',
]

all_files = target_files + admin_files + role_files

print("Scanning files for dialogs...\n")

for file_path in all_files:
    full_path = os.path.join('D:\\My_Projects\\Faster', file_path)
    if not os.path.exists(full_path):
        print(f"MISSING: {file_path}")
        continue
    
    dialogs = find_dialogs_in_file(full_path)
    if dialogs:
        print(f"\n{file_path}:")
        for line, type in dialogs:
            print(f"  Line {line}: {type}")

print("\n\nScan complete.")
