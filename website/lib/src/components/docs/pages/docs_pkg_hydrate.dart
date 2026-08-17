import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering state persistence with bloc_signals_hydrate.
class const DocsPkgHydratePage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'HydratedCubitSignal', anchor: 'hydrated-cubit'),
    TocHeading(title: 'HydratedBlocSignal', anchor: 'hydrated-bloc'),
    TocHeading(
      title: 'Zero-Override Primitives',
      anchor: 'primitive-hydration',
    ),
    TocHeading(title: 'Custom JSON Serialization', anchor: 'custom-json'),
    TocHeading(
      title: 'Storage Adapters & Security',
      anchor: 'storage-adapters',
    ),
    TocHeading(title: 'Clearing & Resetting State', anchor: 'clearing-state'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_hydrate')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Automatic, zero-flicker state persistence and hydration for CubitSignal and BlocSignal across app restarts and browser reloads.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_hydrate package integrates persistent storage engines into BlocSignal containers. '
            'Unlike asynchronous hydration schemes that trigger loading spinners or layout shifts on launch, '
            'bloc_signals_hydrate restores state synchronously during constructor execution, guaranteeing that '
            'widgets render hydrated state on the very first frame.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'pubspec.yaml',
          language: 'yaml',
          code: '''
dependencies:
  bloc_signals_hydrate: ^1.0.0
''',
        ),
        p([
          Component.text(
            'Initialize your storage adapter in main() before launching the application:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'main.dart',
          language: 'dart',
          code: '''
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences or custom storage engine
  HydratedStorage.storage = await SharedPreferencesHydratedStorage.create();

  runApp(const MyApp());
}''',
        ),
      ]),

      // 2. HydratedCubitSignal
      section(id: 'hydrated-cubit', classes: 'docs-section', [
        h2([Component.text('HydratedCubitSignal')]),
        p([
          Component.text('Extend '),
          apiLink(DocSymbol.hydratedCubitSignal),
          Component.text(
            ' instead of CubitSignal to gain automatic persistence. '
            'Every time emit() produces a new distinct state, the updated value is serialized and written to storage automatically.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/theme_cubit.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

enum AppTheme { light, dark, system }

class ThemeCubit extends HydratedCubitSignal<AppTheme> {
  ThemeCubit() : super(initialState: AppTheme.system);

  void toggleTheme() {
    emit(stateValue == AppTheme.dark ? AppTheme.light : AppTheme.dark);
  }

  @override
  AppTheme fromJson(Object? json) {
    if (json is String) {
      return AppTheme.values.firstWhere(
        (t) => t.name == json,
        orElse: () => AppTheme.system,
      );
    }
    return AppTheme.system;
  }

  @override
  Object? toJson(AppTheme state) => state.name;
}''',
          dart313Code: '''
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

enum AppTheme { light, dark, system }

class ThemeCubit() extends HydratedCubitSignal<AppTheme> {
  this() : super(initialState: AppTheme.system);

  void toggleTheme() {
    emit(stateValue == AppTheme.dark ? AppTheme.light : AppTheme.dark);
  }

  @override
  AppTheme fromJson(Object? json) {
    if (json is String) {
      return AppTheme.values.firstWhere(
        (t) => t.name == json,
        orElse: () => AppTheme.system,
      );
    }
    return AppTheme.system;
  }

  @override
  Object? toJson(AppTheme state) => state.name;
}''',
        ),
      ]),

      // 3. HydratedBlocSignal
      section(id: 'hydrated-bloc', classes: 'docs-section', [
        h2([Component.text('HydratedBlocSignal')]),
        p([
          Component.text('For event-driven state containers, extend '),
          apiLink(DocSymbol.hydratedBlocSignal),
          Component.text(
            '. State transitions triggered by incoming events persist automatically.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/counter_bloc.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

sealed class CounterEvent {}
final class Increment extends CounterEvent {}
final class Decrement extends CounterEvent {}

class CounterBloc extends HydratedBlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
    on<Decrement>((event, emit) => emit(stateValue - 1));
  }

  @override
  int fromJson(Object? json) => (json as num?)?.toInt() ?? 0;

  @override
  Object? toJson(int state) => state;
}''',
        ),
      ]),

      // 4. Zero-Override Primitives
      section(id: 'primitive-hydration', classes: 'docs-section', [
        h2([Component.text('Zero-Override Primitive & Collection Hydration')]),
        p([
          Component.text(
            'Because bloc_signals_hydrate accepts dynamic and Object? in serialization methods rather than requiring Map<String, dynamic>, '
            'standard Dart primitive types (int, double, String, bool) and collections (List<String>) hydrate directly without boilerplate:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/view_count_cubit.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

/// Primitives hydrate directly without creating custom Map wrappers.
class ViewCountCubit extends HydratedCubitSignal<int> {
  ViewCountCubit() : super(initialState: 0);

  void recordVisit() => emit(stateValue + 1);

  @override
  int fromJson(Object? json) => (json as num?)?.toInt() ?? 0;

  @override
  Object? toJson(int state) => state;
}''',
        ),
      ]),

      // 5. Custom JSON Serialization
      section(id: 'custom-json', classes: 'docs-section', [
        h2([Component.text('Custom JSON Serialization')]),
        p([
          Component.text(
            'For complex data classes and records, map states to and from standard JSON-encodable maps and lists:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/user_profile_cubit.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class UserProfile {
  const UserProfile({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String email;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

class UserProfileCubit extends HydratedCubitSignal<UserProfile?> {
  UserProfileCubit() : super(initialState: null);

  void updateProfile(UserProfile profile) => emit(profile);

  @override
  UserProfile? fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      return UserProfile.fromJson(json);
    }
    return null;
  }

  @override
  Object? toJson(UserProfile? state) => state?.toJson();
}''',
        ),
      ]),

      // 6. Storage Adapters & Security
      section(id: 'storage-adapters', classes: 'docs-section', [
        h2([Component.text('Storage Adapters & Security')]),
        p([
          Component.text(
            'bloc_signals_hydrate provides modular storage adapters for various security and platform requirements:',
          ),
        ]),
        ul([
          li([
            apiLink(DocSymbol.sharedPreferencesHydratedStorage),
            Component.text(
              ': Standard, lightweight local key-value persistence for mobile and web.',
            ),
          ]),
          li([
            apiLink(DocSymbol.secureHydratedStorage),
            Component.text(
              ': AES-encrypted storage powered by platform keychain and keystore services for sensitive auth tokens and credentials.',
            ),
          ]),
          li([
            strong([Component.text('InMemoryHydratedStorage')]),
            Component.text(
              ': Ephemeral in-memory storage designed for lightning-fast hermetic unit testing.',
            ),
          ]),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Testing Tip',
          children: [
            p([
              Component.text(
                'In unit tests, set HydratedStorage.storage = InMemoryHydratedStorage() in setUp() and clear it in tearDown() to ensure full isolation between test cases.',
              ),
            ]),
          ],
        ),
      ]),

      // 7. Clearing & Resetting State
      section(id: 'clearing-state', classes: 'docs-section', [
        h2([Component.text('Clearing & Resetting State')]),
        p([
          Component.text(
            'To clear persisted state on user logout or session reset, invoke clear(). '
            'This removes the persisted data from disk and resets the in-memory state to initialState without re-persisting the initial state back to storage.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/auth_cubit.dart',
          language: 'dart',
          code: '''
void onUserLogout() async {
  // Clears storage key and restores initialState synchronously
  await userProfileCubit.clear();
}''',
        ),
      ]),
    ]);
  }
}
