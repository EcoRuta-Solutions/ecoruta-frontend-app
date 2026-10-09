import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Datos del usuario que devuelve GET /auth/me.
class Usuario {
  final int? id;
  final String email;
  final String nombre;
  final String rol; // ciudadano | conductor | municipalidad

  const Usuario({
    this.id,
    required this.email,
    required this.nombre,
    required this.rol,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as int?,
    email: (json['email'] ?? '') as String,
    nombre: (json['nombre'] ?? '') as String,
    rol: (json['rol'] ?? '') as String,
  );
}

/// Aquí vive todo lo que habla con los endpoints /auth.
class AuthRepository {
  final Dio _dio;
  final Ref _ref;

  AuthRepository(this._dio, this._ref);

  /// El login del backend es un FORMULARIO (no JSON):
  /// el campo se llama "username" pero lleva el email.
  Future<void> login(String email, String password) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'username': email, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final token = res.data['access_token'] as String;
    await _ref.read(tokenStorageProvider).write(token);
  }

  /// Pregunta al backend quién soy y qué rol tengo.
  Future<Usuario> me() async {
    final res = await _dio.get('/auth/me');
    return Usuario.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> logout() => _ref.read(tokenStorageProvider).clear();
}

final authRepositoryProvider = Provider<AuthRepository>(
      (ref) => AuthRepository(ref.read(dioProvider), ref),
);