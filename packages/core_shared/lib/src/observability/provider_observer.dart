import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'waw_log.dart';
import 'debug_config.dart';

class WawProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (!DebugConfig.enableProviderObserver) return;

    final providerName = provider.name ?? provider.runtimeType.toString();
    WawLog.d('ProviderObserver', '$providerName updated');
  }

  @override
  void providerDidFail(
    ProviderBase provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    final providerName = provider.name ?? provider.runtimeType.toString();
    WawLog.e('ProviderObserver', '$providerName failed', error, stackTrace);
  }
}
