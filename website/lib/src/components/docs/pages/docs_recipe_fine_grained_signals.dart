import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation recipe covering fine-grained signals to escape coarse BLoC rebuilds.
class const DocsRecipeFineGrainedSignalsPage({super.key})
    extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'The Coarse Loading Union Trap',
      anchor: 'coarse-loading-union-trap',
    ),
    TocHeading(
      title: 'Unified State + Computed Projections',
      anchor: 'unified-state-computed',
    ),
    TocHeading(
      title: 'Scoped Rebuilds with context.select and BlocSignalBuilder',
      anchor: 'scoped-rebuilds',
    ),
    TocHeading(
      title: 'Eager Initialization Without Constructor Traps',
      anchor: 'eager-initialization',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('🛠️ Architecture Recipes'),
        ]),
        h1([
          Component.text(
            'Escaping Coarse BLoC Rebuilds with Fine-Grained Signals',
          ),
        ]),
        p(classes: 'docs-lead', [
          Component.text(
            'Replace monolithic loading-union states that wipe out dropdowns and form inputs with unified immutable state, late final computed signals, and scoped widget rebuilds.',
          ),
        ]),
      ]),

      // 1. The Coarse Loading Union Trap
      section(id: 'coarse-loading-union-trap', classes: 'docs-section', [
        h2([Component.text('The Coarse Loading Union Trap')]),
        p([
          Component.text(
            'In classic BLoC apps, a common pattern models screen state as a sealed union of ',
          ),
          code([Component.text('Initial')]),
          Component.text(', '),
          code([Component.text('Loading')]),
          Component.text(', '),
          code([Component.text('Loaded')]),
          Component.text(', and '),
          code([Component.text('Error')]),
          Component.text(
            ' classes. When the user changes a filter or selects a breed from a dropdown, emitting ',
          ),
          code([Component.text('BreedsLoading()')]),
          Component.text(
            ' replaces the entire screen with a full-page spinner—unmounting the dropdown, resetting scroll position, and dropping active user selections.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'coarse_union_antipattern.dart',
          dart313Code: '''
// ❌ ANTI-PATTERN: Coarse union replaces interactive controls on every fetch
sealed class BreedsState;

final class BreedsLoading extends BreedsState;

final class BreedsLoaded({
  required final String? selectedBreed,
  required final List<String> images,
}) extends BreedsState;''',
          dart35Code: '''
// ❌ ANTI-PATTERN: Coarse union replaces interactive controls on every fetch
sealed class BreedsState {
  const BreedsState();
}

final class BreedsLoading extends BreedsState {
  const BreedsLoading();
}

final class BreedsLoaded extends BreedsState {
  const BreedsLoaded({required this.selectedBreed, required this.images});
  final String? selectedBreed;
  final List<String> images;
}''',
        ),
        const DocsCallout(
          type: CalloutType.warning,
          title: 'Why Coarse Unions Hurt Interactive Controls',
          children: [
            p([
              Component.text(
                'Because a coarse BlocBuilder switches the entire subtree when the state type changes to Loading, Flutter disposes and recreates dropdowns, text fields, and scroll controllers on every interaction.',
              ),
            ]),
          ],
        ),
      ]),

      // 2. Unified State + Computed Projections
      section(id: 'unified-state-computed', classes: 'docs-section', [
        h2([Component.text('Unified State + Computed Projections')]),
        p([
          Component.text(
            'Instead of replacing the entire state object with a loading placeholder, keep all canonical fields inside a single immutable state class and expose narrow ',
          ),
          code([Component.text('late final')]),
          Component.text(' '),
          code([Component.text('computed(...)')]),
          Component.text(
            ' projections on your CubitSignal or BlocSignal. Never store mutable shadow fields outside your StateType.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'breeds_cubit.dart',
          dart313Code: '''
class const BreedsState({
  final List<String> breeds = const [],
  final String? selectedBreed,
  final List<String> images = const [],
  final bool isLoadingBreeds = false,
  final bool isLoadingImages = false,
}) {
  BreedsState copyWith({
    List<String>? breeds,
    String? selectedBreed,
    List<String>? images,
    bool? isLoadingBreeds,
    bool? isLoadingImages,
  }) => BreedsState(
    breeds: breeds ?? this.breeds,
    selectedBreed: selectedBreed ?? this.selectedBreed,
    images: images ?? this.images,
    isLoadingBreeds: isLoadingBreeds ?? this.isLoadingBreeds,
    isLoadingImages: isLoadingImages ?? this.isLoadingImages,
  );
}

class BreedsCubit(final DogRepository _repo) extends CubitSignal<BreedsState> {
  this : super(initialState: const BreedsState());

  late final availableBreeds = computed(() => stateValue.breeds);
  late final selectedBreed = computed(() => stateValue.selectedBreed);
  late final isLoadingBreeds = computed(() => stateValue.isLoadingBreeds);
  late final isLoadingImages = computed(() => stateValue.isLoadingImages);
  late final images = computed(() => stateValue.images);

  Future<void> loadBreeds() async {
    emit(stateValue.copyWith(isLoadingBreeds: true));
    try {
      final fetched = await _repo.fetchBreeds();
      if (isClosed) return;
      emit(stateValue.copyWith(breeds: fetched, isLoadingBreeds: false));
    } on Exception catch (error, stackTrace) {
      if (isClosed) return;
      emitError(error, stackTrace);
      emit(stateValue.copyWith(isLoadingBreeds: false));
    }
  }

  Future<void> selectBreed(String breed) async {
    emit(stateValue.copyWith(selectedBreed: breed, isLoadingImages: true));
    try {
      final fetched = await _repo.fetchImages(breed);
      if (isClosed || stateValue.selectedBreed != breed) return;
      emit(stateValue.copyWith(images: fetched, isLoadingImages: false));
    } on Exception catch (error, stackTrace) {
      if (isClosed || stateValue.selectedBreed != breed) return;
      emitError(error, stackTrace);
      emit(stateValue.copyWith(isLoadingImages: false));
    }
  }
}''',
          dart35Code: '''
class BreedsState {
  const BreedsState({
    this.breeds = const [],
    this.selectedBreed,
    this.images = const [],
    this.isLoadingBreeds = false,
    this.isLoadingImages = false,
  });

  final List<String> breeds;
  final String? selectedBreed;
  final List<String> images;
  final bool isLoadingBreeds;
  final bool isLoadingImages;

  BreedsState copyWith({
    List<String>? breeds,
    String? selectedBreed,
    List<String>? images,
    bool? isLoadingBreeds,
    bool? isLoadingImages,
  }) {
    return BreedsState(
      breeds: breeds ?? this.breeds,
      selectedBreed: selectedBreed ?? this.selectedBreed,
      images: images ?? this.images,
      isLoadingBreeds: isLoadingBreeds ?? this.isLoadingBreeds,
      isLoadingImages: isLoadingImages ?? this.isLoadingImages,
    );
  }
}

class BreedsCubit extends CubitSignal<BreedsState> {
  BreedsCubit(this._repo) : super(initialState: const BreedsState());

  final DogRepository _repo;

  late final availableBreeds = computed(() => stateValue.breeds);
  late final selectedBreed = computed(() => stateValue.selectedBreed);
  late final isLoadingBreeds = computed(() => stateValue.isLoadingBreeds);
  late final isLoadingImages = computed(() => stateValue.isLoadingImages);
  late final images = computed(() => stateValue.images);

  Future<void> loadBreeds() async {
    emit(stateValue.copyWith(isLoadingBreeds: true));
    try {
      final fetched = await _repo.fetchBreeds();
      if (isClosed) return;
      emit(stateValue.copyWith(breeds: fetched, isLoadingBreeds: false));
    } on Exception catch (error, stackTrace) {
      if (isClosed) return;
      emitError(error, stackTrace);
      emit(stateValue.copyWith(isLoadingBreeds: false));
    }
  }

  Future<void> selectBreed(String breed) async {
    emit(stateValue.copyWith(selectedBreed: breed, isLoadingImages: true));
    try {
      final fetched = await _repo.fetchImages(breed);
      if (isClosed || stateValue.selectedBreed != breed) return;
      emit(stateValue.copyWith(images: fetched, isLoadingImages: false));
    } on Exception catch (error, stackTrace) {
      if (isClosed || stateValue.selectedBreed != breed) return;
      emitError(error, stackTrace);
      emit(stateValue.copyWith(isLoadingImages: false));
    }
  }
}''',
        ),
      ]),

      // 3. Scoped Rebuilds with context.select and BlocSignalBuilder
      section(id: 'scoped-rebuilds', classes: 'docs-section', [
        h2([
          Component.text(
            'Scoped Rebuilds with context.select and BlocSignalBuilder',
          ),
        ]),
        p([
          Component.text('In your Flutter UI, use '),
          code([Component.text('context.read<BreedsCubit>()')]),
          Component.text(' for dispatching actions and '),
          code([Component.text('context.select<B, R>')]),
          Component.text(' or '),
          code([Component.text('BlocSignalBuilder')]),
          Component.text(
            ' for fine-grained subscriptions. Never use context.watch<T>() to read state—it only listens for container replacement.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'breeds_page.dart',
          code: '''
class BreedsPage extends StatelessWidget {
  const BreedsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BreedsCubit>();
    final breeds = context.select<BreedsCubit, List<String>>(
      (c) => c.availableBreeds.value,
    );
    final currentBreed = context.select<BreedsCubit, String?>(
      (c) => c.selectedBreed.value,
    );

    return Column(
      children: [
        // Dropdown stays mounted and interactive while images reload
        DropdownButton<String>(
          value: currentBreed,
          items: [
            for (final breed in breeds)
              DropdownMenuItem(value: breed, child: Text(breed)),
          ],
          onChanged: (breed) {
            if (breed != null) cubit.selectBreed(breed);
          },
        ),
        Expanded(
          child: BlocSignalBuilder<BreedsCubit, BreedsState>(
            buildWhen: (prev, next) =>
                prev.isLoadingImages != next.isLoadingImages ||
                prev.images != next.images,
            builder: (context, state) {
              if (state.isLoadingImages) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                itemCount: state.images.length,
                itemBuilder: (_, index) => Image.network(state.images[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}''',
        ),
      ]),

      // 4. Eager Initialization Without Constructor Traps
      section(id: 'eager-initialization', classes: 'docs-section', [
        h2([Component.text('Eager Initialization Without Constructor Traps')]),
        p([
          Component.text(
            'Keep constructors pure—do not dispatch initial events inside the constructor when relying on BlocSignalProvider\'s default ',
          ),
          code([Component.text('lazy: true')]),
          Component.text(
            '. When a screen needs data immediately on mount, set ',
          ),
          code([Component.text('lazy: false')]),
          Component.text(
            ' on the provider or trigger the initial load at the route or StatefulWidget.initState boundary.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'breeds_provider_mount.dart',
          code: '''
BlocSignalProvider<BreedsCubit>(
  lazy: false,
  create: (context) => BreedsCubit(DogRepository())..loadBreeds(),
  child: const BreedsPage(),
);''',
        ),
      ]),
    ]);
  }
}
