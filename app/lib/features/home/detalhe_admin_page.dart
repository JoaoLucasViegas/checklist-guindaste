import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
import '../../data/remote/api.dart';

class DetalheAdminPage extends StatefulWidget {
  final String checklistId;

  const DetalheAdminPage({super.key, required this.checklistId});

  @override
  State<DetalheAdminPage> createState() => _DetalheAdminPageState();
}

class _DetalheAdminPageState extends State<DetalheAdminPage> {
  bool _carregando = true;
  bool _processandoAcao = false;
  String? _erro;
  Map<String, dynamic>? _dados;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final api = context.read<Api>();
      final resp = await api.detalhe(widget.checklistId);
      if (!mounted) return;
      setState(() {
        _dados = Map<String, dynamic>.from(resp);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _vistar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.verified_outlined,
          color: TemaApp.sucesso,
          size: 34,
        ),
        title: const Text('Confirmar visto'),
        content: const Text(
          'Ao vistar, este checklist será travado e o operador não poderá mais editá-lo. Deseja continuar?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TemaApp.sucesso),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vistar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _processandoAcao = true);
    try {
      await context.read<Api>().vistar(widget.checklistId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist vistado e travado.')),
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao vistar: $e')),
      );
    } finally {
      if (mounted) setState(() => _processandoAcao = false);
    }
  }

  Future<void> _solicitarCorrecao() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.edit_note_rounded,
          color: TemaApp.ambarEscuro,
          size: 34,
        ),
        title: const Text('Solicitar correção'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Motivo (obrigatório)',
              hintText: 'Descreva o que o operador precisa corrigir...',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Informe o motivo da correção.';
              }
              return null;
            },
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Enviar solicitação'),
          ),
        ],
      ),
    );

    if (motivo == null || motivo.isEmpty || !mounted) return;

    setState(() => _processandoAcao = true);
    try {
      await context.read<Api>().solicitarCorrecao(widget.checklistId, motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correção solicitada ao operador.')),
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao solicitar correção: $e')),
      );
    } finally {
      if (mounted) setState(() => _processandoAcao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: TemaApp.perigo,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Erro ao carregar detalhe:\n$_erro',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _carregar,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : _buildConteudo(_dados!),
      bottomNavigationBar: (_dados == null || _carregando)
          ? null
          : _buildRodape(_dados!),
    );
  }

  Widget _buildConteudo(Map<String, dynamic> d) {
    final ehTablet = Responsivo.ehTablet(context);
    final itensBrutos = ((d['itens'] ?? d['respostas']) as List?) ?? const [];
    final itens = itensBrutos
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final itensProblema = itens.where((i) {
      final resp = (i['resposta'] ?? i['status'] ?? '')
          .toString()
          .toUpperCase();
      return resp == 'N' || resp == 'NAO' || resp == 'PROBLEMA';
    }).toList();

    final itensOk = itens.where((i) {
      final resp = (i['resposta'] ?? i['status'] ?? '')
          .toString()
          .toUpperCase();
      return resp != 'N' && resp != 'NAO' && resp != 'PROBLEMA';
    }).toList();

    final qtdCriticos = itensProblema.where((i) => i['critico'] == true).length;
    final impedido = d['impedido'] == true || qtdCriticos > 0;

    final obsGeral = (d['observacao_geral'] ?? d['observacao'] ?? '')
        .toString()
        .trim();
    final assinaturaB64 =
        (d['assinatura_operador'] ??
                d['assinatura_base64'] ??
                d['assinatura'] ??
                '')
            .toString()
            .trim();
    final eventosBrutos = (d['eventos'] as List?) ?? const [];
    final eventos = eventosBrutos
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final cardObs = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSecao('Observação geral', icone: Icons.notes_rounded),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              obsGeral.isEmpty ? 'Sem observação geral.' : obsGeral,
              style: TextStyle(
                color: obsGeral.isEmpty
                    ? TemaApp.textoTerciario
                    : TemaApp.textoPrimario,
              ),
            ),
          ),
        ),
      ],
    );

    final cardAssinatura = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSecao('Assinatura do operador', icone: Icons.draw_outlined),
        const SizedBox(height: 8),
        _buildAssinatura(assinaturaB64),
      ],
    );

    final cardMetadados = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSecao(
          'Metadados do preenchimento',
          icone: Icons.info_outline_rounded,
        ),
        const SizedBox(height: 8),
        _buildMetadados(d, itens),
      ],
    );

    final cardTimeline = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloSecao('Linha do tempo', icone: Icons.timeline_rounded),
        const SizedBox(height: 8),
        _buildLinhaDoTempo(eventos),
      ],
    );

    return RefreshIndicator(
      onRefresh: _carregar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsivo.paddingPagina(context),
        child: ContainerResponsivo(
          maxWidth: 1040,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Faixa de resumo
              _buildFaixaResumo(
                qtdOk: itensOk.length,
                qtdProblema: itensProblema.length,
                qtdCriticos: qtdCriticos,
                impedido: impedido,
              ),
              const SizedBox(height: 16),

              // 2. Cabeçalho completo
              _buildCabecalho(d, ehTablet),
              const SizedBox(height: 20),

              // 3. Itens com problema no topo (em destaque vermelho)
              if (itensProblema.isNotEmpty) ...[
                _tituloSecao(
                  'Itens com problema (${itensProblema.length})',
                  cor: TemaApp.perigo,
                  icone: Icons.error_outline_rounded,
                ),
                const SizedBox(height: 8),
                ...itensProblema.map(_buildCardItemProblema),
                const SizedBox(height: 18),
              ],

              // 4. Todos os itens OK logo abaixo (seção já aberta)
              _tituloSecao(
                'Itens OK (${itensOk.length})',
                icone: Icons.check_circle_outline_rounded,
                cor: TemaApp.sucesso,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (int i = 0; i < itensOk.length; i++) ...[
                      _buildLinhaItemOk(itensOk[i]),
                      if (i < itensOk.length - 1) const Divider(height: 1),
                    ],
                    if (itensOk.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhum item OK.'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5 & 6. Observação geral + Assinatura do operador
              if (ehTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cardObs),
                    const SizedBox(width: 16),
                    Expanded(child: cardAssinatura),
                  ],
                )
              else ...[
                cardObs,
                const SizedBox(height: 20),
                cardAssinatura,
              ],
              const SizedBox(height: 20),

              // 7 & 8. Metadados + Linha do tempo
              if (ehTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cardMetadados),
                    const SizedBox(width: 16),
                    Expanded(child: cardTimeline),
                  ],
                )
              else ...[
                cardMetadados,
                const SizedBox(height: 20),
                cardTimeline,
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaixaResumo({
    required int qtdOk,
    required int qtdProblema,
    required int qtdCriticos,
    required bool impedido,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: impedido ? TemaApp.perigoFundo : TemaApp.azulFundo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: impedido ? TemaApp.perigo : TemaApp.azulAdmin,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            impedido
                ? Icons.warning_amber_rounded
                : Icons.fact_check_outlined,
            color: impedido ? TemaApp.perigo : TemaApp.escuro,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$qtdOk OK · $qtdProblema com problema · $qtdCriticos crítico${qtdCriticos == 1 ? '' : 's'}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: impedido ? TemaApp.perigo : TemaApp.escuro,
              ),
            ),
          ),
          if (impedido)
            const SeloStatus(
              texto: 'IMPEDIDO',
              fundo: TemaApp.perigo,
              corTexto: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildCabecalho(Map<String, dynamic> d, bool ehTablet) {
    final cab = (d['cabecalho'] is Map)
        ? Map<String, dynamic>.from(d['cabecalho'] as Map)
        : d;
    final operadorMap = d['operador'] as Map?;
    final operador = operadorMap?['nome'] ?? d['operador_nome'] ?? '-';
    final horimetroIni =
        cab['horimetro_inicial'] ??
        d['horimetro_inicial'] ??
        d['horimetro_motor_inicial'] ??
        '-';
    final horimetroFim =
        cab['horimetro_final'] ??
        d['horimetro_final'] ??
        d['horimetro_motor_final'] ??
        '-';
    final combustivel =
        cab['combustivel_pct'] ??
        d['combustivel_pct'] ??
        d['combustivel'] ??
        d['nivel_combustivel'] ??
        '-';
    final combustivelTexto = combustivel == '-' ? '-' : '$combustivel%';
    final entrada = cab['hora_entrada'] ?? d['hora_entrada'] ?? d['entrada'] ?? '-';
    final saida = cab['hora_saida'] ?? d['hora_saida'] ?? d['saida'] ?? '-';

    final colunaEsq = [
      _linhaInfo('Operador', '$operador'),
      _linhaInfo('Equipamento', '${d['equipamento'] ?? '-'}'),
      _linhaInfo('Local / Cais', '${d['local'] ?? '-'}'),
      _linhaInfo('Navio', '${cab['navio'] ?? d['navio'] ?? '-'}'),
    ];
    final colunaDir = [
      _linhaInfo(
        'Turno / Data',
        '${d['turno'] ?? '-'} · ${d['data_turno'] ?? '-'}',
      ),
      _linhaInfo('Horímetros', 'Inicial: $horimetroIni · Final: $horimetroFim'),
      _linhaInfo('Combustível', combustivelTexto),
      _linhaInfo('Entrada / Saída', '$entrada / $saida'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 20,
                  color: TemaApp.escuro,
                ),
                SizedBox(width: 8),
                Text(
                  'Cabeçalho do checklist',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(),
            ),
            if (ehTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: colunaEsq)),
                  const SizedBox(width: 24),
                  Expanded(child: Column(children: colunaDir)),
                ],
              )
            else
              Column(children: [...colunaEsq, ...colunaDir]),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItemProblema(Map<String, dynamic> item) {
    final ordem = item['ordem'] ?? item['numero'] ?? item['item_numero'] ?? '';
    final titulo = item['titulo'] ?? item['descricao'] ?? 'Item';
    final critico = item['critico'] == true;
    final obs = (item['observacao'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: TemaApp.perigoFundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: TemaApp.perigo, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cancel_rounded,
                    color: TemaApp.perigo,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${ordem.toString().isNotEmpty ? '$ordem. ' : ''}$titulo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: TemaApp.perigo,
                      ),
                    ),
                  ),
                  if (critico) ...[
                    const SizedBox(width: 8),
                    const SeloStatus(
                      texto: 'CRÍTICO',
                      fundo: TemaApp.perigo,
                      corTexto: Colors.white,
                    ),
                  ],
                ],
              ),
              if (obs.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TemaApp.perigoBorda),
                  ),
                  child: Text(
                    'Observação: $obs',
                    style: const TextStyle(
                      color: TemaApp.textoPrimario,
                      fontWeight: FontWeight.w600,
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

  Widget _buildLinhaItemOk(Map<String, dynamic> item) {
    final ordem = item['ordem'] ?? item['numero'] ?? item['item_numero'] ?? '';
    final titulo = item['titulo'] ?? item['descricao'] ?? 'Item';
    final resp = (item['resposta'] ?? 'S').toString().toUpperCase();
    final ehNa = resp == 'NA';
    final origem = (item['origem'] ??
            (item['marcado_em_lote'] == true || item['lote'] == true
                ? 'lote'
                : 'manual'))
        .toString()
        .toLowerCase();
    final ehLote = origem == 'lote';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(
        ehNa ? Icons.remove_circle_outline : Icons.check_circle_outline_rounded,
        color: ehNa ? TemaApp.neutro : TemaApp.sucesso,
        size: 22,
      ),
      title: Text(
        '${ordem.toString().isNotEmpty ? '$ordem. ' : ''}$titulo',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: TemaApp.textoPrimario,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ehNa) ...[
            const SeloStatus(
              texto: 'N/A',
              fundo: TemaApp.neutroFundo,
              corTexto: TemaApp.neutro,
            ),
            const SizedBox(width: 6),
          ],
          SeloStatus(
            texto: ehLote ? 'lote' : 'manual',
            fundo: ehLote ? TemaApp.azulFundo : TemaApp.neutroFundo,
            corTexto: ehLote ? TemaApp.escuro : TemaApp.textoSecundario,
          ),
        ],
      ),
    );
  }

  Widget _buildAssinatura(String assinaturaB64) {
    Uint8List? bytes;
    if (assinaturaB64.isNotEmpty) {
      try {
        final limpo = assinaturaB64.contains(',')
            ? assinaturaB64.split(',').last
            : assinaturaB64;
        bytes = base64Decode(limpo);
      } catch (_) {
        bytes = null;
      }
    }

    return Card(
      child: Container(
        height: 150,
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.contain)
            : const Text(
                'Sem assinatura registrada.',
                style: TextStyle(color: TemaApp.textoTerciario),
              ),
      ),
    );
  }

  Widget _buildMetadados(Map<String, dynamic> d, List itens) {
    final meta = (d['metadados'] is Map)
        ? Map<String, dynamic>.from(d['metadados'] as Map)
        : d;
    final inicio =
        meta['inicio_preenchimento_em'] ??
        d['iniciado_em'] ??
        d['inicio_preenchimento_em'] ??
        d['inicio_preenchimento'] ??
        '-';
    final fim =
        meta['finalizado_em'] ??
        d['finalizado_em'] ??
        d['fim_preenchimento'] ??
        '-';

    int? segundos;
    final rawTempo =
        meta['duracao_segundos'] ??
        d['tempo_preenchimento_seg'] ??
        d['duracao_segundos'];
    if (rawTempo is int) {
      segundos = rawTempo;
    } else if (rawTempo is num) {
      segundos = rawTempo.toInt();
    }

    final usouLote = meta['usou_lote'] == true || d['usou_lote'] == true;
    final qtdLote =
        meta['itens_marcados_lote'] ??
        d['itens_marcados_lote'] ??
        d['qtd_itens_lote'] ??
        itens
            .where(
              (i) =>
                  i['marcado_em_lote'] == true ||
                  i['lote'] == true ||
                  (i['origem']?.toString().toLowerCase() == 'lote'),
            )
            .length;

    final tempoTexto = segundos == null
        ? '-'
        : segundos < 60
        ? '${segundos}s'
        : '${segundos ~/ 60}min ${segundos % 60}s';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linhaInfo('Início', '$inicio'),
            _linhaInfo('Fim', '$fim'),
            _linhaInfo('Tempo total', tempoTexto),
            if (segundos != null && segundos < 60)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const SeloStatus(
                  texto: 'Preenchido em menos de 1 min',
                  icone: Icons.schedule_rounded,
                  fundo: TemaApp.ambarFundo,
                  corTexto: TemaApp.ambarEscuro,
                ),
              ),
            _linhaInfo(
              'Uso de lote',
              usouLote ? 'Sim ($qtdLote itens)' : 'Não',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaDoTempo(List<Map<String, dynamic>> eventos) {
    if (eventos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum evento registrado.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < eventos.length; i++) ...[
            _buildItemEvento(eventos[i]),
            if (i < eventos.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildItemEvento(Map<String, dynamic> ev) {
    final tipo = (ev['tipo'] ?? ev['acao'] ?? 'Evento').toString();
    final autor = (ev['autor'] ?? ev['usuario'] ?? '').toString();
    final data = (ev['em'] ?? ev['data_hora'] ?? ev['criado_em'] ?? '')
        .toString();
    final diff = ev['diff'] ?? ev['detalhes'] ?? ev['motivo'];

    IconData icone = Icons.history_rounded;
    Color cor = TemaApp.azulAdmin;
    final tipoLower = tipo.toLowerCase();
    if (tipoLower.contains('edit')) {
      icone = Icons.edit_outlined;
      cor = TemaApp.ambarEscuro;
    } else if (tipoLower.contains('vist')) {
      icone = Icons.verified_outlined;
      cor = TemaApp.sucesso;
    } else if (tipoLower.contains('corre')) {
      icone = Icons.report_problem_outlined;
      cor = TemaApp.perigo;
    } else if (tipoLower.contains('envi')) {
      icone = Icons.send_outlined;
      cor = TemaApp.escuro;
    }

    final titulo = autor.isNotEmpty
        ? '$tipo por $autor${data.isNotEmpty ? ' — $data' : ''}'
        : '$tipo${data.isNotEmpty ? ' — $data' : ''}';

    return ListTile(
      dense: true,
      leading: Icon(icone, size: 22, color: cor),
      title: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: diff != null && diff.toString().trim().isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(diff.toString()),
            )
          : null,
    );
  }

  Widget _buildRodape(Map<String, dynamic> d) {
    final status = (d['status'] ?? '').toString().toUpperCase();
    final vistado = status == 'VISTADO' || d['vistado_em'] != null;

    if (vistado) {
      final quem = d['vistado_por_nome'] ?? d['vistado_por'] ?? 'Administrador';
      final quando = d['vistado_em'] ?? '-';
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: TemaApp.sucessoFundo,
            border: Border(top: BorderSide(color: TemaApp.sucessoBorda)),
          ),
          child: ContainerResponsivo(
            maxWidth: 1040,
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: TemaApp.sucesso),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vistado por $quem em $quando — registro travado',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: TemaApp.sucesso,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: TemaApp.superficie,
          border: Border(top: BorderSide(color: TemaApp.borda)),
        ),
        child: ContainerResponsivo(
          maxWidth: 1040,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _processandoAcao ? null : _solicitarCorrecao,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('SOLICITAR CORREÇÃO'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: TemaApp.sucesso,
                    ),
                    onPressed: _processandoAcao ? null : _vistar,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('VISTAR'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tituloSecao(String texto, {Color? cor, IconData? icone}) {
    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 20, color: cor ?? TemaApp.escuro),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cor ?? TemaApp.textoPrimario,
            ),
          ),
        ),
      ],
    );
  }

  Widget _linhaInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              '$rotulo:',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: TemaApp.textoSecundario,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: TemaApp.textoPrimario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
