import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../auth/sessao.dart';
import '../catalogo/catalogo_controller.dart';

class HomeOperadorPage extends StatefulWidget {
  const HomeOperadorPage({super.key});

  @override
  State<HomeOperadorPage> createState() => _HomeOperadorPageState();
}

class _HomeOperadorPageState extends State<HomeOperadorPage> {
  @override
  void initState() {
    super.initState();
    // Cobre os dois casos: logo após o login e a cada abertura do app já logado.
    context.read<CatalogoController>().iniciar();
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final cat = context.watch<CatalogoController>();
    final c = cat.catalogo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: sessao.sair,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Olá, ${sessao.nome}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: cat.atualizando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Icon(c == null ? Icons.cloud_off : Icons.check_circle),
                title: Text(
                  c == null
                      ? 'Nenhum dado salvo ainda'
                      : '${c.codigo} v${c.versao} · ${c.itens.length} itens',
                ),
                subtitle: Text(
                  c == null
                      ? 'Conecte-se à internet uma vez para baixar o checklist.'
                      : '${c.locais.length} locais · ${c.equipamentos.length} guindastes\n'
                            '${cat.ultimaTentativaFalhou ? "Falha ao atualizar: usando dados salvos" : "Atualizado"}'
                            '${c.atualizadoEm == null ? "" : " às ${_hm(c.atualizadoEm!)}"}',
                ),
                isThreeLine: c != null,
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: cat.atualizar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
