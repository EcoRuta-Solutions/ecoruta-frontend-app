import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/modelos_alerta.dart';
import '../data/modelos_flota.dart';
import '../data/modelos_informe.dart';
import '../data/modelos_lectura_nodo.dart';
import '../data/modelos_panel.dart';
import '../data/modelos_reporte_ciudadano.dart';
import '../data/modelos_ruta.dart';
import '../data/repositorios_mock.dart';
import 'panel_controller.dart';

const _latenciaAccion = Duration(milliseconds: 400);

final contenedoresControllerProvider =
    AsyncNotifierProvider<ContenedoresController, List<NodoEstado>>(
      ContenedoresController.new,
      retry: (_, _) => null,
    );

class ContenedoresController extends AsyncNotifier<List<NodoEstado>> {
  RepositorioContenedores get _repositorio =>
      ref.read(repositorioContenedoresProvider);

  @override
  Future<List<NodoEstado>> build() => _repositorio.listar();

  Future<void> guardar(NodoEstado nodo) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.guardar(nodo);
    await _recargarCompartidos();
  }

  Future<void> eliminar(int id) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.eliminar(id);
    await _recargarCompartidos();
  }

  Future<void> _recargarCompartidos() async {
    state = AsyncData(await _repositorio.listar());
    ref.invalidate(panelControllerProvider);
    ref.invalidate(alertasControllerProvider);
  }
}

typedef SolicitudDetalleNodo = ({int nodoId, int dias});

final detalleNodoProvider = FutureProvider.family
    .autoDispose<DetalleNodo?, SolicitudDetalleNodo>(
      (ref, solicitud) => ref
          .watch(repositorioContenedoresProvider)
          .obtenerDetalle(solicitud.nodoId, dias: solicitud.dias),
      retry: (_, _) => null,
    );

final alertasControllerProvider =
    AsyncNotifierProvider<AlertasController, List<AlertaPanel>>(
      AlertasController.new,
      retry: (_, _) => null,
    );

class AlertasController extends AsyncNotifier<List<AlertaPanel>> {
  RepositorioAlertas get _repositorio => ref.read(repositorioAlertasProvider);

  @override
  Future<List<AlertaPanel>> build() async {
    final nodos = await ref.watch(repositorioContenedoresProvider).listar();
    await _repositorio.asegurarNodos(nodos);
    return _repositorio.listar();
  }

  int get activasSinReconocer =>
      state.asData?.value.where((alerta) => alerta.activaSinReconocer).length ??
      0;

  Future<void> reconocer(String id, {required String quien}) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.reconocer(id, quien: quien);
    state = AsyncData(await _repositorio.listar());
  }

  Future<void> asignar(
    String id, {
    required Conductor conductor,
    required Vehiculo vehiculo,
    required String quien,
  }) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.asignar(
      id,
      conductor: conductor,
      vehiculo: vehiculo,
      quien: quien,
    );
    state = AsyncData(await _repositorio.listar());
  }

  Future<void> atender(String id, {required String quien, String? nota}) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.atender(id, quien: quien, nota: nota);
    state = AsyncData(await _repositorio.listar());
  }
}

final rutasControllerProvider =
    AsyncNotifierProvider<RutasController, List<RutaMunicipal>>(
      RutasController.new,
      retry: (_, _) => null,
    );

class RutasController extends AsyncNotifier<List<RutaMunicipal>> {
  RepositorioRutas get _repositorio => ref.read(repositorioRutasProvider);

  @override
  Future<List<RutaMunicipal>> build() =>
      ref.watch(repositorioRutasProvider).listar();

  Future<void> aprobar(String id, {required String quien}) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.aprobar(id, quien: quien);
    state = AsyncData(await _repositorio.listar());
  }

  Future<void> reasignar(
    String id, {
    required Conductor conductor,
    required Vehiculo vehiculo,
    required String quien,
  }) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.reasignar(
      id,
      conductor: conductor,
      vehiculo: vehiculo,
      quien: quien,
    );
    state = AsyncData(await _repositorio.listar());
  }
}

final flotaControllerProvider =
    AsyncNotifierProvider<FlotaController, DatosFlota>(
      FlotaController.new,
      retry: (_, _) => null,
    );

class DatosFlota {
  const DatosFlota({
    required this.conductores,
    required this.vehiculos,
    required this.usuarios,
  });

  final List<Conductor> conductores;
  final List<Vehiculo> vehiculos;
  final List<UsuarioPanel> usuarios;
}

class FlotaController extends AsyncNotifier<DatosFlota> {
  RepositorioFlota get _repositorio => ref.read(repositorioFlotaProvider);

  @override
  Future<DatosFlota> build() async {
    final repositorio = ref.watch(repositorioFlotaProvider);
    final valores = await Future.wait([
      repositorio.conductores(),
      repositorio.vehiculos(),
      repositorio.usuarios(),
    ]);
    return DatosFlota(
      conductores: valores[0] as List<Conductor>,
      vehiculos: valores[1] as List<Vehiculo>,
      usuarios: valores[2] as List<UsuarioPanel>,
    );
  }

  Future<void> guardarConductor(Conductor conductor) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.guardarConductor(conductor);
    await _recargar();
  }

  Future<void> guardarVehiculo(Vehiculo vehiculo) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.guardarVehiculo(vehiculo);
    await _recargar();
  }

  Future<void> guardarUsuario(UsuarioPanel usuario) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.guardarUsuario(usuario);
    await _recargar();
  }

  Future<void> _recargar() async {
    final conductores = await _repositorio.conductores();
    final vehiculos = await _repositorio.vehiculos();
    final usuarios = await _repositorio.usuarios();
    state = AsyncData(
      DatosFlota(
        conductores: conductores,
        vehiculos: vehiculos,
        usuarios: usuarios,
      ),
    );
  }
}

final reportesCiudadanosControllerProvider =
    AsyncNotifierProvider<ReportesCiudadanosController, List<ReporteCiudadano>>(
      ReportesCiudadanosController.new,
      retry: (_, _) => null,
    );

class ReportesCiudadanosController
    extends AsyncNotifier<List<ReporteCiudadano>> {
  RepositorioReportesCiudadanos get _repositorio =>
      ref.read(repositorioReportesCiudadanosProvider);

  @override
  Future<List<ReporteCiudadano>> build() =>
      ref.watch(repositorioReportesCiudadanosProvider).listar();

  Future<void> iniciarAtencion(
    String id, {
    required String asignadoA,
    required String quien,
  }) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.iniciarAtencion(id, asignadoA: asignadoA, quien: quien);
    state = AsyncData(await _repositorio.listar());
  }

  Future<void> resolver(
    String id, {
    required String quien,
    String? nota,
  }) async {
    await Future<void>.delayed(_latenciaAccion);
    await _repositorio.resolver(id, quien: quien, nota: nota);
    state = AsyncData(await _repositorio.listar());
  }
}

final informesControllerProvider =
    AsyncNotifierProvider<InformesController, DatosInforme>(
      InformesController.new,
      retry: (_, _) => null,
    );

class InformesController extends AsyncNotifier<DatosInforme> {
  RepositorioInformes get _repositorio => ref.read(repositorioInformesProvider);
  late DateTime _inicio;
  late DateTime _fin;

  @override
  Future<DatosInforme> build() {
    _fin = DateTime.now();
    _inicio = DateTime(_fin.year, _fin.month, _fin.day)
        .subtract(const Duration(days: 6));
    return ref.watch(repositorioInformesProvider).cargar(_inicio, _fin);
  }

  Future<void> cargarRango(DateTime inicio, DateTime fin) async {
    _inicio = inicio;
    _fin = fin;
    state = const AsyncLoading<DatosInforme>();
    state = await AsyncValue.guard(
      () => _repositorio.cargar(inicio, fin),
    );
  }

  Future<void> recargar() => cargarRango(_inicio, _fin);
}
