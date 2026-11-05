import 'package:dio/dio.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_flota.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_resumen_flota.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/puntos_criticos_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioPuntosFalso implements RepositorioPuntosCriticos {
  int llamadasListar = 0;
  bool fallar = false;

  static const puntos = [
    PuntoCritico(
      codigo: 'PC-1',
      estado: EstadoPuntoCritico.potencial,
      priorizacionObligatoria: true,
      direccion: 'Calle 1',
      latitud: -8.1,
      longitud: -79.0,
    ),
    PuntoCritico(
      codigo: 'PC-2',
      estado: EstadoPuntoCritico.recuperado,
      priorizacionObligatoria: false,
      direccion: 'Calle 2',
      latitud: -8.2,
      longitud: -79.1,
    ),
  ];

  @override
  Future<List<PuntoCritico>> listarTodos() async {
    llamadasListar++;
    if (fallar) throw StateError('sin conexión');
    return puntos;
  }

  @override
  Future<ResumenPuntosCriticos> resumen() async =>
      ResumenPuntosCriticos.desdePuntos(puntos);

  @override
  Future<PuntoCritico?> obtener(String codigo) async =>
      puntos.where((punto) => punto.codigo == codigo).firstOrNull;
}

class _RepositorioFlotaFalso implements RepositorioResumenFlota {
  @override
  Future<ResumenFlota> cargar() async => const ResumenFlota(
    total: 3,
    porEstado: ConteoEstadosFlota(operativo: 2, reserva: 1, total: 3),
    porTurno: {TurnoFlota.manana: ConteoEstadosFlota(operativo: 2)},
  );
}

/// Dio que responde GET /puntos-criticos desde una lista en memoria,
/// respetando limit y offset como el backend.
Dio _dioPaginado(int total, List<Map<String, dynamic>> peticiones) {
  final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        peticiones.add(Map.of(options.queryParameters));
        final limit = options.queryParameters['limit'] as int;
        final offset = options.queryParameters['offset'] as int;
        final fin = (offset + limit).clamp(0, total);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'total': total,
              'limit': limit,
              'offset': offset,
              'items': [
                for (var i = offset; i < fin; i++)
                  {
                    'id': i + 1,
                    'codigo': 'PC-${i + 1}',
                    'estado': 'potencial',
                    'priorizacion_obligatoria': false,
                    'direccion': 'Dirección ${i + 1}',
                    'referencia': null,
                    'lat': -8.1,
                    'lon': -79.0,
                  },
              ],
            },
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('Providers de puntos críticos', () {
    late _RepositorioPuntosFalso repositorio;
    late ProviderContainer contenedor;

    setUp(() {
      repositorio = _RepositorioPuntosFalso();
      contenedor = ProviderContainer(
        overrides: [
          repositorioPuntosCriticosProvider.overrideWithValue(repositorio),
          repositorioResumenFlotaProvider.overrideWithValue(
            _RepositorioFlotaFalso(),
          ),
        ],
      );
      addTearDown(contenedor.dispose);
    });

    test('puntosCriticosProvider entrega los puntos del repositorio', () async {
      final puntos = await contenedor.read(puntosCriticosProvider.future);

      expect(puntos.map((punto) => punto.codigo), ['PC-1', 'PC-2']);
    });

    test('resumenPuntosCriticosProvider entrega los totales', () async {
      final resumen = await contenedor.read(
        resumenPuntosCriticosProvider.future,
      );

      expect(resumen.total, 2);
      expect(resumen.prioritarios, 1);
      expect(resumen.recuperados, 1);
    });

    test('detallePuntoCriticoProvider busca por código', () async {
      final detalle = await contenedor.read(
        detallePuntoCriticoProvider('PC-2').future,
      );
      final inexistente = await contenedor.read(
        detallePuntoCriticoProvider('NO-EXISTE').future,
      );

      expect(detalle?.direccion, 'Calle 2');
      expect(inexistente, isNull);
    });

    test('resumenFlotaProvider entrega el resumen de flota', () async {
      final flota = await contenedor.read(resumenFlotaProvider.future);

      expect(flota.turno(TurnoFlota.manana).operativo, 2);
      expect(flota.porEstado.reserva, 1);
    });

    test('un error queda en el provider y reintentar vuelve a pedir', () async {
      repositorio.fallar = true;
      final suscripcion = contenedor.listen(puntosCriticosProvider, (_, _) {});
      addTearDown(suscripcion.close);

      await expectLater(
        contenedor.read(puntosCriticosProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(contenedor.read(puntosCriticosProvider).hasError, isTrue);

      repositorio.fallar = false;
      contenedor.invalidate(puntosCriticosProvider);
      final puntos = await contenedor.read(puntosCriticosProvider.future);

      expect(puntos, hasLength(2));
      expect(repositorio.llamadasListar, 2);
    });
  });

  group('RepositorioPuntosCriticosApi', () {
    test('pide páginas de 200 hasta completar los 151 puntos', () async {
      final peticiones = <Map<String, dynamic>>[];
      final repositorio = RepositorioPuntosCriticosApi(
        _dioPaginado(151, peticiones),
      );

      final puntos = await repositorio.listarTodos();

      expect(puntos, hasLength(151));
      expect(peticiones, [
        {'limit': 200, 'offset': 0},
      ]);
    });

    test('recorre varias páginas si el total supera el límite', () async {
      final peticiones = <Map<String, dynamic>>[];
      final repositorio = RepositorioPuntosCriticosApi(
        _dioPaginado(450, peticiones),
      );

      final puntos = await repositorio.listarTodos();

      expect(puntos, hasLength(450));
      expect(puntos.last.codigo, 'PC-450');
      expect(peticiones.map((p) => p['offset']), [0, 200, 400]);
      expect(peticiones.every((p) => p['limit'] == 200), isTrue);
    });

    test('termina si el backend no devuelve más elementos', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
      var llamadas = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            llamadas++;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'total': 10, 'limit': 200, 'offset': 0, 'items': []},
              ),
            );
          },
        ),
      );

      final puntos = await RepositorioPuntosCriticosApi(dio).listarTodos();

      expect(puntos, isEmpty);
      expect(llamadas, 1);
    });
  });
}
