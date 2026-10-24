import 'dart:math' as math;

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
  static const subtitulo = Color(0xFF5B6B73);
  static const ayuda = Color(0xFF9AA5AE);
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

/// Una vuelta de las ruedas mientras se verifica (se repite sin parar).
const vueltaRuedasCarga = Duration(milliseconds: 700);

/// Cuánto tiembla el camión cuando aparece un error.
const duracionTemblorError = Duration(milliseconds: 600);

/// Transición del borde de un campo al enfocarlo o salir de él.
const duracionFocoCampo = Duration(milliseconds: 150);

class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin>
    with TickerProviderStateMixin {
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  late final _animacion = AnimationController(
    vsync: this,
    duration: duracionExitoLogin,
  );
  late final _carga = AnimationController(
    vsync: this,
    duration: vueltaRuedasCarga,
  );
  late final _temblor = AnimationController(
    vsync: this,
    duration: duracionTemblorError,
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
    _carga.dispose();
    _temblor.dispose();
    super.dispose();
  }

  bool get _sinAnimaciones => MediaQuery.disableAnimationsOf(context);

  /// Ruedas rápidas y temblor lateral; vuelve a empezar en cada error.
  void _temblar() {
    if (_sinAnimaciones) return;
    _temblor.forward(from: 0);
  }

  /// Ruedas girando y una vibración leve mientras se verifica.
  void _animarCarga(bool cargando) {
    if (cargando && !_sinAnimaciones) {
      _carga.repeat();
    } else {
      _carga.reset();
    }
  }

  void _enviar() {
    final correoValido = _correoCtrl.text.contains('@');
    final claveValida = _claveCtrl.text.isNotEmpty;
    setState(() => _faltanDatos = !correoValido || !claveValida);
    if (_faltanDatos) {
      _temblar();
      return;
    }
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

  /// Combina las tres animaciones del camión: salida (éxito), ruedas y
  /// vibración (carga) y temblor (error). Solo la salida lo saca de su sitio.
  LogoEcoRuta _logoAnimado() {
    final carga = _carga.value;
    final temblor = _temblor.value;
    // El temblor se apaga poco a poco y termina en reposo.
    final onda = math.sin(temblor * math.pi * 2 * 5) * (1 - temblor);

    return LogoEcoRuta(
      salidaCamion: _salidaCamion.evaluate(_animacion),
      giroRuedas: (carga + temblor * 3) * math.pi * 2,
      desplazamientoCamion: Offset(
        onda * 4,
        math.sin(carga * math.pi * 2 * 4) * 0.8,
      ),
      inclinacionCamion: onda * 0.035,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (anterior, siguiente) {
      if (anterior?.loading != siguiente.loading) {
        _animarCarga(siguiente.loading);
      }
      // Credenciales incorrectas o rol no permitido: los errores que
      // marcan los campos en rojo también hacen temblar el camión.
      if (_ErrorLogin.de(siguiente)?.marcaCampos ?? false) _temblar();

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
          // Con espacio de sobra el contenido queda centrado en vertical;
          // si no cabe (pantalla baja o teclado abierto) se desplaza.
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: _margen,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, viewport.maxHeight - _margen.vertical),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: LogoEcoRuta.ancho,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _animacion,
                            _carga,
                            _temblor,
                          ]),
                          builder: (_, _) => _logoAnimado(),
                        ),
                        const SizedBox(height: 24),
                        const _Titulo(),
                        const SizedBox(height: 6),
                        const Text(
                          'Gestión inteligente de residuos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: _Login.fuente,
                            fontSize: 15,
                            color: _Login.subtitulo,
                          ),
                        ),
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
                            ayuda: 'nombre@correo.com',
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
                            ayuda: 'Tu contraseña',
                            obscureText: _ocultarClave,
                            textInputAction: TextInputAction.done,
                            // Al enfocarla, que el botón también quede a la vista.
                            scrollPadding: const EdgeInsets.only(bottom: 120),
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
                              onPressed: () => setState(
                                () => _ocultarClave = !_ocultarClave,
                              ),
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
        ),
      ),
    );
  }
}

/// Margen de la pantalla: 56 arriba, 28 a los lados y 32 abajo.
const _margen = EdgeInsets.fromLTRB(28, 56, 28, 32);

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

/// Campo de 48 px. El borde es gris, azul al enfocarlo y rojo cuando hay
/// error (el rojo tiene prioridad sobre el foco). El cambio es animado.
class _Campo extends StatefulWidget {
  final TextEditingController controller;
  final bool conError;
  final String ayuda;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsets scrollPadding;
  final Widget? sufijo;

  const _Campo({
    super.key,
    required this.controller,
    required this.conError,
    required this.ayuda,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.scrollPadding = const EdgeInsets.all(20),
    this.sufijo,
  });

  @override
  State<_Campo> createState() => _CampoState();
}

class _CampoState extends State<_Campo> {
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(_alCambiarFoco);
  }

  @override
  void dispose() {
    _foco
      ..removeListener(_alCambiarFoco)
      ..dispose();
    super.dispose();
  }

  void _alCambiarFoco() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final borde = widget.conError
        ? const BorderSide(color: _Login.error)
        : _foco.hasFocus
        ? const BorderSide(color: _Login.azul, width: 1.5)
        : const BorderSide(color: _Login.borde);

    // El borde va en foregroundDecoration (por dentro), así cambiar su
    // grosor no mueve el texto ni cambia el alto del campo.
    return AnimatedContainer(
      duration: duracionFocoCampo,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.fromBorderSide(borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _foco,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onSubmitted: widget.onSubmitted,
        scrollPadding: widget.scrollPadding,
        autocorrect: false,
        enableSuggestions: !widget.obscureText,
        cursorColor: _Login.azul,
        style: const TextStyle(
          fontFamily: _Login.fuente,
          fontSize: 16,
          height: 1.5,
          color: _Login.texto,
        ),
        decoration: InputDecoration(
          hintText: widget.ayuda,
          hintStyle: const TextStyle(
            fontFamily: _Login.fuente,
            fontSize: 16,
            height: 1.5,
            color: _Login.ayuda,
          ),
          // 12 + 24 (16 px × 1,5) + 12 = 48 px de alto.
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: widget.sufijo,
        ),
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
