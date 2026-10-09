import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_alerta.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_flota.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_ruta.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_reporte_ciudadano.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/panel_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorios_mock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Datos deterministas del panel', () {
    test('conservan nodos, valores y resumen entre cargas', () {
      final primera = crearDatosPanelMock();
      final segunda = crearDatosPanelMock();

      expect(
        primera.nodos.map((nodo) => nodo.codigo),
        equals(segunda.nodos.map((nodo) => nodo.codigo)),
      );
      expect(primera.resumen.totalNodos, 8);
      expect(primera.resumen.nodosConDatos, 7);
      expect(primera.resumen.criticos, 2);
      expect(primera.resumen.alertas, 2);
      expect(primera.resumen.normales, 3);
      expect(primera.resumen.sinDatos, 1);
      expect(primera.nodos.last.zona, 'La Esperanza');
    });
  });

  group('Ciclo de vida de alertas', () {
    late RepositorioAlertasMock repositorio;
    late String alertaId;

    setUp(() async {
      repositorio = RepositorioAlertasMock();
      alertaId = (await repositorio.listar()).first.id;
    });

    test('permite reconocer, asignar y atender en orden', () async {
      await repositorio.reconocer(alertaId, quien: 'Ana Sánchez');
      expect(
        (await repositorio.listar()).first.estado,
        EstadoAlerta.reconocida,
      );

      await repositorio.asignar(
        alertaId,
        conductor: const Conductor(
          id: 1,
          nombre: 'Luis Rodríguez',
          telefono: '944 123 456',
          categoriaLicencia: 'A-IIb',
          estado: EstadoConductor.disponible,
        ),
        vehiculo: const Vehiculo(
          id: 1,
          placa: 'TCA-241',
          tipo: 'Compactador',
          capacidadToneladas: 8,
          estado: EstadoVehiculo.operativo,
        ),
        quien: 'Ana Sánchez',
      );
      expect((await repositorio.listar()).first.estado, EstadoAlerta.asignada);

      await repositorio.atender(
        alertaId,
        quien: 'Luis Rodríguez',
        nota: 'Contenedor vaciado.',
      );
      final atendida = (await repositorio.listar()).first;
      expect(atendida.estado, EstadoAlerta.atendida);
      expect(atendida.historial, hasLength(3));
      expect(atendida.historial.last.nota, 'Contenedor vaciado.');
    });

    test(
      'rechaza conductores en descanso y vehículos en mantenimiento',
      () async {
        await repositorio.reconocer(alertaId, quien: 'Ana Sánchez');
        final conductor = const Conductor(
          id: 3,
          nombre: 'José Castillo',
          telefono: '966 345 678',
          categoriaLicencia: 'A-IIb',
          estado: EstadoConductor.descanso,
        );
        const vehiculo = Vehiculo(
          id: 1,
          placa: 'TCA-241',
          tipo: 'Compactador',
          capacidadToneladas: 8,
          estado: EstadoVehiculo.operativo,
        );

        await expectLater(
          repositorio.asignar(
            alertaId,
            conductor: conductor,
            vehiculo: vehiculo,
            quien: 'Ana Sánchez',
          ),
          throwsStateError,
        );

        await expectLater(
          repositorio.asignar(
            alertaId,
            conductor: const Conductor(
              id: 1,
              nombre: 'Luis Rodríguez',
              telefono: '944 123 456',
              categoriaLicencia: 'A-IIb',
              estado: EstadoConductor.disponible,
            ),
            vehiculo: const Vehiculo(
              id: 3,
              placa: 'TCA-316',
              tipo: 'Compactador',
              capacidadToneladas: 8,
              estado: EstadoVehiculo.mantenimiento,
            ),
            quien: 'Ana Sánchez',
          ),
          throwsStateError,
        );
      },
    );
  });

  test('calcula ahorro frente a la ruta fija equivalente', () {
    const ruta = RutaMunicipal(
      id: 'RUT-TEST',
      nombre: 'Centro',
      zona: 'Centro',
      estado: EstadoRuta.propuesta,
      paradas: [],
      distanciaKm: 17,
      duracionMin: 60,
      distanciaFijaKm: 20,
      duracionFijaMin: 75,
      paradasFijas: 8,
    );

    expect(ruta.ahorroKmPorcentaje, 15);
  });

  test('aprueba rutas propuestas y registra el cambio', () async {
    final repositorio = RepositorioRutasMock();
    await repositorio.aprobar('RUT-001', quien: 'Ana Sánchez');
    final ruta = (await repositorio.listar()).first;

    expect(ruta.estado, EstadoRuta.aprobada);
    expect(ruta.historial, hasLength(1));
    expect(ruta.historial.single.quien, 'Ana Sánchez');
  });

  test('reasigna solo a conductor disponible y vehículo operativo', () async {
    final repositorio = RepositorioRutasMock();
    final antes = (await repositorio.listar()).first;

    await repositorio.reasignar(
      antes.id,
      conductor: const Conductor(
        id: 1,
        nombre: 'Luis Rodríguez',
        telefono: '944 123 456',
        categoriaLicencia: 'A-IIb',
        estado: EstadoConductor.disponible,
        vehiculoAsignado: 1,
      ),
      vehiculo: const Vehiculo(
        id: 1,
        placa: 'TCA-241',
        tipo: 'Compactador',
        capacidadToneladas: 8,
        estado: EstadoVehiculo.operativo,
      ),
      quien: 'Ana Sánchez',
    );
    expect((await repositorio.listar()).first.historial, hasLength(1));

    await expectLater(
      repositorio.reasignar(
        antes.id,
        conductor: const Conductor(
          id: 3,
          nombre: 'José Castillo',
          telefono: '966 345 678',
          categoriaLicencia: 'A-IIb',
          estado: EstadoConductor.descanso,
        ),
        vehiculo: const Vehiculo(
          id: 1,
          placa: 'TCA-241',
          tipo: 'Compactador',
          capacidadToneladas: 8,
          estado: EstadoVehiculo.operativo,
        ),
        quien: 'Ana Sánchez',
      ),
      throwsStateError,
    );
  });

  test(
    'avanza reportes recibidos a atención y resolución con historial',
    () async {
      final repositorio = RepositorioReportesCiudadanosMock();
      final reporte = (await repositorio.listar()).first;
      await repositorio.iniciarAtencion(
        reporte.id,
        asignadoA: 'Luis Rodríguez',
        quien: 'Ana Sánchez',
      );
      expect(
        (await repositorio.listar()).first.estado,
        EstadoReporte.enAtencion,
      );

      await repositorio.resolver(
        reporte.id,
        quien: 'Luis Rodríguez',
        nota: 'Punto de recojo atendido.',
      );
      final resuelto = (await repositorio.listar()).first;
      expect(resuelto.estado, EstadoReporte.resuelto);
      expect(resuelto.historial, hasLength(2));
      expect(resuelto.historial.last.nota, 'Punto de recojo atendido.');
    },
  );

  test('impide desactivar un conductor que está en ruta', () async {
    final repositorio = RepositorioFlotaMock();
    await expectLater(
      repositorio.guardarConductor(
        const Conductor(
          id: 2,
          nombre: 'María Flores',
          telefono: '955 234 567',
          categoriaLicencia: 'A-IIIa',
          estado: EstadoConductor.enRuta,
          activo: false,
        ),
      ),
      throwsStateError,
    );
  });
}
