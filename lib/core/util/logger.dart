import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 🔒 SECURITY & ⚡ SPEED OPT: Logger that automatically disables in release mode.
/// This prevents sensitive data leakage in production and improves app performance.
class AppLogger {
  static final Logger _logger = Logger(
    // Filter determines whether a log should be shown
    filter: ProductionFilter(), 
    printer: PrettyPrinter(
      methodCount: kDebugMode ? 2 : 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
    // 🔒 SECURITY: Use a development-only logger in debug, and null logger in release
    output: kDebugMode ? ConsoleOutput() : null, 
  );

  static void info(String message) {
    if (kDebugMode) _logger.i(message);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  static void warning(String message) {
    if (kDebugMode) _logger.w(message);
  }

  static void debug(String message) {
    if (kDebugMode) _logger.d(message);
  }
}

/// Helper filter that only allows logging when NOT in release mode.
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Only log in debug or profile mode, never in release
    return kDebugMode || kProfileMode;
  }
}
