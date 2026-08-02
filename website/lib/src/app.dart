import 'dart:js_interop';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;
import 'pages/home_page.dart';
import 'pages/ported_examples_page.dart';
import 'pages/showcase_page.dart';

class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String _currentPath = '/';

  @override
  void initState() {
    super.initState();
    _updatePath();
    web.window.onpopstate = ((web.Event _) {
      setState(_updatePath);
    }).toJS;
    web.window.onhashchange = ((web.Event _) {
      setState(_updatePath);
    }).toJS;
  }

  void _updatePath() {
    final path = web.window.location.pathname;
    final rawHash = web.window.location.hash.toLowerCase();

    if (path == '/showcase' ||
        path.startsWith('/showcase') ||
        rawHash.contains('showcase')) {
      _currentPath = '/showcase';
    } else if (path == '/ported-examples' ||
        path.startsWith('/ported-examples') ||
        rawHash.contains('ported-examples') ||
        rawHash.contains('ported')) {
      _currentPath = '/ported-examples';
    } else {
      _currentPath = '/';
    }
  }

  @override
  Component build(BuildContext context) {
    switch (_currentPath) {
      case '/showcase':
        return const ShowcasePage();
      case '/ported-examples':
        return const PortedExamplesPage();
      case '/':
      default:
        return const HomePage();
    }
  }
}
