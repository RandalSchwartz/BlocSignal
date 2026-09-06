import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../models/cart_item.dart';

/// Zero-boilerplate composite state using Dart 3 records and FIC [IMap].
///
/// Combines an immutable map of [items] indexed by product ID, an optional
/// [promoCode] discount string, and a checkout status flag [isCheckingOut].
///
/// ```dart
/// const ShoppingCartState state = (
///   items: IMap.empty(),
///   promoCode: null,
///   isCheckingOut: false,
/// );
/// ```
typedef ShoppingCartState = ({
  IMap<String, CartItem> items,
  String? promoCode,
  bool isCheckingOut,
});
