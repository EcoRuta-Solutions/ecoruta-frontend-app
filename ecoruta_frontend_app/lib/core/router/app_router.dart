import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pantalla_login.dart';
import '../../features/ciudadano/pantalla_inicio_ciudadano.dart';
import '../../features/conductor/pantalla_inicio_conductor.dart';
import '../../features/conductor/presentation/pantalla_detalle_ruta.dart';
import '../../features/municipalidad/pantalla_inicio_municipalidad.dart';

/// Dice a qué pantalla va cada rol al iniciar sesión.
String rutaInicioPorRol(String rol) {
  switch (rol) {
    case 'municipalidad':
      return '/municipalidad';
    case 'conductor':
      return '/conductor';
    default:
      return '/ciudadano';
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // Avisa al router cada vez que cambia el estado de la sesión.
  final cambioSesion = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => cambioSesion.value++);
  ref.onDispose(cambioSesion.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: cambioSesion,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final rutaActual = state.matchedLocation;

      // Todavía revisando si hay sesión guardada.
      if (auth.status == AuthStatus.unknown) {
        return rutaActual == '/splash' ? null : '/splash';
      }

      // Sin sesión: solo puede estar en el login.
      if (auth.status == AuthStatus.loggedOut) {
        return rutaActual == '/login' ? null : '/login';
      }

      // Con sesión: lo mandamos a la pantalla de su rol.
      final inicio = rutaInicioPorRol(auth.user?.rol ?? '');
      return rutaActual.startsWith(inicio) ? null : inicio;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const _PantallaCarga(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const PantallaLogin(),
      ),
      GoRoute(
        path: '/ciudadano',
        builder: (_, _) => const PantallaInicioCiudadano(),
      ),
      GoRoute(
        path: '/municipalidad',
        builder: (_, _) => const PantallaInicioMunicipalidad(),
      ),
      GoRoute(
        path: '/conductor',
        builder: (_, _) => const PantallaInicioConductor(),
        routes: [
          GoRoute(
            path: 'ruta/:id',
            builder: (_, state) => PantallaDetalleRuta(
              idRuta: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Pantalla mínima mientras se revisa si hay sesión guardada.
class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}