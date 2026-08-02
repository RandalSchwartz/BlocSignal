import 'package:flutter/foundation.dart';

@immutable
class Item {
  const Item({required this.id, required this.name, required this.price});

  final int id;
  final String name;
  final double price;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          price == other.price;

  @override
  int get hashCode => Object.hash(id, name, price);

  @override
  String toString() => 'Item(id: $id, name: $name, price: \$$price)';
}

@immutable
class Cart {
  const Cart({this.items = const []});

  final List<Item> items;

  double get totalPrice => items.fold(0, (sum, item) => sum + item.price);
  int get itemCount => items.length;

  Cart addItem(Item item) => Cart(items: [...items, item]);
  Cart removeItem(Item item) => Cart(items: [...items]..remove(item));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cart &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(items);
}
