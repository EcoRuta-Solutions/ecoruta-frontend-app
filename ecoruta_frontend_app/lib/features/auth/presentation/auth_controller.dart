import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

/// Foto del estado de la sesión en un momento dado.
class AuthState {
  final AuthStatus status;
  final Usuario? user;
  final bool loading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.loading = false,
    this.error,
  });
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Al abrir la app, intenta recuperar la sesión guardada.
    Future.microtask(_restaurarSesion);
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restaurarSesion() async {
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) {
        state = const AuthState(status: AuthStatus.loggedOut);
        return;
      }
      final user = await _repo.me();
      state = AuthState(status: AuthStatus.loggedIn, user: user);
    } catch (_) {
      await _repo.logout();
      state = const AuthState(status: AuthStatus.loggedOut);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.loggedOut, loading: true);
    try {
      await _repo.login(email.trim(), password);
      final user = await _repo.me();
      state = AuthState(status: AuthStatus.loggedIn, user: user);
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.loggedOut, error: _mensaje(e));
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.loggedOut,
        error: 'Ocurrió un error inesperado',
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.loggedOut);
  }

  String _mensaje(DioException e) {
    final code = e.response?.statusCode;
    if (code == 400 || code == 401) return 'Correo o contraseña incorrectos';
    if (code == 422) return 'Revisa los datos ingresados';
    if (e.response == null) {
      return 'No se pudo conectar con el servidor. ¿Está encendido el backend?';
    }
    return 'Error del servidor ($code)';
  }
}

final authProvider =
NotifierProvider<AuthController, AuthState>(AuthController.new);