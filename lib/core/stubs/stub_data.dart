class StubData {
  StubData._();

  static final List<Map<String, dynamic>> stubUsers = [
    {
      'id': 'usr-001',
      'full_name': 'أحمد محمد',
      'email': 'ahmed@mail.local',
      'phone': '+201001234567',
      'role': 'client',
      'avatar_url': 'https://i.pravatar.cc/150?u=ahmed',
      'is_verified': true,
    },
    {
      'id': 'usr-002',
      'full_name': 'سارة خالد',
      'email': 'sara@mail.local',
      'phone': '+201007654321',
      'role': 'provider',
      'avatar_url': 'https://i.pravatar.cc/150?u=sara',
      'is_verified': true,
    },
    {
      'id': 'usr-admin',
      'full_name': 'مشرف النظام',
      'email': 'admin@mail.local',
      'phone': '+201009998888',
      'role': 'admin',
      'avatar_url': 'https://i.pravatar.cc/150?u=admin',
      'is_verified': true,
    },
  ];

  static final List<Map<String, dynamic>> stubServices = [
    {'id': 'svc-1', 'name_ar': 'سباكة', 'name_en': 'Plumbing', 'icon': '🔧', 'sort_order': 1},
    {'id': 'svc-2', 'name_ar': 'كهرباء', 'name_en': 'Electrical', 'icon': '⚡', 'sort_order': 2},
    {'id': 'svc-3', 'name_ar': 'تنظيف', 'name_en': 'Cleaning', 'icon': '🧹', 'sort_order': 3},
    {'id': 'svc-4', 'name_ar': 'نقل عفش', 'name_en': 'Moving', 'icon': '🚚', 'sort_order': 4},
    {'id': 'svc-5', 'name_ar': 'دهان', 'name_en': 'Painting', 'icon': '🎨', 'sort_order': 5},
    {'id': 'svc-6', 'name_ar': 'توصيل', 'name_en': 'Delivery', 'icon': '📦', 'sort_order': 6},
    {'id': 'svc-7', 'name_ar': 'حدادة', 'name_en': 'Blacksmith', 'icon': '⚒️', 'sort_order': 7},
    {'id': 'svc-8', 'name_ar': 'نجارة', 'name_en': 'Carpentry', 'icon': '🪵', 'sort_order': 8},
  ];

  static final List<Map<String, dynamic>> stubBookings = [
    {
      'id': 'bkg-001',
      'client_name': 'أحمد محمد',
      'service_name': 'سباكة',
      'status': 'pending',
      'price': 150.0,
      'date': '2024-12-15T10:00:00',
      'location': 'الغردقة، حي الدهار',
    },
    {
      'id': 'bkg-002',
      'client_name': 'نورة أحمد',
      'service_name': 'تنظيف',
      'status': 'confirmed',
      'price': 200.0,
      'date': '2024-12-16T14:00:00',
      'location': 'الغردقة، شارع النيل',
    },
    {
      'id': 'bkg-003',
      'client_name': 'خالد عمر',
      'service_name': 'كهرباء',
      'status': 'completed',
      'price': 300.0,
      'date': '2024-12-10T09:00:00',
      'location': 'الغردقة، حي مبارك 2',
    },
  ];

  static final List<Map<String, dynamic>> stubNotifications = [
    {'id': 'notif-1', 'title': 'تم تأكيد الحجز', 'body': 'تم تأكيد حجز خدمة السباكة', 'type': 'info', 'is_read': false},
    {'id': 'notif-2', 'title': 'عرض جديد', 'body': 'خصم 20% على خدمات التنظيف', 'type': 'offer', 'is_read': false},
    {'id': 'notif-3', 'title': 'تم اكتمال الخدمة', 'body': 'يرجى تقييم الخدمة المقدمة', 'type': 'rating', 'is_read': true},
  ];

  static final List<Map<String, dynamic>> stubChatMessages = [
    {'id': 'msg-1', 'sender_id': 'usr-001', 'text': 'السلام عليكم، متى يمكنكم الحضور؟', 'time': '10:30 AM'},
    {'id': 'msg-2', 'sender_id': 'usr-002', 'text': 'وعليكم السلام، يمكننا الحضور غداً الساعة 10 صباحاً', 'time': '10:31 AM'},
    {'id': 'msg-3', 'sender_id': 'usr-001', 'text': 'تمام، الموعد مناسب', 'time': '10:32 AM'},
  ];

  static final List<Map<String, dynamic>> stubWalletTransactions = [
    {'id': 'txn-1', 'type': 'deposit', 'amount': 500.0, 'description': 'إيداع رصيد', 'date': '2024-12-01'},
    {'id': 'txn-2', 'type': 'withdrawal', 'amount': 150.0, 'description': 'سحب رصيد', 'date': '2024-12-05'},
    {'id': 'txn-3', 'type': 'payment', 'amount': 200.0, 'description': 'دفع مقابل خدمة', 'date': '2024-12-10'},
  ];

  static final Map<String, dynamic> stubStats = {
    'total_users': 1250,
    'active_providers': 85,
    'total_bookings': 3420,
    'completed_orders': 3100,
    'revenue_total': 285000.0,
    'avg_rating': 4.3,
  };
}
