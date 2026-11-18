import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../features/conductor/data/repositorio_conductor.dart';
import '../../features/conductor/presentation/mis_rutas_controller.dart';
import '../../features/conductor/presentation/navegacion_conductor_controller.dart';
import '../../features/municipalidad/data/repositorio_puntos_criticos.dart';
import '../../features/municipalidad/data/repositorio_reportes_campo.dart';
import '../../features/municipalidad/data/repositorio_resumen_flota.dart';
import '../../features/municipalidad/data/repositorio_rutas_turno.dart';
import '../../features/municipalidad/data/repositorio_zonas_ruta.dart';
import '../../features/municipalidad/data/repositorios_mock.dart';
import '../../features/municipalidad/presentation/controladores_dominio.dart';
import '../../features/municipalidad/presentation/navegacion_controller.dart';
import '../../features/municipalidad/presentation/panel_controller.dart';
import '../../features/municipalidad/presentation/puntos_criticos_providers.dart';
import '../../features/municipalidad/presentation/reportes_campo_providers.dart';
import '../../features/municipalidad/presentation/rutas_turno_providers.dart';
import '../../features/municipalidad/presentation/zonas_ruta_providers.dart';

/// Providers cuyo contenido depende del usuario que inició sesión.
///
/// Se invalidan al cerrar e iniciar sesión para que una cuenta nueva no vea
/// rutas, reportes ni el panel de la cuenta anterior. Los repositorios van
/// incluidos porque los de ejemplo guardan estado en memoria.
final List<ProviderOrFamily> providersDeSesion = [
  // Conductor
  repositorioConductorProvider,
  misRutasControllerProvider,
  detalleRutaProvider,
  navegacionConductorProvider,
  // Municipalidad: datos
  repositorioPanelProvider,
  repositorioContenedoresProvider,
  repositorioAlertasProvider,
  repositorioFlotaProvider,
  repositorioInformesProvider,
  repositorioPuntosCriticosProvider,
  repositorioReportesCampoProvider,
  repositorioResumenFlotaProvider,
  repositorioRutasTurnoProvider,
  repositorioZonasRutaProvider,
  // Municipalidad: pantallas
  panelControllerProvider,
  contenedoresControllerProvider,
  detalleNodoProvider,
  alertasControllerProvider,
  flotaControllerProvider,
  informesControllerProvider,
  navegacionMunicipalidadProvider,
  puntosCriticosProvider,
  resumenPuntosCriticosProvider,
  detallePuntoCriticoProvider,
  resumenFlotaProvider,
  resumenReportesProvider,
  ultimoReportePuntoProvider,
  rutasHoyProvider,
  generacionRutasProvider,
  zonasRutaPorTurnoProvider,
];

/// Descarta los datos guardados de la sesión anterior.
void limpiarDatosDeSesion(Ref ref) {
  for (final provider in providersDeSesion) {
    ref.invalidate(provider);
  }
}
