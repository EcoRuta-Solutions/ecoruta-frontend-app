import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/municipalidad/data/modelos_panel.dart';

class EcoColors {
  static const Color primario = Color(0xFF12263A);
  static const Color acento = Color(0xFF14B8A6);
  static const Color fondo = Color(0xFFF5F7F8);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color texto = Color(0xFF0F1A24);
  static const Color textoSecundario = Color(0xFF5B6773);
  static const Color borde = Color(0xFFE3E8EC);
  static const Color verde = acento;
  static const Color critico = Color(0xFFE5484D);
}

class EcoLayout {
  static const double anchoCompacto = 600;
  static const double anchoContenido = 920;
}

@immutable
class EstadoVisual {
  const EstadoVisual({
    required this.color,
    required this.fondo,
    required this.icono,
  });

  final Color color;
  final Color fondo;
  final IconData icono;

  EstadoVisual lerp(EstadoVisual other, double t) => EstadoVisual(
    color: Color.lerp(color, other.color, t)!,
    fondo: Color.lerp(fondo, other.fondo, t)!,
    icono: t < 0.5 ? icono : other.icono,
  );
}

@immutable
class ColoresEstado extends ThemeExtension<ColoresEstado> {
  const ColoresEstado({
    required this.critico,
    required this.alerta,
    required this.normal,
    required this.sinDatos,
  });

  final EstadoVisual critico;
  final EstadoVisual alerta;
  final EstadoVisual normal;
  final EstadoVisual sinDatos;

  EstadoVisual para(EstadoNodo estado) => switch (estado) {
    EstadoNodo.critico => critico,
    EstadoNodo.alerta => alerta,
    EstadoNodo.normal => normal,
    EstadoNodo.sinDatos => sinDatos,
  };

  @override
  ColoresEstado copyWith({
    EstadoVisual? critico,
    EstadoVisual? alerta,
    EstadoVisual? normal,
    EstadoVisual? sinDatos,
  }) => ColoresEstado(
    critico: critico ?? this.critico,
    alerta: alerta ?? this.alerta,
    normal: normal ?? this.normal,
    sinDatos: sinDatos ?? this.sinDatos,
  );

  @override
  ColoresEstado lerp(ThemeExtension<ColoresEstado>? other, double t) {
    if (other is! ColoresEstado) return this;
    return ColoresEstado(
      critico: critico.lerp(other.critico, t),
      alerta: alerta.lerp(other.alerta, t),
      normal: normal.lerp(other.normal, t),
      sinDatos: sinDatos.lerp(other.sinDatos, t),
    );
  }
}

enum EstadoProcesoPanel {
  nueva,
  reconocida,
  asignada,
  atendida,
  propuesta,
  aprobada,
  enCurso,
  completada,
  recibido,
  enAtencion,
  resuelto,
  activo,
  mantenimiento,
  inactivo,
  disponible,
  descanso,
  operativo,
}

@immutable
class ColoresProceso extends ThemeExtension<ColoresProceso> {
  const ColoresProceso(this.estados);

  final Map<EstadoProcesoPanel, EstadoVisual> estados;

  EstadoVisual para(EstadoProcesoPanel estado) => estados[estado]!;

  @override
  ColoresProceso copyWith({Map<EstadoProcesoPanel, EstadoVisual>? estados}) =>
      ColoresProceso(estados ?? this.estados);

  @override
  ColoresProceso lerp(ThemeExtension<ColoresProceso>? other, double t) {
    if (other is! ColoresProceso) return this;
    return ColoresProceso({
      for (final estado in EstadoProcesoPanel.values)
        estado: para(estado).lerp(other.para(estado), t),
    });
  }
}

class AppTheme {
  static const coloresEstado = ColoresEstado(
    critico: EstadoVisual(
      color: EcoColors.critico,
      fondo: Color(0xFFFDEBEC),
      icono: Icons.error_rounded,
    ),
    alerta: EstadoVisual(
      color: Color(0xFFF5A524),
      fondo: Color(0xFFFFF5E3),
      icono: Icons.warning_rounded,
    ),
    normal: EstadoVisual(
      color: Color(0xFF30A46C),
      fondo: Color(0xFFE8F6EF),
      icono: Icons.check_circle_rounded,
    ),
    sinDatos: EstadoVisual(
      color: Color(0xFF8B95A1),
      fondo: Color(0xFFF0F2F4),
      icono: Icons.remove_circle_outline_rounded,
    ),
  );

  static const coloresProceso = ColoresProceso({
    EstadoProcesoPanel.nueva: EstadoVisual(
      color: EcoColors.critico,
      fondo: Color(0xFFFDEBEC),
      icono: Icons.fiber_new_rounded,
    ),
    EstadoProcesoPanel.reconocida: EstadoVisual(
      color: EcoColors.primario,
      fondo: Color(0xFFE8EDF2),
      icono: Icons.visibility_rounded,
    ),
    EstadoProcesoPanel.asignada: EstadoVisual(
      color: EcoColors.acento,
      fondo: Color(0xFFE5F7F5),
      icono: Icons.person_pin_circle_rounded,
    ),
    EstadoProcesoPanel.atendida: EstadoVisual(
      color: Color(0xFF30A46C),
      fondo: Color(0xFFE8F6EF),
      icono: Icons.task_alt_rounded,
    ),
    EstadoProcesoPanel.propuesta: EstadoVisual(
      color: EcoColors.primario,
      fondo: Color(0xFFE8EDF2),
      icono: Icons.lightbulb_outline_rounded,
    ),
    EstadoProcesoPanel.aprobada: EstadoVisual(
      color: EcoColors.acento,
      fondo: Color(0xFFE5F7F5),
      icono: Icons.verified_outlined,
    ),
    EstadoProcesoPanel.enCurso: EstadoVisual(
      color: EcoColors.acento,
      fondo: Color(0xFFE5F7F5),
      icono: Icons.route_rounded,
    ),
    EstadoProcesoPanel.completada: EstadoVisual(
      color: Color(0xFF30A46C),
      fondo: Color(0xFFE8F6EF),
      icono: Icons.check_circle_outline_rounded,
    ),
    EstadoProcesoPanel.recibido: EstadoVisual(
      color: EcoColors.primario,
      fondo: Color(0xFFE8EDF2),
      icono: Icons.inbox_outlined,
    ),
    EstadoProcesoPanel.enAtencion: EstadoVisual(
      color: EcoColors.acento,
      fondo: Color(0xFFE5F7F5),
      icono: Icons.handyman_outlined,
    ),
    EstadoProcesoPanel.resuelto: EstadoVisual(
      color: Color(0xFF30A46C),
      fondo: Color(0xFFE8F6EF),
      icono: Icons.task_alt_rounded,
    ),
    EstadoProcesoPanel.activo: EstadoVisual(
      color: Color(0xFF30A46C),
      fondo: Color(0xFFE8F6EF),
      icono: Icons.check_circle_outline_rounded,
    ),
    EstadoProcesoPanel.mantenimiento: EstadoVisual(
      color: Color(0xFFF5A524),
      fondo: Color(0xFFFFF5E3),
      icono: Icons.build_outlined,
    ),
    EstadoProcesoPanel.inactivo: EstadoVisual(
      color: Color(0xFF8B95A1),
      fondo: Color(0xFFF0F2F4),
      icono: Icons.pause_circle_outline_rounded,
    ),
    EstadoProcesoPanel.disponible: EstadoVisual(
      color: Color(0xFF30A46C),
      fondo: Color(0xFFE8F6EF),
      icono: Icons.person_outline_rounded,
    ),
    EstadoProcesoPanel.descanso: EstadoVisual(
      color: Color(0xFF8B95A1),
      fondo: Color(0xFFF0F2F4),
      icono: Icons.coffee_outlined,
    ),
    EstadoProcesoPanel.operativo: EstadoVisual(
      color: Color(0xFF30A46C),
      fondo: Color(0xFFE8F6EF),
      icono: Icons.settings_suggest_outlined,
    ),
  });

  static ThemeData get light {
    final fuenteCuerpo = GoogleFonts.inter().fontFamily;
    final fuenteTitulo = GoogleFonts.plusJakartaSans().fontFamily;
    final baseTextTheme = ThemeData.light().textTheme.apply(
      bodyColor: EcoColors.texto,
      displayColor: EcoColors.texto,
    );
    final textTheme = baseTextTheme.copyWith(
      displayLarge: _fuente(baseTextTheme.displayLarge, fuenteTitulo),
      displayMedium: _fuente(baseTextTheme.displayMedium, fuenteTitulo),
      displaySmall: _fuente(baseTextTheme.displaySmall, fuenteTitulo),
      headlineLarge: _fuente(baseTextTheme.headlineLarge, fuenteTitulo),
      headlineMedium: _fuente(baseTextTheme.headlineMedium, fuenteTitulo),
      headlineSmall: _fuente(baseTextTheme.headlineSmall, fuenteTitulo),
      titleLarge: _fuente(baseTextTheme.titleLarge, fuenteTitulo),
      titleMedium: _fuente(baseTextTheme.titleMedium, fuenteTitulo),
      titleSmall: _fuente(baseTextTheme.titleSmall, fuenteTitulo),
      bodyLarge: _fuente(baseTextTheme.bodyLarge, fuenteCuerpo),
      bodyMedium: _fuente(baseTextTheme.bodyMedium, fuenteCuerpo),
      bodySmall: _fuente(baseTextTheme.bodySmall, fuenteCuerpo),
      labelLarge: _fuente(baseTextTheme.labelLarge, fuenteCuerpo),
      labelMedium: _fuente(baseTextTheme.labelMedium, fuenteCuerpo),
      labelSmall: _fuente(baseTextTheme.labelSmall, fuenteCuerpo),
    );

    final scheme =
        ColorScheme.fromSeed(
          seedColor: EcoColors.primario,
          brightness: Brightness.light,
        ).copyWith(
          primary: EcoColors.primario,
          secondary: EcoColors.acento,
          surface: EcoColors.superficie,
          onSurface: EcoColors.texto,
          onSurfaceVariant: EcoColors.textoSecundario,
          error: coloresEstado.critico.color,
        );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: EcoColors.borde),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fuenteCuerpo,
      textTheme: textTheme,
      extensions: const [coloresEstado, coloresProceso],
      scaffoldBackgroundColor: EcoColors.fondo,
      appBarTheme: AppBarTheme(
        backgroundColor: EcoColors.fondo,
        foregroundColor: EcoColors.texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: EcoColors.texto,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: EcoColors.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: EcoColors.borde),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EcoColors.superficie,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: EcoColors.acento, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: EcoColors.superficie,
        indicatorColor: EcoColors.acento.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static TextStyle? _fuente(TextStyle? style, String? family) =>
      style?.copyWith(
        fontFamily: family,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
