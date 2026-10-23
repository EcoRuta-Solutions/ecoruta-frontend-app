import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'logo_ecoruta.dart';

/// Colores y medidas del diseño del login (pantalla de 390 px).
class _Login {
  static const fondo = Color(0xFFF4F8F1);
  static const texto = Color(0xFF16233B);
  static const azul = Color(0xFF1F4E9C);
  static const azulDeshabilitado = Color(0xFF8FA7CE);
  static const verde = Color(0xFF2E7D32);
  static const borde = Color(0xFFB9C7B2);
  static const error = Color(0xFFB3261E);
  static const fuente = 'Barlow';
  static const fuenteTitulo = 'BarlowCondensed';
}

const mensajeRevisaDatos = 'Revisa tu usuario y contraseña';

/// Mensajes del AuthController que significan "los datos están mal".
const _erroresDeDatos = {
  'Correo o contraseña incorrectos',
  'Revisa los datos ingresados',
};

/// Está en `true` desde que el usuario pulsa "Ingresar" hasta que termina la
/// animación de éxito. Mientras tanto el router no sale de /login.
/// Al recuperar una sesión guardada sigue en `false` y se navega de inmediato.
class CelebrandoLogin extends Notifier<bool> {
  @override
  bool build() => false;

  void iniciar() => state = true;
  void terminar() => state = false;
}

final celebrandoLoginProvider = NotifierProvider<CelebrandoLogin, bool>(
  CelebrandoLogin.new,
);

/// Cuánto dura la animación de éxito antes de pasar a la pantalla del rol.
const duracionExitoLogin = Duration(milliseconds: 1400);

/// Pausa sin movimiento cuando el sistema pide reducir animaciones.
const pausaExitoSinAnimacion = Duration(milliseconds: 800);

class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin>
    with SingleTickerProviderStateMixin {
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  late final _animacion = AnimationController(
    vsync: this,
    duration: duracionExitoLogin,
  );
  bool _ocultarClave = true;

  /// La validación local falló (falta un dato o el correo no es válido).
  bool _faltanDatos = false;

  /// El login terminó bien y se está mostrando "Sesión iniciada".
  bool _exito = false;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _claveCtrl.dispose();
    _animacion.dispose();
    super.dispose();
  }

  void _enviar() {
    final correoValido = _correoCtrl.text.contains('@');
    final claveValida = _claveCtrl.text.isNotEmpty;
    setState(() => _faltanDatos = !correoValido || !claveValida);
    if (_faltanDatos) return;
    ref.read(celebrandoLoginProvider.notifier).iniciar();
    ref.read(authProvider.notifier).login(_correoCtrl.text, _claveCtrl.text);
  }

  Future<void> _celebrar() async {
    final celebrando = ref.read(celebrandoLoginProvider.notifier);
    FocusScope.of(context).unfocus();
    setState(() => _exito = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _animacion.value = 1;
      await Future<void>.delayed(pausaExitoSinAnimacion);
    } else {
      await _animacion.forward().orCancel.catchError((_) {});
    }
    // Al apagarlo, el router lleva a la pantalla del rol.
    celebrando.terminar();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, siguiente) {
      if (!ref.read(celebrandoLoginProvider)) return;
      if (siguiente.status == AuthStatus.loggedIn) {
        _celebrar();
      } else if (!siguiente.loading) {
        ref.read(celebrandoLoginProvider.notifier).terminar();
      }
    });

    final auth = ref.watch(authProvider);
    final error = _faltanDatos
        ? const _ErrorLogin.datos()
        : _ErrorLogin.de(auth);

    return Scaffold(
      backgroundColor: _Login.fondo,
      body: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: _Login.fuente, color: _Login.texto),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LogoEcoRuta.ancho),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedBuilder(
                      animation: _animacion,
                      builder: (_, _) => LogoEcoRuta(
                        salidaCamion: _salidaCamion.evaluate(_animacion),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _Titulo(),
                    const SizedBox(height: 36),
                    if (_exito)
                      _Exito(
                        rol: auth.user?.rol ?? '',
                        aparicion: _aparicionCheck.animate(_animacion),
                      )
                    else ...[
                      const _Etiqueta('Correo'),
                      const SizedBox(height: 6),
                      _Campo(
                        key: const Key('login-correo'),
                        controller: _correoCtrl,
                        conError: error?.marcaCampos ?? false,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      const _Etiqueta('Contraseña'),
                      const SizedBox(height: 6),
                      _Campo(
                        key: const Key('login-clave'),
                        controller: _claveCtrl,
                        conError: error?.marcaCampos ?? false,
                        obscureText: _ocultarClave,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!auth.loading) _enviar();
                        },
                        sufijo: IconButton(
                          tooltip: _ocultarClave
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          color: _Login.texto.withValues(alpha: 0.7),
                          icon: Icon(
                            _ocultarClave
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _ocultarClave = !_ocultarClave),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error.mensaje,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _Login.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else
                        const SizedBox(height: 24),
                      _BotonIngresar(
                        cargando: auth.loading,
                        onPressed: _enviar,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primero aparece el check; luego el camión sale del logo hacia la derecha.
final _aparicionCheck = CurveTween(
  curve: const Interval(0, 0.3, curve: Curves.easeOutBack),
);
final _salidaCamion = CurveTween(
  curve: const Interval(0.25, 1, curve: Curves.easeInCubic),
);

/// Círculo verde con check, "Sesión iniciada" y el rol con el que entra.
class _Exito extends StatelessWidget {
  final String rol;
  final Animation<double> aparicion;

  const _Exito({required this.rol, required this.aparicion});

  static String _nombreRol(String rol) => switch (rol) {
    'municipalidad' => 'Municipalidad',
    'conductor' => 'Conductor',
    _ => rol,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          ScaleTransition(
            scale: aparicion,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _Login.verde,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sesión iniciada',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Entrando como ${_nombreRol(rol)}',
            style: TextStyle(
              fontSize: 16,
              color: _Login.texto.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Qué error mostrar y si los campos se pintan de rojo.
class _ErrorLogin {
  final String mensaje;
  final bool marcaCampos;

  const _ErrorLogin(this.mensaje, {required this.marcaCampos});

  const _ErrorLogin.datos() : mensaje = mensajeRevisaDatos, marcaCampos = true;

  /// Traduce el error del AuthController al texto del diseño.
  /// Los fallos de red o del servidor conservan su mensaje y no marcan
  /// los campos, porque el problema no son los datos ingresados.
  static _ErrorLogin? de(AuthState auth) {
    final error = auth.error;
    if (error == null || auth.loading) return null;
    if (error == mensajeSinAcceso) {
      return const _ErrorLogin(mensajeSinAcceso, marcaCampos: true);
    }
    if (_erroresDeDatos.contains(error)) return const _ErrorLogin.datos();
    return _ErrorLogin(error, marcaCampos: false);
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'EcoRuta',
            style: TextStyle(color: _Login.azul),
          ),
          TextSpan(
            text: ' Trujillo',
            style: TextStyle(color: _Login.verde),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      semanticsLabel: 'EcoRuta Trujillo',
      style: TextStyle(
        fontFamily: _Login.fuenteTitulo,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}

/// Campo de 48 px con borde gris, o rojo cuando hay error.
class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final bool conError;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? sufijo;

  const _Campo({
    super.key,
    required this.controller,
    required this.conError,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.sufijo,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color, double grosor) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: grosor),
    );

    final normal = conError ? _Login.error : _Login.borde;
    final foco = conError ? _Login.error : _Login.azul;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: !obscureText,
      cursorColor: _Login.azul,
      style: const TextStyle(
        fontFamily: _Login.fuente,
        fontSize: 16,
        height: 1.5,
        color: _Login.texto,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        // 12 + 24 (16 px × 1,5) + 12 = 48 px de alto.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        suffixIcon: sufijo,
        border: borde(normal, 1),
        enabledBorder: borde(normal, 1),
        focusedBorder: borde(foco, 2),
      ),
    );
  }
}

/// Botón "Ingresar": se aclara, se deshabilita y dice "Verificando…"
/// mientras espera al backend.
class _BotonIngresar extends StatelessWidget {
  final bool cargando;
  final VoidCallback onPressed;

  const _BotonIngresar({required this.cargando, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: cargando ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _Login.azul,
          disabledBackgroundColor: _Login.azulDeshabilitado,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: _Login.fuente,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(cargando ? 'Verificando…' : 'Ingresar'),
      ),
    );
  }
}
