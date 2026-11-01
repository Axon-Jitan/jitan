import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What this tablet keeps: its own secret (never shown or logged) and a
/// random id. Everything platform-specific stays behind this class.
abstract interface class TerminalStore {
  Future<String?> token();
  Future<void> saveToken(String token);
  Future<void> clearToken();

  /// Random, made once: only this tablet can retry a pairing.
  Future<String> deviceId();

  /// What HR sees under Tablet; `null` when the system won't say.
  Future<String?> deviceName();
}

class PlatformTerminalStore implements TerminalStore {
  const PlatformTerminalStore();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'terminal.token';
  static const _deviceKey = 'terminal.deviceId';

  @override
  Future<String?> token() => _storage.read(key: _tokenKey);

  @override
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  @override
  Future<String> deviceId() async {
    final stored = await _storage.read(key: _deviceKey);
    if (stored != null) return stored;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _deviceKey, value: id);
    return id;
  }

  @override
  Future<String?> deviceName() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model}'.trim();
  }
}
