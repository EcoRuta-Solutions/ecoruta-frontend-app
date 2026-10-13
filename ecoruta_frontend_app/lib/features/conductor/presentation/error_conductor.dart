import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

String mensajeErrorCargaConductor(Object error) {
  if (error is DioException) {
    final codigo = error.response?.statusCode;
    if (codigo == 401) return 'Tu sesión venció. Inicia sesión nuevamente.';
    if (codigo == 403) {
      return 'No tienes permiso para consultar estas rutas.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.';
    }
  }

  if (error is FormatException ||
      error is TypeError ||
      error is NoSuchMethodError) {
    return 'El servidor devolvió datos inesperados. '
        'Inténtalo de nuevo más tarde.';
  }

  return 'El servidor devolvió datos inesperados. '
      'Inténtalo de nuevo más tarde.';
}

void registrarErrorCargaConductor(Object error) {
  if (kDebugMode) {
    debugPrint('Error de rutas (${error.runtimeType}): $error');
  }
}
