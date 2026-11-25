import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'data/remote/api.dart';
import 'data/remote/api_mock.dart';
import 'data/remote/api_real.dart';
import 'features/auth/login_page.dart';
import 'features/auth/sessao.dart';
import 'features/home/home_admin_page.dart';
import 'features/home/home_operador_page.dart';
import 'data/repositories/catalogo_repository.dart';
import 'features/catalogo/catalogo_controller.dart';
import 'sync/sincronizador.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessao = Sessao();
  await sessao.restaurar(); // recupera o login salvo, mesmo sem internet
  final Api api = Config.usarMock
      ? ApiMock()
      : ApiReal(Config.apiUrlPadrao, lerToken: () => sessao.token);
  runApp(
    MultiProvider(
      providers: [
        Provider<Api>.value(value: api),
        ChangeNotifierProvider<Sessao>.value(value: sessao),
        ChangeNotifierProvider<CatalogoController>(
          create: (_) => CatalogoController(CatalogoRepository(api)),
        ),
        ChangeNotifierProvider<Sincronizador>(
          create: (_) => Sincronizador(
            api,
            lerUsuarioId: () => sessao.usuarioId,
            aoExpirarSessao: sessao.sair,
          ),
        ),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checklist de Guindaste',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: Consumer<Sessao>(
        builder: (_, s, _) {
          if (!s.logado) return const LoginPage();
          return s.ehAdmin ? const HomeAdminPage() : const HomeOperadorPage();
        },
      ),
    );
  }
}
