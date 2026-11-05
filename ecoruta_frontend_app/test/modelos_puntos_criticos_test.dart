import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_flota.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_puntos_criticos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PuntoCritico.fromJson', () {
    test('lee todos los campos del esquema PuntoCriticoOut', () {
      final punto = PuntoCritico.fromJson({
        'id': 7,
        'codigo': 'PC-007',
        'estado': 'potencial',
        'priorizacion_obligatoria': true,
        'direccion': 'Av. España 123',
        'referencia': 'Frente al mercado',
        'lat': -8.11,
        'lon': -79.03,
        'este_utm17s': 717000,
        'norte_utm17s': 9103000,
        'creado_en': '2026-10-01T10:00:00Z',
      });

      expect(punto.id, 7);
      expect(punto.codigo, 'PC-007');
      expect(punto.estado, EstadoPuntoCritico.potencial);
      expect(punto.priorizacionObligatoria, isTrue);
      expect(punto.direccion, 'Av. España 123');
      expect(punto.referencia, 'Frente al mercado');
      expect(punto.latitud, -8.11);
      expect(punto.longitud, -79.03);
      expect(punto.tieneCoordenadas, isTrue);
      expect(punto.categoria, CategoriaPuntoCritico.prioritario);
    });

    test('tolera nulos, campos ausentes y enteros en coordenadas', () {
      final punto = PuntoCritico.fromJson({
        'codigo': 'PC-001',
        'estado': 'recuperado',
        'referencia': null,
        'lat': -8,
        'lon': -79,
      });

      expect(punto.id, isNull);
      expect(punto.priorizacionObligatoria, isFalse);
      expect(punto.direccion, '');
      expect(punto.referencia, isNull);
      expect(punto.latitud, -8.0);
      expect(punto.categoria, CategoriaPuntoCritico.recuperado);
    });

    test('marca sin coordenadas y estado desconocido sin fallar', () {
      final punto = PuntoCritico.fromJson({
        'codigo': 'PC-002',
        'estado': 'otro',
        'referencia': '   ',
        'lat': null,
      });

      expect(punto.estado, EstadoPuntoCritico.desconocido);
      expect(punto.referencia, isNull);
      expect(punto.tieneCoordenadas, isFalse);
      expect(punto.categoria, CategoriaPuntoCritico.potencial);
    });

    test('un recuperado con priorización se pinta como recuperado', () {
      final punto = PuntoCritico.fromJson({
        'codigo': 'PC-003',
        'estado': 'recuperado',
        'priorizacion_obligatoria': true,
      });

      expect(punto.categoria, CategoriaPuntoCritico.recuperado);
    });
  });

  test('PaginaPuntosCriticos.fromJson lee total, limit, offset e items', () {
    final pagina = PaginaPuntosCriticos.fromJson({
      'total': 151,
      'limit': 200,
      'offset': 0,
      'items': [
        {'codigo': 'PC-1', 'estado': 'potencial'},
        {'codigo': 'PC-2', 'estado': 'recuperado'},
      ],
    });

    expect(pagina.total, 151);
    expect(pagina.limit, 200);
    expect(pagina.offset, 0);
    expect(pagina.items.map((punto) => punto.codigo), ['PC-1', 'PC-2']);
  });

  group('ResumenPuntosCriticos.fromJson', () {
    test('lee los totales por estado y por prioridad', () {
      final resumen = ResumenPuntosCriticos.fromJson({
        'total': 151,
        'por_estado': {'potencial': 120, 'recuperado': 31},
        'por_prioridad': {'prioritarios': 40, 'no_prioritarios': 111},
      });

      expect(resumen.total, 151);
      expect(resumen.potenciales, 120);
      expect(resumen.recuperados, 31);
      expect(resumen.prioritarios, 40);
      expect(resumen.noPrioritarios, 111);
    });

    test('usa cero cuando faltan bloques', () {
      final resumen = ResumenPuntosCriticos.fromJson({'total': 3});

      expect(resumen.total, 3);
      expect(resumen.potenciales, 0);
      expect(resumen.prioritarios, 0);
    });
  });

  group('ResumenFlota.fromJson', () {
    test('lee estados, turnos, demo y datos provisionales', () {
      final flota = ResumenFlota.fromJson({
        'total': 12,
        'por_estado': {
          'operativo': 8,
          'reserva': 3,
          'mantenimiento': 1,
          'total': 12,
        },
        'por_turno': {
          'manana': {'operativo': 4, 'reserva': 1, 'total': 5},
          'tarde': {'operativo': 3, 'reserva': 1, 'mantenimiento': 1},
          'noche': {'operativo': 1, 'reserva': 1, 'total': 2},
        },
        'sin_turno_reconocido': 0,
        'demo': 2,
        'datos_provisionales': 5,
      });

      expect(flota.total, 12);
      expect(flota.porEstado.operativo, 8);
      expect(flota.porEstado.reserva, 3);
      expect(flota.porEstado.mantenimiento, 1);
      expect(flota.turno(TurnoFlota.manana).operativo, 4);
      expect(flota.turno(TurnoFlota.tarde).mantenimiento, 1);
      expect(flota.turno(TurnoFlota.tarde).total, 0);
      expect(flota.turno(TurnoFlota.noche).operativo, 1);
      expect(flota.demo, 2);
      expect(flota.datosProvisionales, 5);
    });

    test('un turno ausente cuenta como cero', () {
      final flota = ResumenFlota.fromJson({
        'total': 1,
        'por_estado': {'operativo': 1},
        'por_turno': {
          'manana': {'operativo': 1},
        },
      });

      expect(flota.turno(TurnoFlota.noche).operativo, 0);
      expect(flota.sinTurnoReconocido, 0);
      expect(flota.demo, 0);
    });
  });
}
