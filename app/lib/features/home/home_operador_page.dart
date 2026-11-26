import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local/banco_local.dart';
import '../../data/remote/api.dart';
import '../../domain/catalogo.dart';
import '../../sync/sincronizador.dart';
import '../auth/confirmar_saida.dart';
import '../auth/sessao.dart';
import '../catalogo/catalogo_controller.dart';
import '../checklist_form/checklist_form_page.dart';
import 'detalhe_operador_page.dart';

class HomeOperadorPage extends StatefulWidget {
  const HomeOperadorPage({super.key});

  @override
  State<HomeOperadorPage> createState() => _HomeOperadorPageState();
}

class _HomeOperadorPageState extends State<HomeOperadorPage> {
  List<Map<String, dynamic>> _rascunhos = [];
  List<Map<String, dynamic>> _filaEnvio = [];

  Map<String, Map<String, dynamic>> _remotosPorId = {};

  bool _carregandoRascunhos = true;
  String? _erroRascunhos;

  late final Sincronizador _sincronizador;

  @override
  void initState() {
    super.initState();

    context.read<CatalogoController>().iniciar();

    _sincronizador = context.read<Sincronizador>()
      ..addListener(_sincronizacaoAlterada);

    _sincronizador.iniciar();

    _carregarTudo();
  }

  void _sincronizacaoAlterada() {
    if (mounted) {
      _carregarTudo();
    }
  }

  Future<void> _carregarTudo() async {
    await Future.wait([_carregarRascunhos(), _carregarRemotos()]);
  }

  Future<void> _carregarRemotos() async {
    try {
      final resp = await context.read<Api>().listarChecklists();

      final itens = (resp['itens'] as List?) ?? const [];

      final mapa = <String, Map<String, dynamic>>{};

      for (final item in itens) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final id = m['id']?.toString();

          if (id != null && id.isNotEmpty) {
            mapa[id] = m;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _remotosPorId = mapa;
      });
    } catch (e) {
      debugPrint('ERRO listarChecklists: $e');
    }
  }

  Future<void> _carregarRascunhos() async {
    final usuarioId = context.read<Sessao>().usuarioId;

    if (usuarioId == null) {
      if (mounted) {
        setState(() {
          _carregandoRascunhos = false;
        });
      }
      return;
    }

    if (!mounted) return;

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

      setState(() {
        _erroRascunhos = 'Falha ao carregar rascunhos: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregandoRascunhos = false;
        });
      }
    }
  }

  Future<void> _abrirChecklist(
    Catalogo catalogo, {
    String? rascunhoId,
    bool modoEdicao = false,
    bool emCorrecaoSolicitada = false,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChecklistFormPage(
          catalogo: catalogo,
          rascunhoId: rascunhoId,
          modoEdicao: modoEdicao,
          emCorrecaoSolicitada: emCorrecaoSolicitada,
        ),
      ),
    );

    if (!mounted) return;

    await _carregarTudo();
  }

  Future<void> _abrirDetalhe(
    String id,
    Catalogo? catalogo, {
    required bool emCorrecaoSolicitada,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DetalheOperadorPage(
          checklistId: id,
          onEditar: catalogo == null
              ? null
              : () => _abrirChecklist(
                  catalogo,
                  rascunhoId: id,
                  modoEdicao: true,
                  emCorrecaoSolicitada: emCorrecaoSolicitada,
                ),
        ),
      ),
    );

    if (!mounted) return;

    await _carregarTudo();
  }

  String _hm(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatarData(String? data) {
    if (data == null || data.length < 10) {
      return 'Data não informada';
    }

    return data.substring(0, 10).split('-').reversed.join('/');
  }

  String _dataRascunho(Map<String, dynamic> rascunho) {
    final json = rascunho['json'];

    if (json is! Map) {
      return 'Data não informada';
    }

    return _formatarData(json['data_turno'] as String?);
  }

  String _labelStatus(
    String statusLocal,
    String? statusServidor,
    String? erro,
  ) {
    if (statusLocal == 'PENDENTE_ENVIO') {
      return 'Pendente de envio';
    }

    if (statusLocal == 'ERRO_VALIDACAO') {
      return 'Erro: ${erro ?? 'revise os dados'}';
    }

    return switch (statusServidor) {
      'CORRECAO_SOLICITADA' => 'Correção solicitada',
      'VISTADO' => 'Vistado (travado)',
      'ENVIADO' => 'Enviado (aguardando visto)',
      _ => 'Enviado',
    };
  }

  List<Map<String, dynamic>> _combinarEnviados() {
    final lista = <Map<String, dynamic>>[];

    final idsAdicionados = <String>{};

    for (final local in _filaEnvio) {
      final id = local['id']?.toString();

      if (id == null || id.isEmpty) continue;

      idsAdicionados.add(id);

      lista.add({'id': id, 'local': local, 'remoto': _remotosPorId[id]});
    }

    for (final entry in _remotosPorId.entries) {
      if (!idsAdicionados.contains(entry.key)) {
        lista.add({'id': entry.key, 'local': null, 'remoto': entry.value});
      }
    }

    return lista;
  }

  Widget _buildCardEnviado(Map<String, dynamic> item, Catalogo? catalogo) {
    final id = item['id'] as String;

    final local = item['local'] as Map<String, dynamic>?;

    final remoto = item['remoto'] as Map<String, dynamic>?;

    final statusLocal = (local?['status'] as String?) ?? 'SINCRONIZADO';

    final statusServidor = remoto?['status']?.toString().toUpperCase();

    final motivo = (remoto?['motivo_correcao'] ?? '').toString().trim();

    final editado = remoto?['editado'] == true;

    final ehCorrecao = statusServidor == 'CORRECAO_SOLICITADA';

    final ehVistado = statusServidor == 'VISTADO';

    final podeEditar = !ehVistado && catalogo != null;

    final dataTexto = local != null
        ? _dataRascunho(local)
        : _formatarData(remoto?['data_turno']?.toString());

    final titulo = remoto?['equipamento'] != null
        ? '${remoto!['equipamento']} · $dataTexto'
        : 'Checklist · $dataTexto';

    return Card(
      color: ehCorrecao ? Colors.amber.shade100 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              statusLocal == 'ERRO_VALIDACAO'
                  ? Icons.error_outline
                  : ehCorrecao
                  ? Icons.warning_amber
                  : ehVistado
                  ? Icons.verified
                  : Icons.cloud_upload_outlined,
              color: ehCorrecao
                  ? Colors.amber.shade900
                  : ehVistado
                  ? Colors.green.shade700
                  : null,
            ),
            title: Row(
              children: [
                Expanded(child: Text(titulo)),
                if (editado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Editado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              _labelStatus(
                statusLocal,
                statusServidor,
                local?['ultimo_erro'] as String?,
              ),
            ),
            trailing: podeEditar
                ? TextButton.icon(
                    onPressed: () => _abrirChecklist(
                      catalogo,
                      rascunhoId: id,
                      modoEdicao: true,
                      emCorrecaoSolicitada: ehCorrecao,
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                  )
                : null,
            onTap: remoto != null
                ? () => _abrirDetalhe(
                    id,
                    catalogo,
                    emCorrecaoSolicitada: ehCorrecao,
                  )
                : null,
          ),
          if (ehCorrecao && motivo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Motivo da correção: $motivo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
        ],
      ),
    );
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

    final enviados = _combinarEnviados();

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
      body: RefreshIndicator(
        onRefresh: _carregarTudo,
        child: ListView(
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
                      : () async {
                          await sincronizador.sincronizar();

                          if (!mounted) return;

                          await _carregarTudo();
                        },
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
                      : '${c.codigo} v${c.versao} · '
                            '${c.itens.length} itens',
                ),
                subtitle: Text(
                  c == null
                      ? 'Conecte-se à internet uma vez para baixar o checklist.'
                      : '${c.locais.length} locais · '
                            '${c.equipamentos.length} guindastes\n'
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

            if (enviados.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nenhum checklist finalizado neste aparelho.'),
              )
            else
              for (final item in enviados) _buildCardEnviado(item, c),
          ],
        ),
      ),
    );
  }
}
