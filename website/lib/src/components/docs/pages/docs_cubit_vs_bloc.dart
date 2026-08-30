import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering the architectural comparison between CubitSignal and BlocSignal.
class const DocsCubitVsBlocPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Philosophy', anchor: 'overview-philosophy'),
    TocHeading(
      title: 'Architectural Comparison',
      anchor: 'architectural-comparison',
    ),
    TocHeading(title: 'When to Use CubitSignal', anchor: 'when-to-use-cubit'),
    TocHeading(title: 'When to Use BlocSignal', anchor: 'when-to-use-bloc'),
    TocHeading(title: 'Decision Matrix', anchor: 'decision-matrix'),
    TocHeading(title: 'Side-by-Side Example', anchor: 'side-by-side-example'),
    TocHeading(
      title: 'Composable Mixins (Single Inheritance)',
      anchor: 'composable-mixins',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🧠 Core Concepts')]),
        h1([Component.text('CubitSignal vs. BlocSignal')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Understand the fundamental tradeoffs between direct method invocation in CubitSignal and declarative, event-driven pipelines in BlocSignal.',
          ),
        ]),
      ]),

      // 1. Overview & Philosophy
      section(id: 'overview-philosophy', classes: 'docs-section', [
        h2([Component.text('Overview & Philosophy')]),
        p([
          Component.text('Both '),
          apiLink(DocSymbol.cubitSignal),
          Component.text(' and '),
          apiLink(DocSymbol.blocSignal),
          Component.text(' extend the same underlying state container, '),
          apiLink(DocSymbol.blocSignalBase),
          Component.text(
            '. They share identical reactive signal graph integration, 0ms synchronous state propagation, and observer traceability. '
            'The key distinction lies entirely in how mutations are initiated.',
          ),
        ]),
        DocsCallout(
          type: CalloutType.tip,
          title: 'Shared Signal Foundation',
          children: [
            p([
              Component.text('Because both classes extend '),
              apiLink(DocSymbol.blocSignalBase),
              Component.text(', UI widgets ('),
              apiLink(DocSymbol.blocSignalBuilder),
              Component.text(', '),
              apiLink(DocSymbol.blocSignalListener),
              Component.text(', '),
              apiLink(DocSymbol.contextSelect, label: 'context.select'),
              Component.text(
                ') interact with both Cubits and Blocs interchangeably. You can even migrate from CubitSignal to BlocSignal without changing a single line of widget code.',
              ),
            ]),
          ],
        ),
      ]),

      // 2. Architectural Comparison
      section(id: 'architectural-comparison', classes: 'docs-section', [
        h2([Component.text('Architectural Comparison')]),
        p([
          Component.text(
            'The primary architectural difference is the presence of an Event layer:',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            strong([Component.text('CubitSignal: ')]),
            Component.text(
              'Functions are exposed directly as public methods (for example, increment() or login()). '
              'State transitions occur immediately when the method executes emit().',
            ),
          ]),
          li([
            strong([Component.text('BlocSignal: ')]),
            Component.text(
              'UI components dispatch typed event objects via add(Event). '
              'Registered event handlers process events, coordinate concurrency through transformers, and invoke emit().',
            ),
          ]),
        ]),
      ]),

      // 3. When to Use CubitSignal
      section(id: 'when-to-use-cubit', classes: 'docs-section', [
        h2([Component.text('When to Use CubitSignal')]),
        p([
          Component.text(
            'CubitSignal is the recommended choice for the vast majority of application state management tasks. '
            'It provides minimal boilerplate, instant readability, and straightforward unit testing.',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            strong([Component.text('Simple UI State: ')]),
            Component.text(
              'Toggle switches, modals, theme pickers, tabs, and bottom navigation indices.',
            ),
          ]),
          li([
            strong([Component.text('Form Handling & Validation: ')]),
            Component.text(
              'Capturing input fields, validation rules, and submitting form payloads.',
            ),
          ]),
          li([
            strong([Component.text('Single-Action Async Operations: ')]),
            Component.text(
              'Fetching data from a REST endpoint where event transformations are not required.',
            ),
          ]),
        ]),
      ]),

      // 4. When to Use BlocSignal
      section(id: 'when-to-use-bloc', classes: 'docs-section', [
        h2([Component.text('When to Use BlocSignal')]),
        p([
          Component.text(
            'BlocSignal excels when complex asynchronous coordination, event queuing, or comprehensive audit logs are required.',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            strong([Component.text('Event Concurrency Control: ')]),
            Component.text(
              'When you need to drop duplicate button clicks (droppable), sequence incoming requests (sequential), or restart search queries (restartable).',
            ),
          ]),
          li([
            strong([Component.text('Strict Event Audit Trails: ')]),
            Component.text(
              'When compliance, analytics, or debugging requirements demand logging every discrete user intent before state computation begins.',
            ),
          ]),
          li([
            strong([Component.text('Complex Multi-Event Workflows: ')]),
            Component.text(
              'Multi-step checkout wizards, real-time gaming loops, and biometric authentication pipelines.',
            ),
          ]),
        ]),
      ]),

      // 5. Decision Matrix
      section(id: 'decision-matrix', classes: 'docs-section', [
        h2([Component.text('Decision Matrix')]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Feature / Requirement')]),
                th([Component.text('CubitSignal')]),
                th([Component.text('BlocSignal')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  strong([Component.text('Boilerplate Overhead')]),
                ]),
                td([Component.text('Minimal (Methods only)')]),
                td([Component.text('Moderate (Events + Handlers)')]),
              ]),
              tr([
                td([
                  strong([Component.text('Execution Style')]),
                ]),
                td([Component.text('Direct method call')]),
                td([Component.text('Dispatched event stream')]),
              ]),
              tr([
                td([
                  strong([Component.text('Concurrency Transformers')]),
                ]),
                td([Component.text('Manual async guards')]),
                td([
                  Component.text(
                    'Built-in (droppable, sequential, restartable)',
                  ),
                ]),
              ]),
              tr([
                td([
                  strong([Component.text('Event Audit Logging')]),
                ]),
                td([Component.text('Change transitions only')]),
                td([Component.text('Full onEvent + onTransition logging')]),
              ]),
              tr([
                td([
                  strong([Component.text('Learning Curve')]),
                ]),
                td([Component.text('Low & intuitive')]),
                td([Component.text('Medium')]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 6. Side-by-Side Example
      section(id: 'side-by-side-example', classes: 'docs-section', [
        h2([Component.text('Side-by-Side Example')]),
        p([
          Component.text(
            'Here is the same authentication state container implemented as both a CubitSignal and a BlocSignal:',
          ),
        ]),
        h3([Component.text('1. Implemented with CubitSignal')]),
        const DocsCodeBlock(
          filename: 'auth_cubit.dart',
          dart313Code: '''
sealed class AuthState;
final class AuthInitial extends AuthState;
final class AuthAuthenticated(final String username) extends AuthState;

class AuthCubit(final AuthRepository repository)
    extends CubitSignal<AuthState> {
  this : super(initialState: const AuthInitial());

  Future<void> login(String username, String password) async {
    final success = await repository.authenticate(username, password);
    if (success) {
      emit(AuthAuthenticated(username));
    }
  }

  void logout() => emit(const AuthInitial());
}''',
          dart35Code: '''
sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.username);
  final String username;
}

class AuthCubit extends CubitSignal<AuthState> {
  AuthCubit(this._repository) : super(initialState: const AuthInitial());

  final AuthRepository _repository;

  Future<void> login(String username, String password) async {
    final success = await _repository.authenticate(username, password);
    if (success) {
      emit(AuthAuthenticated(username));
    }
  }

  void logout() => emit(const AuthInitial());
}''',
        ),
        h3([Component.text('2. Implemented with BlocSignal')]),
        const DocsCodeBlock(
          filename: 'auth_bloc.dart',
          dart313Code: '''
sealed class AuthEvent;
final class AuthLoginRequested(final String username, final String password)
    extends AuthEvent;
final class AuthLogoutRequested extends AuthEvent;

class AuthBloc(final AuthRepository repository)
    extends BlocSignal<AuthEvent, AuthState> {
  this : super(initialState: const AuthInitial()) {
    on<AuthLoginRequested>((event, emit) async {
      final success = await repository.authenticate(event.username, event.password);
      if (success) {
        emit(AuthAuthenticated(event.username));
      }
    }, transformer: droppable());

    on<AuthLogoutRequested>((event, emit) => emit(const AuthInitial()));
  }
}''',
          dart35Code: '''
sealed class AuthEvent {}
final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested(this.username, this.password);
  final String username;
  final String password;
}
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthBloc extends BlocSignal<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(initialState: const AuthInitial()) {
    on<AuthLoginRequested>((event, emit) async {
      final success = await _repository.authenticate(event.username, event.password);
      if (success) {
        emit(AuthAuthenticated(event.username));
      }
    }, transformer: droppable());

    on<AuthLogoutRequested>((event, emit) => emit(const AuthInitial()));
  }

  final AuthRepository _repository;
}''',
        ),
      ]),

      // 7. Composable Mixins (Overcoming Single Inheritance)
      section(id: 'composable-mixins', classes: 'docs-section', [
        h2([
          Component.text('Composable Mixins (Overcoming Single Inheritance)'),
        ]),
        p([
          Component.text(
            'In Dart, a class can only extend a single superclass. In production applications, classes frequently inherit from an existing base class (such as Flutter’s ',
          ),
          code([Component.text('ChangeNotifier')]),
          Component.text(', '),
          code([Component.text('TextEditingController')]),
          Component.text(', '),
          code([Component.text('AnimationController')]),
          Component.text(', or a third-party/domain '),
          code([Component.text('BaseRepository')]),
          Component.text(
            '). Rather than writing wrapper boilerplate or refactoring your inheritance tree, use ',
          ),
          apiLink(DocSymbol.cubitSignalMixin),
          Component.text(' and '),
          apiLink(DocSymbol.blocSignalMixin),
          Component.text(
            ' to turn any class into a full reactive state container.',
          ),
        ]),
        DocsCallout(
          type: CalloutType.important,
          title: 'Full Ecosystem Polymorphism',
          children: [
            p([
              Component.text('Because '),
              apiLink(DocSymbol.cubitSignalMixin),
              Component.text(' implements '),
              apiLink(DocSymbol.blocSignalBase),
              Component.text(
                ', any class mixing it in is 100% compatible with ',
              ),
              apiLink(DocSymbol.blocSignalProvider),
              Component.text(', '),
              apiLink(DocSymbol.contextSelect, label: 'context.select'),
              Component.text(', and '),
              apiLink(DocSymbol.blocSignalTest),
              Component.text(' out of the box with zero glue code.'),
            ]),
          ],
        ),
        h3([
          Component.text('1. Mixing Cubit Capabilities into an Existing Class'),
        ]),
        p([
          Component.text(
            'Mix in CubitSignalMixin<State> and call initCubitSignal(initialState: ...) inside your constructor:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'user_repository.dart',
          dart313Code: '''
sealed class UserState;
final class UserInitial extends UserState;
final class UserLoading extends UserState;
final class UserLoaded(final User user) extends UserState;

class UserRepository(final ApiClient api) extends BaseRepository
    with CubitSignalMixin<UserState> {
  this {
    initCubitSignal(initialState: const UserInitial());
  }

  Future<void> fetchUser(String id) async {
    emit(const UserLoading());
    final user = await api.getUser(id);
    emit(UserLoaded(user));
  }
}''',
          dart35Code: '''
sealed class UserState {
  const UserState();
}

final class UserInitial extends UserState {
  const UserInitial();
}

final class UserLoading extends UserState {
  const UserLoading();
}

final class UserLoaded extends UserState {
  const UserLoaded(this.user);
  final User user;
}

class UserRepository extends BaseRepository
    with CubitSignalMixin<UserState> {
  UserRepository(this._api) {
    initCubitSignal(initialState: const UserInitial());
  }

  final ApiClient _api;

  Future<void> fetchUser(String id) async {
    emit(const UserLoading());
    final user = await _api.getUser(id);
    emit(UserLoaded(user));
  }
}''',
        ),
        h3([Component.text('2. Mixing BLoC Event Handling Capabilities')]),
        p([
          Component.text(
            'To add structured event handling with concurrency transformers, mix in both CubitSignalMixin and BlocSignalMixin:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'auth_service.dart',
          dart313Code: '''
class AuthService(final AuthApiClient authApi) extends BaseService
    with
        CubitSignalMixin<AuthState>,
        BlocSignalMixin<AuthEvent, AuthState> {
  this {
    initCubitSignal(initialState: const AuthInitial());

    on<AuthLoginRequested>((event, emit) async {
      emit(const AuthLoading());
      final user = await authApi.login(event.username, event.password);
      emit(AuthAuthenticated(user.name));
    }, transformer: droppable());

    on<AuthLogoutRequested>((event, emit) => emit(const AuthInitial()));
  }
}''',
          dart35Code: '''
class AuthService extends BaseService
    with
        CubitSignalMixin<AuthState>,
        BlocSignalMixin<AuthEvent, AuthState> {
  AuthService(this._authApi) {
    initCubitSignal(initialState: const AuthInitial());

    on<AuthLoginRequested>((event, emit) async {
      emit(const AuthLoading());
      final user = await _authApi.login(event.username, event.password);
      emit(AuthAuthenticated(user.name));
    }, transformer: droppable());

    on<AuthLogoutRequested>((event, emit) => emit(const AuthInitial()));
  }

  final AuthApiClient _authApi;
}''',
        ),
        h3([Component.text('3. DRY Core Architecture')]),
        p([
          Component.text(
            'Under the hood, CubitSignal and BlocSignal themselves compose CubitSignalMixin and BlocSignalMixin as their single source of truth. '
            'Whether extending the standard base classes or mixing them into existing superclasses, the performance, signal graphs, and event lifecycles are identical.',
          ),
        ]),
      ]),
    ]);
  }
}
