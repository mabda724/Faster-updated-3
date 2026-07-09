@echo off
set /p PAYMOB_PUBLIC_KEY=Enter Paymob Public Key (egy_pk_...): 
set /p PAYMOB_SECRET_KEY=Enter Paymob Secret Key (egy_sk_...): 
set /p PAYMOB_INTEGRATION_ID_CARD=Enter Paymob Card Integration ID: 
set /p PAYMOB_INTEGRATION_ID_WALLET=Enter Paymob Wallet Integration ID: 

(
echo # Supabase Configuration
echo SUPABASE_URL=https://xoxnjnhqpqkkctkvxzzy.supabase.co
echo SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY_HERE
echo.
echo # Paymob Configuration
echo PAYMOB_PUBLIC_KEY=%PAYMOB_PUBLIC_KEY%
echo PAYMOB_SECRET_KEY=%PAYMOB_SECRET_KEY%
echo PAYMOB_INTEGRATION_ID_CARD=%PAYMOB_INTEGRATION_ID_CARD%
echo PAYMOB_INTEGRATION_ID_WALLET=%PAYMOB_INTEGRATION_ID_WALLET%
echo.
echo # Admin
echo ADMIN_EMAIL=admin@faster.com
echo.
echo # Environment
echo FLUTTER_ENV=production
) > "D:\My_Projects\Faster\assets\.env.new"

echo New .env created at assets\.env.new
echo Verify contents then replace assets/.env
pause
