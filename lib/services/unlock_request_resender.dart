import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class UnlockRequestResendResult {
  final bool success;
  final String? errorMessage;
  final String? requestId;

  const UnlockRequestResendResult({
    required this.success,
    this.errorMessage,
    this.requestId,
  });
}

class UnlockRequestResender {
  static const String _endpoint =
      'https://oggqvcjtvfgyagaisvmj.functions.supabase.co/unlock-requests';
  static const String _installationIdKey = 'installation_id';
  static const String _friendNameKey = 'friendName';
  static const String _friendEmailKey = 'friendEmail';
  static const String _friendWhatsappKey = 'friendWhatsappE164';
  static const String _notificationModeKey = 'notificationMode';
  static const String _requesterNameKey = 'requester_name';
  static const String _defaultMode = 'email_only';
  static const String _whatsappOnlyMode = 'whatsapp_only';
  static const int _defaultMinutes = 60;

  Future<UnlockRequestResendResult> resend({
    required String packageName,
    String? appName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final friendName = (prefs.getString(_friendNameKey) ?? '').trim();
    final friendEmail = (prefs.getString(_friendEmailKey) ?? '').trim();
    final friendWhatsapp = (prefs.getString(_friendWhatsappKey) ?? '').trim();
    final notificationMode =
        (prefs.getString(_notificationModeKey) ?? _defaultMode).trim();
    final requesterName = (prefs.getString(_requesterNameKey) ?? '').trim();
    final installationId = (prefs.getString(_installationIdKey) ?? '').trim();

    if (notificationMode != _whatsappOnlyMode && friendEmail.isEmpty) {
      return const UnlockRequestResendResult(
        success: false,
        errorMessage: 'Falta el email del amigo responsable',
      );
    }
    if (notificationMode == _whatsappOnlyMode && friendWhatsapp.isEmpty) {
      return const UnlockRequestResendResult(
        success: false,
        errorMessage: 'Falta el WhatsApp del amigo responsable',
      );
    }
    if (installationId.isEmpty) {
      return const UnlockRequestResendResult(
        success: false,
        errorMessage: 'No se encontró installationId. Reinicia la app.',
      );
    }

    final payload = <String, dynamic>{
      'packageName': packageName,
      'appName': (appName == null || appName.trim().isEmpty)
          ? packageName
          : appName.trim(),
      'requesterName': requesterName.isEmpty ? 'Usuario' : requesterName,
      'friendName': friendName.isEmpty ? 'amigo responsable' : friendName,
      'notificationMode':
          notificationMode.isEmpty ? _defaultMode : notificationMode,
      'minutes': _defaultMinutes,
      'v': 1,
    };
    if (friendEmail.isNotEmpty) payload['friendEmail'] = friendEmail;
    if (friendWhatsapp.isNotEmpty) {
      payload['friendWhatsappE164'] = friendWhatsapp;
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      request.headers.set('X-Installation-Id', installationId);
      request.add(utf8.encode(jsonEncode(payload)));

      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return UnlockRequestResendResult(
          success: false,
          errorMessage: 'http_${response.statusCode}',
        );
      }

      final parsed = jsonDecode(body);
      if (parsed is! Map<String, dynamic>) {
        return const UnlockRequestResendResult(
          success: false,
          errorMessage: 'Respuesta inválida del servidor',
        );
      }

      final ok = parsed['ok'] == true;
      if (!ok) {
        final emailSent = parsed['emailSent'] == true;
        final whatsappSent = parsed['whatsappSent'] == true;
        if (!emailSent && !whatsappSent) {
          return const UnlockRequestResendResult(
            success: false,
            errorMessage:
                'No se pudo notificar al amigo (email/WhatsApp fallaron)',
          );
        }
      }

      final requestId = (parsed['requestId'] ?? parsed['request_id'])?.toString();
      return UnlockRequestResendResult(success: true, requestId: requestId);
    } catch (e) {
      return UnlockRequestResendResult(
        success: false,
        errorMessage: e.toString(),
      );
    } finally {
      client?.close(force: true);
    }
  }
}
