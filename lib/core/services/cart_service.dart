import 'dart:async';

class CartItem {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String unit;
  final String merchantId;
  final String merchantName;
  int quantity;

  double get totalPrice => price * quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.unit = '1 كجم',
    required this.merchantId,
    required this.merchantName,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'image_url': imageUrl,
        'unit': unit,
        'merchant_id': merchantId,
        'merchant_name': merchantName,
        'quantity': quantity,
      };
}

class CartService {
  CartService._();
  static final CartService _instance = CartService._();
  factory CartService() => _instance;

  final Map<String, CartItem> _items = {};
  final _ctrl = StreamController<Map<String, CartItem>>.broadcast();

  Stream<Map<String, CartItem>> get stream => _ctrl.stream;
  Map<String, CartItem> get items => Map.unmodifiable(_items);
  int get count => _items.values.fold(0, (s, i) => s + i.quantity);
  double get total => _items.values.fold(0.0, (s, i) => s + i.totalPrice);
  bool get isEmpty => _items.isEmpty;

  void add(CartItem item) {
    final key = item.id;
    if (_items.containsKey(key)) {
      _items[key]!.quantity += item.quantity;
    } else {
      _items[key] = item;
    }
    _emit();
  }

  void remove(String id) {
    _items.remove(id);
    _emit();
  }

  void updateQuantity(String id, int qty) {
    if (qty <= 0) {
      _items.remove(id);
    } else if (_items.containsKey(id)) {
      _items[id]!.quantity = qty;
    }
    _emit();
  }

  void clear() {
    _items.clear();
    _emit();
  }

  void _emit() => _ctrl.add(Map.from(_items));

  void dispose() => _ctrl.close();
}
