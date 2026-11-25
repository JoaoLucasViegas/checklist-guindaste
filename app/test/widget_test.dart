import 'package:checklist_guindaste/data/remote/api.dart';
import 'package:checklist_guindaste/data/remote/api_mock.dart';
import 'package:checklist_guindaste/features/auth/login_page.dart';
import 'package:checklist_guindaste/features/auth/sessao.dart';
import 'package:checklist_guindaste/features/auth/confirmar_saida.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('sair pede confirmação e permite permanecer na sessão', (
    tester,
  ) async {
    final sessao = Sessao();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmarSaida(context, sessao),
              child: const Text('Sair'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Deseja sair?'), findsOneWidget);
    expect(find.textContaining('Sem conexão'), findsOneWidget);

    await tester.tap(find.text('Permanecer'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('PIN errado mostra a mensagem de erro (mock)', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Api>.value(value: ApiMock()),
          ChangeNotifierProvider<Sessao>(create: (_) => Sessao()),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '1001');
    await tester.enterText(find.byType(TextField).at(1), '9999');
    await tester.tap(find.text('Entrar'));
    await tester.pump(); // inicia o login
    await tester.pump(
      const Duration(milliseconds: 500),
    ); // espera o atraso do mock

    expect(find.text('Matrícula ou PIN incorretos'), findsOneWidget);
  });
}
