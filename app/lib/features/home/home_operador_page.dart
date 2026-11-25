import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local/banco_local.dart';
import '../../domain/catalogo.dart';
import '../../sync/sincronizador.dart';
import '../auth/confirmar_saida.dart';
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
  List<Map<String, dynamic>> _filaEnvio = [];
  bool _carregandoRascunhos = true;
  String? _erroRascunhos;
  late final Sincronizador _sincronizador;

  @override
  void initState() {
    super.initState();
    // Cobre os dois casos: logo após o login e a cada abertura do app já logado.
    context.read<CatalogoController>().iniciar();
    _sincronizador = context.read<Sincronizador>()
      ..addListener(_sincronizacaoAlterada);
    _sincronizador.iniciar();
    _carregarRascunhos();
  }

  void _sincronizacaoAlterada() {
    if (mounted) _carregarRascunhos();
  }

  Future<void> _carregarRascunhos() async {
    final usuarioId = context.read<Sessao>().usuarioId;
    if (usuarioId == null) return;
    setState(() {
      _carregandoRascunhos = true;
      _erroRascunhos = null;
    });
    try {
      final checklists = await BancoLocal.listarChecklists(
        usuarioId: usuarioId,
      );
      if (!mounted) return;
      setState(() {
        _rascunhos = checklists
            .where((linha) => linha['status'] == 'RASCUNHO')
            .toList()
            .reversed
            .toList();
        _filaEnvio = checklists
            .where(
              (linha) => {
                'PENDENTE_ENVIO',
                'ERRO_VALIDACAO',
                'SINCRONIZADO',
              }.contains(linha['status']),
            )
            .toList()
            .reversed
            .toList();
      });
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

  String _statusChecklist(Map<String, dynamic> checklist) {
    final status = checklist['status'] as String;
    return switch (status) {
      'PENDENTE_ENVIO' => 'Pendente de envio',
      'ERRO_VALIDACAO' =>
        'Erro: ${checklist['ultimo_erro'] ?? 'revise os dados'}',
      'SINCRONIZADO' => 'Enviado',
      _ => status,
    };
  }

  @override
  void dispose() {
    _sincronizador.removeListener(_sincronizacaoAlterada);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final cat = context.watch<CatalogoController>();
    final sincronizador = context.watch<Sincronizador>();
    final c = cat.catalogo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => confirmarSaida(context, sessao),
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
              leading: Icon(
                sincronizador.redeDisponivel ? Icons.wifi : Icons.wifi_off,
              ),
              title: Text(
                sincronizador.redeDisponivel ? 'Online' : 'Sem internet',
              ),
              subtitle: Text(
                '${sincronizador.pendentes} pendente(s) de envio · '
                '${sincronizador.errosValidacao} com erro',
              ),
              trailing: IconButton(
                tooltip: 'Sincronizar agora',
                onPressed: sincronizador.sincronizando
                    ? null
                    : sincronizador.sincronizar,
                icon: sincronizador.sincronizando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ),
          ),
          if (sincronizador.erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                sincronizador.erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
          const SizedBox(height: 24),
          Text(
            'Checklists e status',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_filaEnvio.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum checklist finalizado neste aparelho.'),
            )
          else
            for (final checklist in _filaEnvio)
              Card(
                child: ListTile(
                  leading: Icon(
                    checklist['status'] == 'ERRO_VALIDACAO'
                        ? Icons.error_outline
                        : Icons.cloud_upload_outlined,
                  ),
                  title: Text('Checklist · ${_dataRascunho(checklist)}'),
                  subtitle: Text(_statusChecklist(checklist)),
                ),
              ),
        ],
      ),
    );
  }
}
