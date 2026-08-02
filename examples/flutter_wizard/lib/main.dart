import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Wizard Form State.
@immutable
class WizardState {
  const WizardState({
    this.currentStep = 0,
    this.username = '',
    this.email = '',
    this.fullName = '',
    this.bio = '',
    this.isSubmitted = false,
  });

  final int currentStep;
  final String username;
  final String email;
  final String fullName;
  final String bio;
  final bool isSubmitted;

  WizardState copyWith({
    int? currentStep,
    String? username,
    String? email,
    String? fullName,
    String? bio,
    bool? isSubmitted,
  }) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WizardState &&
          runtimeType == other.runtimeType &&
          currentStep == other.currentStep &&
          username == other.username &&
          email == other.email &&
          fullName == other.fullName &&
          bio == other.bio &&
          isSubmitted == other.isSubmitted;

  @override
  int get hashCode =>
      currentStep.hashCode ^
      username.hashCode ^
      email.hashCode ^
      fullName.hashCode ^
      bio.hashCode ^
      isSubmitted.hashCode;
}

/// Sealed class representing all wizard events.
sealed class WizardEvent {
  const WizardEvent();
}

final class WizardStepChanged extends WizardEvent {
  const WizardStepChanged(this.step);
  final int step;
}

final class AccountInfoUpdated extends WizardEvent {
  const AccountInfoUpdated({required this.username, required this.email});
  final String username;
  final String email;
}

final class ProfileInfoUpdated extends WizardEvent {
  const ProfileInfoUpdated({required this.fullName, required this.bio});
  final String fullName;
  final String bio;
}

final class WizardSubmitted extends WizardEvent {
  const WizardSubmitted();
}

final class WizardReset extends WizardEvent {
  const WizardReset();
}

/// Instructive Example: [WizardBlocSignal]
///
/// Orchestrates a multi-step registration wizard using `computed()` step validation signals.
///
/// **Educational Key Takeaway**:
/// - `isStep1Valid`, `isStep2Valid`, and `canSubmit` update reactively on frame 1 as fields change.
/// - Allows the Stepper widget to evaluate step completion states cleanly without manual boolean checks.
class WizardBlocSignal extends BlocSignal<WizardEvent, WizardState> {
  WizardBlocSignal() : super(initialState: const WizardState()) {
    on<WizardStepChanged>(_onStepChanged);
    on<AccountInfoUpdated>(_onAccountUpdated);
    on<ProfileInfoUpdated>(_onProfileUpdated);
    on<WizardSubmitted>(_onSubmitted);
    on<WizardReset>(_onReset);

    // Step validation computed projections
    isStep1Valid = computed(() {
      final s = stateValue;
      return s.username.trim().length >= 3 &&
          s.email.contains('@') &&
          s.email.contains('.');
    });

    isStep2Valid = computed(() {
      final s = stateValue;
      return s.fullName.trim().isNotEmpty && s.bio.trim().length >= 5;
    });

    canSubmit = computed(() => isStep1Valid.value && isStep2Valid.value);
  }

  /// Reactive computed signal checking if Step 1 (username & email) is valid.
  late final ReadonlySignal<bool> isStep1Valid;

  /// Reactive computed signal checking if Step 2 (fullName & bio) is valid.
  late final ReadonlySignal<bool> isStep2Valid;

  /// Reactive computed signal checking if all required wizard steps are complete for submission.
  late final ReadonlySignal<bool> canSubmit;

  void _onStepChanged(WizardStepChanged event, void Function(WizardState) emit) {
    if (event.step >= 0 && event.step <= 2) {
      emit(stateValue.copyWith(currentStep: event.step));
    }
  }

  void _onAccountUpdated(
      AccountInfoUpdated event, void Function(WizardState) emit) {
    emit(stateValue.copyWith(username: event.username, email: event.email));
  }

  void _onProfileUpdated(
      ProfileInfoUpdated event, void Function(WizardState) emit) {
    emit(stateValue.copyWith(fullName: event.fullName, bio: event.bio));
  }

  void _onSubmitted(WizardSubmitted event, void Function(WizardState) emit) {
    if (canSubmit.value) {
      emit(stateValue.copyWith(isSubmitted: true));
    }
  }

  void _onReset(WizardReset event, void Function(WizardState) emit) {
    emit(const WizardState());
  }
}

void main() {
  runApp(const WizardApp());
}

class WizardApp extends StatelessWidget {
  const WizardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlocSignal Wizard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<WizardBlocSignal>(
        create: (_) => WizardBlocSignal(),
        child: const WizardPage(),
      ),
    );
  }
}

class WizardPage extends StatelessWidget {
  const WizardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<WizardBlocSignal>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Wizard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => bloc.add(const WizardReset()),
          ),
        ],
      ),
      body: BlocSignalBuilder<WizardBlocSignal, WizardState>(
        builder: (context, state) {
          if (state.isSubmitted) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 80),
                  const SizedBox(height: 16),
                  Text('Welcome, ${state.fullName}!',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Username: ${state.username} | Email: ${state.email}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => bloc.add(const WizardReset()),
                    child: const Text('Start Over'),
                  ),
                ],
              ),
            );
          }

          return Stepper(
            currentStep: state.currentStep,
            onStepTapped: (step) => bloc.add(WizardStepChanged(step)),
            onStepContinue: () {
              if (state.currentStep == 0 && bloc.isStep1Valid.value) {
                bloc.add(const WizardStepChanged(1));
              } else if (state.currentStep == 1 && bloc.isStep2Valid.value) {
                bloc.add(const WizardStepChanged(2));
              } else if (state.currentStep == 2 && bloc.canSubmit.value) {
                bloc.add(const WizardSubmitted());
              }
            },
            onStepCancel: state.currentStep > 0
                ? () => bloc.add(WizardStepChanged(state.currentStep - 1))
                : null,
            steps: [
              Step(
                title: const Text('Account Details'),
                isActive: state.currentStep >= 0,
                state: bloc.isStep1Valid.value
                    ? StepState.complete
                    : StepState.indexed,
                content: const AccountStepView(),
              ),
              Step(
                title: const Text('Personal Profile'),
                isActive: state.currentStep >= 1,
                state: bloc.isStep2Valid.value
                    ? StepState.complete
                    : StepState.indexed,
                content: const ProfileStepView(),
              ),
              Step(
                title: const Text('Confirmation'),
                isActive: state.currentStep >= 2,
                content: const SummaryStepView(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AccountStepView extends StatefulWidget {
  const AccountStepView({super.key});

  @override
  State<AccountStepView> createState() => _AccountStepViewState();
}

class _AccountStepViewState extends State<AccountStepView> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<WizardBlocSignal>();
    _usernameController =
        TextEditingController(text: bloc.stateValue.username);
    _emailController = TextEditingController(text: bloc.stateValue.email);
  }

  void _onChanged() {
    context.read<WizardBlocSignal>().add(AccountInfoUpdated(
          username: _usernameController.text,
          email: _emailController.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username (min 3 chars)',
          ),
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
          ),
          onChanged: (_) => _onChanged(),
        ),
      ],
    );
  }
}

class ProfileStepView extends StatefulWidget {
  const ProfileStepView({super.key});

  @override
  State<ProfileStepView> createState() => _ProfileStepViewState();
}

class _ProfileStepViewState extends State<ProfileStepView> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<WizardBlocSignal>();
    _nameController = TextEditingController(text: bloc.stateValue.fullName);
    _bioController = TextEditingController(text: bloc.stateValue.bio);
  }

  void _onChanged() {
    context.read<WizardBlocSignal>().add(ProfileInfoUpdated(
          fullName: _nameController.text,
          bio: _bioController.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
          ),
          onChanged: (_) => _onChanged(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Short Bio (min 5 chars)',
          ),
          onChanged: (_) => _onChanged(),
        ),
      ],
    );
  }
}

class SummaryStepView extends StatelessWidget {
  const SummaryStepView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<WizardBlocSignal>();
    return BlocSignalBuilder<WizardBlocSignal, WizardState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${state.username}'),
            Text('Email: ${state.email}'),
            Text('Full Name: ${state.fullName}'),
            Text('Bio: ${state.bio}'),
            const SizedBox(height: 16),
            if (!bloc.canSubmit.value)
              const Text(
                'Please complete all required fields before submitting.',
                style: TextStyle(color: Colors.red),
              ),
          ],
        );
      },
    );
  }
}
