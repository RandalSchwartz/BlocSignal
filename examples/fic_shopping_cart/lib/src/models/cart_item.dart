import 'package:flutter/foundation.dart';

/// An immutable item in a shopping cart.
///
/// ```dart
/// const item = CartItem(
///   id: 'apple_1',
///   title: 'Honeycrisp Apple',
///   price: 1.99,
///   quantity: 3,
/// );
/// print(item.lineTotal); // 5.97
/// ```
@immutable
class CartItem {
  /// Creates an immutable [CartItem].
  const CartItem({
    required this.id,
    required this.title,
    required this.price,
    this.quantity = 1,
  });

  /// Unique identifier of the product.
  final String id;

  /// Display title of the product.
  final String title;

  /// Unit price in dollars.
  final double price;

  /// Quantity of this item in the cart.
  final int quantity;

  /// Total price for this line item ([price] multiplied by [quantity]).
  double get lineTotal => price * quantity;

  /// Returns a copy of this [CartItem] with the specified fields replaced.
  CartItem copyWith({
    String? id,
    String? title,
    double? price,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Converts this [CartItem] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'quantity': quantity,
    };
  }

  /// Parses a [CartItem] from a JSON map.
  static CartItem? fromJson(dynamic data) {
    if (data
        case {
          'id': final String id,
          'title': final String title,
          'price': final num price,
          'quantity': final int quantity,
        }) {
      return CartItem(
        id: id,
        title: title,
        price: price.toDouble(),
        quantity: quantity,
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          price == other.price &&
          quantity == other.quantity;

  @override
  int get hashCode => Object.hash(id, title, price, quantity);
}
