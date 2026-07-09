#!/bin/bash
# Paymob Integration Verification Script
# Run this to verify all Paymob-fixed components are in place

echo "🔍 Verifying Paymob Integration Fixes..."
echo "========================================"
echo ""

# 1. Check migrations exist
echo "✅ Checking migration files..."
if [ -f "supabase/migrations/070_payment_rls_policies.sql" ]; then
    echo "  ✓ 070_payment_rls_policies.sql exists"
else
    echo "  ✗ MISSING: 070_payment_rls_policies.sql"
fi
if [ -f "supabase/migrations/071_update_settled_amount.sql" ]; then
    echo "  ✓ 071_update_settled_amount.sql exists"
else
    echo "  ✗ MISSING: 071_update_settled_amount.sql"
fi
if [ -f "supabase/migrations/072_fix_earnings_trigger.sql" ]; then
    echo "  ✓ 072_fix_earnings_trigger.sql exists"
else
    echo "  ✗ MISSING: 072_fix_earnings_trigger.sql"
fi

# 2. Check webhook function
echo ""
echo "✅ Checking Edge Function..."
if [ -f "supabase/functions/paymob-webhook/index.ts" ]; then
    echo "  ✓ paymob-webhook function exists"
else
    echo "  ✗ MISSING: paymob-webhook function"
fi

# 3. Check iOS configuration
echo ""
echo "✅ Checking iOS configuration..."
if grep -q "platform :ios, '13.0'" ios/Podfile; then
    echo "  ✓ iOS platform set to 13.0+"
else
    echo "  ✗ iOS platform not set correctly"
fi
if grep -q "pod 'PaymobSDK'" ios/Podfile; then
    echo "  ✓ PaymobSDK pod included"
else
    echo "  ✗ PaymobSDK pod not found"
fi
if grep -q "GeneratedPluginRegistrant.register" ios/Runner/AppDelegate.swift; then
    echo "  ✓ AppDelegate uses plugin auto-registration"
else
    echo "  ✗ AppDelegate may have custom method channel"
fi

# 4. Check Flutter analysis
echo ""
echo "✅ Running Flutter analysis..."
flutter analyze lib/core/services/paymob_service.dart lib/features/booking/presentation/client_checkout_screen.dart > /tmp/flutter_analysis.txt 2>&1
if grep -q "No issues found" /tmp/flutter_analysis.txt; then
    echo "  ✓ Paymob-related files pass flutter analyze"
else
    echo "  ✗ Flutter analysis issues detected"
    cat /tmp/flutter_analysis.txt
fi

# 5. Check .env.example
echo ""
echo "✅ Checking environment configuration..."
if grep -q "PAYMOB_PUBLIC_KEY" .env.example; then
    echo "  ✓ PAYMOB_PUBLIC_KEY placeholder exists"
else
    echo "  ✗ PAYMOB_PUBLIC_KEY missing from .env.example"
fi
if grep -q "PAYMOB_SECRET_KEY" .env.example; then
    echo "  ✓ PAYMOB_SECRET_KEY placeholder exists"
else
    echo "  ✗ PAYMOB_SECRET_KEY missing from .env.example"
fi
if grep -q "PAYMOB_INTEGRATION_ID_CARD" .env.example; then
    echo "  ✓ PAYMOB_INTEGRATION_ID_CARD placeholder exists"
else
    echo "  ✗ PAYMOB_INTEGRATION_ID_CARD missing from .env.example"
fi
if grep -q "PAYMOB_INTEGRATION_ID_WALLET" .env.example; then
    echo "  ✓ PAYMOB_INTEGRATION_ID_WALLET placeholder exists"
else
    echo "  ✗ PAYMOB_INTEGRATION_ID_WALLET missing from .env.example"
fi

# 6. Check documentation
echo ""
echo "✅ Checking documentation..."
if [ -f "PAYMOB_INTEGRATION_GUIDE.md" ]; then
    echo "  ✓ PAYMOB_INTEGRATION_GUIDE.md exists"
else
    echo "  ✗ Missing integration guide"
fi
if [ -f "PAYMOB_FIXES_SUMMARY.md" ]; then
    echo "  ✓ PAYMOB_FIXES_SUMMARY.md exists"
else
    echo "  ✗ Missing fixes summary"
fi

# 7. Summary
echo ""
echo "========================================"
echo "✅ Verification complete!"
echo ""
echo "Next steps:"
echo "1. Run migrations in Supabase:"
echo "   supabase db push"
echo "   OR manually run 070, 071, 072 SQL files"
echo ""
echo "2. Deploy Edge Functions:"
echo "   supabase functions deploy paymob-webhook --no-verify-jwt"
echo ""
echo "3. Set Edge Function secrets in Supabase Dashboard"
echo ""
echo "4. Configure Paymob webhook URL in Paymob Dashboard"
echo ""
echo "5. Run iOS setup: cd ios && pod install"
echo ""
echo "6. Test in Paymob test mode before going live"
echo ""
echo "📄 See PAYMOB_INTEGRATION_GUIDE.md for detailed instructions"
