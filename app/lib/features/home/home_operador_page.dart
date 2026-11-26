import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
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
  static const int _limiteVisivel = 3;

  List<Map<String, dynamic>> _rascunhos = [];
  List<Map<String, dynamic>> _meusChecklists = [];
  bool _carregando = true;
  String? _erroLista;
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
    if (mounted) _carregarTudo();
  }

  /// Carrega rascunhos locais e mescla a fila local com o status do servidor (FE-13).
  Future<void> _carregarTudo() async {
    final usuarioId = context.read<Sessao>().usuarioId;
    final api = context.read<Api>();
    if (usuarioId == null) return;
    setState(() {
      _carregando = true;
      _erroLista = null;
    });
    try {
      final locais = await BancoLocal.listarChecklists(usuarioId: usuarioId);
      final rascunhos = locais
          .where((linha) => linha['status'] == 'RASCUNHO')
          .toList()
          .reversed
          .toList();

      final mapaMesclado = <String, Map<String, dynamic>>{};

      // 1. Itens locais finalizados (offline-first)
      for (final linha in locais.reversed) {
        final st = linha['status'] as String;
        if (st == 'RASCUNHO') continue;
        final id = linha['id'] as String;
        final json = linha['json'] as Map<String, dynamic>;
        mapaMesclado[id] = {
          'id': id,
          'status': st == 'SINCRONIZADO' ? 'ENVIADO' : st,
          'origem_local': true,
          'ultimo_erro': linha['ultimo_erro'],
          'data_turno': json['data_turno'],
          'turno': json['turno'],
          'equipamento_id': json['equipamento_id'],
          'horimetro_inicial': json['horimetro_inicial'],
          'horimetro_final': json['horimetro_final'],
          'impedido': false,
          'editado': false,
          'motivo_correcao': null,
        };
      }

      // 2. Sobrepõe com status real do servidor (FE-13: CORRECAO_SOLICITADA, VISTADO, editado, motivo)
      try {
        final resp = await api.listarChecklists();
        final remotos = (resp['itens'] as List?) ?? const [];
        for (final raw in remotos) {
          final r = Map<String, dynamic>.from(raw as Map);
          final id = r['id'].toString();
          final anterior = mapaMesclado[id];
          // Se estiver PENDENTE_ENVIO ou ERRO_VALIDACAO localmente, preserva o aviso local
          final statusLocal = anterior?['status']?.toString();
          final manterLocal =
              statusLocal == 'PENDENTE_ENVIO' ||
              statusLocal == 'ERRO_VALIDACAO';
          mapaMesclado[id] = {
            ...?anterior,
            ...r,
            'id': id,
            'status': manterLocal ? statusLocal : (r['status'] ?? 'ENVIADO'),
          };
        }
      } catch (_) {
        // Offline: segue normalmente com os dados locais
      }

      final listaFinal = mapaMesclado.values.toList();
      // Correção solicitada sempre no topo para atenção imediata do operador
      listaFinal.sort((a, b) {
        final aCorr = a['status'] == 'CORRECAO_SOLICITADA' ? 0 : 1;
        final bCorr = b['status'] == 'CORRECAO_SOLICITADA' ? 0 : 1;
        return aCorr.compareTo(bCorr);
      });

      if (!mounted) return;
      setState(() {
        _rascunhos = rascunhos;
        _meusChecklists = listaFinal;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroLista = 'Falha ao carregar checklists: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirChecklist(
    Catalogo? catalogo, {
    String? rascunhoId,
    bool modoEdicao = false,
    bool emCorrecaoSolicitada = false,
    String? motivoCorrecao,
  }) async {
    if (catalogo == null) {
      final cat = context.read<CatalogoController>();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baixando catálogo do checklist… tente novamente.'),
        ),
      );
      await cat.atualizar();
      if (!mounted || cat.catalogo == null) return;
      catalogo = cat.catalogo!;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChecklistFormPage(
          catalogo: catalogo!,
          rascunhoId: rascunhoId,
          modoEdicao: modoEdicao,
          emCorrecaoSolicitada: emCorrecaoSolicitada,
          motivoCorrecao: motivoCorrecao,
        ),
      ),
    );
    await _carregarTudo();
  }

  Future<bool> _confirmarRemoverRascunho(Map<String, dynamic> rascunho) async {
    final json = rascunho['json'] as Map<String, dynamic>;
    final data = _dataTexto(json['data_turno']);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: TemaApp.perigo,
          size: 32,
        ),
        title: const Text('Remover rascunho?'),
        content: Text(
          'O rascunho de $data ainda não foi finalizado nem enviado e será removido deste aparelho.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TemaApp.perigo),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) return false;
    await BancoLocal.removerRascunho(rascunho['id'] as String);
    await _carregarTudo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rascunho removido.')),
      );
    }
    return true;
  }

  Future<void> _abrirDetalhe(
    Catalogo? c,
    Map<String, dynamic> checklist,
  ) async {
    final id = checklist['id'].toString();
    final status = (checklist['status'] ?? '').toString().toUpperCase();
    final motivo = checklist['motivo_correcao']?.toString();
    final podeEditar =
        status != 'VISTADO' &&
        status != 'PENDENTE_ENVIO' &&
        status != 'ERRO_VALIDACAO';

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DetalheOperadorPage(
          checklistId: id,
          onEditar: podeEditar
              ? () => _abrirChecklist(
                  c,
                  rascunhoId: id,
                  modoEdicao: true,
                  emCorrecaoSolicitada: status == 'CORRECAO_SOLICITADA',
                  motivoCorrecao: motivo,
                )
              : null,
        ),
      ),
    );
    await _carregarTudo();
  }

  void _abrirModalLista({
    required String titulo,
    required int total,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TemaApp.fundo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              decoration: const BoxDecoration(
                color: TemaApp.superficie,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: TemaApp.borda)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$titulo ($total)',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: TemaApp.textoPrimario,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  20 + MediaQuery.paddingOf(ctx).bottom,
                ),
                itemCount: total,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: itemBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dataTexto(dynamic raw) {
    final data = raw?.toString();
    if (data == null || data.length < 10) return 'Data não informada';
    if (data.contains('/')) return data;
    return data.substring(0, 10).split('-').reversed.join('/');
  }

  String _nomeEquipamento(Map<String, dynamic> item, Catalogo? c) {
    final direto = item['equipamento']?.toString();
    if (direto != null && direto.isNotEmpty) return direto;
    final eqId = item['equipamento_id']?.toString();
    if (c != null && eqId != null) {
      for (final eq in c.equipamentos) {
        if (eq.id == eqId) return eq.identificacao;
      }
    }
    return 'Check-List Diário';
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
    final ehTablet = Responsivo.ehTablet(context);

    final erroTopo = sincronizador.erro ?? _erroLista;

    final painelAcoes = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBannerConexao(sincronizador),
        const SizedBox(height: 14),
        SizedBox(
          height: 58,
          child: FilledButton.icon(
            style: TemaApp.botaoAmbar,
            onPressed: () => _abrirChecklist(c),
            icon: const Icon(Icons.add_rounded, size: 26),
            label: const Text('Novo Check-List Diário'),
          ),
        ),
        const SizedBox(height: 14),
        _buildCartaoCatalogo(cat, c),
      ],
    );

    final rascunhosVisiveis = _rascunhos.take(_limiteVisivel).toList();
    final checklistsVisiveis = _meusChecklists.take(_limiteVisivel).toList();

    final painelListas = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Seção Rascunhos (compacta com máscara visual + "Ver todos")
        if (_rascunhos.isNotEmpty) ...[
          _cabecalhoSecao(
            titulo: 'RASCUNHOS',
            total: _rascunhos.length,
            onVerTodos: _rascunhos.length > _limiteVisivel
                ? () => _abrirModalLista(
                    titulo: 'Rascunhos',
                    total: _rascunhos.length,
                    itemBuilder: (ctx, i) => _buildCardRascunho(_rascunhos[i], c, onAposRemover: () => Navigator.of(ctx).pop()),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (int i = 0; i < rascunhosVisiveis.length; i++) ...[
                  _buildLinhaRascunho(rascunhosVisiveis[i], c),
                  if (i < rascunhosVisiveis.length - 1)
                    const Divider(height: 1),
                ],
                if (_rascunhos.length > _limiteVisivel) ...[
                  const Divider(height: 1),
                  InkWell(
                    onTap: () => _abrirModalLista(
                      titulo: 'Rascunhos',
                      total: _rascunhos.length,
                      itemBuilder: (ctx, i) => _buildCardRascunho(
                        _rascunhos[i],
                        c,
                        onAposRemover: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Ver todos os ${_rascunhos.length} rascunhos →',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: TemaApp.ambarEscuro,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Seção Meus Check-Lists (compacta com máscara visual + "Ver todos")
        _cabecalhoSecao(
          titulo: 'MEUS CHECK-LISTS',
          total: _meusChecklists.length,
          onVerTodos: _meusChecklists.length > _limiteVisivel
              ? () => _abrirModalLista(
                  titulo: 'Meus Check-Lists',
                  total: _meusChecklists.length,
                  itemBuilder: (_, i) =>
                      _buildCartaoChecklist(_meusChecklists[i], c),
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (_carregando)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_meusChecklists.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    color: TemaApp.textoTerciario,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nenhum check-list finalizado neste aparelho ainda.',
                      style: TextStyle(color: TemaApp.textoSecundario),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          for (final checklist in checklistsVisiveis) ...[
            _buildCartaoChecklist(checklist, c),
            const SizedBox(height: 10),
          ],
          if (_meusChecklists.length > _limiteVisivel)
            OutlinedButton.icon(
              onPressed: () => _abrirModalLista(
                titulo: 'Meus Check-Lists',
                total: _meusChecklists.length,
                itemBuilder: (_, i) =>
                    _buildCartaoChecklist(_meusChecklists[i], c),
              ),
              icon: const Icon(Icons.list_alt_rounded),
              label: Text(
                'Ver todos os ${_meusChecklists.length} check-lists',
              ),
            ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: TemaApp.fundo,
      body: Column(
        children: [
          // Cabeçalho escuro
          Container(
            color: TemaApp.escuro,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ehTablet ? 24 : 16,
                  vertical: 16,
                ),
                child: ContainerResponsivo(
                  maxWidth: 1120,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PERFIL OPERADOR',
                              style: TextStyle(
                                color: TemaApp.ambar,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sessao.nome ?? 'Operador',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: TemaApp.escuroCard,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => confirmarSaida(context, sessao),
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Barra de notificação de erro NO TOPO (visibilidade imediata)
          if (erroTopo != null)
            BarraNotificacaoErro(
              mensagem: erroTopo,
              onFechar: () => setState(() => _erroLista = null),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await sincronizador.sincronizar();
                await _carregarTudo();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: Responsivo.paddingPagina(context),
                child: ContainerResponsivo(
                  maxWidth: 1120,
                  child: ehTablet
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 380, child: painelAcoes),
                            const SizedBox(width: 24),
                            Expanded(child: painelListas),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            painelAcoes,
                            const SizedBox(height: 22),
                            painelListas,
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalhoSecao({
    required String titulo,
    required int total,
    VoidCallback? onVerTodos,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$titulo ($total)',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: TemaApp.textoTerciario,
            ),
          ),
        ),
        if (onVerTodos != null)
          InkWell(
            onTap: onVerTodos,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Ver todos',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: TemaApp.azulAdmin,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLinhaRascunho(
    Map<String, dynamic> rascunho,
    Catalogo? c, {
    VoidCallback? onAposRemover,
  }) {
    final json = rascunho['json'] as Map<String, dynamic>;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: const Icon(Icons.edit_note_rounded, color: TemaApp.ambarEscuro),
      title: Text(
        'Rascunho · ${_dataTexto(json['data_turno'])}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
      ),
      subtitle: Text(
        'Salvo às ${_hm(DateTime.parse(rascunho['atualizado_em'] as String).toLocal())}',
        style: const TextStyle(fontSize: 12.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remover rascunho',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: TemaApp.perigo,
              size: 22,
            ),
            onPressed: () async {
              final removeu = await _confirmarRemoverRascunho(rascunho);
              if (removeu) onAposRemover?.call();
            },
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () => _abrirChecklist(c, rascunhoId: rascunho['id'] as String),
    );
  }

  Widget _buildCardRascunho(
    Map<String, dynamic> rascunho,
    Catalogo? c, {
    VoidCallback? onAposRemover,
  }) {
    return Card(
      child: _buildLinhaRascunho(rascunho, c, onAposRemover: onAposRemover),
    );
  }

  Widget _buildBannerConexao(Sincronizador sincronizador) {
    final online = sincronizador.redeDisponivel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: online ? TemaApp.sucessoFundo : TemaApp.ambarFundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: online ? TemaApp.sucessoBorda : TemaApp.ambarBorda,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: online ? TemaApp.sucesso : TemaApp.ambarEscuro,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online
                      ? 'Conectado à Base Central'
                      : 'Modo offline · sem internet',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: online ? TemaApp.sucesso : TemaApp.ambarEscuro,
                  ),
                ),
                if (sincronizador.pendentes > 0 ||
                    sincronizador.errosValidacao > 0)
                  Text(
                    '${sincronizador.pendentes} pendente(s) · ${sincronizador.errosValidacao} com erro',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: TemaApp.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sincronizar agora',
            onPressed: sincronizador.sincronizando
                ? null
                : sincronizador.sincronizar,
            icon: sincronizador.sincronizando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.sync_rounded,
                    color: online ? TemaApp.sucesso : TemaApp.ambarEscuro,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartaoCatalogo(CatalogoController cat, Catalogo? c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            cat.atualizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(
                    c == null
                        ? Icons.cloud_off_outlined
                        : Icons.check_circle_outline_rounded,
                    color: c == null ? TemaApp.ambarEscuro : TemaApp.sucesso,
                    size: 22,
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                c == null
                    ? 'Catálogo não baixado. Toque para atualizar.'
                    : '${c.codigo} v${c.versao} · ${c.itens.length} itens · ${c.equipamentos.length} guindastes',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TemaApp.textoSecundario,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar catálogo',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: cat.atualizar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartaoChecklist(Map<String, dynamic> checklist, Catalogo? c) {
    final status = (checklist['status'] ?? 'ENVIADO').toString().toUpperCase();
    final ehCorrecao = status == 'CORRECAO_SOLICITADA';
    final ehErro = status == 'ERRO_VALIDACAO';
    final ehVistado = status == 'VISTADO';
    final ehPendente = status == 'PENDENTE_ENVIO';
    final impedido = checklist['impedido'] == true;
    final editado = checklist['editado'] == true;
    final motivo = (checklist['motivo_correcao'] ?? '').toString().trim();

    return Material(
      color: ehCorrecao
          ? const Color(0xFFFFFBEB)
          : impedido && !ehVistado
          ? TemaApp.perigoFundo.withValues(alpha: 0.45)
          : TemaApp.superficie,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: ehPendente || ehErro
            ? null
            : () => _abrirDetalhe(c, checklist),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ehCorrecao
                  ? TemaApp.ambarEscuro
                  : ehErro || (impedido && !ehVistado)
                  ? TemaApp.perigo
                  : ehVistado
                  ? TemaApp.sucessoBorda
                  : TemaApp.borda,
              width: ehCorrecao || ehErro || (impedido && !ehVistado)
                  ? 1.6
                  : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _iconeStatusChecklist(status, impedido: impedido),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _seloStatus(status),
                                  if (impedido)
                                    const SeloStatus(
                                      texto: 'IMPEDIDO',
                                      icone: Icons.warning_amber_rounded,
                                      fundo: TemaApp.perigo,
                                      corTexto: Colors.white,
                                    ),
                                  if (editado)
                                    const SeloStatus(
                                      texto: 'Editado',
                                      icone: Icons.edit_outlined,
                                      fundo: TemaApp.azulFundo,
                                      corTexto: TemaApp.azulAdmin,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _dataTexto(checklist['data_turno']),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TemaApp.textoTerciario,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _nomeEquipamento(checklist, c),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: impedido && !ehVistado
                                ? TemaApp.perigo
                                : TemaApp.textoPrimario,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ehErro
                              ? 'Erro: ${checklist['ultimo_erro'] ?? 'revise os dados'}'
                              : 'Turno ${_rotuloTurno(checklist['turno']?.toString() ?? '-')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: ehErro
                                ? TemaApp.perigo
                                : TemaApp.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // FE-13: Cartão amarelo com motivo da correção + botão direto Corrigir
              if (ehCorrecao && motivo.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TemaApp.ambarFundo,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TemaApp.ambarBorda),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: TemaApp.ambarEscuro,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Motivo: $motivo',
                          style: const TextStyle(
                            color: TemaApp.textoPrimario,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: TemaApp.ambar,
                          foregroundColor: TemaApp.escuro,
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _abrirChecklist(
                          c,
                          rascunhoId: checklist['id'].toString(),
                          modoEdicao: true,
                          emCorrecaoSolicitada: true,
                          motivoCorrecao: motivo,
                        ),
                        child: const Text('Corrigir'),
                      ),
                    ],
                  ),
                ),
              ],
              if (ehVistado) ...[
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: TemaApp.sucesso,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Registro travado · Ver histórico →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TemaApp.sucesso,
                      ),
                    ),
                  ],
                ),
              ] else if (!ehPendente && !ehErro && !ehCorrecao) ...[
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Ver detalhes / Editar →',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: TemaApp.azulAdmin,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconeStatusChecklist(String status, {required bool impedido}) {
    final (IconData icone, Color cor, Color fundo, Color borda, String dica) =
        switch (status) {
          'VISTADO' => (
            Icons.verified_rounded,
            TemaApp.sucesso,
            TemaApp.sucessoFundo,
            TemaApp.sucessoBorda,
            'Vistado e travado',
          ),
          'CORRECAO_SOLICITADA' => (
            Icons.edit_note_rounded,
            TemaApp.ambarEscuro,
            TemaApp.ambarFundo,
            TemaApp.ambarBorda,
            'Correção solicitada',
          ),
          'ERRO_VALIDACAO' => (
            Icons.error_outline_rounded,
            TemaApp.perigo,
            TemaApp.perigoFundo,
            TemaApp.perigoBorda,
            'Erro de validação',
          ),
          'PENDENTE_ENVIO' => (
            Icons.cloud_upload_outlined,
            TemaApp.ambarEscuro,
            TemaApp.ambarFundo,
            TemaApp.ambarBorda,
            'Pendente de envio',
          ),
          _ when impedido => (
            Icons.warning_amber_rounded,
            Colors.white,
            TemaApp.perigo,
            TemaApp.perigo,
            'Equipamento impedido',
          ),
          _ => (
            Icons.cloud_done_outlined,
            TemaApp.sucesso,
            TemaApp.sucessoFundo,
            TemaApp.sucessoBorda,
            'Enviado',
          ),
        };

    return Tooltip(
      message: dica,
      child: Semantics(
        label: dica,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borda, width: 1.2),
          ),
          child: Icon(icone, color: cor, size: 24),
        ),
      ),
    );
  }

  Widget _seloStatus(String status) {
    return switch (status) {
      'CORRECAO_SOLICITADA' => const SeloStatus(
        texto: 'Correção solicitada',
        icone: Icons.edit_note_rounded,
        fundo: TemaApp.ambarFundo,
        corTexto: TemaApp.ambarEscuro,
      ),
      'VISTADO' => const SeloStatus(
        texto: 'Vistado',
        icone: Icons.verified_outlined,
        fundo: TemaApp.sucessoFundo,
        corTexto: TemaApp.sucesso,
      ),
      'ERRO_VALIDACAO' => const SeloStatus(
        texto: 'Erro de envio',
        icone: Icons.error_outline_rounded,
        fundo: TemaApp.perigoFundo,
        corTexto: TemaApp.perigo,
      ),
      'PENDENTE_ENVIO' => const SeloStatus(
        texto: 'Pendente de envio',
        icone: Icons.cloud_upload_outlined,
        fundo: TemaApp.ambarFundo,
        corTexto: TemaApp.ambarEscuro,
      ),
      _ => const SeloStatus(
        texto: 'Enviado',
        icone: Icons.check_circle_outline_rounded,
        fundo: TemaApp.sucessoFundo,
        corTexto: TemaApp.sucesso,
      ),
    };
  }
}

String _rotuloTurno(String turno) => switch (turno) {
  'T_08_14' => '08×14',
  'T_14_20' => '14×20',
  'T_20_02' => '20×02',
  'T_02_08' => '02×08',
  _ => turno,
};
