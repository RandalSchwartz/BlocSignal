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
  bloc_signals: ^1.10.0
  bloc_signals_hydrate: ^1.2.0
  shared_preferences: ^2.3.0
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
  final prefs = await SharedPreferences.getInstance();
  HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);

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
  this : super(initialState: AppTheme.system);

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
              ': Lightweight local key-value persistence for mobile and web. Defaults to the ',
            ),
            apiLink(DocSymbol.kDefaultHydratedStoragePrefix),
            Component.text(
              " prefix ('bloc_signals_hydrate_') to isolate persisted state from app preferences (pass prefix: '' to opt out for legacy keys). ",
            ),
            strong([Component.text('Plaintext Warning: ')]),
            Component.text(
              'SharedPreferences stores unencrypted XML/plist/localStorage data; use SecureHydratedStorage for tokens, credentials, or personal data.',
            ),
          ]),
          li([
            apiLink(DocSymbol.secureHydratedStorage),
            Component.text(
              ': AES-encrypted storage powered by platform keychain and keystore services for sensitive auth tokens and credentials. ',
            ),
            Component.text(
              'Deep-clones cached Map and List collections on read and write so in-place caller mutations never corrupt cached storage.',
            ),
          ]),
          li([
            apiLink(DocSymbol.memoryHydratedStorage),
            Component.text(
              ': Ephemeral in-memory storage designed for hermetic unit testing, isolating cached Map and List collections with deep JSON cloning.',
            ),
          ]),
        ]),
        p([
          Component.text(
            'When an id is set, HydratedMixin.storageToken percent-encodes storagePrefix and id via Uri.encodeComponent joined by ":" to prevent separator collisions. '
            'Override storagePrefix with a stable string literal in release web/obfuscated builds where runtimeType.toString() is minified, '
            'and deserialization FormatExceptions omit raw stored JSON payloads (source == null) while rejecting corrupt SecureHydratedStorage entries instead of caching raw strings. '
            'initHydratedState and storage I/O boundaries isolate recoverable deserialization errors and non-Error platform objects via onError() while keeping fatal VM Errors fail-fast. '
            'For application-level payload encryption, size bounding, and schema evolution, override ',
          ),
          apiLink(DocSymbol.hydratedCipher, label: 'cipher (HydratedCipher)'),
          Component.text(', '),
          code([Component.text('maxPayloadBytes')]),
          Component.text(', and '),
          code([Component.text('storageVersion')]),
          Component.text(' + '),
          code([Component.text('migrate(json, fromVersion)')]),
          Component.text(' directly on your hydrated container.'),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Testing Tip',
          children: [
            p([
              Component.text(
                'In unit tests, set HydratedStorage.storage = MemoryHydratedStorage() in setUp() and clear it in tearDown() to ensure full isolation between test cases.',
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
            'This removes the persisted data from disk and executes ',
          ),
          apiLink(DocSymbol.blocSignalOnReset),
          Component.text(' and '),
          apiLink(DocSymbol.blocSignalRunWithoutHistory),
          Component.text(
            ' inside batch() to reset the in-memory state to initialState atomically without re-persisting or polluting composed ReplayMixin history stacks. '
            'Similarly, cold-boot hydrate() wraps restoration in ',
          ),
          apiLink(DocSymbol.blocSignalRunWithoutHistory),
          Component.text(
            ' regardless of mixin composition order. '
            'Storage persist() and clear() operations are serialized through a per-instance FIFO Mutex with generation tombstones so concurrent async writes cannot resurrect state cleared mid-flight.',
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
