import 'package:bloc_signals/bloc_signals.dart';
import '../models/models.dart';

class CatalogCubit extends CubitSignal<List<Item>> {
  CatalogCubit() : super(initialState: _catalogItems);

  static const List<Item> _catalogItems = [
    Item(id: 1, name: 'Code With Dart', price: 42.0),
    Item(id: 2, name: 'Flutter In Action', price: 35.0),
    Item(id: 3, name: 'BlocSignal Masterclass', price: 49.99),
    Item(id: 4, name: 'Reactive Systems Handbook', price: 29.50),
    Item(id: 5, name: 'OpenTelemetry Observability', price: 39.00),
  ];

  void loadCatalog() {
    emit(_catalogItems);
  }
}
