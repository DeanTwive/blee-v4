/// A simple Result type for Blee.
/// Used by all repository and use-case methods to model success/failure
/// without throwing across architectural boundaries.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final String message;
  final Object? raw;
  const Failure(this.message, {this.raw});
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get valueOrThrow {
    if (this is Success<T>) return (this as Success<T>).value;
    throw StateError((this as Failure<T>).message);
  }

  String get errorOrThrow {
    if (this is Failure<T>) return (this as Failure<T>).message;
    throw StateError('Result is Success, not Failure');
  }

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(String message) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      Failure<T>(:final message) => onFailure(message),
    };
  }
}
