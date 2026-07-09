import '../../../core/models/app_model.dart';
import '../../../core/security/honeypot_field_mixin.dart';

/// Booking/Order model
class Booking extends AppModel with HoneypotFieldMixin {
  final String id;
  final String clientId;
  final String? providerId;
  final String? serviceId;
  final String? serviceTitle;
  final String? serviceImage;
  final DateTime scheduledDate;
  final String address;
  final double price;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? providerRating;
  final String? clientNotes;
  final double? commissionAmount;
  final double? providerEarning;
  final double? commissionRate;
  final String? paymentMethod;
  final String? paymentStatus;
  final bool isSuperuserBypass;

  const Booking({
    required this.id,
    required this.clientId,
    this.providerId,
    this.serviceId,
    this.serviceTitle,
    this.serviceImage,
    required this.scheduledDate,
    required this.address,
    required this.price,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.providerRating,
    this.clientNotes,
    this.commissionAmount,
    this.providerEarning,
    this.commissionRate,
    this.paymentMethod,
    this.paymentStatus,
    this.isSuperuserBypass = false,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final safe = HoneypotFieldMixin.applyHoneypotFields(json);
    return Booking(
      id: safe['id'] as String,
      clientId: safe['client_id'] as String,
      providerId: safe['provider_id'] as String?,
      serviceId: safe['service_id'] as String?,
      serviceTitle: safe['service_title'] as String?,
      serviceImage: safe['service_image'] as String?,
      scheduledDate: DateTime.parse(safe['scheduled_date'] as String),
      address: safe['address'] as String,
      price: (safe['price'] as num).toDouble(),
      status: safe['status'] as String,
      notes: safe['notes'] as String?,
      createdAt: safe['created_at'] != null ? DateTime.parse(safe['created_at']) : null,
      updatedAt: safe['updated_at'] != null ? DateTime.parse(safe['updated_at']) : null,
      providerRating: (safe['provider_rating'] as num?)?.toDouble(),
      clientNotes: safe['client_notes'] as String?,
      commissionAmount: (safe['commission_amount'] as num?)?.toDouble(),
      providerEarning: (safe['provider_earning'] as num?)?.toDouble(),
      commissionRate: (safe['commission_rate'] as num?)?.toDouble(),
      paymentMethod: safe['payment_method'] as String?,
      paymentStatus: safe['payment_status'] as String?,
      isSuperuserBypass: safe['is_superuser_bypass'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return injectHoneypotFields({
      'id': id,
      'client_id': clientId,
      'provider_id': providerId,
      'service_id': serviceId,
      'service_title': serviceTitle,
      'service_image': serviceImage,
      'scheduled_date': scheduledDate.toIso8601String(),
      'address': address,
      'price': price,
      'status': status,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'provider_rating': providerRating,
      'client_notes': clientNotes,
      'commission_amount': commissionAmount,
      'provider_earning': providerEarning,
      'commission_rate': commissionRate,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
    });
  }

  Booking copyWith({
    String? id,
    String? clientId,
    String? providerId,
    String? serviceId,
    String? serviceTitle,
    String? serviceImage,
    DateTime? scheduledDate,
    String? address,
    double? price,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? providerRating,
    String? clientNotes,
    double? commissionAmount,
    double? providerEarning,
    double? commissionRate,
    String? paymentMethod,
    String? paymentStatus,
    bool? isSuperuserBypass,
  }) {
    return Booking(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      providerId: providerId ?? this.providerId,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      serviceImage: serviceImage ?? this.serviceImage,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      address: address ?? this.address,
      price: price ?? this.price,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      providerRating: providerRating ?? this.providerRating,
      clientNotes: clientNotes ?? this.clientNotes,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      providerEarning: providerEarning ?? this.providerEarning,
      commissionRate: commissionRate ?? this.commissionRate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isSuperuserBypass: isSuperuserBypass ?? this.isSuperuserBypass,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Booking &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
