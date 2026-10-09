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
