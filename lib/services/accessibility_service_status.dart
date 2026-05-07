import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityServiceStatus {
  static const _channel = MethodChannel('com.example.change_your_life/accessibility');

  Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('[accessibility] isEnabled error: $e');
      return true;
    }
  }

  Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openSettings');
    } catch (e) {
      debugPrint('[accessibility] openSettings error: $e');
    }
  }
}
