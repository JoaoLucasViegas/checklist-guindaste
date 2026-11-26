import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
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

  Future<void> _abrirChecklist(Catalogo? catalogo, {String? rascunhoId}) async {
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
        builder: (_) =>
            ChecklistFormPage(catalogo: catalogo!, rascunhoId: rascunhoId),
      ),
    );
    await _carregarRascunhos();
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dataChecklist(Map<String, dynamic> registro) {
    final json = registro['json'] as Map<String, dynamic>;
    final data = json['data_turno'] as String?;
    if (data == null || data.length < 10) return 'Data não informada';
    return data.split('-').reversed.join('/');
  }

  String _tituloEquipamento(Map<String, dynamic> registro, Catalogo? c) {
    final json = registro['json'] as Map<String, dynamic>;
    final eqId = json['equipamento_id'] as String?;
    if (c != null && eqId != null) {
      for (final eq in c.equipamentos) {
        if (eq.id == eqId) return eq.identificacao;
      }
    }
    return 'Check-List Diário';
  }

  String _resumoLinha(Map<String, dynamic> registro) {
    final json = registro['json'] as Map<String, dynamic>;
    final turno = (json['turno'] as String?) ?? '-';
    final hIni = json['horimetro_inicial']?.toString() ?? '';
    final hFim = json['horimetro_final']?.toString() ?? '';
    final horim = hIni.isNotEmpty
        ? ' · Horim. $hIni${hFim.isNotEmpty ? ' → $hFim' : ''}'
        : '';
    return 'Turno ${_rotuloTurno(turno)}$horim';
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

    final painelAcoes = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner de conexão (igual à referência)
        _buildBannerConexao(sincronizador),
        if (sincronizador.erro != null) ...[
          const SizedBox(height: 8),
          _bannerErro(sincronizador.erro!),
        ],
        const SizedBox(height: 14),

        // CTA principal Âmbar
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

        // Card discreto do catálogo
        _buildCartaoCatalogo(cat, c),
      ],
    );

    final painelListas = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rascunhos.isNotEmpty) ...[
          _tituloSecao('RASCUNHOS (${_rascunhos.length})'),
          const SizedBox(height: 10),
          for (final rascunho in _rascunhos) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: TemaApp.ambarFundo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: TemaApp.ambarEscuro,
                  ),
                ),
                title: Text(
                  'Rascunho · ${_dataChecklist(rascunho)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Salvo às ${_hm(DateTime.parse(rascunho['atualizado_em'] as String).toLocal())}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _abrirChecklist(
                  c,
                  rascunhoId: rascunho['id'] as String,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],

        _tituloSecao('MEUS CHECK-LISTS (${_filaEnvio.length})'),
        const SizedBox(height: 10),
        if (_carregandoRascunhos)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_erroRascunhos != null)
          _bannerErro(_erroRascunhos!)
        else if (_filaEnvio.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: const [
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
        else
          for (final checklist in _filaEnvio) ...[
            _buildCartaoChecklist(checklist, c),
            const SizedBox(height: 10),
          ],
      ],
    );

    return Scaffold(
      backgroundColor: TemaApp.fundo,
      body: Column(
        children: [
          // Cabeçalho escuro fiel à referência image_2631d7.png
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

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await sincronizador.sincronizar();
                await _carregarRascunhos();
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
    final status = checklist['status'] as String;
    final ehErro = status == 'ERRO_VALIDACAO';
    final ehEnviado = status == 'SINCRONIZADO';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SeloStatus(
                  texto: ehErro
                      ? 'Erro de envio'
                      : ehEnviado
                      ? 'Enviado'
                      : 'Pendente de envio',
                  icone: ehErro
                      ? Icons.error_outline_rounded
                      : ehEnviado
                      ? Icons.check_circle_outline_rounded
                      : Icons.cloud_upload_outlined,
                  fundo: ehErro
                      ? TemaApp.perigoFundo
                      : ehEnviado
                      ? TemaApp.sucessoFundo
                      : TemaApp.ambarFundo,
                  corTexto: ehErro
                      ? TemaApp.perigo
                      : ehEnviado
                      ? TemaApp.sucesso
                      : TemaApp.ambarEscuro,
                ),
                const Spacer(),
                Text(
                  _dataChecklist(checklist),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: TemaApp.textoTerciario,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _tituloEquipamento(checklist, c),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TemaApp.textoPrimario,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ehErro
                  ? 'Erro: ${checklist['ultimo_erro'] ?? 'revise os dados'}'
                  : _resumoLinha(checklist),
              style: TextStyle(
                fontSize: 13.5,
                color: ehErro ? TemaApp.perigo : TemaApp.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tituloSecao(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: TemaApp.textoTerciario,
      ),
    );
  }

  Widget _bannerErro(String texto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TemaApp.perigoFundo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TemaApp.perigoBorda),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: TemaApp.perigo,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _rotuloTurno(String turno) => switch (turno) {
  'T_08_14' => '08×14',
  'T_14_20' => '14×20',
  'T_20_02' => '20×02',
  'T_02_08' => '02×08',
  _ => turno,
};
