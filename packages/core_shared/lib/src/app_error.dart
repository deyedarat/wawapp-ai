/// Error types for user-friendly error handling
enum AppErrorType {
  networkError,
  permissionDenied,
  notFound,
  timeout,
  unknown,
}

/// Application error wrapper for consistent error handling
class AppError implements Exception {
  final AppErrorType type;
  final String? message;

  const AppError({
    required this.type,
    this.message,
  });

  /// Create AppError from any exception
  factory AppError.from(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('connection')) {
      return const AppError(type: AppErrorType.networkError);
    }

    if (errorStr.contains('permission-denied') ||
        errorStr.contains('unauthorized')) {
      return const AppError(type: AppErrorType.permissionDenied);
    }

    if (errorStr.contains('not-found') || errorStr.contains('not found')) {
      return const AppError(type: AppErrorType.notFound);
    }

    if (errorStr.contains('timeout') || errorStr.contains('deadline')) {
      return const AppError(type: AppErrorType.timeout);
    }

    return AppError(
      type: AppErrorType.unknown,
      message: error.toString(),
    );
  }

  /// Get user-friendly Arabic message
  String toUserMessage() {
    switch (type) {
      case AppErrorType.networkError:
        return 'يبدو أنه لا يوجد اتصال بالإنترنت.';
      case AppErrorType.permissionDenied:
        return 'لا تملك صلاحية الوصول إلى هذه البيانات.';
      case AppErrorType.notFound:
        return 'البيانات المطلوبة غير موجودة.';
      case AppErrorType.timeout:
        return 'انتهت مهلة الاتصال، حاول مرة أخرى.';
      case AppErrorType.unknown:
        return 'حدث خطأ غير متوقّع، حاول مرة أخرى.';
    }
  }

  @override
  String toString() => 'AppError($type${message != null ? ': $message' : ''})';
}
