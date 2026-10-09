import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de sesión (JWT) de forma cifrada en el celular.
/// Así el usuario sigue logueado aunque cierre la app.
class TokenStorage {
  static const _key = 'access_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}