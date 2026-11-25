import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local/banco_local.dart';
import '../../domain/catalogo.dart';
import '../auth/sessao.dart';
import '../catalogo/catalogo_controller.dart';
import '../checklist_form/checklist_form_page.dart';

class HomeOperadorPage extends StatefulWidget {
  const HomeOperadorPage({super.key});

  @override
  State<HomeOperadorPage> createState() => _HomeOperadorPageState();
}

class _HomeOperadorPageState extends State<HomeOperadorPage> {
  List<Map<String, dynamic>> _rascunhos = [];
  bool _carregandoRascunhos = true;
  String? _erroRascunhos;

  @override
  void initState() {
    super.initState();
    // Cobre os dois casos: logo após o login e a cada abertura do app já logado.
    context.read<CatalogoController>().iniciar();
    _carregarRascunhos();
  }

  Future<void> _carregarRascunhos() async {
    final usuarioId = context.read<Sessao>().usuarioId;
    if (usuarioId == null) return;
    setState(() {
      _carregandoRascunhos = true;
      _erroRascunhos = null;
    });
    try {
      final rascunhos = await BancoLocal.listarChecklists(
        status: 'RASCUNHO',
        usuarioId: usuarioId,
      );
      if (!mounted) return;
      setState(() => _rascunhos = rascunhos.reversed.toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroRascunhos = 'Falha ao carregar rascunhos: $e');
    } finally {
      if (mounted) setState(() => _carregandoRascunhos = false);
    }
  }

  Future<void> _abrirChecklist(Catalogo catalogo, {String? rascunhoId}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ChecklistFormPage(catalogo: catalogo, rascunhoId: rascunhoId),
      ),
    );
    await _carregarRascunhos();
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dataRascunho(Map<String, dynamic> rascunho) {
    final json = rascunho['json'] as Map<String, dynamic>;
    final data = json['data_turno'] as String?;
    if (data == null || data.length < 10) return 'Data não informada';
    return data.split('-').reversed.join('/');
  }

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
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: c == null ? null : () => _abrirChecklist(c),
              icon: const Icon(Icons.add),
              label: const Text('Novo checklist'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Rascunhos', style: Theme.of(context).textTheme.titleLarge),
          if (_carregandoRascunhos)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erroRascunhos != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _erroRascunhos!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else if (_rascunhos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum rascunho salvo.'),
            )
          else
            for (final rascunho in _rascunhos)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text('Checklist · ${_dataRascunho(rascunho)}'),
                  subtitle: Text(
                    'Salvo ${_hm(DateTime.parse(rascunho['atualizado_em'] as String).toLocal())}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: c == null
                      ? null
                      : () => _abrirChecklist(
                          c,
                          rascunhoId: rascunho['id'] as String,
                        ),
                ),
              ),
        ],
      ),
    );
  }
}
