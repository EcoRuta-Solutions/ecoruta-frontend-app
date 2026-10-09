import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/panel_mock.dart';
import '../data/repositorios_mock.dart';

final panelControllerProvider =
    AsyncNotifierProvider<PanelController, DatosPanel>(
      PanelController.new,
      retry: (_, _) => null,
    );

class PanelController extends AsyncNotifier<DatosPanel> {
  @override
  Future<DatosPanel> build() => ref.watch(repositorioPanelProvider).cargar();

  Future<void> recargar() async {
    state = const AsyncLoading<DatosPanel>();
    state = await AsyncValue.guard(
      () => ref.read(repositorioPanelProvider).cargar(),
    );
  }
}
