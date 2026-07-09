# Firebase Cloud Messaging (FCM) Setup Guide

## Overview
This application uses Firebase Cloud Messaging (FCM) for push notifications instead of OneSignal. All notification functionality has been migrated to FCM.

## Configuration Files

### Android
- **File**: `android/app/google-services.json`
- **Status**: ✅ Already configured
- **Plugin**: Applied in `android/app/build.gradle.kts` (line 9)

### iOS
- **File**: `ios/Runner/GoogleService-Info.plist` (needs to be added)
- **Podfile**: Updated with Firebase pods (lines 16-18)
- **Status**: ⚠️ Needs GoogleService-Info.plist file

## Dependencies (pubspec.yaml)
```yaml
firebase_messaging: ^16.2.0
firebase_core: ^4.7.0
flutter_local_notifications: ^18.0.0
```

## Notification Service

The `NotificationService` class (`lib/core/services/notification_service.dart`) handles all FCM functionality:

### Features
- ✅ FCM token management (save to database)
- ✅ Foreground message handling
- ✅ Background message handling
- ✅ Local notifications with custom sound
- ✅ In-app notifications with sound
- ✅ Topic subscription/unsubscription
- ✅ Notification tap handling

### Key Methods

#### Initialize
```dart
await NotificationService.initialize();
```
Called from `main.dart` on app startup.

#### Send Push Notification
```dart
await NotificationService.sendPushNotification(
  userId: 'user_id',
  title: 'Notification Title',
  body: 'Notification Body',
  type: 'notification_type',
  data: {
    'key': 'value',
  },
);
```

#### Show In-App Notification
```dart
await NotificationService.showInAppNotification(
  title: 'Title',
  message: 'Message',
  type: 'type',
  data: {'key': 'value'},
);
```

## Notification Types

The app supports the following notification types:

| Type | Description | Usage |
|------|-------------|-------|
| `order_status` | Order status changes | When booking status changes |
| `new_booking` | New booking assigned | When provider gets new booking |
| `withdrawal_request` | Withdrawal request | When provider requests withdrawal |
| `withdrawal_update` | Withdrawal status update | When admin updates withdrawal |
| `chat_message` | New chat message | When user receives chat message |
| `settlement` | Commission settlement | When provider settles commission |

## Database Integration

FCM tokens are stored in the `profiles` table:
- Column: `fcm_token`
- Updated automatically when token refreshes
- Saved on app initialization

## Supabase Edge Function

The app uses a Supabase Edge Function `send-notification` to send FCM notifications:

```typescript
// Function: send-notification
// Input: { userId, title, body, type, data }
// Output: { success: boolean, error?: string }
```

## Sound Configuration

### Android
- **File**: `android/app/src/main/res/raw/notification_sound.mp3`
- **Format**: MP3
- **Used in**: AndroidNotificationDetails

### iOS
- **File**: `ios/Runner/notification_sound.mp3`
- **Format**: MP3
- **Used in**: DarwinNotificationDetails

## Notification Handling in Screens

### Tracking Screen
- Sends FCM notification when booking status changes
- Uses `NotificationService.sendPushNotification()`
- Includes booking data in notification payload

### Provider Wallet Screen
- Sends FCM notification to admin when commission is settled
- Uses `NotificationService.sendPushNotification()`
- Includes settlement data in notification payload

### Chat Screen
- Sends FCM notification when new message is sent
- Uses `NotificationService.sendPushNotification()`
- Includes chat data in notification payload

## Navigation on Notification Tap

Notifications can navigate to specific screens:

| Notification Type | Navigation Target |
|-------------------|-------------------|
| `order_status` | Booking detail screen |
| `new_booking` | Booking detail screen |
| `withdrawal_request` | Admin withdrawals screen |
| `withdrawal_update` | Provider wallet screen |
| `chat_message` | Chat screen |
| `settlement` | Admin screen (admin) / Wallet screen (provider) |

## Migration from OneSignal

### Removed Files
- ❌ `lib/core/services/onesignal_service.dart`
- ❌ `ONESIGNAL_SETUP.md`

### Updated Files
- ✅ `pubspec.yaml` - Removed `onesignal_flutter`
- ✅ `main.dart` - Removed OneSignal initialization
- ✅ `auth_repository.dart` - Removed OneSignal login/logout
- ✅ `provider_wallet_screen.dart` - Updated to use FCM
- ✅ `tracking_screen.dart` - Updated to use FCM
- ✅ `chat_screen.dart` - Updated to use FCM
- ✅ `provider_orders_screen.dart` - Removed OneSignal import

## Testing FCM Notifications

### Using Firebase Console
1. Go to Firebase Console
2. Select your project
3. Navigate to Cloud Messaging
4. Click "Send your first message"
5. Enter title, body, and target (user segment or FCM token)
6. Send and test on device

### Using Supabase Edge Function
```sql
SELECT net.http_post(
  url := 'https://your-project.supabase.co/functions/v1/send-notification',
  headers := jsonb_build_object('Authorization', 'Bearer YOUR_JWT'),
  body := jsonb_build_object(
    'userId', 'user_id',
    'title', 'Test Notification',
    'body', 'This is a test',
    'type', 'test',
    'data', '{}'::jsonb
  )
);
```

## Troubleshooting

### Notifications Not Received
1. Check FCM token is saved in database
2. Verify Firebase project configuration
3. Check app has notification permissions
4. Test with Firebase Console first
5. Check Supabase Edge Function logs

### Sound Not Playing
1. Verify sound file exists in correct location
2. Check file format (MP3 for Android/iOS)
3. Test with default sound first

### iOS Not Working
1. Add `GoogleService-Info.plist` to `ios/Runner/`
2. Run `pod install` in `ios/` directory
3. Enable Push Notifications in Apple Developer Portal
4. Check APNs certificate configuration

## Build Status

✅ **Android**: Build successful (47.8 MB)
- Location: `build/app/outputs/flutter-apk/app-release.apk`
- Firebase plugin enabled
- google-services.json configured

⚠️ **iOS**: Needs GoogleService-Info.plist
- Podfile updated with Firebase pods
- Run `pod install` after adding GoogleService-Info.plist

## Next Steps

1. **iOS Setup**: Add `GoogleService-Info.plist` to `ios/Runner/`
2. **APNs Configuration**: Configure Apple Push Notification service
3. **Test Notifications**: Test FCM on both Android and iOS
4. **Edge Function**: Ensure Supabase Edge Function `send-notification` is deployed
5. **Production Keys**: Use production Firebase keys for release builds
