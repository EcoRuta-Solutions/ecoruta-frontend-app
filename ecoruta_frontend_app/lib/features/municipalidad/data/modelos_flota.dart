enum EstadoConductor { disponible, enRuta, descanso }

enum EstadoVehiculo { operativo, mantenimiento }

enum RolPanel { administrador, operador, supervisor }

class Conductor {
  const Conductor({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.categoriaLicencia,
    required this.estado,
    this.vehiculoAsignado,
    this.activo = true,
  });

  final int id;
  final String nombre;
  final String telefono;
  final String categoriaLicencia;
  final EstadoConductor estado;
  final int? vehiculoAsignado;
  final bool activo;

  Conductor copiar({
    String? nombre,
    String? telefono,
    String? categoriaLicencia,
    EstadoConductor? estado,
    int? vehiculoAsignado,
    bool? activo,
  }) => Conductor(
    id: id,
    nombre: nombre ?? this.nombre,
    telefono: telefono ?? this.telefono,
    categoriaLicencia: categoriaLicencia ?? this.categoriaLicencia,
    estado: estado ?? this.estado,
    vehiculoAsignado: vehiculoAsignado ?? this.vehiculoAsignado,
    activo: activo ?? this.activo,
  );
}

class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.placa,
    required this.tipo,
    required this.capacidadToneladas,
    required this.estado,
    this.activo = true,
  });

  final int id;
  final String placa;
  final String tipo;
  final double capacidadToneladas;
  final EstadoVehiculo estado;
  final bool activo;

  Vehiculo copiar({
    String? placa,
    String? tipo,
    double? capacidadToneladas,
    EstadoVehiculo? estado,
    bool? activo,
  }) => Vehiculo(
    id: id,
    placa: placa ?? this.placa,
    tipo: tipo ?? this.tipo,
    capacidadToneladas: capacidadToneladas ?? this.capacidadToneladas,
    estado: estado ?? this.estado,
    activo: activo ?? this.activo,
  );
}

class UsuarioPanel {
  const UsuarioPanel({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.activo,
  });

  final int id;
  final String nombre;
  final String correo;
  final RolPanel rol;
  final bool activo;

  UsuarioPanel copiar({
    String? nombre,
    String? correo,
    RolPanel? rol,
    bool? activo,
  }) => UsuarioPanel(
    id: id,
    nombre: nombre ?? this.nombre,
    correo: correo ?? this.correo,
    rol: rol ?? this.rol,
    activo: activo ?? this.activo,
  );
}

/// Conteo de camiones por estado (esquema `ConteoEstados` del backend).
class ConteoEstadosFlota {
  const ConteoEstadosFlota({
    this.operativo = 0,
    this.reserva = 0,
    this.mantenimiento = 0,
    this.total = 0,
  });

  final int operativo;
  final int reserva;
  final int mantenimiento;
  final int total;

  static const vacio = ConteoEstadosFlota();

  factory ConteoEstadosFlota.fromJson(Map<String, dynamic>? j) {
    if (j == null) return vacio;
    return ConteoEstadosFlota(
      operativo: (j['operativo'] as num?)?.toInt() ?? 0,
      reserva: (j['reserva'] as num?)?.toInt() ?? 0,
      mantenimiento: (j['mantenimiento'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
    );
  }
}

enum TurnoFlota { manana, tarde, noche }

/// GET /flota/resumen (esquema `ResumenFlotaOut`, solo municipalidad).
class ResumenFlota {
  const ResumenFlota({
    required this.total,
    required this.porEstado,
    required this.porTurno,
    this.sinTurnoReconocido = 0,
    this.demo = 0,
    this.datosProvisionales = 0,
  });

  final int total;
  final ConteoEstadosFlota porEstado;
  final Map<TurnoFlota, ConteoEstadosFlota> porTurno;
  final int sinTurnoReconocido;

  /// Camiones demo (seed_demo.py del backend) incluidos en el total.
  final int demo;

  /// Camiones con datos_confirmados=false incluidos en el total.
  final int datosProvisionales;

  ConteoEstadosFlota turno(TurnoFlota turno) =>
      porTurno[turno] ?? ConteoEstadosFlota.vacio;

  factory ResumenFlota.fromJson(Map<String, dynamic> j) {
    final turnos = j['por_turno'] as Map<String, dynamic>? ?? const {};
    return ResumenFlota(
      total: (j['total'] as num?)?.toInt() ?? 0,
      porEstado: ConteoEstadosFlota.fromJson(
        j['por_estado'] as Map<String, dynamic>?,
      ),
      porTurno: {
        for (final turno in TurnoFlota.values)
          if (turnos[turno.name] is Map<String, dynamic>)
            turno: ConteoEstadosFlota.fromJson(
              turnos[turno.name] as Map<String, dynamic>,
            ),
      },
      sinTurnoReconocido: (j['sin_turno_reconocido'] as num?)?.toInt() ?? 0,
      demo: (j['demo'] as num?)?.toInt() ?? 0,
      datosProvisionales: (j['datos_provisionales'] as num?)?.toInt() ?? 0,
    );
  }
}
