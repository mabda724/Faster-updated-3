import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_paymob_sdk/flutter_paymob_sdk.dart';
import 'package:talker/talker.dart';

import 'supabase_service.dart';

/// Result wrapper that includes both the SDK result and the Paymob order ID
class PaymentResult {
  final bool isSuccessful;
  final bool isPending;
  final bool isRejected;
  final String orderId;
  final Map<String, dynamic>? transactionDetails;
  final String? errorMessage;

  PaymentResult({
    required this.isSuccessful,
    required this.isPending,
    required this.isRejected,
    required this.orderId,
    this.transactionDetails,
    this.errorMessage,
  });
}

class PaymobServiceWrapper {
  static final _talker = Talker();
  static final _service = PaymobService();

  /// Secure Mode without a local server.
  /// A Supabase Edge Function creates the Paymob client_secret using secrets
  /// stored in Supabase, then the app launches the Paymob SDK.
  static Future<PaymentResult> pay({
    required int amount,
    required String userId,
    required String fullName,
    required String email,
    required String phone,
    String paymentMethod = 'card',
    String appName = 'Faster',
    Color? buttonColor,
  }) async {
    try {
      final response = await SupabaseService.db.functions
          .invoke(
            'paymob-create-intention',
            body: {
              'amount': amount * 100,
              'user_id': userId,
              'full_name': fullName,
              'email': email,
              'phone': phone,
              'payment_method': paymentMethod,
            },
          )
          .timeout(const Duration(seconds: 20));

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : Map<String, dynamic>.from(response.data as Map);

      if (response.status != 200 || data['success'] != true) {
        throw Exception(
          data['error'] ?? data['details'] ?? 'فشل تجهيز عملية الدفع',
        );
      }

      final orderId = data['order_id']?.toString() ?? '';

      final sdkResult = await _service.payWithPaymob(
        publicKey: data['public_key'],
        clientSecret: data['client_secret'],
        customization: PaymobCustomization(
          appName: appName,
          buttonBackgroundColor: buttonColor ?? const Color(0xFF6366F1),
          buttonTextColor: Colors.white,
          showSaveCard: true,
        ),
      );

      // Extract transaction details and error message from SDK result if available
      Map<String, dynamic>? transactionDetails;
      String? errorMessage;

      try {
        // Try to get transaction details using common field names
        final sdkDynamic = sdkResult as dynamic;
        if (sdkDynamic.transactionDetails != null) {
          transactionDetails = Map<String, dynamic>.from(sdkDynamic.transactionDetails);
        } else if (sdkDynamic.transaction != null) {
          transactionDetails = Map<String, dynamic>.from(sdkDynamic.transaction);
        } else if (sdkDynamic.data != null) {
          transactionDetails = Map<String, dynamic>.from(sdkDynamic.data);
        }

        // Try to get error message from common field names
        if (sdkDynamic.errorMessage != null) {
          errorMessage = sdkDynamic.errorMessage?.toString();
        } else if (sdkDynamic.error != null) {
          errorMessage = sdkDynamic.error?.toString();
        } else if (sdkDynamic.message != null) {
          errorMessage = sdkDynamic.message?.toString();
        }
      } catch (_) {
        // Ignore extraction errors, fields will remain null
      }

      return PaymentResult(
        isSuccessful: sdkResult.isSuccessful,
        isPending: sdkResult.isPending,
        isRejected: sdkResult.isRejected,
        orderId: orderId,
        transactionDetails: transactionDetails,
        errorMessage: errorMessage,
      );
    } catch (e, stack) {
      _talker.handle(e, stack, 'Paymob Native UI Error');
      rethrow;
    }
  }
}
