# State Management Architecture

This directory contains the core state management infrastructure built with Riverpod.

## Structure

### Core Components

- **app_state.dart** - Base classes for all state (AppState, ImmutableState, LoadingStateMixin, ErrorStateMixin)
- **async_value.dart** - Extension methods for AsyncValue to simplify loading/error/data handling
- **error_handler.dart** - Unified error handling with custom exceptions (AppException, NetworkException, CacheException, ValidationException)

### Pattern

All state should be:
- **Immutable** - Use `final` fields and `copyWith` methods
- **Explicit** - Loading and error states are part of the state, not implicit
- **Testable** - State logic separated from UI

### Usage

For a feature state:

```dart
// 1. Define immutable state
class HomeState extends AppState {
  final List<Service> services;
  final bool isLoading;
  final String? error;
  
  const HomeState({
    this.services = const [],
    this.isLoading = false,
    this.error,
  });
  
  HomeState copyWith({
    List<Service>? services,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 2. Create StateNotifier
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._serviceRepository) : super(const HomeState());
  
  final ServiceRepository _serviceRepository;
  
  Future<void> loadServices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final services = await _serviceRepository.getServices();
      state = state.copyWith(services: services, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ErrorHandler.getErrorMessage(e));
    }
  }
}

// 3. Create provider
final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref.watch(serviceRepositoryProvider));
});
```

### AsyncValue Helpers

```dart
// Instead of:
ref.watch(provider).when(
  data: (data) => ...,
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);

// You can use:
ref.watch(provider).whenR(
  data: (data) => UI(),
  loading: () => Loading(),
  error: (err, stack) => ErrorView(error: err),
);
```
