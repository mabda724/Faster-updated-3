import 'package:flutter/material.dart';
import 'supabase_service.dart';

/// Smart Delivery Fee Calculator
/// 
/// Calculates delivery fees with the following rules:
/// 1. Base fee = max(min_fee, distance_km * price_per_km)
/// 2. FREE delivery if items_total >= 200 EGP
/// 3. CAP delivery fee at (items_total * max_ratio) if fee > ratio
/// 4. If fee > items_total, warn customer and cap at 50% of items_total
/// 
/// This prevents the "delivery costs more than product" problem.
class DeliveryFeeService {
  /// Calculate smart delivery fee
  /// 
  /// Returns a [SmartDeliveryResult] with fee details and warnings.
  static Future<SmartDeliveryResult> calculateFee({
    required double itemsTotal,
    required double distanceKm,
  }) async {
    try {
      final result = await SupabaseService.db.rpc(
        'calculate_smart_delivery_fee',
        params: {
          'p_distance_km': distanceKm,
          'p_items_total': itemsTotal,
        },
      );

      return SmartDeliveryResult(
        deliveryFee: double.tryParse(result['delivery_fee']?.toString() ?? '0') ?? 0,
        rawFee: double.tryParse(result['raw_fee']?.toString() ?? '0') ?? 0,
        itemsTotal: itemsTotal,
        distanceKm: distanceKm,
        feeType: result['fee_type'] ?? 'normal',
        feeNotes: result['notes'] ?? '',
        pricePerKm: double.tryParse(result['price_per_km']?.toString() ?? '2.5') ?? 2.5,
      );
    } catch (e) {
      debugPrint('Error calculating delivery fee: $e');
      // Fallback calculation
      double rawFee = distanceKm * 2.5;
      double finalFee = rawFee;
      String feeType = 'normal';
      String notes = '';

      if (itemsTotal >= 200) {
        finalFee = 0;
        feeType = 'free_delivery';
        notes = 'توصيل مجاني لأن قيمة الطلب 200 ج.م أو أكثر';
      } else if (itemsTotal > 0 && rawFee > itemsTotal * 0.8) {
        finalFee = itemsTotal * 0.8;
        feeType = 'capped';
        notes = 'الرسوم تقليلت تلقائياً لتكون أقل من قيمة الطلب';
      } else if (itemsTotal > 0 && rawFee > itemsTotal) {
        finalFee = itemsTotal * 0.5;
        feeType = 'capped';
        notes = 'رسوم التوصيل لا يمكن أن تتجاوز قيمة الطلب';
      }

      return SmartDeliveryResult(
        deliveryFee: finalFee,
        rawFee: rawFee,
        itemsTotal: itemsTotal,
        distanceKm: distanceKm,
        feeType: feeType,
        feeNotes: notes,
        pricePerKm: 2.5,
      );
    }
  }

  /// Quick local calculation without network call (use with cached settings)
  static SmartDeliveryResult calculateFeeSync({
    required double itemsTotal,
    required double distanceKm,
    double minFee = 15.0,
    double pricePerKm = 2.5,
    double maxFeeRatio = 0.8,
    double freeDeliveryThreshold = 200.0,
  }) {
    double rawFee = distanceKm * pricePerKm;
    double finalFee = rawFee < minFee ? minFee : rawFee;
    String feeType = 'normal';
    String notes = '';

    if (itemsTotal >= freeDeliveryThreshold) {
      finalFee = 0;
      feeType = 'free_delivery';
      notes = 'توصيل مجاني لأن قيمة الطلب ${freeDeliveryThreshold.toStringAsFixed(0)} ج.م أو أكثر 🎉';
    } else if (itemsTotal > 0 && finalFee > (itemsTotal * maxFeeRatio)) {
      finalFee = itemsTotal * maxFeeRatio;
      feeType = 'capped';
      notes = 'الرسوم تقليلت تلقائياً من ${rawFee.toStringAsFixed(0)} إلى ${finalFee.toStringAsFixed(0)} ج.م';
    } else if (itemsTotal > 0 && finalFee > itemsTotal) {
      finalFee = itemsTotal * 0.5;
      feeType = 'capped';
      notes = 'رسوم التوصيل لا يمكن أن تتجاوز قيمة الطلب';
    }

    return SmartDeliveryResult(
      deliveryFee: finalFee,
      rawFee: rawFee,
      itemsTotal: itemsTotal,
      distanceKm: distanceKm,
      feeType: feeType,
      feeNotes: notes,
      pricePerKm: pricePerKm,
    );
  }
}

class SmartDeliveryResult {
  final double deliveryFee;
  final double rawFee;
  final double itemsTotal;
  final double distanceKm;
  final String feeType;
  final String feeNotes;
  final double pricePerKm;

  SmartDeliveryResult({
    required this.deliveryFee,
    required this.rawFee,
    required this.itemsTotal,
    required this.distanceKm,
    required this.feeType,
    required this.feeNotes,
    required this.pricePerKm,
  });

  /// Whether this is a free delivery
  bool get isFree => feeType == 'free_delivery';

  /// Whether the fee was capped
  bool get isCapped => feeType == 'capped';

  /// Whether this result had a warning (fee capped or close to items total)
  bool get hasWarning => isCapped || deliveryFee > itemsTotal * 0.6;

  /// Total amount to pay (if used in checkout)
  double get totalAmount => itemsTotal + deliveryFee;

  /// Warning text for the customer
  String? get warningText {
    if (isFree) return null;
    if (feeType == 'capped') return feeNotes;
    if (deliveryFee > itemsTotal * 0.6) {
      return 'رسوم التوصيل (${deliveryFee.toStringAsFixed(0)} ج.م) قريبة من قيمة الطلب - هذا طلب عادي مقبول';
    }
    return null;
  }
}
