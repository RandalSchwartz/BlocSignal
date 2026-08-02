import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

sealed class CartEvent {
  const CartEvent();
}

final class CartStarted extends CartEvent {
  const CartStarted();
}

final class CartItemAdded extends CartEvent {
  const CartItemAdded(this.item);
  final Item item;
}

final class CartItemRemoved extends CartEvent {
  const CartItemRemoved(this.item);
  final Item item;
}

@immutable
sealed class CartState {
  const CartState();
}

final class CartLoading extends CartState {
  const CartLoading();
}

final class CartLoaded extends CartState {
  const CartLoaded(this.cart);
  final Cart cart;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartLoaded &&
          runtimeType == other.runtimeType &&
          cart == other.cart;

  @override
  int get hashCode => cart.hashCode;
}

final class CartError extends CartState {
  const CartError(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

class CartBloc extends BlocSignal<CartEvent, CartState> {
  CartBloc() : super(initialState: const CartLoading()) {
    on<CartStarted>((event, emit) {
      emit(const CartLoaded(Cart()));
    });

    on<CartItemAdded>((event, emit) {
      if (stateValue case CartLoaded(:final cart)) {
        emit(CartLoaded(cart.addItem(event.item)));
      }
    });

    on<CartItemRemoved>((event, emit) {
      if (stateValue case CartLoaded(:final cart)) {
        emit(CartLoaded(cart.removeItem(event.item)));
      }
    });
  }
}
