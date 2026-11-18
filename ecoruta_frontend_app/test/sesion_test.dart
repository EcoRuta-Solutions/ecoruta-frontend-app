import 'package:ecoruta_frontend_app/core/network/api_client.dart';
import 'package:ecoruta_frontend_app/core/storage/token_storage.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/auth/data/auth_repository.dart';
import 'package:ecoruta_frontend_app/features/auth/presentation/auth_controller.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/modelos_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/repositorio_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/mis_rutas_controller.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/navegacion_conductor_controller.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/pantalla_mi_ruta.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/puntos_criticos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

final _hoy = DateTime(2026, 11, 17, 8);

/// Backend de prueba: responde según la cuenta con sesión abierta.
class _Backend {
  static const usuarios = {
    'ana@ecoruta.test': Usuario(
      id: 1,
      email: 'ana@ecoruta.test',
      nombre: 'Ana',
      rol: 'conductor',
    ),
    'beto@ecoruta.test': Usuario(
      id: 2,
      email: 'beto@ecoruta.test',
      nombre: 'Beto',
      rol: 'conductor',
    ),
  };

  Usuario? actual;

  Usuario get usuario => actual ?? (throw StateError('sin sesión'));

  /// Placa del camión asignado a cada cuenta.
  String get placa => 'CAMION-${usuario.nombre.toUpperCase()}';
}

class _TokenEnMemoria implements TokenStorage {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String valor) async => token = valor;

  @override
  Future<void> clear() async => token = null;
}

class _AuthRepositoryFalso implements AuthRepository {
  _AuthRepositoryFalso(this.backend, this.tokens);

  final _Backend backend;
  final _TokenEnMemoria tokens;

  @override
  Future<void> login(String email, String password) async {
    backend.actual = _Backend.usuarios[email];
    await tokens.write('token-$email');
  }

  @override
  Future<Usuario> me() async => backend.usuario;

  @override
  Future<void> logout() async {
    backend.actual = null;
    await tokens.clear();
  }
}

class _RepositorioConductorFalso implements RepositorioConductor {
  _RepositorioConductorFalso(this.backend);

  final _Backend backend;

  RutaConductor _ruta() {
    final dia = DateTime(_hoy.year, _hoy.month, _hoy.day);
    return RutaConductor(
      id: backend.usuario.id!,
      fechaInicio: dia,
      fechaFin: dia,
      horaInicio: dia.add(const Duration(hours: 5)),
      horaFin: dia.add(const Duration(hours: 9)),
      camionId: backend.usuario.id!,
      conductorId: backend.usuario.id,
      estado: EstadoRutaConductor.pendiente,
      turno: 'manana',
      camion: CamionConductor(
        id: backend.usuario.id!,
        placa: backend.placa,
        turno: 'manana',
      ),
      paradas: const [],
    );
  }

  @override
  Future<List<RutaConductor>> misRutas() async =>
      backend.actual == null ? const [] : [_ruta()];

  @override
  Future<RutaConductor> detalle(int id) async => _ruta();

  @override
  Future<RutaConductor> cambiarEstado(int id, EstadoRutaConductor estado) =>
      throw UnimplementedError();

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) => throw UnimplementedError();
}

class _RepositorioPuntosFalso implements RepositorioPuntosCriticos {
  _RepositorioPuntosFalso(this.backend);

  final _Backend backend;

  @override
  Future<List<PuntoCritico>> listarTodos() async => [
    PuntoCritico(
      codigo: 'PUNTO-${backend.usuario.nombre.toUpperCase()}',
      estado: EstadoPuntoCritico.potencial,
      priorizacionObligatoria: false,
      direccion: 'Dirección de prueba',
    ),
  ];

  @override
  Future<ResumenPuntosCriticos> resumen() async => ResumenPuntosCriticos(
    total: backend.usuario.id!,
    potenciales: 0,
    recuperados: 0,
    prioritarios: 0,
    noPrioritarios: 0,
  );

  @override
  Future<PuntoCritico?> obtener(String codigo) async => null;
}

List<Override> _overrides(_Backend backend) {
  final tokens = _TokenEnMemoria();
  return [
    tokenStorageProvider.overrideWithValue(tokens),
    authRepositoryProvider.overrideWithValue(
      _AuthRepositoryFalso(backend, tokens),
    ),
    repositorioConductorProvider.overrideWith(
      (ref) => _RepositorioConductorFalso(backend),
    ),
    repositorioPuntosCriticosProvider.overrideWith(
      (ref) => _RepositorioPuntosFalso(backend),
    ),
    relojConductorProvider.overrideWithValue(() => _hoy),
  ];
}

void main() {
  test(
    'dos sesiones seguidas no reutilizan los datos de la anterior',
    () async {
      final backend = _Backend();
      final contenedor = ProviderContainer(overrides: _overrides(backend));
      addTearDown(contenedor.dispose);
      final auth = contenedor.read(authProvider.notifier);
      await Future<void>.delayed(Duration.zero); // restaura la sesión (vacía)

      // Primera sesión: Ana.
      await auth.login('ana@ecoruta.test', 'x');
      final rutasAna = await contenedor.read(misRutasControllerProvider.future);
      expect(rutasAna.single.camion!.placa, 'CAMION-ANA');
      expect(
        (await contenedor.read(puntosCriticosProvider.future)).single.codigo,
        'PUNTO-ANA',
      );
      expect(
        (await contenedor.read(resumenPuntosCriticosProvider.future)).total,
        1,
      );
      expect(
        (await contenedor.read(detalleRutaProvider(1).future)).camion!.placa,
        'CAMION-ANA',
      );
      contenedor
          .read(navegacionConductorProvider.notifier)
          .seleccionar(DestinoConductor.mas);

      // Cierra sesión y entra Beto sin reiniciar la app.
      await auth.logout();
      await auth.login('beto@ecoruta.test', 'x');

      expect(contenedor.read(authProvider).user!.nombre, 'Beto');
      final rutasBeto = await contenedor.read(
        misRutasControllerProvider.future,
      );
      expect(rutasBeto.single.camion!.placa, 'CAMION-BETO');
      expect(
        (await contenedor.read(puntosCriticosProvider.future)).single.codigo,
        'PUNTO-BETO',
      );
      expect(
        (await contenedor.read(resumenPuntosCriticosProvider.future)).total,
        2,
      );
      expect(
        (await contenedor.read(detalleRutaProvider(1).future)).camion!.placa,
        'CAMION-BETO',
      );
      expect(
        contenedor.read(navegacionConductorProvider).destino,
        DestinoConductor.miRuta,
      );
    },
  );

  testWidgets('Mi ruta muestra saludo y rutas del usuario nuevo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(backend),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaMiRuta()),
        ),
      ),
    );
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(PantallaMiRuta)),
    );
    final auth = contenedor.read(authProvider.notifier);

    await tester.runAsync(() => auth.login('ana@ecoruta.test', 'x'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.textContaining('CAMION-ANA'), findsWidgets);

    await tester.runAsync(() async {
      await auth.logout();
      await auth.login('beto@ecoruta.test', 'x');
    });
    await tester.pumpAndSettle();

    expect(find.text('Hola, Beto'), findsOneWidget);
    expect(find.textContaining('CAMION-BETO'), findsWidgets);
    expect(find.text('Hola, Ana'), findsNothing);
    expect(find.textContaining('CAMION-ANA'), findsNothing);
  });
}
